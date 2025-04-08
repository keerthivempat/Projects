#include "proclore.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <fcntl.h>

#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

void proclore(const char *pid_str) {
    pid_t pid = getpid();
    char path[PATH_MAX];
    char status[64];
    char exe_path[PATH_MAX];
    int vm_size = 0;
    pid_t pgrp;

    if (pid_str != NULL) {
        pid = atoi(pid_str);
    }

    snprintf(path, sizeof(path), "/proc/%d/stat", pid);

    FILE *stat_file = fopen(path, "r");
    if (stat_file == NULL) {
        fprintf(stderr, COLOR_ERROR "Could not open /proc/%d/stat: %s\n" COLOR_RESET, pid, strerror(errno));
        return;
    }

    fscanf(stat_file, "%*d %*s %c %*d %*d %d", status, &pgrp);
    fclose(stat_file);

    snprintf(path, sizeof(path), "/proc/%d/statm", pid);

    FILE *statm_file = fopen(path, "r");
    if (statm_file == NULL) {
        fprintf(stderr, COLOR_ERROR "Could not open /proc/%d/statm: %s\n" COLOR_RESET, pid, strerror(errno));
        return;
    }

    fscanf(statm_file, "%d", &vm_size);
    fclose(statm_file);

    snprintf(path, sizeof(path), "/proc/%d/exe", pid);
    ssize_t len = readlink(path, exe_path, sizeof(exe_path) - 1);
    if (len == -1) {
        fprintf(stderr, COLOR_ERROR "Could not read /proc/%d/exe: %s\n" COLOR_RESET, pid, strerror(errno));
        return;
    }
    exe_path[len] = '\0';

    char status_code = status[0];
    char *process_status = "";
    switch (status_code) {
        case 'R':
            process_status = (tcgetpgrp(STDIN_FILENO) == pgrp) ? "R+" : "R";
            break;
        case 'S':
            process_status = (tcgetpgrp(STDIN_FILENO) == pgrp) ? "S+" : "S";
            break;
        case 'Z':
            process_status = "Z";
            break;
        default:
            process_status = "Unknown";
            break;
    }

    printf("pid : %d\n", pid);
    printf("process status : %s\n", process_status);
    printf("Process Group : %d\n", pgrp);
    printf("Virtual memory : %d\n", vm_size);
    printf("executable path : %s\n", exe_path);
}
