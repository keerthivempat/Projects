#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <dirent.h>
#include <pwd.h>
#include <grp.h>
#include <time.h>
#include <errno.h>
#include "reveal.h"
#include "utilities.h"

#define COLOR_RESET "\x1b[0m"
#define COLOR_DIR "\x1b[34m"
#define COLOR_EXEC "\x1b[32m"
#define COLOR_LINK "\x1b[36m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

int compare(const void *a, const void *b) {
    struct dirent **dirA = (struct dirent **)a;
    struct dirent **dirB = (struct dirent **)b;
    return strcasecmp((*dirA)->d_name, (*dirB)->d_name);
}

void print_permissions(struct stat fileStat) {
    printf((S_ISDIR(fileStat.st_mode)) ? "d" : "-");
    printf((fileStat.st_mode & S_IRUSR) ? "r" : "-");
    printf((fileStat.st_mode & S_IWUSR) ? "w" : "-");
    printf((fileStat.st_mode & S_IXUSR) ? "x" : "-");
    printf((fileStat.st_mode & S_IRGRP) ? "r" : "-");
    printf((fileStat.st_mode & S_IWGRP) ? "w" : "-");
    printf((fileStat.st_mode & S_IXGRP) ? "x" : "-");
    printf((fileStat.st_mode & S_IROTH) ? "r" : "-");
    printf((fileStat.st_mode & S_IWOTH) ? "w" : "-");
    printf((fileStat.st_mode & S_IXOTH) ? "x" : "-");
}

void reveal(const char *dir, int op_a, int op_l) {
    struct dirent **namelist;
    struct stat fileStat;

    // Handle 'reveal -'
    if (strcmp(dir, "-") == 0) {
        dir = getenv("OLDPWD");
        if (!dir) {
            fprintf(stderr, COLOR_ERROR "reveal: OLDPWD not set\n" COLOR_RESET);
            return;
        }
    }

    int n = scandir(dir, &namelist, NULL, alphasort);
    if (n < 0) {
        fprintf(stderr, COLOR_ERROR "Error scanning directory: %s\n" COLOR_RESET, strerror(errno));
        return;
    }

    // Limit to 1000 entries
    if (n > 1000) {
        fprintf(stderr, COLOR_ERROR "Too many entries in directory, only showing first 1000.\n" COLOR_RESET);
        n = 1000;
    }

    // Display total blocks if the '-l' option is used
    if (op_l) {
        int total_blocks = 0;
        for (int i = 0; i < n; i++) {
            if (op_a || namelist[i]->d_name[0] != '.') {
                char full_path[PATH_MAX];
                snprintf(full_path, sizeof(full_path), "%s/%s", dir, namelist[i]->d_name);

                if (stat(full_path, &fileStat) < 0) {
                    fprintf(stderr, COLOR_ERROR "Error getting status for %s: %s\n" COLOR_RESET, full_path, strerror(errno));
                    continue;
                }

                total_blocks += fileStat.st_blocks;
            }
        }
        printf("total %d\n", total_blocks / 2);
    }

    // Print directory contents
    for (int i = 0; i < n; i++) {
        if (op_a || namelist[i]->d_name[0] != '.') {
            char full_path[PATH_MAX];
            snprintf(full_path, sizeof(full_path), "%s/%s", dir, namelist[i]->d_name);

            if (stat(full_path, &fileStat) < 0) {
                fprintf(stderr, COLOR_ERROR "Error getting status for %s: %s\n" COLOR_RESET, full_path, strerror(errno));
                continue;
            }

            if (op_l) {
                print_permissions(fileStat);
                printf(" %3ld", fileStat.st_nlink);
                printf(" %-8s", getpwuid(fileStat.st_uid)->pw_name);
                printf(" %-8s", getgrgid(fileStat.st_gid)->gr_name);
                printf(" %8ld", fileStat.st_size);

                char timebuf[80];
                struct tm *timeinfo = localtime(&fileStat.st_mtime);
                strftime(timebuf, sizeof(timebuf), "%b %d %H:%M", timeinfo);
                printf(" %s ", timebuf);
            }

            if (S_ISDIR(fileStat.st_mode)) {
                printf(COLOR_DIR "%s" COLOR_RESET, namelist[i]->d_name);
            } else if (fileStat.st_mode & S_IXUSR) {
                printf(COLOR_EXEC "%s" COLOR_RESET, namelist[i]->d_name);
            } else if (S_ISLNK(fileStat.st_mode)) {
                printf(COLOR_LINK "%s" COLOR_RESET, namelist[i]->d_name);
            } else {
                printf("%s", namelist[i]->d_name);
            }

            printf("\n");
        }
        free(namelist[i]);
    }

    free(namelist);
}
