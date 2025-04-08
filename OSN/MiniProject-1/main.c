#include "all.h"
#include "activities.h"
#include "mysignal.h"
#include "iman.h"
#include "myshrc.h"
#include "foreground_background.h"
#include "neonate.h"
#define MAX_INPUT_SIZE 4096
#define MAX_JOBS 100
#define MAX_BG_PROCESSES 100
char fg_command[4096];
// char *shell_home_directory = NULL;
char extra_prompt[4096];
extern char command_log[MAX_COMMANDS][COMMAND_LEN];
bg_process bg_processes[MAX_BG_PROCESSES];
int bg_process_count = 0;
extern int log_count;
int last_command_time = 0;
int job_count = 0;  // Number of active jobs
extern pid_t fg_pid;
pid_t pid_fg=-1;

void add_command_to_bg_list(pid_t pid, const char *command) {
    if (bg_process_count < MAX_BG_PROCESSES) {
        bg_processes[bg_process_count].pid = pid;
        strncpy(bg_processes[bg_process_count].command, command, 255);
        bg_processes[bg_process_count].command[255] = '\0'; // Ensure null termination
        bg_processes[bg_process_count].job_id = ++job_count; // Increment job count and assign job ID
        bg_processes[bg_process_count].state = RUNNING; // Set the state
        bg_process_count++;
        // printf("Added background process: PID=%d, Command=%s\n", pid, command); // Debugging
    } else {
        printf("\033[1;31mMaximum background processes limit reached.\033[0m\n"); // Red color
    }
}

void remove_completed_bg_process(pid_t pid) {
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].pid == pid) {
            // Shift the remaining processes
            for (int j = i; j < bg_process_count - 1; j++) {
                bg_processes[j] = bg_processes[j + 1];
            }
            bg_process_count--;
            printf("Removed completed process: PID=%d\n", pid); // Debugging
            void check_and_update_processes();
            break;
        }
    }
}

void check_bg_processes() {
    int status;
    pid_t pid;
    
    for (int i = 0; i < bg_process_count; i++) {
        pid = waitpid(bg_processes[i].pid, &status, WNOHANG);
        
        if (pid == 0) {
            // Process is still running, no need to set state again
            continue;
        } else if (pid > 0) {
            // Process has finished (either exited or terminated)
            if (WIFEXITED(status)) {
                bg_processes[i].state = COMPLETED;
                printf("[%d]  Done                    %s\n", bg_processes[i].job_id, bg_processes[i].command);
            } else if (WIFSIGNALED(status)) {
                bg_processes[i].state = TERMINATED;
                printf("[%d]  Terminated by signal %d  %s\n", bg_processes[i].job_id, WTERMSIG(status), bg_processes[i].command);
            }
        }
    }
}

