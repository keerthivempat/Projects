Displaying prompt:
The prompt is generated and displayed by the display_prompt function, which is defined in the prompt.c file and declared in the prompt.h header file.
char *home_directory: This represents the shell's home directory. The prompt will show paths relative to this directory when inside it, and absolute paths when outside.
char system_name[HOST_NAME_MAX]: Stores the name of the system (hostname).
char cwd[PATH_MAX]: Stores the current working directory as an absolute path.
char relative_path[PATH_MAX]: Stores the path relative to the home directory if the current directory is within the home directory. Otherwise, it stores the absolute path.

hop:
The hop function changes the current working directory of the shell based on the given path. It also provides specific functionality for paths like ~ (home directory) and - (last visited directory). After changing the directory, it updates the shell's state to reflect this change.
The function handles errors for invalid directories, such as attempting to change to a directory that does not exist or trying to use - without having a last directory set.

reveal:
COLOR_RESET, COLOR_DIR, COLOR_EXEC, COLOR_LINK: Define ANSI escape codes for coloring the terminal output. These are used to differentiate directories, executable files, and symbolic links by color.
Before listing the files, the total number of blocks used by the files in the directory is calculated if op_l is set. This involves iterating over the directory entries and using stat to get the file's block size. The result is printed as total X, where X is the total block count divided by 2

log:
void displayHistory();
This function displays the history of commands stored in the log.
If no commands have been stored (logCount is 0), it prints "No commands in log.". stores the last 15 commands, if we write more than that then it overwrites.

proclore:
displays information about the process such as its status, process group, virtual memory size, and the path to the executable.
A switch statement is used to convert the single-character status code into a more meaningful string:
'R': Running (R+ if it's in the foreground, R if it's in the background).
'S': Sleeping (S+ if it's in the foreground, S if it's in the background).
'Z': Zombie.
default: Unknown status.
The function is meant to be called with an optional PID string. If no PID is provided, it defaults to the current process. It prints all the gathered information to the console.

Seek:
search for directories, files, or both, and to execute a command on the found items.
Matched directories are printed in blue (\033[1;34m) and matched files in green (\033[1;32m).
The function checks if both only_dirs and only_files flags are set. If so, it prints an error message because it's invalid to search for both files and directories exclusively.

utilities.c file:
The utilities.c file defines a set of utility functions. These functions handle system information retrieval, path manipulation, job management, and command execution in the background. 
System Information Functions: These help retrieve details like the system's hostname, current user's name, current working directory, and relative path from the home directory.
Background Job Management: The program can execute commands in the background, track them, and manage their lifecycle (checking if they are completed and cleaning up the job list).
Echo Handling: The handle_echo() function simulates the echo command by printing whatever comes after "echo " in the input string.
Background Job Monitoring: The shell regularly checks for completed background jobs and updates the job list accordingly.