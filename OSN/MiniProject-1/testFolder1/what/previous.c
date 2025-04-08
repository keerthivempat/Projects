#include "all.h"
#include "activities.h"
#define MAX_INPUT_SIZE 4096
#define MAX_JOBS 100
#define MAX_BG_PROCESSES 100
extern char command_log[MAX_COMMANDS][COMMAND_LEN];
bg_process bg_processes[MAX_BG_PROCESSES];
int bg_process_count = 0;
extern int log_count;
int last_command_time = 0;
int job_count = 0;  // Number of active jobs
// Function to add a background job to the array
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
        printf("Maximum background processes limit reached.\n");
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
            // Process is still running
            bg_processes[i].state = RUNNING;
        } else if (pid > 0) {
            // Process has completed
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
    char *resolved_command = resolve_alias(command);  // Assume resolve_alias is implemented
    if (resolved_command) {
        command = resolved_command;
    }
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
                        fprintf(stderr, "Invalid sleep time\n");
                    }
                } else {
                    fprintf(stderr, "sleep: missing operand\n");
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
            fprintf(stderr, "No command to execute\n");
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
    char *resolved_command = resolve_alias(command);
    if (resolved_command) {
        command = resolved_command;
    }
    char *original_command = strdup(command);
    int background = 0;
    char *input_file = NULL;
    char *output_file = NULL;
    int append_mode = 0;
    // Check if the command is to be executed in the background
    if (command[strlen(command) - 1] == '&') {
        background = 1;
        command[strlen(command) - 1] = '\0';  // Remove the '&' from the command
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
            perror("No such input file found!");
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
            perror("Failed to open output file");
            free(original_command);
            return;
        }
        dup2(output_fd, STDOUT_FILENO);  // Redirect output
        close(output_fd);
    }
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
                fprintf(stderr, "seek: missing target argument\n");
            }
        } else if (strcmp(token, "reveal") == 0) {
            int op_a = 0, op_l = 0;
            token = strtok(NULL, " ");
            if (token && strcmp(token, "-") == 0) {
                if (*last_directory && **last_directory) {
                    reveal(*last_directory, op_a, op_l);
                } else {
                    fprintf(stderr, "reveal: OLDPWD not set\n");
                }
                return;
            }
            while (token && token[0] == '-') {
                size_t len = strlen(token);
                for (size_t i = 1; i < len; i++) {
                    if (token[i] == 'a') op_a = 1;
                    else if (token[i] == 'l') op_l = 1;
                    else fprintf(stderr, "reveal: invalid option -- '%c'\n", token[i]);
                }
                token = strtok(NULL, " ");
            }
            char *directory = token ? token : ".";
            reveal(directory, op_a, op_l);
        } else if (strcmp(token, "sleep") == 0) {
            token = strtok(NULL, " ");
            if (token) {
                int duration = atoi(token);
                if (duration > 0) {
                    if (background) {
                        execute_background(original_command);
                    } else {
                        time_t start_time = time(NULL);
                        sleep(duration);
                        time_t end_time = time(NULL);
                        int elapsed = (int)(end_time - start_time);
                        last_command_time = elapsed; // Store the time of the last command
                        if (elapsed > 2) {
                            printf("%s : %ds\n", original_command, elapsed);
                        }
                    }
                } else {
                    fprintf(stderr, "sleep: invalid duration '%s'\n", token);
                }
            } else {
                fprintf(stderr, "sleep: missing duration\n");
            }
        } else if (strcmp(token, "log") == 0) {
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
                    fprintf(stderr, "Error: No index provided for log execute\n");
                }
                return;
            }
            handle_log_command();
        } else if (strcmp(token, "proclore") == 0) {
            token = strtok(NULL, " ");
            proclore(token);
        } else if (strcmp(token, "activities") == 0) {
            check_bg_processes();
            list_activities();
        } else {
            // External command handling
            pid_t pid = fork();
            if (pid == 0) { // Child process
                // Execute the external command
                char *args[100]; // Adjust size based on your needs
                int i = 0;
                char *token = strtok(original_command, " ");
                while (token != NULL) {
                    args[i++] = token;
                    token = strtok(NULL, " ");
                }
                args[i] = NULL; // Null-terminate the argument list
                execvp(args[0], args); // Execute the external command
                perror("execvp failed"); // In case execvp fails
                exit(EXIT_FAILURE);
            } else if (pid < 0) { // Error in forking
                perror("fork failed");
            } else { // Parent process
                wait(NULL); // Wait for the child process to complete
            }
        }
    }
    // Restore original I/O redirection
    if (input_file) dup2(saved_stdin, STDIN_FILENO);
    if (output_file) dup2(saved_stdout, STDOUT_FILENO);
    close(saved_stdin);
    close(saved_stdout);
    free(original_command);
    if (resolved_command) free(resolved_command);
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
            execute_foreground(cmd_start, shell_home_directory, last_directory);
        }
        command_start = (*command_end == ';') ? command_end + 1 : command_end;
    }
     check_bg_processes();
}
int main() {
    char input[MAX_INPUT_SIZE];
    char shell_home_directory[PATH_MAX];
    char *last_directory = NULL;
    load_aliases(".myshrc");
    load_log(command_log, &log_count);
    get_current_directory(shell_home_directory, sizeof(shell_home_directory));
    while (1) {
        display_prompt(shell_home_directory);
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
        if (background) {
            execute_background(input);
        } else {
            process_input(input, shell_home_directory, &last_directory);
        }
        check_and_update_processes();
       if (strstr(original_input, "log") == NULL) {
            add_to_log(command_log, &log_count, original_input);  // Log the full command, including '&'
        }
    }
    if (last_directory) {
        free(last_directory);
    }
    return 0;
}




