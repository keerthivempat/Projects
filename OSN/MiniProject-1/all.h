#ifndef _ALL_H
#define ALL_H

#include <stdio.h>
#include <signal.h>
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
#include <time.h>
#include "prompt.h"
#include "hop.h"
#include "reveal.h"
#include "utilities.h"
#include "log.h"
#include "proclore.h"
#include "seek.h"
// #include "bashrc.h" // Include for .myshrc functionality
#include "pipes.h"
#include "activities.h"
#include "mysignal.h"
#include <sys/wait.h>
#include <errno.h>
#define MAX_LOG_SIZE 15
#define MAX_COMMAND_LENGTH 100  // Adjust according to your requirements
extern char extra_prompt[4096];  // 4096 bytes for extra prompt storage
extern char fg_command[4096];
extern pid_t pid_fg;
void hop(char *path, char *home_directory, char **last_directory);
void load_log(char log[MAX_COMMANDS][COMMAND_LEN], int *log_count);
void save_log(char log[MAX_COMMANDS][COMMAND_LEN], int log_count);
void add_to_log(char log[MAX_COMMANDS][COMMAND_LEN], int *log_count, const char *command);
void print_log();
void clear_log();
void handle_log_command();
void execute_log_command(int index, char *shell_home_directory, char **last_directory);
void handle_pipes(char *input);

void proclore(const char *pid_str);
void display_prompt(char *home_directory,char* extra_prompt);
void reveal(const char *dir, int op_a, int op_l);
void seek(const char *target, const char *directory, int only_dirs, int only_files, int execute_flag);
void get_system_name(char *system_name, size_t size);
char* get_username();
void get_current_directory(char *cwd, size_t size);
void get_relative_path(char *cwd, char *home_directory, char *relative_path, size_t size);
void handle_echo(char *input);
void check_bg_processses();
void add_to_bg_list(pid_t pid, char *command) ;
void remove_completed_bg_process(pid_t pid);
// void sigchld_handler(int sig);

// void setup_sigchld_handler();
// void check_background_jobs();
extern char *last_directory ;
void execute_background(char *command);

void execute_foreground(char *command, char *shell_home_directory, char **last_directory);
void process_input(char *input, char *shell_home_directory, char **last_directory);
// void add_to_background_jobs(pid_t pid, char *command);
// Functions to manage background processes
void add_process(pid_t pid, const char *command);
void update_process_state(pid_t pid, process_state_t state);
void list_activities();
void sort_bg_processes_lexicographically();
void check_and_update_processes();
#endif