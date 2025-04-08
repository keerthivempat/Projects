#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>
#include <time.h>
#include <grp.h>
#include <errno.h>
#include <sys/wait.h>
#include "utilities.h"

// Job jobs[MAX_JOBS];  // Definition of the job array
// int jcount = 0;     // Initialize job count
// int next_job_number = 1; // Initialize next job number

void get_system_name(char *system_name, size_t size) {
    gethostname(system_name, size);
}

char* get_username() {
    return getenv("USER");
}

void get_current_directory(char *cwd, size_t size) {
    getcwd(cwd, size);
}

void get_relative_path(char *cwd, char *home_directory, char *relative_path, size_t size) {
    if (strncmp(cwd, home_directory, strlen(home_directory)) == 0) {
        if (strcmp(cwd, home_directory) == 0) {
            strncpy(relative_path, "~", size);
        } else {
            snprintf(relative_path, size, "~%s", cwd + strlen(home_directory));
        }
    } else {
        strncpy(relative_path, cwd, size);
    }
}

void handle_echo(char *command) {
    // Skip the "echo" part of the command
    char *args = command + 5;

    // Check if "-n" flag is present
    int newline = 1;  // By default, append newline
    if (strncmp(args, "-n", 2) == 0) {
        newline = 0;  // Suppress newline
        args += 3;  // Skip "-n" and any space after it
    }

    // Print the rest of the arguments
    printf("%s", args);

    // Only print newline if the "-n" flag wasn't used
    if (newline) {
        printf("\n");
    }
}