#include "all.h"
#define MAX_INPUT_SIZE 4096
#define MAX_JOBS 100
#define MAX_BG_PROCESSES 100

// Struct to store the background process info
// typedef struct {
//     pid_t pid;
//     char command[256];
//     char state[10];  // "Running" or "Stopped"
// } bg_process_t;
extern char command_log[MAX_COMMANDS][COMMAND_LEN];
typedef struct {
    pid_t pid;
    char command[256];
    process_state_t state; 
    int job_id;
} bg_process;
bg_process bg_processes[MAX_BG_PROCESSES];
int bg_process_count = 0;
extern int log_count;
int last_command_time = 0;
int job_count = 0;  // Number of active jobs


// Function to add a background job to the array
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
        printf("Maximum background processes limit reached.\n");
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
        // printf("Checking process %d\n", bg_processes[i].pid); // Debugging
        pid = waitpid(bg_processes[i].pid, &status, WNOHANG);
        if (pid == 0) {
            // Process still running
            // printf("Process %d is still running\n", bg_processes[i].pid); // Debugging
            bg_processes[i].state = RUNNING;
        } else if (pid > 0) {
            if (WIFEXITED(status)) {
                bg_processes[i].state = COMPLETED;
                printf("Background process %d completed normally.\n", bg_processes[i].pid);
                remove_completed_bg_process(bg_processes[i].pid); // Remove the process from the list
            } else if (WIFSIGNALED(status)) {
                bg_processes[i].state = TERMINATED;
                printf("Background process %d terminated by signal %d.\n", bg_processes[i].pid, WTERMSIG(status));
                remove_completed_bg_process(bg_processes[i].pid); // Remove the process from the list
            }
        }
    }
}




void execute_background(char *command) {
    // printf("hi\n");
    char *resolved_command = resolve_alias(command); // Assume resolve_alias is implemented
    if (resolved_command) {
        command = resolved_command;
    }
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
            // Special command handling
            if (strcmp(args[0], "sleep") == 0) {
                if (arg_count > 1) {
                    int seconds = atoi(args[1]);
                    if (seconds > 0) {
                        sleep(seconds);
                    } else {
                        fprintf(stderr, "Invalid sleep time\n");
                    }
                } else {
                    fprintf(stderr, "sleep: missing operand\n");
                }
                exit(0);
            } else if (strcmp(args[0], "echo") == 0) {
                for (int i = 1; i < arg_count; i++) {
                    printf("%s ", args[i]);
                }
                printf("\n");
                exit(0);
            } else {
                // Execute general commands
                if (execvp(args[0], args) == -1) {
                    perror("execvp failed");
                    exit(EXIT_FAILURE);
                }
            }
        } else {
            fprintf(stderr, "No command to execute\n");
            exit(EXIT_FAILURE);
        }
    } else if (pid > 0) {
        // Parent process
        printf("[%d] %d\n", job_count+1, pid);
        add_command_to_bg_list(pid, original_command);
        add_process(pid,original_command);
        //  check_and_update_processes();
        //  list_activities();
    } else {
        perror("fork failed");
    }

    free(original_command);  // Free the duplicated command
}

