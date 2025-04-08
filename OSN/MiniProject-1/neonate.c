#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/select.h>
#include <termios.h>
#include <ctype.h>

#include "neonate.h"

// Color macros
#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

// Helper function to check if a string is composed entirely of digits (a PID)
int is_number(const char *str) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (!isdigit(str[i])) {
            return 0;
        }
    }
    return 1;
}

// Helper function to get the most recent process ID
int get_latest_pid() {
    DIR *proc_dir = opendir("/proc");
    if (proc_dir == NULL) {
        fprintf(stderr, COLOR_ERROR "Failed to open /proc directory: %s\n" COLOR_RESET, strerror(errno));
        return -1;
    }

    struct dirent *entry;
    int max_pid = -1;

    while ((entry = readdir(proc_dir)) != NULL) {
        if (is_number(entry->d_name)) {
            int pid = atoi(entry->d_name);
            if (pid > max_pid) {
                max_pid = pid;
            }
        }
    }

    closedir(proc_dir);
    return max_pid;
}

// Set terminal to non-blocking mode to detect 'x' key press
void set_nonblocking_input() {
    struct termios oldt, newt;
    if (tcgetattr(STDIN_FILENO, &oldt) == -1) {
        fprintf(stderr, COLOR_ERROR "Failed to get terminal attributes: %s\n" COLOR_RESET, strerror(errno));
        exit(EXIT_FAILURE);
    }
    newt = oldt;
    newt.c_lflag &= ~(ICANON | ECHO);  // Disable canonical mode and echo
    if (tcsetattr(STDIN_FILENO, TCSANOW, &newt) == -1) {
        fprintf(stderr, COLOR_ERROR "Failed to set terminal attributes: %s\n" COLOR_RESET, strerror(errno));
        exit(EXIT_FAILURE);
    }
    if (fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK) == -1) {
        fprintf(stderr, COLOR_ERROR "Failed to set non-blocking input: %s\n" COLOR_RESET, strerror(errno));
        exit(EXIT_FAILURE);
    }
}

// Restore terminal settings after non-blocking input
void restore_terminal_settings() {
    struct termios oldt;
    if (tcgetattr(STDIN_FILENO, &oldt) == -1) {
        fprintf(stderr, COLOR_ERROR "Failed to get terminal attributes: %s\n" COLOR_RESET, strerror(errno));
        exit(EXIT_FAILURE);
    }
    oldt.c_lflag |= (ICANON | ECHO);  // Restore canonical mode and echo
    if (tcsetattr(STDIN_FILENO, TCSANOW, &oldt) == -1) {
        fprintf(stderr, COLOR_ERROR "Failed to restore terminal attributes: %s\n" COLOR_RESET, strerror(errno));
        exit(EXIT_FAILURE);
    }
}

// Function to implement neonate -n [time_arg]
void neonate_n(int time_arg) {
    set_nonblocking_input();
    char input_char;
    
    while (1) {
        int latest_pid = get_latest_pid();
        if (latest_pid != -1) {
            printf("%d\n", latest_pid);
        } else {
            fprintf(stderr, COLOR_ERROR "Error fetching the latest PID.\n" COLOR_RESET);
        }

        // Sleep for time_arg seconds
        for (int i = 0; i < time_arg; i++) {
            if (read(STDIN_FILENO, &input_char, 1) > 0 && input_char == 'x') {
                printf("Terminating neonate process\n");
                restore_terminal_settings();
                return;
            }
            sleep(1);
        }
    }

    restore_terminal_settings();
}
