#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include "myshrc.h"

// Structure to hold aliases
typedef struct Alias {
    char *name;
    char *command;
    struct Alias *next;
} Alias;

Alias *alias_list = NULL; // Head of the alias list

// Structure to hold functions
typedef struct ShellFunction {
    char *name;
    char *body;
    struct ShellFunction *next;
} ShellFunction;

ShellFunction *function_list = NULL; // Head of the function list

// Function to add an alias to the alias list
void add_alias(const char *name, const char *command) {
    Alias *new_alias = malloc(sizeof(Alias));
    new_alias->name = strdup(name);
    new_alias->command = strdup(command);
    new_alias->next = alias_list;
    alias_list = new_alias;
}

// Function to add a function to the function list
void add_function(const char *name, const char *body) {
    ShellFunction *new_function = malloc(sizeof(ShellFunction));
    new_function->name = strdup(name);
    new_function->body = strdup(body);
    new_function->next = function_list;
    function_list = new_function;
}

// Function to check if a command is a shell function
int is_shell_function(const char *name) {
    ShellFunction *current = function_list;
    while (current) {
        if (strcmp(current->name, name) == 0) {
            return 1; // Found the function
        }
        current = current->next;
    }
    return 0; // Function not found
}
char** split_command(const char *command) {
    char **args = malloc(64 * sizeof(char*)); // Allocate memory for arguments
    char *cmd = strdup(command);
    char *token;
    int pos = 0;

    token = strtok(cmd, " ");
    while (token != NULL) {
        args[pos++] = strdup(token);
        token = strtok(NULL, " ");
    }
    args[pos] = NULL; // Null-terminate the array

    free(cmd);
    return args;
}

void process_command(char *user_input) {
    // Expand any alias
    // printf("u\n");
    char *expanded_command = expand_alias(user_input);
    printf("expanded_command%s",expanded_command);

    // Check if the command is a shell function
    if (is_shell_function(expanded_command)) {
        // printf("cmg\n");
        execute_shell_function(expanded_command);
    } else {
        printf("cm,,,,,g\n");
        // Convert user input into arguments
        char **args = split_command(expanded_command);

        // Execute the command using execvp
        if (execvp(args[0], args) == -1) {
            perror("execvp failed"); // Print error if execvp fails
        }

        // Free allocated memory for arguments
        for (int i = 0; args[i]; i++) {
            free(args[i]);
        }
        free(args);
    }
}

// Function to load aliases and functions from .myshrc file
void load_myshrc(const char *shell_home_directory) {
    printf("hi\n");
    char filepath[256];
    strcpy(filepath, "myshrc.txt");

    FILE *file = fopen(filepath, "r");
    if (!file) {
        fprintf(stderr, "Could not open %s\n", filepath);
        return;
    }

    char line[256];
    while (fgets(line, sizeof(line), file)) {
        if (strncmp(line, "alias", 5) == 0) {
            // Parse alias
            printf("hehe\n");
            char *alias_name = strtok(line + 6, "=");
            printf("alias name:%s",alias_name);
            char *alias_command = strtok(NULL, "\n");
            printf("alias_command%s",alias_command);
            if (alias_name && alias_command) {
                if (alias_command[0] == '\'' || alias_command[0] == '\"') {
                    alias_command++; // Skip the first quote
                    alias_command[strlen(alias_command) - 1] = '\0'; // Remove the trailing quote
                }
                printf("alias_command2%s",alias_command);
                add_alias(alias_name, alias_command);
            }
        } else if (strstr(line, "() {")) {
            printf("here\n");            // Parse function
            char *function_name = strtok(line, " ");
            char function_body[512];
            function_body[0] = '\0'; // Initialize as an empty string

            // Read until we find the closing brace '}'
            while (fgets(line, sizeof(line), file)) {
                if (strstr(line, "}")) break;
                strcat(function_body, line);
            }
            add_function(function_name, function_body);
        }
    }

    fclose(file);
}

// Function to split the command into two parts at the first space
void split_command_at_space(const char *command, char **cmd_part1, char **cmd_part2) {
    // Find the position of the first space
    const char *space_pos = strchr(command, ' ');
    
    if (space_pos == NULL) {
        printf("no spaceis found\n");
        // No space found, entire command is the first part
        *cmd_part1 = strdup(command);
        *cmd_part2 = NULL;
    } else {
        // Space found, split into two parts
        size_t len1 = space_pos - command;
        size_t len2 = strlen(space_pos + 1);
        
        *cmd_part1 = malloc(len1 + 1);
        *cmd_part2 = malloc(len2 + 1);
        
        if (*cmd_part1 == NULL || *cmd_part2 == NULL) {
            perror("malloc failed");
            exit(EXIT_FAILURE);
        }
        
        strncpy(*cmd_part1, command, len1);
        (*cmd_part1)[len1] = '\0'; // Null-terminate the first part
        
        strcpy(*cmd_part2, space_pos + 1); // Copy the second part
    }
}
char* concatenate_with_space(const char *str1, const char *str2) {
    // Allocate memory for the concatenated string with space and null terminator
    size_t len1 = strlen(str1);
    size_t len2 = strlen(str2);
    char *result = malloc(len1 + len2 + 2); // +2 for space and null terminator

    if (result == NULL) {
        fprintf(stderr, "Memory allocation failed\n");
        exit(EXIT_FAILURE);
    }

    // Copy the first string into result
    strcpy(result, str1);
    // Append a space
    result[len1] = ' ';
    // Copy the second string after the space
    strcpy(result + len1 + 1, str2);

    return result;
}
// Function to expand an alias
char* expand_alias(char *command) {
    printf("command is %s\n",command);
    char *cmd_part1 = NULL;
    char *cmd_part2 = NULL;
    //  printf("%s\n", cmd_part1);
    split_command_at_space(command, &cmd_part1, &cmd_part2);
    printf("hmm\n");
    
     printf("%s\n",cmd_part2);
    Alias *current = alias_list;
    while (current) {
        if (strcmp(current->name, cmd_part1) == 0) {
            printf("Expanded alias: %s -> %s\n", cmd_part1, current->command); // Debugging line
            char * result = concatenate_with_space(current->command, cmd_part2);
            return result;
        }
        current = current->next;
    }
    
    return command; // Return original command if no alias found
}

// Function to execute a shell function
void execute_shell_function(char *command) {
    ShellFunction *current = function_list;
    while (current) {
        if (strcmp(current->name, command) == 0) {
            // Here you can run the body of the function (e.g., call other shell commands)
            printf("Executing shell function: %s\n", current->body);
            return;
        }
        current = current->next;
    }
    fprintf(stderr, "No such function: %s\n", command);
}

// Function to process and execute a command


