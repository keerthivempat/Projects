#ifndef LOG_H
#define LOG_H

#define MAX_COMMANDS 15
#define COMMAND_LEN 1024
#define LOG_FILE_PATH "/home/keerthivempati/Desktop/OSN/MiniProject-1/store_command.txt"

// Function declarations
void load_log(char log[MAX_COMMANDS][COMMAND_LEN], int *log_count);
void save_log(char log[MAX_COMMANDS][COMMAND_LEN], int log_count);
void add_to_log(char log[MAX_COMMANDS][COMMAND_LEN], int *log_count, const char *command);
void print_log();
void clear_log();
void handle_log_command();
void execute_log_command(int index, char *shell_home_directory, char **last_directory);

#endif // LOG_H