void execute_background(char *command) {
    char *original_command = strdup(command);  // Duplicate original command
    // Tokenize the command
    char *args[256];
    int arg_count = 0;
    char *token = strtok(command, " ");
    while (token != NULL && arg_count < 255) {
        args[arg_count++] = token;
        token = strtok(NULL, " ");
    }
    args[arg_count] = NULL;  // Null-terminate the arguments array
    pid_t pid = fork();
    if (pid == 0) {
        // Child process
        if (arg_count > 0) {
            // Special command handling for sleep
            if (strcmp(args[0], "sleep") == 0) {
                if (arg_count > 1) {
                    int seconds = atoi(args[1]);
                    if (seconds > 0) {
                        sleep(seconds);
                    } else {
                        fprintf(stderr, "\033[1;31mInvalid sleep time\033[0m\n"); // Red color
                    }
                } else {
                    fprintf(stderr, "\033[1;31msleep: missing operand\033[0m\n"); // Red color
                }
                exit(0);
            }
            // Special command handling for echo
            else if (strcmp(args[0], "echo") == 0) {
                for (int i = 1; i < arg_count; i++) {
                    printf("%s ", args[i]);
                }
                printf("\n");
                exit(0);
            }
            // Detach the background process from the terminal
            else {
                // Redirect stdin, stdout, and stderr to /dev/null
                fclose(stdin);
                fclose(stdout);
                fclose(stderr);
                stdin = fopen("/dev/null", "r");
                stdout = fopen("/dev/null", "w");
                stderr = fopen("/dev/null", "w");
                // Execute the command (including vim or vi)
                if (execvp(args[0], args) == -1) {
                    perror("execvp failed");
                    exit(EXIT_FAILURE);
                }
            }
        } else {
            fprintf(stderr, "\033[1;31mNo command to execute\033[0m\n"); // Red color
            exit(EXIT_FAILURE);
        }
    } else if (pid > 0) {
        // Parent process
        printf("[%d] %d\n", job_count + 1, pid);
        add_command_to_bg_list(pid, original_command);
    } 
    free(original_command);  // Free the duplicated command
}
void execute_foreground(char *command, char *shell_home_directory, char **last_directory) {
    char *original_command = strdup(command);
    int background = 0;
    char *input_file = NULL;
    char *output_file = NULL;
    int append_mode = 0;
     time_t start_time, end_time;
     int elapsed;
    //  printf("final:%s",command);
    //   process_command(command);

   if (command[strlen(command) - 1] == '&') {
        background = 1;
        command[strlen(command) - 1] = '\0'; 
    }
    // Handle I/O redirection
    char *redirect_in = strchr(command, '<');
    char *redirect_out = strstr(command, ">>");  // Look for ">>" for append
    if (!redirect_out) {
        redirect_out = strchr(command, '>');  // Fall back to ">" if no ">>" is found
    }
    int saved_stdin = dup(STDIN_FILENO);
    int saved_stdout = dup(STDOUT_FILENO);
    if (redirect_in) {
        *redirect_in = '\0';
        input_file = strtok(redirect_in + 1, " \t");
        int input_fd = open(input_file, O_RDONLY);
        if (input_fd < 0) {
          fprintf(stderr, "\033[0;31mNo such input file found!\033[0m\n");
            free(original_command);
            return;
        }
        dup2(input_fd, STDIN_FILENO);  // Redirect input
        close(input_fd);
    }
    if (redirect_out) {
        int output_fd;
        if (strncmp(redirect_out, ">>", 2) == 0) {
            append_mode = 1;
            *redirect_out = '\0';  // Split the command at ">>"
            output_file = strtok(redirect_out + 2, " \t");
        } else {
            *redirect_out = '\0';  // Split the command at '>'
            output_file = strtok(redirect_out + 1, " \t");
        }
        int flags = O_CREAT | O_WRONLY | (append_mode ? O_APPEND : O_TRUNC);
        output_fd = open(output_file, flags, 0644);
        if (output_fd < 0) {
           fprintf(stderr, "\033[0;31mFailed to open output file\033[0m\n");
            free(original_command);
            return;
        }
        dup2(output_fd, STDOUT_FILENO);  // Redirect output
        close(output_fd);
    }
     start_time = time(NULL);
    // Tokenize and handle command logic
    char *token = strtok(command, " ");
    if (token) {
        if (strcmp(token, "hop") == 0) {
            token = strtok(NULL, " ");
            while (token) {
                hop(token, shell_home_directory, last_directory);
                token = strtok(NULL, " ");
            }
        } else if (strchr(token, '|')) {
            printf("Pipe detected in command: '%s'\n", command);
            handle_pipes(command);
        } else if (strcmp(token, "echo") == 0) {
            token = strtok(NULL, " ");
            int suppress_newline = 0;
            if (token && strcmp(token, "-n") == 0) {
                suppress_newline = 1;
                token = strtok(NULL, " ");
            }
            while (token) {
                printf("%s", token);
                token = strtok(NULL, " ");
                if (token) printf(" "); // Add a space between arguments
            }
            if (!suppress_newline) {
                printf("\n");
            }
        } else if (strcmp(token, "seek") == 0) {
            int only_dirs = 0, only_files = 0, execute_flag = 0;
            char *target = NULL;
            char *directory = ".";
            while ((token = strtok(NULL, " ")) != NULL) {
                if (strcmp(token, "-d") == 0) {
                    only_dirs = 1;
                } else if (strcmp(token, "-f") == 0) {
                    only_files = 1;
                } else if (strcmp(token, "-e") == 0) {
                    execute_flag = 1;
                } else if (target == NULL) {
                    target = token;
                } else {
                    directory = token;
                }
            }
            if (target) {
                seek(target, directory, only_dirs, only_files, execute_flag);
            } else {
                  fprintf(stderr, "\033[0;31mseek: missing target argument\033[0m\n");
            }
        } else if (strcmp(token, "reveal") == 0) {
            int op_a = 0, op_l = 0;
            token = strtok(NULL, " ");
            if (token && strcmp(token, "-") == 0) {
                if (*last_directory && **last_directory) {
                    reveal(*last_directory, op_a, op_l);
                } else {
                    fprintf(stderr, "\033[0;31mreveal: OLDPWD not set\033[0m\n");
                }
                return;
            }
            while (token && token[0] == '-') {
                size_t len = strlen(token);
                for (size_t i = 1; i < len; i++) {
                    if (token[i] == 'a') op_a = 1;
                    else if (token[i] == 'l') op_l = 1;
                   else fprintf(stderr, "\033[0;31mreveal: invalid option -- '%c'\033[0m\n", token[i]);
                }
                token = strtok(NULL, " ");
            }
            char *directory = token ? token : ".";
            reveal(directory, op_a, op_l);
        }
        //  else if (strcmp(token, "sleep") == 0) {
        //     token = strtok(NULL, " ");
        //     if (token) {
        //         int duration = atoi(token);
        //         if (duration > 0) {
        //             if (background) {
        //                 execute_background(original_command);
        //             } else {
        //                 time_t start_time = time(NULL);
        //                 sleep(duration);
        //                 time_t end_time = time(NULL);
        //                 int elapsed = (int)(end_time - start_time);
        //                 last_command_time = elapsed; // Store the time of the last command
        //                 // if (elapsed > 2) {
        //                 //     printf("%s : %ds\n", original_command, elapsed);
        //                 // }
        //             }
        //         } else {
        //             fprintf(stderr, "sleep: invalid duration '%s'\n", token);
        //         }
        //     } else {
        //         fprintf(stderr, "sleep: missing duration\n");
        //     }
        // }
         else if (strcmp(token, "log") == 0) {
            token = strtok(NULL, " ");
            if (token && strcmp(token, "purge") == 0) {
                clear_log();
                return;
            } else if (token && strcmp(token, "execute") == 0) {
                token = strtok(NULL, " ");
                if (token) {
                    int index = atoi(token);
                    execute_log_command(index, shell_home_directory, last_directory);
                } else {
                    fprintf(stderr, "\033[0;31mError: No index provided for log execute\033[0m\n");
                }
                return;
            }
            handle_log_command();
        } else if (strcmp(token, "proclore") == 0) {
            token = strtok(NULL, " ");
            proclore(token);
        } else if (strcmp(token, "activities") == 0) {
            // check_bg_processes();
            list_activities();
        } else if (strncmp(token, "ping", 4) == 0) {
    int pid, signal;
    if (sscanf(command + 5, "%d %d", &pid, &signal) == 2) {
        send_signal_to_process(pid, signal);
    } else {
        printf("Invalid command format. Use: ping <pid> <signal>\n");
    }
}

        else if(strcmp(token,"fg")==0){
            token = strtok(NULL, " ");
            if (token) {
                int pid = atoi(token);
                fg(pid);
            } else {
                fprintf(stderr, "\033[0;31mfg: missing pid\033[0m\n");
            }
        }
        else if(strcmp(token,"bg")==0){
            token = strtok(NULL, " ");
            if (token) {
                int pid = atoi(token);
                bg(pid);
            } else {
               fprintf(stderr, "\033[0;31mbg: missing pid\033[0m\n");
            }
        }
        // else if(strcmp(token,"alias")==0){
        //      process_command(command);
        // }
        else if (strcmp(token, "iMan") == 0) {
        char *man_command = strtok(NULL, " ");
        if (man_command) {
            // Create an instance of HttpResponse
            struct HttpResponse response;
            memset(response.data, 0, sizeof(response.data));
            fetch_man_page(man_command, &response);
        } else {
             fprintf(stderr, "\033[0;31miMan: missing command name\033[0m\n");
        }
    }
    else if(strcmp(token, "neonate") == 0){
         token = strtok(NULL, " ");
    if (token && strcmp(token, "-n") == 0) {
        token = strtok(NULL, " ");
        if (token) {
            int time_arg = atoi(token);
            if (time_arg > 0) {
                neonate_n(time_arg);
            } else {
                 fprintf(stderr, "\033[0;31mneonate: invalid time argument '%s'\033[0m\n", token);
            }
        } else {
            fprintf(stderr, "\033[0;31mneonate: missing time argument\033[0m\n");
        }
    }
    }
    
   else {
    char *args[100];
    int i = 0;
    strcpy(fg_command,original_command);
                char *arg = strtok(original_command, " ");  // Use original command
                while (arg != NULL) {
                    args[i++] = arg;
                    arg = strtok(NULL, " ");
                }
                args[i] = NULL;
            // External command handling (e.g., "cat neww.txt")
            pid_t pid = fork();
            if (pid == 0) {  // Child process
                // printf("hu\n");
                  // Null-terminate the argument list

                if (execvp(args[0], args) < 0) {
                   fprintf(stderr, "\033[0;31mexecvp failed\033[0m\n");
                    exit(EXIT_FAILURE);
                }
            } else if (pid > 0) {  // Parent process
                
                if (!background) {
                     pid_fg = pid;
                    int status;
                    
                    // Wait for the foreground process to finish
                    waitpid(pid, &status, WUNTRACED);
                    pid_fg = -1;
    
                } else {
                    printf("Background process PID: %d\n", pid);
                }
            } else {
                fprintf(stderr, "\033[0;31mfork failed\033[0m\n");
            }
        }
    }
    
    end_time = time(NULL);
    elapsed = (int)(end_time - start_time);
    // If process took more than 2 seconds, print process name and elapsed time
    if (elapsed > 2) {
        end_time = time(NULL);
elapsed = (int)(end_time - start_time);
// If process took more than 2 seconds, append process name and elapsed time to extra_prompt
if (elapsed > 2) {
    char elapsed_info[256];  // Adjust the size as needed
    snprintf(elapsed_info, sizeof(elapsed_info), "%s: %d seconds", command, elapsed);

    if (strlen(extra_prompt) > 0) {
            // Append with a semicolon if extra_prompt is not empty
            strncat(extra_prompt, "; ", sizeof(extra_prompt) - strlen(extra_prompt) - 1);
        }
        // Append the command and elapsed time to extra_prompt
        strncat(extra_prompt, elapsed_info, sizeof(extra_prompt) - strlen(extra_prompt) - 1);
    }

    }
    // Restore original I/O redirection
    if (input_file) dup2(saved_stdin, STDIN_FILENO);
    if (output_file) dup2(saved_stdout, STDOUT_FILENO);
    close(saved_stdin);
    close(saved_stdout);
    free(original_command);
    // if (resolved_command) free(resolved_command);
}
void process_input(char *input, char *shell_home_directory, char **last_directory) {
    char trimmed_input[MAX_INPUT_SIZE];
    strncpy(trimmed_input, input, MAX_INPUT_SIZE - 1);
    trimmed_input[MAX_INPUT_SIZE - 1] = '\0'; // Ensure null termination
    char *start = trimmed_input;
    while (*start == ' ') start++;
    char *end = start + strlen(start) - 1;
    while (end > start && *end == ' ') end--;
    *(end + 1) = '\0';
    if (*start == '\0') {
        return;
    }
    if (strchr(start, '|')) {
        handle_pipes(start);
        return; // Exit early as pipes are handled separately
    }
    if (strstr(start, "log") == NULL) {
        // Assuming command_log and log_count are defined elsewhere
        add_to_log(command_log, &log_count, start);
    }
    char *command_start = start;
    while (*command_start != '\0') {
        char *command_end = command_start;
        int inside_quote = 0;
        while (*command_end != '\0') {
            if (*command_end == '\'' || *command_end == '\"') {
                inside_quote = !inside_quote;
            } else if (*command_end == ';' && !inside_quote) {
                break;
            }
            command_end++;
        }
        char command[MAX_INPUT_SIZE];
        strncpy(command, command_start, command_end - command_start);
        command[command_end - command_start] = '\0';
        char *cmd_start = command;
        while (*cmd_start == ' ') cmd_start++;
        char *cmd_end = cmd_start + strlen(cmd_start) - 1;
        while (cmd_end > cmd_start && *cmd_end == ' ') cmd_end--;
        *(cmd_end + 1) = '\0';
        if (*cmd_start != '\0') {
            if (strchr(cmd_start, '&')) {
                execute_background(cmd_start);
            } else {
                // printf("execute\n");
                execute_foreground(cmd_start, shell_home_directory, last_directory);
            }
        }
        command_start = (*command_end == ';') ? command_end + 1 : command_end;
    }
    // check_bg_processes();
}

