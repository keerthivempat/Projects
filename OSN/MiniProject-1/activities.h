#ifndef ACTIVITIES_H
#define ACTIVITIES_H
#include <sys/wait.h>
#define MAX_BG_PROCESSES 100
typedef enum {
    RUNNING,
    COMPLETED,
    TERMINATED,
    STOPPED
} process_state_t;

// Struct to store the background process info
typedef struct {
    pid_t pid;
    char command[256];
    process_state_t state;
    int job_id;
}bg_process;
const char *state_to_string(process_state_t state);
// Functions to manage background processes
void add_process(pid_t pid, const char *command);
void update_process_state(pid_t pid, process_state_t state);
void list_activities();
void sort_bg_processes_lexicographically();
void check_and_update_bg_processes();

#endif
