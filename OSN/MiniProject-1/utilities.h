#ifndef UTILITIES_H
#define UTILITIES_H
#include <stdlib.h>

void get_system_name(char *system_name, size_t size);
char* get_username();
void get_current_directory(char *cwd, size_t size);
void get_relative_path(char *cwd, char *home_directory, char *relative_path, size_t size);
void execute_in_background(char *cmd);
void handle_echo(char *input);
void check_background_jobs();
#endif