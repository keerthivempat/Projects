#include "seek.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

void seek_recursive(const char *target, const char *directory, const char *base_dir, int only_dirs, int only_files, int execute_flag, int *match_count, char **match_path) {
    DIR *dir;
    struct dirent *entry;
    struct stat statbuf;
    char path[4096];
    char relative_path[4096];

    if ((dir = opendir(directory)) == NULL) {
        // Error in opening directory
        fprintf(stderr, "\033[1;31mError opening directory %s: %s\033[0m\n", directory, strerror(errno));
        return;
    }

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        snprintf(path, sizeof(path), "%s/%s", directory, entry->d_name);

        if (stat(path, &statbuf) == -1) {
            // Error in stat
            fprintf(stderr, "\033[1;31mError getting status for %s: %s\033[0m\n", path, strerror(errno));
            continue;
        }

        snprintf(relative_path, sizeof(relative_path), "%s/%s", base_dir, entry->d_name);
        // printf("DEBUG: Current path: %s\n", path);
        // printf("DEBUG: Relative path: %s\n", relative_path);

        int is_dir = S_ISDIR(statbuf.st_mode);
        int is_file = S_ISREG(statbuf.st_mode);

        if ((only_dirs && is_dir) || (only_files && is_file) || (!only_dirs && !only_files)) {
            if (target == NULL || strstr(relative_path, target) != NULL) {
                (*match_count)++;

                if (is_dir) {
                    printf("\033[1;34m%s\033[0m\n", relative_path); 
                } else if (is_file) {
                    printf("\033[1;32m%s\033[0m\n", relative_path); 
                }
            }
        }

        if (is_dir) {
            seek_recursive(target, path, relative_path, only_dirs, only_files, execute_flag, match_count, match_path);
        }
    }

    closedir(dir);
}

void seek(const char *target, const char *directory, int only_dirs, int only_files, int execute_flag) {
    if (only_dirs && only_files) {
        // Error for invalid flags
        fprintf(stderr, "\033[1;31mInvalid flags!\033[0m\n");
        return;
    }

    int match_count = 0;

    seek_recursive(target, directory, directory, only_dirs, only_files, execute_flag, &match_count, NULL);

    if (!execute_flag && match_count == 0) {
        printf("No match found!\n");
    }
}
