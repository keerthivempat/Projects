#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <string.h>
#include <sys/types.h>
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include "activities.h"

extern void check_bg_processes();
extern bg_process bg_processes[MAX_BG_PROCESSES];
extern int bg_process_count;

// Color macros
#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

const char *state_to_string(process_state_t state) {
    switch (state) {
        case RUNNING:
            return "Running";
        case COMPLETED:
            return "Completed";
        case TERMINATED:
            return "Terminated";
        case STOPPED:
            return "Stopped";
        default:
            return "Unknown";
    }
}

void add_process(pid_t pid, const char *command) {
    printf("hidnfdnf\n");
    if (bg_process_count < MAX_BG_PROCESSES) {
        bg_processes[bg_process_count].pid = pid;
        strncpy(bg_processes[bg_process_count].command, command, 255);
        bg_processes[bg_process_count].command[255] = '\0';
        bg_processes[bg_process_count].state = RUNNING;
        bg_processes[bg_process_count].job_id = bg_process_count + 1;
        bg_process_count++;
    }
}

void update_process_state(pid_t pid, process_state_t state) {
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].pid == pid) {
            bg_processes[i].state = state;
            break;
        }
    }
}

int compare_processes(const void *a, const void *b) {
    bg_process *processA = (bg_process *)a;
    bg_process *processB = (bg_process *)b;
    return strcmp(processA->command, processB->command);
}

void sort_processes_lexicographically() {
    qsort(bg_processes, bg_process_count, sizeof(bg_process), compare_processes);
}

void check_and_update_processes() {
    for (int i = 0; i < bg_process_count; i++) {
        pid_t pid = bg_processes[i].pid;
        int status;

        // Skip already stopped processes until they are resumed
        if (bg_processes[i].state == STOPPED) {
            printf("Process %d is already stopped. Skipping check.\n", pid);
            continue;
        }

        // Check if the process has changed state
        pid_t result = waitpid(pid, &status, WNOHANG | WUNTRACED | WCONTINUED);

        if (result == -1) {
            fprintf(stderr, COLOR_ERROR "waitpid error\n" COLOR_RESET);
            continue;
        }

        if (result == 0) {
            // Process is still running or unchanged
            continue;
        }

        if (WIFEXITED(status)) {
            printf("Process %d exited normally with status %d.\n", pid, WEXITSTATUS(status));
            bg_processes[i].state = COMPLETED;  // Mark process as completed
        } else if (WIFSIGNALED(status)) {
            printf("Process %d was terminated by signal %d.\n", pid, WTERMSIG(status));
            bg_processes[i].state = TERMINATED;  // Mark process as terminated
            // Remove terminated process from the list
            for (int j = i; j < bg_process_count - 1; j++) {
                bg_processes[j] = bg_processes[j + 1];
            }
            bg_process_count--;
            i--;  // Adjust index after removal
        } else if (WIFSTOPPED(status)) {
            printf("Process %d was stopped by signal %d.\n", pid, WSTOPSIG(status));
            bg_processes[i].state = STOPPED;  // Mark process as stopped
            printf("Updated process %d to STOPPED state.\n", pid);
        } else if (WIFCONTINUED(status)) {
            printf("Process %d was resumed.\n", pid);
            bg_processes[i].state = RUNNING;  // Mark process as running after resume
        }
    }
}

void list_activities() {
    check_and_update_processes();
    printf("%d\n", bg_process_count);
    if (bg_process_count == 0) {
        printf("No background processes.\n");
        return;
    }
    sort_processes_lexicographically();
    for (int i = 0; i < bg_process_count; i++) {
        if (bg_processes[i].state == TERMINATED) {
            continue; // Skip terminated processes
        }
        printf("[%d] : %s - %s\n", bg_processes[i].pid, bg_processes[i].command, state_to_string(bg_processes[i].state));
    }
}
