#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <limits.h>
#include <sys/types.h>
#include <dirent.h>
#include <sys/stat.h>
#include <pwd.h>
#include <grp.h>
#include <time.h>
#include <errno.h>

#define MAX_INPUT_SIZE 1024

// Color definitions using ANSI escape codes
#define COLOR_RESET "\x1b[0m"
#define COLOR_DIR "\x1b[34m"    // Blue
#define COLOR_EXEC "\x1b[32m"   // Green
#define COLOR_LINK "\x1b[36m"   // Cyan

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

void display_prompt(char *home_directory) {
    char system_name[HOST_NAME_MAX];
    char cwd[PATH_MAX];
    char relative_path[PATH_MAX];

    get_system_name(system_name, sizeof(system_name));
    get_current_directory(cwd, sizeof(cwd));
    get_relative_path(cwd, home_directory, relative_path, sizeof(relative_path));

    char *username = get_username();

    printf("<%s@%s:%s> ", username, system_name, relative_path);
}

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
            fprintf(stderr, "hop: OLDPWD not set\n");
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
        perror("hop");
    }
}

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
    int n = scandir(dir, &namelist, NULL, alphasort);

    if (n < 0) {
        perror("scandir");
        return;
    }

    // Count valid entries
    int count = 0;
    for (int i = 0; i < n; i++) {
        if (op_a || namelist[i]->d_name[0] != '.') {
            count++;
        }
    }

    // Print total blocks if -l flag is set
    if (op_l) {
        int total_blocks = 0;
        for (int i = 0; i < n; i++) {
            if (op_a || namelist[i]->d_name[0] != '.') {
                char full_path[PATH_MAX];
                snprintf(full_path, sizeof(full_path), "%s/%s", dir, namelist[i]->d_name);

                if (stat(full_path, &fileStat) < 0) {
                    perror("stat");
                    continue;
                }

                total_blocks += fileStat.st_blocks;
            }
        }
        printf("total %d\n", total_blocks / 2);
    }

    // Print entries
    for (int i = 0; i < n; i++) {
        if (op_a || namelist[i]->d_name[0] != '.') {
            char full_path[PATH_MAX];
            snprintf(full_path, sizeof(full_path), "%s/%s", dir, namelist[i]->d_name);

            if (stat(full_path, &fileStat) < 0) {
                perror("stat");
                continue;
            }

            if (op_l) {
                print_permissions(fileStat);
                printf(" %ld", fileStat.st_nlink);
                printf(" %s", getpwuid(fileStat.st_uid)->pw_name);
                printf(" %s", getgrgid(fileStat.st_gid)->gr_name);
                printf(" %8ld", fileStat.st_size);

                char timebuf[80];
                struct tm *timeinfo = localtime(&fileStat.st_mtime);
                strftime(timebuf, sizeof(timebuf), "%b %d %H:%M", timeinfo);
                printf(" %s", timebuf);
            }

            if (S_ISDIR(fileStat.st_mode)) {
                printf(COLOR_DIR "%s" COLOR_RESET, namelist[i]->d_name); // Directory
            } else if (fileStat.st_mode & S_IXUSR) {
                printf(COLOR_EXEC "%s" COLOR_RESET, namelist[i]->d_name); // Executable
            } else if (S_ISLNK(fileStat.st_mode)) {
                printf(COLOR_LINK "%s" COLOR_RESET, namelist[i]->d_name); // Symbolic link
            } else {
                printf("%s", namelist[i]->d_name); // Regular file
            }

            printf("\n");
        }
        free(namelist[i]);
    }

    free(namelist);
}

int main() {
    char input[MAX_INPUT_SIZE];
    char *last_directory = NULL;

    char shell_home_directory[PATH_MAX];
    get_current_directory(shell_home_directory, sizeof(shell_home_directory));

    while (1) {
        display_prompt(shell_home_directory);
        fgets(input, MAX_INPUT_SIZE, stdin);
        input[strcspn(input, "\n")] = 0;

        char *token = strtok(input, " ");
        if (token && strcmp(token, "hop") == 0) {
            token = strtok(NULL, " ");
            if (!token) {
                hop("~", shell_home_directory, &last_directory);
            } else {
                while (token) {
                    hop(token, shell_home_directory, &last_directory);
                    token = strtok(NULL, " ");
                }
            }
        } else if (token && strcmp(token, "reveal") == 0) {
            int op_a = 0, op_l = 0;
            token = strtok(NULL, " ");

            while (token && token[0] == '-') {
                for (int i = 1; i < strlen(token); i++) {
                    if (token[i] == 'a') op_a = 1;
                    if (token[i] == 'l') op_l = 1;
                }
                token = strtok(NULL, " ");
            }

            const char *dir = token ? token : ".";
            reveal(dir, op_a, op_l);
        }
    }

    if (last_directory) {
        free(last_directory);
    }

    return 0;
}
