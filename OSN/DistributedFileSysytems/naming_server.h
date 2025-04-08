#ifndef NAMING_SERVER_H
#define NAMING_SERVER_H

#define NAMING_SERVER_INFO_FILE "naming_server_info.txt"
#define BUFFER_SIZE 1024
#define MAX_SERVERS 100
#define MAX_IP_LENGTH 16
#define MAX_PORT_LENGTH 6
#define MAX_PATHS 100
#define MAX_PATH_LENGTH 256
#define MAX_FILE_SIZE 1048576 
#define MAX_FILES 1000
#define MAX_PENDING_OPS 1000
#define FILE_LOCKED -1
#define FILE_AVAILABLE 0


#include <uthash.h>  // Make sure to install uthash development library

// LRU Cache structure
#define MAX_CACHE_SIZE 1000

// Struct to store storage server information
typedef struct {
    char ip[MAX_IP_LENGTH];
    char nm_port[MAX_PORT_LENGTH]; 
    char client_port[MAX_PORT_LENGTH];
    char accessible_paths[MAX_PATHS][MAX_PATH_LENGTH];
    int path_count;
} StorageServer;

// File lock status structure
typedef struct {
    char filepath[MAX_PATH_LENGTH];
    int write_locked;
    int reader_count;
    pthread_mutex_t lock;
    pthread_cond_t read_cond;
    pthread_cond_t write_cond;
} FileLock;

typedef struct CacheNode {
    char key[MAX_PATH_LENGTH];           // Path as key
    void *value;               // Storage server info
    struct CacheNode* prev;
    struct CacheNode* next;
} CacheNode;

typedef struct {
    int size;
    CacheNode* head;
    CacheNode* tail;
    CacheNode* hash[MAX_CACHE_SIZE];  // Simple hash table for O(1) lookup
    pthread_mutex_t lock;   
} LRUCache;

// HashMap structure for path to server mapping
typedef struct {
    char path[MAX_PATH_LENGTH];          // key
    StorageServer server;                // value
    UT_hash_handle hh;                   // makes this structure hashable
} PathServerMap;



extern StorageServer storage_servers[MAX_SERVERS];
extern int server_count;

extern PathServerMap* path_server_map;
extern LRUCache* cache;
extern FileLock file_locks[MAX_FILES];
extern int file_lock_count;
extern pthread_mutex_t file_locks_mutex;
extern pthread_mutex_t server_list_mutex;
// Function declarations
LRUCache* create_cache();
void free_cache(LRUCache *cache);
void cache_insert(LRUCache *cache, const char *key, void *value);
void* cache_lookup(LRUCache *cache, const char *key);
void initialize_hashmap();
void cleanup_hashmap();
void hashmap_insert(const char* path, StorageServer server);
// Reader-writer lock helper functions
int acquire_read_lock(const char *filepath);
int release_read_lock(const char *filepath);
int acquire_write_lock(const char *filepath);
int release_write_lock(const char *filepath);
void cleanup_locks();
void cleanup_cache();

char* get_local_ip();
void write_naming_server_info(const char* ip, int client_port, int storage_port);
int initialize_socket(int *port);
void list_storage_servers();
void list_all_accessible_paths(int client_socket);
void add_accessible_path(StorageServer *server, const char *filePath, const char *name);
int forward_create_request_to_ss(StorageServer server, const char *filePath, const char *name, int is_folder);
int create_file_or_folder_on_ns(const char *filePath, const char *name, int is_folder);
StorageServer get_storage_server_info(const char *filePath);
void* client_thread_handler(void* arg);
void* storage_thread_handler(void* arg);
void handle_client_requests(int client_socket);
void handle_storage_requests(int storage_socket);
int copy_file_or_directory(StorageServer ss1Info, StorageServer ss2Info, char* srcPath, char* destPath);

#endif // NAMING_SERVER_H
