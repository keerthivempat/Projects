#ifndef FOREGROUND_BACKGROUND_H
#define FOREGROUND_BACKGROUND_H
#include <sys/wait.h>
// Function declarations for bringing processes to the foreground and background
void fg(pid_t pid);
void bg(int pid);
#endif