void stop_interactive_process(pid_t pid) {
    printf("Sending SIGSTOP to interactive process %d\n", pid);
    if (kill(pid, SIGSTOP) == -1) {
        perror("Failed to stop process");
    }
}
void execute_foreground(char *command, char *shell_home_directory, char **last_directory) {
    char *resolved_command = resolve_alias(command);
    if (resolved_command) {
        command = resolved_command;
    }
    char *original_command = strdup(command);
    int background = 0;
    char *input_file = NULL;
    char *output_file = NULL;
    int append_mode = 0;

    // Check if the command is to be executed in the background
    if (command[strlen(command) - 1] == '&') {
        background = 1;
        command[strlen(command) - 1] = '\0';  // Remove the '&' from the command
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
            perror("No such input file found!");
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
        } else if (*redirect_out == '>') {
            *redirect_out = '\0';  // Split the command at '>'
            output_file = strtok(redirect_out + 1, " \t");
        }
        printf("Redirecting output to file: %s\n", output_file);  // Debug output
        int flags = O_CREAT | O_WRONLY | (append_mode ? O_APPEND : O_TRUNC);
        output_fd = open(output_file, flags, 0644);
        if (output_fd < 0) {
            perror("Failed to open output file");
            free(original_command);
            return;
        }
        dup2(output_fd, STDOUT_FILENO);  // Redirect output
        close(output_fd);
        fflush(stdout);
    }

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
            handle_pipes(command); // Ensure this function does not cause double execution
        } else if (strcmp(token, "echo") == 0) {
            if (background) {
                // Run echo in the background
                execute_background(original_command);
            } else {
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
                fprintf(stderr, "seek: missing target argument\n");
            }
        } else if (strcmp(token, "reveal") == 0) {
            int op_a = 0, op_l = 0;
            token = strtok(NULL, " ");
            if (token && strcmp(token, "-") == 0) {
                if (*last_directory && **last_directory) {
                    reveal(*last_directory, op_a, op_l);
                } else {
                    fprintf(stderr, "reveal: OLDPWD not set\n");
                }
                return;
            }
            while (token && token[0] == '-') {
                size_t len = strlen(token);
                for (size_t i = 1; i < len; i++) {
                    if (token[i] == 'a') op_a = 1;
                    else if (token[i] == 'l') op_l = 1;
                    else fprintf(stderr, "reveal: invalid option -- '%c'\n", token[i]);
                }
                token = strtok(NULL, " ");
            }
            char *directory = token ? token : ".";
            reveal(directory, op_a, op_l);
        } else if (strcmp(token, "sleep") == 0) {
            token = strtok(NULL, " ");
            if (token) {
                int duration = atoi(token);
                if (duration > 0) {
                    if (background) {
                        execute_background(original_command);
                        // printf("%d\n", getpid());
                    } else {
                        time_t start_time = time(NULL);
                        sleep(duration);
                        time_t end_time = time(NULL);
                        int elapsed = (int)(end_time - start_time);
                        last_command_time = elapsed; // Store the time of the last command
                        if (elapsed > 2) {
                            printf("%s : %ds\n", original_command, elapsed);
                        }
                    }
                } else {
                    fprintf(stderr, "sleep: invalid duration '%s'\n", token);
                }
            } else {
                fprintf(stderr, "sleep: missing duration\n");
            }
        } else if (strcmp(token, "log") == 0) {
            token = strtok(NULL, " ");
            if (token && strcmp(token, "purge") == 0) {
                clear_log(); // Clear the log file
                return;
            } else if (token && strcmp(token, "execute") == 0) {
                token = strtok(NULL, " "); // Get the index
                if (token) {
                    int index = atoi(token); // Convert the index string to an integer
                    execute_log_command(index, shell_home_directory, last_directory);
                } else {
                    printf("Error: No index provided for log execute\n");
                }
                return;
            }
            handle_log_command();
        } 
         else if (strcmp(token, "proclore") == 0) {
            token = strtok(NULL, " ");
            proclore(token);
        } else if (strcmp(token, "activities") == 0) {
             list_activities();
        } else if (strcmp(token, "log") != 0) {
            // Execute other system commands
            if (background) {
                execute_background(original_command);
            } else {
                system(original_command);
            }
        }
    }

    // Restore standard input/output after redirection
    dup2(saved_stdin, STDIN_FILENO);
    dup2(saved_stdout, STDOUT_FILENO);
    close(saved_stdin);
    close(saved_stdout);

    free(original_command);
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
            execute_foreground(cmd_start, shell_home_directory, last_directory);
        }
        command_start = (*command_end == ';') ? command_end + 1 : command_end;
    }
     check_bg_processes();
}
int main() {
    char input[MAX_INPUT_SIZE];
    char shell_home_directory[PATH_MAX];
    char *last_directory = NULL;

    load_aliases(".myshrc");
    load_log(command_log, &log_count);
    get_current_directory(shell_home_directory, sizeof(shell_home_directory));

    while (1) {
        display_prompt(shell_home_directory);
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

        if (background) {
            execute_background(input);
        } else {
            process_input(input, shell_home_directory, &last_directory);
        }

        // void check_bg_processses();  // Call after executing the command
        check_and_update_processes();
       if (strstr(original_input, "log") == NULL) {
            add_to_log(command_log, &log_count, original_input);  // Log the full command, including '&'
        }
    }

    if (last_directory) {
        free(last_directory);
    }
    
    return 0;
}