int main() {
    // printf("Starting main function...\n");
    // fflush(stdout);
    // printf("hi");
    // fflush(stdout);
    char input[MAX_INPUT_SIZE];
    char shell_home_directory[PATH_MAX];
    char *last_directory = NULL;
    initialize_signal_handlers();
    // printf("Signal handlers initialized.\n");
    //   load_myshrc("myshrc.txt"); 
    signal(SIGINT, sigint_handler);
    signal(SIGTSTP, sigtstp_handler);
    signal(SIGQUIT, sigquit_handler);
    // load_aliases(".myshrc");
    load_log(command_log, &log_count);
    get_current_directory(shell_home_directory, sizeof(shell_home_directory));
    // Load .myshrc configuration file
//load_myshrc(shell_home_directory);
    while (1) {
        check_bg_processes();
        display_prompt(shell_home_directory,extra_prompt);
        // printf("hi");
        fflush(stdout);  
        if (fgets(input, MAX_INPUT_SIZE, stdin)) {
            input[strcspn(input, "\n")] = 0;  // Remove newline character
        } else {
            break;
        }
        if (strlen(input) == 0) {
            continue;  // Skip empty input
        }
        // Create a copy of the input to log later
        char original_input[MAX_INPUT_SIZE];
        strncpy(original_input, input, MAX_INPUT_SIZE);
        // Check if command is background (ends with '&')
        int background = 0;
        if (input[strlen(input) - 1] == '&') {
            background = 1;
            input[strlen(input) - 1] = '\0';  // Remove the '&'
        }
         // Resolve aliases before executing the command
        // resolve_alias(input);
        if (background) {
            execute_background(input);
        } else {
            process_input(input, shell_home_directory, &last_directory);
        }
        
       if (strstr(original_input, "log") == NULL) {
            add_to_log(command_log, &log_count, original_input);  // Log the full command, including '&'
        }
    }
    if (last_directory) {
        free(last_directory);
    }
    return 0;
}