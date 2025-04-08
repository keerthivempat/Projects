#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
#include <time.h>
#include <stdbool.h>

#define MAX_REQUESTS 100
#define YELLOW "\033[33m"
#define PINK "\033[35m"
#define GREEN "\033[32m"
#define RED "\033[31m"
#define WHITE "\033[37m"
#define RESET "\033[0m"

typedef struct {
    pthread_mutex_t mutex;
    sem_t access_sem;
    int readers;
    int writers;
    int is_deleted;
    pthread_mutex_t state_mutex;
} File;

typedef struct {
    int user_id;
    int file_num;
    char operation[10];
    int request_time;
    bool is_processed;
    bool is_cancelled;
    pthread_t thread;
} Request;

// Global variables
int read_time, write_time, delete_time;
int num_files, max_concurrent, max_wait_time;
Request requests[MAX_REQUESTS];
int num_requests = 0;
File* files;
pthread_mutex_t print_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_mutex_t completion_mutex = PTHREAD_MUTEX_INITIALIZER;
time_t start_time;

int get_current_time() {
    return (int)(time(NULL) - start_time);
}

void print_message(const char* color, const char* format, ...) {
    pthread_mutex_lock(&print_mutex);
    va_list args;
    va_start(args, format);
    printf("%s", color);
    vprintf(format, args);
    printf("%s\n", RESET);
    fflush(stdout);
    va_end(args);
    pthread_mutex_unlock(&print_mutex);
}

bool check_timeout(Request* req, int current_time) {
    if ((current_time - req->request_time) >= max_wait_time && !req->is_processed) {
        req->is_cancelled = true;
        print_message(RED, "User %d canceled the request due to no response at %d seconds",
                     req->user_id, req->request_time + max_wait_time);
        return true;
    }
    return false;
}

void* handle_read(void* arg) {
    Request* req = (Request*)arg;
    int file_idx = req->file_num - 1;
    
    sleep(req->request_time); // Wait until request time
    print_message(YELLOW, "User %d has made request for performing READ on file %d at %d seconds",
                 req->user_id, req->file_num, req->request_time);
    
    sleep(1); // LAZY waits 1 second before processing
    
    if (check_timeout(req, get_current_time())) {
        return NULL;
    }
    
    pthread_mutex_lock(&files[file_idx].state_mutex);
    if (files[file_idx].is_deleted) {
        print_message(WHITE, "LAZY has declined the request of User %d at %d seconds because an invalid/deleted file was requested.",
                     req->user_id, get_current_time());
        pthread_mutex_unlock(&files[file_idx].state_mutex);
        return NULL;
    }
    pthread_mutex_unlock(&files[file_idx].state_mutex);
    
    if (sem_wait(&files[file_idx].access_sem) == 0) {
        req->is_processed = true;
        pthread_mutex_lock(&files[file_idx].mutex);
        files[file_idx].readers++;
        pthread_mutex_unlock(&files[file_idx].mutex);
        
        print_message(PINK, "LAZY has taken up the request of User %d at %d seconds",
                     req->user_id, get_current_time());
        
        sleep(read_time);
        
        pthread_mutex_lock(&files[file_idx].mutex);
        files[file_idx].readers--;
        pthread_mutex_unlock(&files[file_idx].mutex);
        
        sem_post(&files[file_idx].access_sem);
        
        print_message(GREEN, "The request for User %d was completed at %d seconds",
                     req->user_id, get_current_time());
    }
    
    return NULL;
}

void* handle_write(void* arg) {
    Request* req = (Request*)arg;
    int file_idx = req->file_num - 1;
    
    sleep(req->request_time); // Wait until request time
    print_message(YELLOW, "User %d has made request for performing WRITE on file %d at %d seconds",
                 req->user_id, req->file_num, req->request_time);
    
    sleep(1); // LAZY waits 1 second before processing
    
    if (check_timeout(req, get_current_time())) {
        return NULL;
    }
    
    pthread_mutex_lock(&files[file_idx].state_mutex);
    if (files[file_idx].is_deleted) {
        print_message(WHITE, "LAZY has declined the request of User %d at %d seconds because an invalid/deleted file was requested.",
                     req->user_id, get_current_time());
        pthread_mutex_unlock(&files[file_idx].state_mutex);
        return NULL;
    }
    pthread_mutex_unlock(&files[file_idx].state_mutex);
    
    if (sem_wait(&files[file_idx].access_sem) == 0) {
        req->is_processed = true;
        pthread_mutex_lock(&files[file_idx].mutex);
        files[file_idx].writers++;
        pthread_mutex_unlock(&files[file_idx].mutex);
        
        print_message(PINK, "LAZY has taken up the request of User %d at %d seconds",
                     req->user_id, get_current_time());
        
        sleep(write_time);
        
        pthread_mutex_lock(&files[file_idx].mutex);
        files[file_idx].writers--;
        pthread_mutex_unlock(&files[file_idx].mutex);
        
        sem_post(&files[file_idx].access_sem);
        
        print_message(GREEN, "The request for User %d was completed at %d seconds",
                     req->user_id, get_current_time());
    }
    
    return NULL;
}

