#include "foreground_background.h"
#include "activities.h"
#include "all.h"
#include <stdio.h>
#include <sys/wait.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>

extern bg_process bg_processes[MAX_BG_PROCESSES];

extern int bg_process_count;

// Color macros
#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

int find_process_by_pid(pid_t pid) {
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].pid == pid) {
            return i; // Return the index
        }
    }
    return -1; // Not found
}

void fg(int pid) {
    printf("Entering fg with PID %d\n", pid);
    int found = 0;
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].pid == pid) {
            found = 1;

            // Set the foreground process group
            printf("Setting foreground process group to PID %d\n", pid);
            // if (tcsetpgrp(STDIN_FILENO, pid) == -1) {
            //     fprintf(stderr, COLOR_ERROR "tcsetpgrp failed\n" COLOR_RESET);
            //     return;
            // }

            int status;
            while (waitpid(pid, &status, WUNTRACED) != pid) {
                if (errno != EINTR) {
                    fprintf(stderr, COLOR_ERROR "waitpid failed\n" COLOR_RESET);
                    return;
                }
            }

            // Check the status of the process
            if (WIFSTOPPED(status)) {
                printf("Process %d stopped by signal %d\n", pid, WSTOPSIG(status));
                bg_processes[i].state = STOPPED;
            } else if (WIFEXITED(status)) {
                printf("Process %d exited with status %d\n", pid, WEXITSTATUS(status));
                remove_completed_bg_process(pid);
            } else if (WIFSIGNALED(status)) {
                printf("Process %d terminated by signal %d\n", pid, WTERMSIG(status));
                remove_completed_bg_process(pid);
            }

            // Restore the shell's process group
            printf("Restoring shell process group\n");
            // if (tcsetpgrp(STDIN_FILENO, getpgrp()) == -1) {
            //     fprintf(stderr, COLOR_ERROR "tcsetpgrp failed\n" COLOR_RESET);
            // }

            // Update prompt and shell status
            printf("Process %d state after fg: %s\n", pid, state_to_string(bg_processes[i].state));
            break;
        }
    }

    if (!found) {
        fprintf(stderr, COLOR_ERROR "No such process found\n" COLOR_RESET);
    }
}

void bg(int pid) {
    int found = 0;
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].pid == pid) {
            found = 1;
            if (bg_processes[i].state == TERMINATED) {
                fprintf(stderr, COLOR_ERROR "No such process found\n" COLOR_RESET);
                return;
            }
            bg_processes[i].state = RUNNING;
            if (kill(pid, SIGCONT) == -1) {
                fprintf(stderr, COLOR_ERROR "Error continuing process\n" COLOR_RESET);
            } else {
                printf("[%d] %d resumed in background\n", bg_processes[i].job_id, pid);
                bg_processes[i].state = RUNNING; // Ensure state is updated
            }
            break;
        }
    }
    if (!found) {
        fprintf(stderr, COLOR_ERROR "No such process found\n" COLOR_RESET);
    }
}
