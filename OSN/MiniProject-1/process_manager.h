// process_manager.h
#ifndef PROCESS_MANAGER_H
#define PROCESS_MANAGER_H

#include <sys/types.h>

// Node structure for linked list
typedef struct ProcessNode {
    pid_t pid;
    struct ProcessNode* next;
} ProcessNode;

// Global variables for managing the list of stopped processes
extern ProcessNode* stopped_process_list;

// Function declarations
void add_stopped_process(pid_t pid);
void remove_stopped_process(pid_t pid);
void print_stopped_processes(void);

#endif