void* handle_delete(void* arg) {
    Request* req = (Request*)arg;
    int file_idx = req->file_num - 1;
    
    sleep(req->request_time); // Wait until request time
    print_message(YELLOW, "User %d has made request for performing DELETE on file %d at %d seconds",
                 req->user_id, req->file_num, req->request_time);
    
    sleep(1); // LAZY waits 1 second before processing
    
    if (check_timeout(req, get_current_time())) {
        return NULL;
    }
    
    pthread_mutex_lock(&files[file_idx].state_mutex);
    if (files[file_idx].is_deleted) {
        print_message(WHITE, "LAZY has declined the request of User %d at %d seconds because an invalid/deleted file was requested.",
                     req->user_id, get_current_time());
        pthread_mutex_unlock(&files[file_idx].state_mutex);
        return NULL;
    }
    
    if (files[file_idx].readers > 0 || files[file_idx].writers > 0) {
        pthread_mutex_unlock(&files[file_idx].state_mutex);
        print_message(RED, "User %d canceled the request due to no response at %d seconds",
                     req->user_id, req->request_time + max_wait_time);
        return NULL;
    }
    
    if (sem_wait(&files[file_idx].access_sem) == 0) {
        req->is_processed = true;
        files[file_idx].is_deleted = 1;
        
        print_message(PINK, "LAZY has taken up the request of User %d at %d seconds",
                     req->user_id, get_current_time());
        
        sleep(delete_time);
        
        sem_post(&files[file_idx].access_sem);
        
        print_message(GREEN, "The request for User %d was completed at %d seconds",
                     req->user_id, get_current_time());
    }
    
    pthread_mutex_unlock(&files[file_idx].state_mutex);
    return NULL;
}

void process_requests() {
    printf("LAZY has woken up!\n");
    
    start_time = time(NULL);
    
    // Create all threads at the start
    for (int i = 0; i < num_requests; i++) {
        void* (*handler)(void*) = NULL;
        
        if (strcmp(requests[i].operation, "READ") == 0) {
            handler = handle_read;
        } else if (strcmp(requests[i].operation, "WRITE") == 0) {
            handler = handle_write;
        } else if (strcmp(requests[i].operation, "DELETE") == 0) {
            handler = handle_delete;
        }
        
        if (handler != NULL) {
            requests[i].is_processed = false;
            requests[i].is_cancelled = false;
            pthread_create(&requests[i].thread, NULL, handler, &requests[i]);
        }
    }
    
    // Wait for all threads to complete
    for (int i = 0; i < num_requests; i++) {
        pthread_join(requests[i].thread, NULL);
    }
    
    printf("LAZY has no more pending requests and is going back to sleep!\n");
}

int main() {
    scanf("%d %d %d", &read_time, &write_time, &delete_time);
    scanf("%d %d %d", &num_files, &max_concurrent, &max_wait_time);
    
    files = malloc(num_files * sizeof(File));
    for (int i = 0; i < num_files; i++) {
        pthread_mutex_init(&files[i].mutex, NULL);
        pthread_mutex_init(&files[i].state_mutex, NULL);
        sem_init(&files[i].access_sem, 0, max_concurrent);
        files[i].readers = 0;
        files[i].writers = 0;
        files[i].is_deleted = 0;
    }
    
    char operation[10];
    while (1) {
        scanf("%s", operation);
        if (strcmp(operation, "STOP") == 0) break;
        
        requests[num_requests].user_id = atoi(operation);
        scanf("%d %s %d", 
              &requests[num_requests].file_num,
              requests[num_requests].operation,
              &requests[num_requests].request_time);
        num_requests++;
    }
    
    process_requests();
    
    // Cleanup
    for (int i = 0; i < num_files; i++) {
        pthread_mutex_destroy(&files[i].mutex);
        pthread_mutex_destroy(&files[i].state_mutex);
        sem_destroy(&files[i].access_sem);
    }
    free(files);
    
    return 0;
}