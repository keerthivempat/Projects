#ifndef MYSHRC_H
#define MYSHRC_H

// Function to load aliases and functions from .myshrc
void load_myshrc(const char *shell_home_directory);

// Function to handle alias expansion
char* expand_alias(char *command);

// Function to handle function execution
void execute_shell_function(char *command);

#endif
