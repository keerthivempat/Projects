#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <errno.h>
#include "log.h"
#include "hop.h"
#include "reveal.h"
#include "proclore.h"
#include "seek.h"

extern void execute_foreground(char *command, char *shell_home_directory, char **last_directory);

// Rename `log` to `command_log` to avoid conflict with the built-in function
char command_log[MAX_COMMANDS][COMMAND_LEN];
int log_count = 0;

// Color macros
#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

void clear_log() {
    FILE *file = fopen(LOG_FILE_PATH, "w");
    if (file) {
        fclose(file); // Just open and close the file to clear its contents
        printf("cleared\n");
    } else {
        fprintf(stderr, COLOR_ERROR "Failed to clear log file: %s\n" COLOR_RESET, strerror(errno));
    }
}

// Function to load log from file
void load_log(char command_log[MAX_COMMANDS][COMMAND_LEN], int *log_count) {
    FILE *file = fopen(LOG_FILE_PATH, "r");
    if (file == NULL) {
        if (errno != ENOENT) { // Not a "No such file" error
            fprintf(stderr, COLOR_ERROR "Failed to open log file: %s\n" COLOR_RESET, strerror(errno));
        }
        return;
    }

    char buffer[COMMAND_LEN];
    *log_count = 0;
    while (fgets(buffer, sizeof(buffer), file) && *log_count < MAX_COMMANDS) {
        // Remove trailing newline from the log entry
        buffer[strcspn(buffer, "\n")] = 0;
        strcpy(command_log[*log_count], buffer);
        (*log_count)++;
    }
    fclose(file);
}

// Function to save log to file
void save_log(char command_log[MAX_COMMANDS][COMMAND_LEN], int log_count) {
    FILE *file = fopen(LOG_FILE_PATH, "w");
    if (file == NULL) {
        fprintf(stderr, COLOR_ERROR "Failed to open log file for writing: %s\n" COLOR_RESET, strerror(errno));
        return;
    }

    // Adjust log_count in case it's less than MAX_COMMANDS
    int count_to_save = (log_count < MAX_COMMANDS) ? log_count : MAX_COMMANDS;

    for (int i = 0; i < count_to_save; i++) {
        fprintf(file, "%s\n", command_log[i]);
    }
    fclose(file);
}

// Function to add a new command to the log
void add_to_log(char command_log[MAX_COMMANDS][COMMAND_LEN], int *log_count, const char *command) {
    // Do not store the 'log' command or identical consecutive commands
    if (strstr(command, "log") != NULL || (*log_count > 0 && strcmp(command_log[*log_count - 1], command) == 0)) {
        return;
    }

    if (*log_count < MAX_COMMANDS) {
        strcpy(command_log[*log_count], command);
        (*log_count)++;
    } else {
        // Overwrite oldest command by shifting all entries up
        for (int i = 1; i < MAX_COMMANDS; i++) {
            strcpy(command_log[i - 1], command_log[i]);
        }
        strcpy(command_log[MAX_COMMANDS - 1], command);
    }

    save_log(command_log, *log_count);
}

// Function to print the log
void print_log() {
    FILE *file = fopen(LOG_FILE_PATH, "r");
    if (file == NULL) {
        fprintf(stderr, COLOR_ERROR "Failed to open log file: %s\n" COLOR_RESET, strerror(errno));
        return;
    }

    char buffer[COMMAND_LEN];
    int has_commands = 0;
    while (fgets(buffer, sizeof(buffer), file)) {
        has_commands = 1;
        printf("%s", buffer);
    }

    if (!has_commands) {
        printf("No commands in the history\n");
    }

    fclose(file);
}

void execute_log_command(int index, char *shell_home_directory, char **last_directory) {
    if (index <= 0 || index > log_count) {
        printf("Error: Invalid log index. Please provide a valid index (1 to %d).\n", log_count);
        return;
    }

    // The log is ordered from most recent to oldest, so we reverse the index
    int log_index = log_count - index;
    char command[COMMAND_LEN];
    strncpy(command, command_log[log_index], COMMAND_LEN - 1);
    command[COMMAND_LEN - 1] = '\0'; // Ensure null termination

    printf("Executing command: %s\n", command);

    // Here you invoke your shell's main command execution logic
    execute_foreground(command, shell_home_directory, last_directory);
}

void handle_log_command() {
    // Existing code to print log entries
    print_log();
}
