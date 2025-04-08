#include <stdio.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include "mysignal.h"
#include "activities.h"
#include "all.h"

extern int bg_process_count;
extern bg_process bg_processes[MAX_BG_PROCESSES];

pid_t fg_pid = -1;  // -1 means no foreground process currently

// Function to get the foreground process
pid_t get_foreground_process() {
    return fg_pid;
}

// Function to kill all active processes before logging out
void kill_all_processes() {
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].state == RUNNING) {
            printf("Killing background process %d (%s)\n", bg_processes[i].pid, bg_processes[i].command);
            if (kill(bg_processes[i].pid, SIGKILL) == -1) {
                printf("\033[31m"); // Red color start
                perror("kill");
                printf("\033[0m");   // Reset color
            }
            update_process_state(bg_processes[i].pid, TERMINATED);
        }
    }
    printf("All processes terminated. Exiting shell...\n");
}

// Handlers for signals
void sigint_handler(int sig) {
    (void)sig; 
    if (fg_pid != -1) {
        printf("Sending SIGINT to process %d\n", fg_pid);
        if (kill(fg_pid, SIGINT) == -1) {
            printf("\033[31m"); // Red color start
            perror("kill");
            printf("\033[0m");   // Reset color
        }
        fg_pid = -1;
    }
}

void sigtstp_handler(int sig) {
    (void)sig;  // Suppress unused parameter warning

    // Check if there's a foreground process
    if (pid_fg == -1) {
        return;
    }

    // Add the foreground process to the background job list
    add_process(pid_fg, fg_command);

    // Update the background process state to STOPPED
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].pid == pid_fg) {
            kill(pid_fg, SIGSTOP);
            bg_processes[i].state = STOPPED;
            break;
        }
    }

    // Clear the foreground process tracking
    pid_fg = -1;
}

void sigquit_handler(int sig) {
    printf("\n");
    (void)sig; 
    printf("SIGQUIT handler called.\n");
    kill_all_processes();
    exit(0);
}

void send_signal_to_process(pid_t pid, int signal) {
    signal = signal % 32;  // Modulo 32 to ensure valid signal number
    printf("Sending signal %d to process %d\n", signal, pid);

    // Check if process exists
    if (kill(pid, 0) == -1) {
        if (errno == ESRCH) {
            printf("\033[31mNo such process found with PID %d\033[0m\n", pid);  // Red color
        } else {
            printf("\033[31m"); // Red color start
            perror("Error checking process");
            printf("\033[0m");   // Reset color
        }
        return;
    }

    // Send the signal
    if (kill(pid, signal) == -1) {
        printf("\033[31m"); // Red color start
        perror("Error sending signal");
        printf("Signal %d could not be sent to process %d\033[0m\n", signal, pid);  // Reset color
    } else {
        printf("Signal %d sent successfully to process %d\n", signal, pid);
    }
}

void initialize_signal_handlers() {
    struct sigaction sa;

    // Set up the handler for SIGINT (Ctrl+C)
    sa.sa_handler = sigint_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGINT, &sa, NULL) == -1) {
        printf("\033[31m"); // Red color start
        perror("sigaction - SIGINT");
        printf("\033[0m");   // Reset color
    }

    // Set up the handler for SIGTSTP (Ctrl+Z)
    sa.sa_handler = sigtstp_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGTSTP, &sa, NULL) == -1) {
        printf("\033[31m"); // Red color start
        perror("sigaction - SIGTSTP");
        printf("\033[0m");   // Reset color
    }

    // Set up the handler for SIGQUIT (Ctrl+D)
    sa.sa_handler = sigquit_handler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    if (sigaction(SIGQUIT, &sa, NULL) == -1) {
        printf("\033[31m"); // Red color start
        perror("sigaction - SIGQUIT");
        printf("\033[0m");   // Reset color
    }
}
