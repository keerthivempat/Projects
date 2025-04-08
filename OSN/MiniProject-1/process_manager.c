// process_manager.c
#include <stdio.h>
#include <stdlib.h>
#include "process_manager.h"

// Initialize the head of the stopped process list
ProcessNode* stopped_process_list = NULL;

void add_stopped_process(pid_t pid) {
    ProcessNode* new_node = (ProcessNode*)malloc(sizeof(ProcessNode));
    if (new_node == NULL) {
        perror("Failed to allocate memory for new process node");
        return;
    }
    new_node->pid = pid;
    new_node->next = stopped_process_list;
    stopped_process_list = new_node;
}

void remove_stopped_process(pid_t pid) {
    ProcessNode** current = &stopped_process_list;
    while (*current) {
        ProcessNode* entry = *current;
        if (entry->pid == pid) {
            *current = entry->next;
            free(entry);
            return;
        }
        current = &entry->next;
    }
}

void print_stopped_processes(void) {
    ProcessNode* current = stopped_process_list;
    while (current) {
        printf("Stopped process with PID %d\n", current->pid);
        current = current->next;
    }
}