#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pwd.h>
#include <grp.h>
#include <errno.h>
#include <sys/wait.h>
#include <time.h>
#include "prompt.h"
#include "hop.h"
#include "reveal.h"
#include "utilities.h"
#include "log.h"
#include "proclore.h"
#include "seek.h"
#include "bashrc.h" // Include for .myshrc functionality
#include "pipes.h"
#include "activities.h"
#include "background.h"
#include <signal.h>
#define MAX_INPUT_SIZE 4096
extern char command_log[MAX_COMMANDS][COMMAND_LEN];
extern int log_count;
int last_command_time = 0;
void execute_command(char *command, char *shell_home_directory, char **last_directory);
void process_input(char *input, char *shell_home_directory, char **last_directory);
void execute_command(char *command, char *shell_home_directory, char **last_directory) {
    char *resolved_command = resolve_alias(command);
    if (resolved_command) {
        command = resolved_command;
    }
    char *original_command = strdup(command);
    int background = 0;
    char *input_file = NULL;
    char *output_file = NULL;
    int append_mode = 0;
    if (command[strlen(command) - 1] == '&') {
        background = 1;
        command[strlen(command) - 1] = '\0';
    }
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
            perror("No such input file found!");
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
    } else if (*redirect_out == '>') {
        *redirect_out = '\0';  // Split the command at '>'
        output_file = strtok(redirect_out + 1, " \t");
    }
    printf("Redirecting output to file: %s\n", output_file);  // Debug output
    int flags = O_CREAT | O_WRONLY | (append_mode ? O_APPEND : O_TRUNC);
    output_fd = open(output_file, flags, 0644);
    if (output_fd < 0) {
        perror("Failed to open output file");
        free(original_command);
        return;
    }
    dup2(output_fd, STDOUT_FILENO);  // Redirect output
    close(output_fd);
    fflush(stdout);
}
    char *token = strtok(command, " ");
    if (token) {
        if (strcmp(token, "hop") == 0) {
            token = strtok(NULL, " ");
            while (token) {
                hop(token, shell_home_directory, last_directory);
                token = strtok(NULL, " ");
            }
        }
        else if (strchr(token, '|')) {
            printf("Pipe detected in command: '%s'\n", command);
            handle_pipes(command); // Ensure this function does not cause double execution
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
                fprintf(stderr, "seek: missing target argument\n");
            }
        } else if (strcmp(token, "reveal") == 0) {
            int op_a = 0, op_l = 0;
            token = strtok(NULL, " ");
            if (token && strcmp(token, "-") == 0) {
                if (*last_directory && **last_directory) {
                    reveal(*last_directory, op_a, op_l);
                } else {
                    fprintf(stderr, "reveal: OLDPWD not set\n");
                }
                return;
            }
            while (token && token[0] == '-') {
                size_t len = strlen(token);
                for (size_t i = 1; i < len; i++) {
                    if (token[i] == 'a') op_a = 1;
                    else if (token[i] == 'l') op_l = 1;
                    else {
                        fprintf(stderr, "Invalid flag for reveal: %c\n", token[i]);
                        return;
                    }
                }
                token = strtok(NULL, " ");
            }
            const char *dir = token ? token : ".";
            reveal(dir, op_a, op_l);
        } else if (strcmp(token, "proclore") == 0) {
            token = strtok(NULL, " ");
            if (token == NULL) {
                proclore(NULL);
            } else {
                proclore(token);
            }
        } else if (strcmp(token, "sleep") == 0) {
            token = strtok(NULL, " ");
            if (token) {
                int duration = atoi(token);
                if (duration > 0) {
                    if (background) {
                        execute_in_background(original_command);
                        // printf("%d\n", getpid());
                    } else {
                        time_t start_time = time(NULL);
                        sleep(duration);
                        time_t end_time = time(NULL);
                        int elapsed = (int)(end_time - start_time);
                        last_command_time = elapsed; // Store the time of the last command
                        if (elapsed > 2) {
                            printf("%s : %ds\n", original_command, elapsed);
                        }
                    }
                } else {
                    fprintf(stderr, "sleep: invalid duration '%s'\n", token);
                }
            } else {
                fprintf(stderr, "sleep: missing duration\n");
            }
        } else if (strcmp(token, "log") == 0) {
            token = strtok(NULL, " ");
            if (token && strcmp(token, "purge") == 0) {
                clear_log(); // Clear the log file
                return;
            } else if (token && strcmp(token, "execute") == 0) {
                token = strtok(NULL, " "); // Get the index
                if (token) {
                    int index = atoi(token); // Convert the index string to an integer
                    execute_log_command(index, shell_home_directory, last_directory);
                } else {
                    printf("Error: No index provided for log execute\n");
                }
                return;
            }
            handle_log_command();
        } 
        else if(strcmp(token, "activities")==0){
            activities();
            }else {
            if (background) {
                execute_in_background(original_command);
                // printf("%d\n", getpid());
                // return;
            } else {
                time_t start_time = time(NULL);
                int ret = system(original_command);
                time_t end_time = time(NULL);
                int elapsed = (int)(end_time - start_time);
                last_command_time = elapsed; // Store the time of the last command
                if (elapsed > 2) {
                    printf("%s : %ds\n", original_command, elapsed);
                }
                if (ret == -1) {
                    perror("system call failed");
                }
            }
        }
    }
    free(original_command);
    dup2(saved_stdin, STDIN_FILENO);
    dup2(saved_stdout, STDOUT_FILENO);
    close(saved_stdin);
    close(saved_stdout);
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
            execute_command(cmd_start, shell_home_directory, last_directory);
        }
        command_start = (*command_end == ';') ? command_end + 1 : command_end;
    }
     check_background_jobs();
}
int main() {
    char input[MAX_INPUT_SIZE];
    char shell_home_directory[PATH_MAX];
    char *last_directory = NULL;
    load_aliases(".myshrc");
    load_log(command_log, &log_count);
        get_current_directory(shell_home_directory, sizeof(shell_home_directory));

    while (1) {
        check_background_jobs();  // Call before displaying prompt
        display_prompt(shell_home_directory); // Pass the last_command_time to the prompt
           fflush(stdout);  

        if (fgets(input, MAX_INPUT_SIZE, stdin)) {
          input[strcspn(input, "\n")] = 0; // Remove newline character
        }
        else{
            break;
        }
        if (strlen(input) == 0) {
            continue; // Skip empty input
        }
        process_input(input, shell_home_directory, &last_directory);
        //  check_background_jobs();  // Call after executing the command
        if (strstr(input, "log") == NULL) {
            add_to_log(command_log, &log_count, input);
        }
    }
    if (last_directory) {
        free(last_directory);
    }
    return 0;
}









