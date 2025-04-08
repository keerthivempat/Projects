#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <limits.h>
#include <errno.h>
#include "hop.h"
#include "utilities.h"

// Color macros
#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

void hop(char *path, char *home_directory, char **last_directory) {
    char new_directory[PATH_MAX];
    char temp_directory[PATH_MAX];

    get_current_directory(temp_directory, sizeof(temp_directory));

    if (strcmp(path, "~") == 0) {
        strcpy(new_directory, home_directory);
    } else if (strcmp(path, "-") == 0) {
        if (*last_directory) {
            strcpy(new_directory, *last_directory);
        } else {
            fprintf(stderr, COLOR_ERROR "hop: OLDPWD not set\n" COLOR_RESET);
            return;
        }
    } else {
        if (path[0] == '~') {
            snprintf(new_directory, PATH_MAX, "%s%s", home_directory, path + 1);
        } else {
            strcpy(new_directory, path);
        }
    }

    if (chdir(new_directory) == 0) {
        get_current_directory(new_directory, sizeof(new_directory));
        if (strcmp(new_directory, home_directory) == 0) {
            printf("/home/%s/\n", get_username());
        } else if (strncmp(new_directory, home_directory, strlen(home_directory)) == 0) {
            printf("/home/%s/%s\n", get_username(), new_directory + 1 + strlen(home_directory));
        } else {
            printf("%s\n", new_directory);
        }

        if (*last_directory) {
            free(*last_directory);
        }
        *last_directory = strdup(temp_directory);
    } else {
        fprintf(stderr, COLOR_ERROR "hop: %s\n" COLOR_RESET, strerror(errno));
    }
}
