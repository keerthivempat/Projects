#include <stdio.h>
#include <unistd.h>
#include <limits.h>
#include "prompt.h"
#include "utilities.h"
#include <string.h>

void display_prompt(char *home_directory, char *extra_prompt) {
    char system_name[HOST_NAME_MAX];
    char cwd[PATH_MAX];
    char relative_path[PATH_MAX];

    get_system_name(system_name, sizeof(system_name));
    get_current_directory(cwd, sizeof(cwd));
    get_relative_path(cwd, home_directory, relative_path, sizeof(relative_path));

    char *username = get_username();

    const char *pink_color = "\033[38;5;207m";
    const char *reset_color = "\033[0m";

    // Print the regular shell prompt and the extra prompt if it exists
    if (extra_prompt && strlen(extra_prompt) > 0) {
        printf("%s<%s@%s:%s %s%s%s> ", pink_color, username, system_name, relative_path, extra_prompt, reset_color, pink_color);
    } else {
        printf("%s<%s@%s:%s> ", pink_color, username, system_name, relative_path);
    }

    // Reset the color to default for the command input
    printf("%s", reset_color);

    // Ensure the prompt is printed immediately
    fflush(stdout);
}