#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pwd.h>
#include <grp.h>
#include <errno.h>
#include <sys/wait.h>
#include <time.h>
#include "prompt.h"
#include "hop.h"
#include "reveal.h"
#include "utilities.h"
#include "log.h"
#include "proclore.h"
#include "seek.h"
#include "bashrc.h" // Include for .myshrc functionality

#define MAX_INPUT_SIZE 4096

// Global variables for log management
extern char command_log[MAX_COMMANDS][COMMAND_LEN];
extern int log_count;

// Global variable to store the time of the last foreground process
int last_command_time = 0;

// Function prototypes
void execute_command(char *command, char *shell_home_directory, char **last_directory);
void process_input(char *input, char *shell_home_directory, char **last_directory);
void handle_log_command();

// Function to execute a command
void execute_command(char *command, char *shell_home_directory, char **last_directory) {
    char *resolved_command = resolve_alias(command);

    if (resolved_command) {
        command = resolved_command;
    }

    char *original_command = strdup(command);
    int background = 0;
    char *input_file = NULL;
    char *output_file = NULL;
    int append_mode = 0;

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
    // Save original file descriptors
    int saved_stdin = dup(STDIN_FILENO);
    int saved_stdout = dup(STDOUT_FILENO);

    if (redirect_in) {
        *redirect_in = '\0';
        input_file = strtok(redirect_in + 1, " \t");

      int input_fd = open(input_file, O_RDONLY);
        if (input_fd < 0) {
            perror("No such input file found!");
            free(original_command);
            return;
        }
        dup2(input_fd, STDIN_FILENO);  // Redirect input
        close(input_fd);
    }
    // Handle output redirection ">" or ">>"
    if (redirect_out) {
        if (strncmp(redirect_out, ">>", 2) == 0) {
            append_mode = 1;
            *redirect_out = '\0';  // Split the command at ">>"
            output_file = strtok(redirect_out + 2, " \t");  // Get the output file name
        } else if (*redirect_out == '>') {
            *redirect_out = '\0';  // Split the command at '>'
            output_file = strtok(redirect_out + 1, " \t");  // Get the output file name
        }

        // Open output file with the correct mode
        int flags = O_CREAT | O_WRONLY | (append_mode ? O_APPEND : O_TRUNC);
        int output_fd = open(output_file, flags, 0644);
        if (output_fd < 0) {
            perror("Failed to open output file");
            free(original_command);
            return;
        }
        dup2(output_fd, STDOUT_FILENO);  // Redirect output
        close(output_fd);
    }

    char *token = strtok(command, " ");
    if (token) {
        if (strcmp(token, "hop") == 0) {
            token = strtok(NULL, " ");
            if (!token) {
                hop("~", shell_home_directory, last_directory);
            } else {
                while (token) {
                    hop(token, shell_home_directory, last_directory);
                    token = strtok(NULL, " ");
                }
            }
        } else if (strcmp(token, "echo") == 0) {
            handle_echo(command);
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
                fprintf(stderr, "seek: missing target argument\n");
            }
        } else if (strcmp(token, "reveal") == 0) {
            int op_a = 0, op_l = 0;
            token = strtok(NULL, " ");

            if (token && strcmp(token, "-") == 0) {
                if (*last_directory && **last_directory) {
                    reveal(*last_directory, op_a, op_l);
                } else {
                    fprintf(stderr, "reveal: OLDPWD not set\n");
                }
                return;
            }

            while (token && token[0] == '-') {
                size_t len = strlen(token);
                for (size_t i = 1; i < len; i++) {
                    if (token[i] == 'a') op_a = 1;
                    else if (token[i] == 'l') op_l = 1;
                    else {
                        fprintf(stderr, "Invalid flag for reveal: %c\n", token[i]);
                        return;
                    }
                }
                token = strtok(NULL, " ");
            }

            const char *dir = token ? token : ".";
            reveal(dir, op_a, op_l);
        } else if (strcmp(token, "proclore") == 0) {
            token = strtok(NULL, " ");
            if (token == NULL) {
                proclore(NULL);
            } else {
                proclore(token);
            }
        } else if (strcmp(token, "sleep") == 0) {
            token = strtok(NULL, " ");
            if (token) {
                int duration = atoi(token);
                if (duration > 0) {
                    if (background) {
                        execute_in_background(original_command);
                        printf("%d\n", getpid());
                    } else {
                        time_t start_time = time(NULL);
                        sleep(duration);
                        time_t end_time = time(NULL);
                        int elapsed = (int)(end_time - start_time);
                        last_command_time = elapsed; // Store the time of the last command
                        if (elapsed > 2) {
                            printf("%s : %ds\n", original_command, elapsed);
                        }
                    }
                } else {
                    fprintf(stderr, "sleep: invalid duration '%s'\n", token);
                }
            } else {
                fprintf(stderr, "sleep: missing duration\n");
            }
        } else if (strcmp(token, "log") == 0) {
            token = strtok(NULL, " ");
            if (token && strcmp(token, "purge") == 0) {
                clear_log(); // Clear the log file
                return;
            } else if (token && strcmp(token, "execute") == 0) {
                token = strtok(NULL, " "); // Get the index
                if (token) {
                    int index = atoi(token); // Convert the index string to an integer
                    execute_log_command(index, shell_home_directory, last_directory);
                } else {
                    printf("Error: No index provided for log execute\n");
                }
                return;
            }
            handle_log_command();
        } else {
            if (background) {
                execute_in_background(original_command);
                printf("%d\n", getpid());
            } else {
                time_t start_time = time(NULL);
                int ret = system(original_command);
                time_t end_time = time(NULL);
                int elapsed = (int)(end_time - start_time);
                last_command_time = elapsed; // Store the time of the last command
                if (elapsed > 2) {
                    printf("%s : %ds\n", original_command, elapsed);
                }
                if (ret == -1) {
                    perror("system call failed");
                }
            }
        }
    }

    free(original_command);

    // Restore original file descriptors
    dup2(saved_stdin, STDIN_FILENO);
    dup2(saved_stdout, STDOUT_FILENO);
    close(saved_stdin);
    close(saved_stdout);
}

