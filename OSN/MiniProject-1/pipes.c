#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/wait.h>
#include <errno.h>
#include <fcntl.h>
#include "pipes.h"

#define MAX_COMMANDS 10
#define MAX_ARGS 20

// Color macros
#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

// Function prototype
void remove_quotes(char *str);
void handle_pipes(char *input);

// Helper function to execute a command
void executee_command(char *command) {
    char *args[MAX_ARGS];
    char *token = strtok(command, " \t\n");
    int i = 0;

    while (token != NULL && i < MAX_ARGS - 1) {
        // Remove quotes from each token
        remove_quotes(token);
        args[i++] = token;
        token = strtok(NULL, " \t\n");
    }
    args[i] = NULL;

    if (execvp(args[0], args) == -1) {
        
        fprintf(stderr, COLOR_ERROR "Command execution failed: %s\n" COLOR_RESET, strerror(errno));
        exit(EXIT_FAILURE);
    }
}

// Enhanced remove_quotes function
void remove_quotes(char *str) {
    char *dst = str;
    char *src = str;

    // Remove quotes by copying characters except for the quotes
    while (*src) {
        if (*src != '"' && *src != '\'') {
            *dst++ = *src;
        }
        src++;
    }
    *dst = '\0';  // Null-terminate the modified string
}

// Main pipe handler with I/O redirection
void handle_pipes(char *input) {
    char *commands[MAX_COMMANDS];
    int num_commands = 0;
    char *input_file = NULL;
    char *output_file = NULL;
    int append_mode = 0;

    // Check for invalid use of pipes at the start or end
    if (input[0] == '|' || input[strlen(input) - 1] == '|') {
        fprintf(stderr, COLOR_ERROR "Invalid use of pipe\n" COLOR_RESET);
        return;
    }

    // Handle I/O redirection before pipes
    char *redirect_in = strchr(input, '<');
    char *redirect_out = strstr(input, ">>");
    if (!redirect_out) {
        redirect_out = strchr(input, '>');
    }

    // Handle input redirection
    if (redirect_in) {
        *redirect_in = '\0'; // Terminate the command before '<'
        input_file = strtok(redirect_in + 1, " \t");
    }

    // Handle output redirection
    if (redirect_out) {
        if (strncmp(redirect_out, ">>", 2) == 0) {
            append_mode = 1;
            *redirect_out = '\0'; // Terminate the command before '>>'
            output_file = strtok(redirect_out + 2, " \t");
        } else {
            *redirect_out = '\0'; // Terminate the command before '>'
            output_file = strtok(redirect_out + 1, " \t");
        }
    }

    // Split the input by '|'
    char *token = strtok(input, "|");

    while (token != NULL && num_commands < MAX_COMMANDS) {
        // Trim leading and trailing spaces
        while (*token == ' ') token++;
        char *end = token + strlen(token) - 1;
        while (end > token && *end == ' ') end--;
        *(end + 1) = '\0';

        if (strlen(token) == 0) {
            fprintf(stderr, COLOR_ERROR "Invalid use of pipe\n" COLOR_RESET);
            return;
        }

        // Store the command
        commands[num_commands++] = strdup(token);
        token = strtok(NULL, "|");
    }

    if (num_commands == 0) {
        fprintf(stderr, COLOR_ERROR "No commands provided\n" COLOR_RESET);
        return;
    }

    int pipefd[2]; // Array to hold pipe file descriptors
    int fd_in = 0; // File descriptor for input
    pid_t pid;

    for (int i = 0; i < num_commands; ++i) {
        if (i < num_commands - 1) {
            // Create pipe for inter-process communication
            if (pipe(pipefd) == -1) {
                fprintf(stderr, COLOR_ERROR "Pipe failed: %s\n" COLOR_RESET, strerror(errno));
                exit(EXIT_FAILURE);
            }
        }

        if ((pid = fork()) == -1) {
            fprintf(stderr, COLOR_ERROR "Fork failed: %s\n" COLOR_RESET, strerror(errno));
            exit(EXIT_FAILURE);
        }

        if (pid == 0) {
            // Child process
            if (i == 0 && input_file) {
                // Handle input redirection
                int input_fd = open(input_file, O_RDONLY);
                if (input_fd < 0) {
                    fprintf(stderr, COLOR_ERROR "Input file open failed: %s\n" COLOR_RESET, strerror(errno));
                    exit(EXIT_FAILURE);
                }
                dup2(input_fd, STDIN_FILENO);
                close(input_fd);
            } else {
                // Set up input for the command from the previous pipe
                dup2(fd_in, STDIN_FILENO);
            }

            if (i < num_commands - 1) {
                // Redirect output to the next command
                dup2(pipefd[1], STDOUT_FILENO);
            } else if (output_file) {
                // Handle output redirection to a file
                int flags = O_CREAT | O_WRONLY | (append_mode ? O_APPEND : O_TRUNC);
                int output_fd = open(output_file, flags, 0644);
                if (output_fd < 0) {
                    fprintf(stderr, COLOR_ERROR "Output file open failed: %s\n" COLOR_RESET, strerror(errno));
                    exit(EXIT_FAILURE);
                }
                dup2(output_fd, STDOUT_FILENO);
                close(output_fd);
            }

            // Close unused file descriptors
            if (i < num_commands - 1) close(pipefd[0]);
            close(pipefd[1]);

            // Execute the command
            executee_command(commands[i]);

            // Exit child process after executing the command
            exit(EXIT_SUCCESS);
        } else {
            // Parent process
            if (i < num_commands - 1) {
                // Close write end of the pipe in parent
                close(pipefd[1]);
            }

            // Update fd_in to read from the pipe for the next command
            fd_in = pipefd[0];

            // Wait for the child process to finish
            wait(NULL);
        }
    }

    // Free allocated memory for commands
    for (int i = 0; i < num_commands; ++i) {
        free(commands[i]);
    }
}