// Function to handle commands separated by ';'
void process_input(char *input, char *shell_home_directory, char **last_directory) {
    // Trim leading and trailing spaces from the input
    char trimmed_input[MAX_INPUT_SIZE];
    strncpy(trimmed_input, input, MAX_INPUT_SIZE - 1);
    trimmed_input[MAX_INPUT_SIZE - 1] = '\0'; // Ensure null termination

    // Remove leading spaces
    char *start = trimmed_input;
    while (*start == ' ') start++;

    // Remove trailing spaces
    char *end = start + strlen(start) - 1;
    while (end > start && *end == ' ') end--;
    *(end + 1) = '\0';

    // If the input is empty after trimming, skip processing
    if (*start == '\0') {
        return;
    }

    // Log the entire command string
    if (strstr(start, "log") == NULL) {
        add_to_log(command_log, &log_count, start);
    }

    // Handle commands separated by ';'
    char *command_start = start;
    while (*command_start != '\0') {
        // Find the end of the current command
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

        // Null-terminate the current command
        char command[MAX_INPUT_SIZE];
        strncpy(command, command_start, command_end - command_start);
        command[command_end - command_start] = '\0';

        // Trim leading and trailing spaces from the command
        char *cmd_start = command;
        while (*cmd_start == ' ') cmd_start++;
        char *cmd_end = cmd_start + strlen(cmd_start) - 1;
        while (cmd_end > cmd_start && *cmd_end == ' ') cmd_end--;
        *(cmd_end + 1) = '\0';

        if (*cmd_start != '\0') {
            execute_command(cmd_start, shell_home_directory, last_directory);
        }

        // Move to the next command
        command_start = (*command_end == ';') ? command_end + 1 : command_end;
    }
}

// Function to handle the 'log' command
void handle_log_command() {
    // Existing code to print log entries
    print_log();
}

int main() {
    char input[MAX_INPUT_SIZE];
    char shell_home_directory[PATH_MAX];
    char *last_directory = NULL;

    // Load aliases from the .myshrc file
    load_aliases(".myshrc");

    // Load the previous log commands at the start
    load_log(command_log, &log_count);

    // Get current directory for the prompt
        get_current_directory(shell_home_directory, sizeof(shell_home_directory));

    while (1) {
        display_prompt(shell_home_directory); // Pass the last_command_time to the prompt

        if (!fgets(input, MAX_INPUT_SIZE, stdin)) {
            break; // Exit on EOF
        }
        input[strcspn(input, "\n")] = 0; // Remove newline character

        if (strlen(input) == 0) {
            continue; // Skip empty input
        }

        // Process the input with aliases
        // char *resolved_command = resolve_alias(input);
        // if (resolved_command) {
        //     // If alias found, use the resolved command
        //     strcpy(input, resolved_command);
        // }

        // Process the input (handling commands separated by ';' and background commands)
        process_input(input, shell_home_directory, &last_directory);

        // Check for any background jobs that may have finished
        check_background_jobs();

        // Log the commands after execution (except 'log' commands)
        if (strstr(input, "log") == NULL) {
            add_to_log(command_log, &log_count, input);
        }
    }

    if (last_directory) {
        free(last_directory);
    }

    return 0;
}
