// naming_server.c Code 
#include <stdio.h>
#include <ctype.h>
#include <errno.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <libgen.h> // For basename()
#include <netdb.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/select.h>
#include "naming_server.h"
#include <errno.h>
#include <asm-generic/socket.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <dirent.h>
#include <sys/time.h>

#define MAX_BACKUPS 20  // Define the number of backups
StorageServer storage_servers[MAX_SERVERS];
StorageServer backup_storage_servers1[MAX_SERVERS]; // Backup storage servers
StorageServer backup_storage_servers2[MAX_SERVERS]; // Second backup storage servers
int server_count = 0;
int is_up[MAX_SERVERS] = {1}; 
int errorCode=0;
int index_server=0;
char home[1024];
PathServerMap* path_server_map = NULL;   // Global hashmap
LRUCache* cache = NULL;                  // Global LRU cache
FileLock file_locks[MAX_FILES];
int file_lock_count = 0;
pthread_mutex_t file_locks_mutex;
pthread_mutex_t server_list_mutex;
int total_count=0;

//StorageServer storage_servers[MAX_SERVERS];
void logging_data(char* data) {
    char home[1024];
    if (getcwd(home, sizeof(home)) == NULL) {
        perror("getcwd() error");
        return;
    }
    char log_file_path[4096];
    snprintf(log_file_path, sizeof(log_file_path), "%s/log.txt", home);

    // Open the file with write permissions
    int log_fd = open(log_file_path, O_RDWR | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH | S_IWOTH);
    if (log_fd == -1) {
        perror("\033[1;31mCouldn't open the file\033[0m");
        return;
    }
    lseek(log_fd, 0, SEEK_END);
    write(log_fd, "\n", 1);
    write(log_fd, data, strlen(data));
    close(log_fd);
}

// Initialize LRU Cache
// Helper to create a cache node
CacheNode* create_cache_node(const char *key, void *value) {
    CacheNode *node = (CacheNode *)malloc(sizeof(CacheNode));
    if (!node) {
        perror("Failed to allocate memory for CacheNode");
        return NULL;
    }
    strncpy(node->key, key, MAX_PATH_LENGTH - 1);
    node->key[MAX_PATH_LENGTH - 1] = '\0';
    node->value = value;
    node->prev = node->next = NULL;
    return node;
}

// Helper function to check if a path is absolute
int is_absolute_path(const char *path) {
    return path[0] == '/';  // A simple check: absolute paths begin with '/'
}

// Helper function to resolve a relative path to an absolute path
void resolve_relative_path(char *resolved_path, const char *path) {
    if (is_absolute_path(path)) {
        // If the path is already absolute, use it directly
        strcpy(resolved_path, path);
    } else {
        // If the path is relative, prepend the home directory
        snprintf(resolved_path, 4096, "%s/%s", home, path);
    }
}

// Helper function to recursively copy files and directories
void copy_directory_1(const char *src, const char *dst);

void add_paths_from_dir(const char *base_path) {
    DIR *dir = opendir(base_path);
    if (dir == NULL) {
        perror("opendir failed");
        return;
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        // Skip the special directories "." and ".."
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        char full_path[4096];
        snprintf(full_path, sizeof(full_path), "%s/%s", base_path, entry->d_name);

        struct stat path_stat;
        if (stat(full_path, &path_stat) == 0) {
            // If it's a directory, recurse into it
            if (S_ISDIR(path_stat.st_mode)) {
                // Add the directory to accessible paths
                strncpy(storage_servers[server_count].accessible_paths[storage_servers[server_count].path_count], full_path, MAX_PATH_LENGTH - 1);
                storage_servers[server_count].path_count++;
                add_paths_from_dir(full_path);  // Recurse into subdirectories
            } else if (S_ISREG(path_stat.st_mode)) {
                // If it's a file, just add the path
                strncpy(storage_servers[server_count].accessible_paths[storage_servers[server_count].path_count], full_path, MAX_PATH_LENGTH - 1);
                storage_servers[server_count].path_count++;
            }
        }
    }
    closedir(dir);
}

// Function to copy the accessible path to backup servers
void create_backups(int index) {
    // Ensure the backup directories exist for backup1 and backup2
    char backup1_path[4200], backup2_path[4200];
    char resolved_original_path[1024];

    // Copy the original storage server to backup servers
    backup_storage_servers1[index] = storage_servers[index];
    backup_storage_servers2[index] = storage_servers[index];

    // Iterate over the accessible paths
    for (int i = 0; i < storage_servers[index].path_count; i++) {
        // Resolve the original path (either absolute or relative)
        resolve_relative_path(resolved_original_path, storage_servers[index].accessible_paths[i]);

        // Convert the original path to relative path from home
        char relative_path[4096];
        if (strncmp(resolved_original_path, home, strlen(home)) == 0) {
            strcpy(relative_path, resolved_original_path + strlen(home) + 1);  // +1 to skip the '/'
        }

        // Now copy to backup1
        snprintf(backup1_path, sizeof(backup1_path), "backup1/%d/%s", index+1, relative_path);
        snprintf(backup2_path, sizeof(backup2_path), "backup2/%d/%s", index+1, relative_path);

        // Ensure the parent directory exists
        char parent_dir[4096];
        strcpy(parent_dir, backup1_path);
        char *last_slash = strrchr(parent_dir, '/');
        if (last_slash) {
            *last_slash = '\0';
            mkdir(parent_dir, 0755); // Create parent directory for backup1
        }
        strcpy(parent_dir, backup2_path);
        if (last_slash) {
            *last_slash = '\0';
            mkdir(parent_dir, 0755); // Create parent directory for backup2
        }

        // Check if the original path is a directory or file
        struct stat st;
        if (stat(resolved_original_path, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                // It's a directory, so recursively copy the entire directory
                copy_directory_1(resolved_original_path, backup1_path);
                copy_directory_1(resolved_original_path, backup2_path);
            } else if (S_ISREG(st.st_mode)) {
                // It's a file, so copy it to the backup locations
                int src_fd = open(resolved_original_path, O_RDONLY);
                if (src_fd == -1) {
                    perror("Error opening source file");
                    continue;
                }

                int dst_fd1 = open(backup1_path, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode);
                int dst_fd2 = open(backup2_path, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode);

                if (dst_fd1 == -1 || dst_fd2 == -1) {
                    perror("Error opening destination file");
                    close(src_fd);
                    continue;
                }

                // Copy file content from the source to both backup locations
                char buffer[4096];
                ssize_t bytes_read;
                while ((bytes_read = read(src_fd, buffer, sizeof(buffer))) > 0) {
                    write(dst_fd1, buffer, bytes_read);
                    write(dst_fd2, buffer, bytes_read);
                }

                close(src_fd);
                close(dst_fd1);
                close(dst_fd2);
            }
        }
    }
    // After the initial paths have been added, process each path
    for (int i = 0; i < storage_servers[server_count].path_count; i++) {
        char *path = storage_servers[server_count].accessible_paths[i];

        struct stat path_stat;
        if (stat(path, &path_stat) == 0) {
            if (S_ISDIR(path_stat.st_mode)) {
                // If it's a directory, add all files and subdirectories
                add_paths_from_dir(path);
            }
        }
    }
    backup_storage_servers1[index]=storage_servers[index];
    backup_storage_servers2[index]=storage_servers[index];
}

// Helper function to recursively copy a directory
void copy_directory_1(const char *src, const char *dst) {
    DIR *dir = opendir(src);
    if (!dir) {
        perror("Error opening directory");
        return;
    }

    // Create the destination directory
    struct stat st;
    if (stat(src, &st) == 0) {
        mkdir(dst, st.st_mode);  // Set permissions of the directory
    }

    // Traverse the source directory and copy its contents
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;  // Skip the . and .. directories
        }

        char src_path[4096], dst_path[4096];
        snprintf(src_path, sizeof(src_path), "%s/%s", src, entry->d_name);
        snprintf(dst_path, sizeof(dst_path), "%s/%s", dst, entry->d_name);

        struct stat entry_stat;
        if (stat(src_path, &entry_stat) == 0) {
            if (S_ISDIR(entry_stat.st_mode)) {
                // Recursively copy subdirectories
                copy_directory_1(src_path, dst_path);
            } else if (S_ISREG(entry_stat.st_mode)) {
                // Copy regular files
                int src_fd = open(src_path, O_RDONLY);
                if (src_fd == -1) {
                    perror("Error opening source file");
                    continue;
                }

                int dst_fd1 = open(dst_path, O_WRONLY | O_CREAT | O_TRUNC, entry_stat.st_mode);
                if (dst_fd1 == -1) {
                    perror("Error opening destination file");
                    close(src_fd);
                    continue;
                }

                // Copy file content from the source to the backup location
                char buffer[4096];
                ssize_t bytes_read;
                while ((bytes_read = read(src_fd, buffer, sizeof(buffer))) > 0) {
                    write(dst_fd1, buffer, bytes_read);
                }

                close(src_fd);
                close(dst_fd1);
            }
        }
    }

    closedir(dir);
}

// Create LRU Cache
LRUCache* create_cache() {
    LRUCache *cache = (LRUCache *)malloc(sizeof(LRUCache));
    if (!cache) {
        perror("Failed to allocate LRUCache");
        return NULL;
    }
    cache->head = cache->tail = NULL;
    cache->size = 0;
    memset(cache->hash, 0, sizeof(cache->hash));
    if (pthread_mutex_init(&cache->lock, NULL) != 0) {
        perror("Mutex initialization failed");
        free(cache);
        return NULL;
    }
    return cache;
}

// Free cache
void free_cache(LRUCache *cache) {
    if (!cache) return;

    CacheNode *current = cache->head;
    while (current) {
        CacheNode *next = current->next;
        free(current);
        current = next;
    }

    pthread_mutex_destroy(&cache->lock);
    free(cache);
}

// Insert into cache
void cache_insert(LRUCache *cache, const char *key, void *value) {
    if (!cache || !key) return;

    pthread_mutex_lock(&cache->lock);

    unsigned int hash_index = strlen(key) % MAX_CACHE_SIZE;
    CacheNode *node = cache->hash[hash_index];

    if (node) {
        // If the node already exists, update its value
        node->value = value;
        pthread_mutex_unlock(&cache->lock);
        return;
    }

    // Create a new node
    node = create_cache_node(key, value);
    if (!node) {
        pthread_mutex_unlock(&cache->lock);
        return;
    }

    // Insert at the front of the cache
    node->next = cache->head;
    if (cache->head) cache->head->prev = node;
    cache->head = node;
    if (!cache->tail) cache->tail = node;

    cache->hash[hash_index] = node;
    cache->size++;

    if (cache->size > MAX_CACHE_SIZE) {
        // Evict least recently used
        CacheNode *lru = cache->tail;
        cache->tail = lru->prev;
        if (cache->tail) cache->tail->next = NULL;

        cache->hash[strlen(lru->key) % MAX_CACHE_SIZE] = NULL;
        free(lru);
        cache->size--;
    }

    pthread_mutex_unlock(&cache->lock);
}

// Lookup cache
void* cache_lookup(LRUCache *cache, const char *key) {
    if (!cache || !key) return NULL;

    pthread_mutex_lock(&cache->lock);

    unsigned int hash_index = strlen(key) % MAX_CACHE_SIZE;
    CacheNode *node = cache->hash[hash_index];

    if (!node) {
        pthread_mutex_unlock(&cache->lock);
        return NULL;
    }

    // Move to the front of the cache
    if (node != cache->head) {
        if (node->prev) node->prev->next = node->next;
        if (node->next) node->next->prev = node->prev;
        if (node == cache->tail) cache->tail = node->prev;

        node->next = cache->head;
        node->prev = NULL;
        if (cache->head) cache->head->prev = node;
        cache->head = node;
    }

    pthread_mutex_unlock(&cache->lock);
    return node->value;
}


// Initialize hashmap
void initialize_hashmap() {
    // UTHash handles initialization automatically
    path_server_map = NULL;
}

// Insert into hashmap
void hashmap_insert(const char* path, StorageServer server) {
    PathServerMap* s;
    
    // Check if path already exists
    HASH_FIND_STR(path_server_map, path, s);
    if (s == NULL) {
        s = (PathServerMap*)malloc(sizeof(PathServerMap));
        strncpy(s->path, path, MAX_PATH_LENGTH - 1);
        HASH_ADD_STR(path_server_map, path, s);
    }
    s->server = server;
}

// Helper function to update hashmap entries for a storage server
void update_hashmap_entries(StorageServer *server) {
    // Add/update hashmap entries for all paths of this server
    for (int i = 0; i < server->path_count; i++) {
        hashmap_insert(server->accessible_paths[i], *server);
    }
}

// Lookup in hashmap
StorageServer* hashmap_lookup(const char* path) {
    PathServerMap* s;
    HASH_FIND_STR(path_server_map, path, s);
    return s ? &s->server : NULL;
}
// Cleanup functions
void cleanup_cache() {
    if (!cache) return;
    
    CacheNode* current = cache->head;
    while (current) {
        CacheNode* next = current->next;
        free(current);
        current = next;
    }
    free(cache);
}

void cleanup_hashmap() {
    PathServerMap *current, *tmp;
    HASH_ITER(hh, path_server_map, current, tmp) {
        HASH_DEL(path_server_map, current);
        free(current);
    }
}

// Reader-writer lock helper functions
int acquire_read_lock(const char *filepath) {
    for (int i = 0; i < MAX_FILES; ++i) {
        printf("%s\n", file_locks[i].filepath);
        printf("%s\n", filepath);
        if (strcmp(file_locks[i].filepath, filepath) == 0) {
            pthread_mutex_lock(&file_locks[i].lock);
            while (file_locks[i].write_locked) {
                pthread_cond_wait(&file_locks[i].read_cond, &file_locks[i].lock);
            }
            file_locks[i].reader_count++;
            pthread_mutex_unlock(&file_locks[i].lock);
            return 0; // Success
        }
    }
    return -1; // File not found
}

int release_read_lock(const char *filepath) {
    for (int i = 0; i < MAX_FILES; ++i) {
        if (strcmp(file_locks[i].filepath, filepath) == 0) {
            pthread_mutex_lock(&file_locks[i].lock);
            file_locks[i].reader_count--;
            if (file_locks[i].reader_count == 0) {
                pthread_cond_signal(&file_locks[i].write_cond);
            }
            pthread_mutex_unlock(&file_locks[i].lock);
            return 0; // Success
        }
    }
    return -1; // File not found
}

int acquire_write_lock(const char *filepath) {
    for (int i = 0; i < MAX_FILES; ++i) {
        if (strcmp(file_locks[i].filepath, filepath) == 0) {
            pthread_mutex_lock(&file_locks[i].lock);
            while (file_locks[i].write_locked || file_locks[i].reader_count > 0) {
                pthread_cond_wait(&file_locks[i].write_cond, &file_locks[i].lock);
            }
            file_locks[i].write_locked = 1;
            pthread_mutex_unlock(&file_locks[i].lock);
            return 0; // Success
        }
    }
    return -1; // File not found
}

int release_write_lock(const char *filepath) {
    for (int i = 0; i < MAX_FILES; ++i) {
        if (strcmp(file_locks[i].filepath, filepath) == 0) {
            pthread_mutex_lock(&file_locks[i].lock);
            file_locks[i].write_locked = 0;
            pthread_cond_broadcast(&file_locks[i].read_cond);
            pthread_cond_signal(&file_locks[i].write_cond);
            pthread_mutex_unlock(&file_locks[i].lock);
            return 0; // Success
        }
    }
    return -1; // File not found
}

void cleanup_locks() {
    pthread_mutex_destroy(&file_locks_mutex);
    pthread_mutex_destroy(&server_list_mutex);
    
    for (int i = 0; i < MAX_FILES; i++) {
        pthread_mutex_destroy(&file_locks[i].lock);
        pthread_cond_destroy(&file_locks[i].read_cond);
        pthread_cond_destroy(&file_locks[i].write_cond);
    }
}

char* get_local_ip() {
    static char IPbuffer[256];  
    char hostbuffer[256];
    struct hostent *host_entry;

    if (gethostname(hostbuffer, sizeof(hostbuffer)) == -1) {
        perror("gethostname");
        exit(EXIT_FAILURE);
    }

    host_entry = gethostbyname(hostbuffer);
    if (host_entry == NULL) {
        perror("gethostbyname");
        exit(EXIT_FAILURE);
    }

    strcpy(IPbuffer, inet_ntoa(*(struct in_addr *) host_entry->h_addr_list[0]));
    return IPbuffer;
}

int initialize_socket(int *port) {
    int server_fd, opt = 1;
    struct sockaddr_in address;

    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }

    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt))) {
        perror("setsockopt");
        exit(EXIT_FAILURE);
    }

    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(0);  // Set port to 0 to allow dynamic assignment

    if (bind(server_fd, (struct sockaddr*)&address, sizeof(address)) < 0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }

    socklen_t len = sizeof(address);
    if (getsockname(server_fd, (struct sockaddr*)&address, &len) == -1) {
        perror("getsockname failed");
        exit(EXIT_FAILURE);
    }
    *port = ntohs(address.sin_port);

    if (listen(server_fd, 3) < 0) {
        perror("listen");
        exit(EXIT_FAILURE);
    }
    return server_fd;
}

void list_storage_servers() {
    printf("Registered Storage Servers:\n");
    for (int i = 0; i < server_count; i++) {
        printf("Server %d: IP = %s, NM Port = %s, Client Port = %s, Accessible Paths = [", 
               i + 1, 
               storage_servers[i].ip, 
               storage_servers[i].nm_port, 
               storage_servers[i].client_port);
        
        for (int j = 0; j < storage_servers[i].path_count; j++) {
            printf("%s", storage_servers[i].accessible_paths[j]);
            if (j < storage_servers[i].path_count - 1) {
                printf(", ");
            }
        }
        printf("]\n");
    }
}

void list_all_accessible_paths(int client_socket) {
    char buffer[MAX_PATH_LENGTH + 20]; // Extra space for formatting with server info
    //printf("count: %d\n", storage_servers[0].path_count);
    for (int i = 0; i < server_count; i++) {
        if(is_up[i]==1)
        {
            for (int j = 0; j < storage_servers[i].path_count; j++) {
                snprintf(buffer, sizeof(buffer), "%s\n", storage_servers[i].accessible_paths[j]);
                send(client_socket, buffer, strlen(buffer), 0); // Send each path
            }
        }
    }

    // Send "END_OF_LIST" to mark the end of the list
    strcpy(buffer, "END_OF_LIST\n");
    send(client_socket, buffer, strlen(buffer), 0);
}

void add_accessible_path(StorageServer *server, const char *filePath, const char *name) {
    // Construct the full path
    char fullPath[MAX_PATH_LENGTH];
    snprintf(fullPath, sizeof(fullPath), "%s/%s", filePath, name);  // Assuming a Unix-like path structure

    // Check if there's space for a new path on the selected server
    if (server->path_count < MAX_PATHS) {
        // Add the new path to the server's accessible paths
        strncpy(server->accessible_paths[server->path_count], fullPath, MAX_PATH_LENGTH);
        server->accessible_paths[server->path_count][MAX_PATH_LENGTH - 1] = '\0';  // Ensure null termination
        server->path_count++;  // Increment the path count
        // Update hashmap with the new path
        hashmap_insert(fullPath, *server);
        printf("Added path: %s to Storage Server with IP %s\n", fullPath, server->ip);
    } else {
        printf("Unable to add path: %s. Storage server at capacity.\n", fullPath);
    }
}

void add_accessible_path_backup(StorageServer *server, const char *filePath, const char *name) {
    // Construct the full path
    char fullPath[MAX_PATH_LENGTH];
    snprintf(fullPath, sizeof(fullPath), "%s/%s", filePath, name);  // Assuming a Unix-like path structure

    // Check if there's space for a new path on the selected server
    if (server->path_count < MAX_PATHS) {
        // Add the new path to the server's accessible paths
        strncpy(server->accessible_paths[server->path_count], fullPath, MAX_PATH_LENGTH);
        server->accessible_paths[server->path_count][MAX_PATH_LENGTH - 1] = '\0';  // Ensure null termination
        server->path_count++;  // Increment the path count
        // Update hashmap with the new path
        hashmap_insert(fullPath, *server);
        //printf("Added path: %s to Storage Server with IP %s\n", fullPath, server->ip);
    } else {
        //printf("Unable to add path: %s. Storage server at capacity.\n", fullPath);
    }
}

int forward_delete_request_to_ss(const StorageServer *server, const char *filePath) {
    int sock;
    struct sockaddr_in server_address;
    char message[1024];
    char response[10];
    char log_data[4096];
    // Create a socket
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("Socket creation failed");
        snprintf(log_data, sizeof(log_data), "Socket creation failed\n");
        logging_data(log_data);
        return -1;
    }

    // Configure the server address
    memset(&server_address, 0, sizeof(server_address));
    server_address.sin_family = AF_INET;
    server_address.sin_port = htons(atoi(server->nm_port));
    if (inet_pton(AF_INET, server->ip, &server_address.sin_addr) <= 0) {
        perror("Invalid address or address not supported");
        snprintf(log_data, sizeof(log_data), "Invalid address or address not supported\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }

    // Connect to the storage server
    if (connect(sock, (struct sockaddr*)&server_address, sizeof(server_address)) < 0) {
        perror("Connection to storage server failed");
        snprintf(log_data, sizeof(log_data), "Connection to storage server failed\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }

    // Send the delete request in format: "DELETE <filePath>"
    snprintf(message, sizeof(message), "DELETE %s", filePath);
    if (send(sock, message, strlen(message), 0) < 0) {
        perror("Failed to send delete request");
        snprintf(log_data, sizeof(log_data), "Failed to send delete request\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }

    // Receive the response from the storage server
    ssize_t bytes_received = recv(sock, response, sizeof(response) - 1, 0);
    if (bytes_received < 0) {
        perror("Failed to receive response from storage server");
        snprintf(log_data, sizeof(log_data), "Failed to receive response from storage server\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }

    // Null-terminate the response
    response[bytes_received] = '\0';
    close(sock);

    // Check if the server sent an acknowledgment (ACK) or a failure (STOP)
    return (strcmp(response, "ACK") == 0) ? 0 : -1;
}

int delete_folder_recursive(const char *path) {
    DIR *dir = opendir(path);
    if (!dir) return -1;

    struct dirent *entry;
    char filepath[4096];

    while ((entry = readdir(dir)) != NULL) {
        // Skip . and ..
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        snprintf(filepath, sizeof(filepath), "%s/%s", path, entry->d_name);

        // Recursively delete directories, or delete files
        struct stat st;
        if (stat(filepath, &st) == 0) {
            if (S_ISDIR(st.st_mode)) {
                // Recursive call for directory
                if (delete_folder_recursive(filepath) != 0) {
                    closedir(dir);
                    return -1;
                }
            } else {
                // Delete file
                if (remove(filepath) != 0) {
                    closedir(dir);
                    return -1;
                }
            }
        }
    }

    closedir(dir);
    return rmdir(path);  // Remove the directory itself
}

int forward_delete_request_to_ss_backup(const StorageServer *server, const char *filePath) {
    char full_path1[4096], full_path2[4096], home[1024], half_path1[4096], half_path2[4096], log[4096]; 
    getcwd(home, sizeof(home));
    snprintf(full_path1, sizeof(full_path1), "%s/backup1/%d/%s", home, index_server+1, filePath);
    snprintf(half_path1, sizeof(half_path1), "backup1/%d/%s", index_server+1, filePath);
    snprintf(full_path2, sizeof(full_path2), "%s/backup2/%d/%s", home, index_server+1, filePath);
    snprintf(half_path2, sizeof(half_path2), "backup1/%d/%s",  index_server+1, filePath);
    struct stat st;
    if (stat(full_path1, &st) != 0) {
        printf("Path does not exist: %s\n", full_path1);
        return -1;
    }

    int result;
    if (S_ISDIR(st.st_mode)) {
        // Delete directory and its contents
        result = delete_folder_recursive(full_path1);
    } else {
        // Delete file
        result = remove(full_path1);
    }

    if (result == 0) {
        
        snprintf(log, strlen(log), "Successfully deleted: %s\n", full_path1);
        logging_data(log);
    } else {
        snprintf(log, strlen(log), "Failed to delete: %s, error: %s\n", full_path1, strerror(errno));
        logging_data(log);
    }

    if (stat(full_path2, &st) != 0) {
        snprintf(log, strlen(log), "Path does not exist: %s\n", full_path2);
        logging_data(log);
        return -1;
    }

    if (S_ISDIR(st.st_mode)) {
        // Delete directory and its contents
        result = delete_folder_recursive(full_path2);
    } else {
        // Delete file
        result = remove(full_path2);
    }

    if (result == 0) {
        
        snprintf(log, strlen(log), "Successfully deleted: %s\n", full_path2);
        logging_data(log);
    } else {
        snprintf(log, strlen(log), "Failed to delete: %s, error: %s\n", full_path2, strerror(errno));
        logging_data(log);
    }

}

// Function to check if a given path or file exists within a directory path
int file_exists_in_path(const char *directory, const char *target) {
    char fullPath[MAX_PATH_LENGTH];
    snprintf(fullPath, sizeof(fullPath), "%s/%s", directory, target);
    return access(fullPath, F_OK) == 0;  // Returns 0 if file exists, -1 otherwise
}

int delete_file_or_folder(const char *filePath) {
    int found = 0;
    int found1=0;
    StorageServer *targetServer = NULL;

    // Check each storage server and each accessible path
    for (int i = 0; i < server_count; i++) {
        for (int j = 0; j < storage_servers[i].path_count; j++) {
            // Check if the path is exactly the filePath or contains filePath within a folder
            if (strcmp(storage_servers[i].accessible_paths[j], filePath) == 0 ||
                file_exists_in_path(storage_servers[i].accessible_paths[j], filePath)) {
                
                targetServer = &storage_servers[i];
                found = i;
                found1=1;
                break;
            }
        }
        if (found) break;  // Stop searching if we've found the target server
    }

    // If no storage server can handle this path, return an error
    if (!found1) {
        printf("No storage server can access the given path: %s\n", filePath);
        return 101;
    }
    char log_buffer[4096];
    if(is_up[found]==1)
    {
        // Forward delete request to the appropriate storage server and check result
        int result = forward_delete_request_to_ss(targetServer, filePath);
        int result1= forward_delete_request_to_ss_backup(&(backup_storage_servers1[found]), filePath);
        int result2= forward_delete_request_to_ss_backup(&(backup_storage_servers2[found]), filePath);
        if (result == 0) 
        {
            printf("File or folder deleted successfully on storage server.\n");

            // Remove path from accessible paths of all storage servers if it matches filePath
            for (int i = 0; i < server_count; i++) {
                for (int j = 0; j < storage_servers[i].path_count; j++) {
                    if (strcmp(storage_servers[i].accessible_paths[j], filePath) == 0) {
                        // Shift remaining paths
                        for (int k = j; k < storage_servers[i].path_count - 1; k++) {
                            strcpy(storage_servers[i].accessible_paths[k], storage_servers[i].accessible_paths[k + 1]);
                        }
                        storage_servers[i].path_count--;  // Decrease the path count
                        printf("Path '%s' removed from accessible paths of storage server %s.\n", 
                            filePath, storage_servers[i].ip);
                        snprintf(log_buffer, sizeof(log_buffer), "Path '%s' removed from accessible paths of storage server %s.\n", 
                            filePath, storage_servers[i].ip);
                        logging_data(log_buffer);
                        break;
                    }
                }
            }
        } 
        else {
            result=109;
        }
        return result;
    }
    else
    {
        index_server=found;
        return 0;
    }

}

int forward_create_request_to_ss(StorageServer server, const char *filePath, const char *name, int is_folder) {
    int sock;
    struct sockaddr_in server_addr;
    char message[256];
    char response[10];
    char log_data[4096];
    // Create socket
    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock == -1) {
        printf("Could not create socket for storage server.\n");
        snprintf(log_data, sizeof(log_data), "Could not create socket for storage server.\n");
        logging_data(log_data);
        return -1;
    }
    
    // Configure server address
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(atoi(server.nm_port));
    if (inet_pton(AF_INET, server.ip, &server_addr.sin_addr) <= 0) {
        printf("Invalid IP address for storage server.\n");
        snprintf(log_data, sizeof(log_data), "Invalid IP address for storage server.\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }
    
    // Connect to the storage server
    if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        printf("Connection to storage server failed.\n");
        snprintf(log_data, sizeof(log_data), "Connection to storage server failed.\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }
    snprintf(message, sizeof(message), "CREATE %s %s %d", filePath, name, is_folder);
    if (send(sock, message, strlen(message), 0) < 0) {
        printf("Failed to send create request to storage server.\n");
        snprintf(log_data, sizeof(log_data), "Failed to send create request to storage server.\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }
    
    // Receive the response
    int recv_size = recv(sock, response, sizeof(response) - 1, 0);
    if (recv_size < 0) {
        printf("Failed to receive response from storage server.\n");
        snprintf(log_data, sizeof(log_data), "Failed to receive response from storage server.\n");
        logging_data(log_data);
        close(sock);
        return -1;
    }
    
    response[recv_size] = '\0';  // Null-terminate the response
    
    // Check if the server acknowledged the creation
    if (strcmp(response, "ACK") == 0) {
        printf("File or folder created successfully on storage server.\n");
        snprintf(log_data, sizeof(log_data), "File or folder created successfully on storage server.\n");
        logging_data(log_data);
        close(sock);
        return 0;  // Success
    } else {
        printf("Storage server failed to create the file or folder.\n");
        snprintf(log_data, sizeof(log_data), "Storage server failed to create the file or folder.\n");
        logging_data(log_data);
        close(sock);
        return -1;  // Failure
    }
}

int forward_create_request_to_backup_ss(StorageServer server, const char *filePath, const char *name, int is_folder) {
    char full_path1[4100], full_path2[4100], home[1024], half_path1[4100], half_path2[4100]; 
    getcwd(home, sizeof(home));
    snprintf(full_path1, sizeof(full_path1), "%s/backup1/%d/%s", home, index_server+1, filePath);
    snprintf(half_path1, sizeof(half_path1), "backup1/%d/%s", index_server+1, filePath);
    snprintf(full_path2, sizeof(full_path2), "%s/backup2/%d/%s", home, index_server+1, filePath);
    snprintf(half_path2, sizeof(half_path2), "backup1/%d/%s",  index_server+1, filePath);
    char target_path1[4200], target_path2[4200];
    snprintf(target_path1, sizeof(target_path1), "%s/%s", full_path1, name);
    snprintf(target_path2, sizeof(target_path2), "%s/%s", full_path2, name);

    if (is_folder == 1) {
        // Create the folder (directory)
        if (mkdir(target_path1, 0777) == -1) {
            //perror("Failed to create folder in backup1");
            return -1;
        }
        if (mkdir(target_path2, 0777) == -1) {
            //perror("Failed to create folder in backup2");
            return -1;
        }
    } else {
        // Create the file
        FILE *file1 = fopen(target_path1, "w");
        if (file1 == NULL) {
            //perror("Failed to create file in backup1");
            return -1;
        }
        fclose(file1);

        FILE *file2 = fopen(target_path2, "w");
        if (file2 == NULL) {
            //perror("Failed to create file in backup2");
            return -1;
        }
        fclose(file2);
    }
    add_accessible_path_backup(&(backup_storage_servers1[index_server]), half_path1, name);
    add_accessible_path_backup(&(backup_storage_servers2[index_server]), half_path2, name);
}

int is_path_accessible(const char* filePath) {
    // Iterate over each storage server
    for (int i = 0; i < server_count; i++) {
        StorageServer server = storage_servers[i];
        // Iterate over each accessible path in the current server
        for (int j = 0; j < server.path_count; j++) {
            if (strcmp(server.accessible_paths[j], filePath) == 0) {
                return 1;  // Path is accessible
            }
        }
    }
    return 0;  // Path is not accessible in any server
}

int create_file_or_folder_on_ns(const char *filePath, const char *name, int is_folder) {
    char log_data[4096];
    // Check if the filePath is accessible
    if (!is_path_accessible(filePath)) {
        printf("Path is not accessible for creation.\n");
        snprintf(log_data, sizeof(log_data), "Path is not accessible for creation.\n");
        logging_data(log_data);
        return -1;
    }

    // Find a storage server with available space for the new path
    int selectedIndex = -1;
    for (int i = 0; i < server_count; i++) {
        if (storage_servers[i].path_count < MAX_PATHS) {
            selectedIndex = i;  // Store the index of the selected server
            break;  // Exit once a server with available space is found
        }
    }
    
    if (selectedIndex == -1) {
        printf("No storage server available for creating the %s.\n", is_folder ? "directory" : "file");
        snprintf(log_data, sizeof(log_data),"No storage server available for creating the %s.\n", is_folder ? "directory" : "file");
        logging_data(log_data);
        return -1;  // No available storage server found
    }

    // Forward creation request to the selected storage server
    int result = forward_create_request_to_ss(storage_servers[selectedIndex], filePath, name, is_folder);
    int result1 = forward_create_request_to_backup_ss(storage_servers[selectedIndex], filePath, name, is_folder);
    if (result != 0) {
        snprintf(log_data, sizeof(log_data), "failed to create file/folder in ss %d\n", selectedIndex);
        logging_data(log_data);
        return 109;
    }
    
    // Add the new path to accessible paths for the specific storage server
    add_accessible_path(&storage_servers[selectedIndex], filePath, name);
    return 0;
}

StorageServer get_storage_server_info(const char *filePath) {
    StorageServer empty_server = {0};  // Default return value
    
    if (!filePath) {
        printf("Invalid file path\n");
        return empty_server;
    }
    
    // First, check LRU cache
    void* cached_value = cache_lookup(cache, filePath);
    if (cached_value) {
        printf("Cache hit for path: %s\n", filePath);
        return *(StorageServer*)cached_value;
    }
    
    // Next, check hashmap
    StorageServer* mapped_server = hashmap_lookup(filePath);
    if (mapped_server) {
        printf("Hashmap hit for path: %s\n", filePath);
        // Create a new StorageServer for cache storage
        StorageServer* server_copy = malloc(sizeof(StorageServer));
        if (server_copy) {
            memcpy(server_copy, mapped_server, sizeof(StorageServer));
            cache_insert(cache, filePath, server_copy);
            return *mapped_server;
        }
    }
    //printf("%d\n",server_count);
    // Search through storage servers with proper locking
    for (int i = 0; i < server_count; i++) {
        for (int j = 0; j < storage_servers[i].path_count; j++) {
            printf("%s\n",storage_servers[i].accessible_paths[j] );
            if (strcmp(storage_servers[i].accessible_paths[j], filePath) == 0) {
                // Create copies for cache and hashmap
                StorageServer* server_copy = malloc(sizeof(StorageServer));
                if (server_copy) {
                    memcpy(server_copy, &storage_servers[i], sizeof(StorageServer));
                    cache_insert(cache, filePath, server_copy);
                    hashmap_insert(filePath, storage_servers[i]);
                    StorageServer result = storage_servers[i];
                    index_server=i;
                    return result;
                }
            }
        }
    }    
    //printf("No matching storage server found for path: %s\n", filePath);
    //return empty_server;
    errorCode=101;
    return empty_server;

}

void read_from_backup(int idx, const char* file_path, char* data)
{
    // Allocate memory for the full file path (backup1/idx/file_path)
    char full_path[1024]; // 1024 is just a safe size, adjust as needed

    // Format the full file path
    snprintf(full_path, sizeof(full_path), "backup1/%d/%s", idx + 1, file_path);
    printf("Attempting to open file: %s\n", full_path);

    // Open the file using the open system call (this gives us a file descriptor)
    int fd = open(full_path, O_RDONLY);
    if (fd == -1) {
        perror("Error opening file");
        return;
    }

    // Print a message to confirm the file is opened
    printf("File opened successfully!\n");

    // Read and store the content of the file into the data buffer
    ssize_t bytes_read;
    size_t total_bytes_read = 0;

    while ((bytes_read = read(fd, data + total_bytes_read, MAX_FILE_SIZE - total_bytes_read)) > 0) {
        total_bytes_read += bytes_read;

        // If we've reached the end of the data array, stop reading
        if (total_bytes_read >= MAX_FILE_SIZE) {
            printf("Data buffer is full. Stopping read.\n");
            break;
        }
    }

    if (bytes_read == -1) {
        perror("Error reading file");
    }

    // Null-terminate the data buffer to treat it as a C string (optional, if needed)
    if (total_bytes_read < MAX_FILE_SIZE) {
        data[total_bytes_read] = '\0';  // Null-terminate the string if there's space left
    }

    // Close the file descriptor
    close(fd);
    printf("File closed.\n");
}

// Function to copy a file
int copy_file1(const char *src, const char *dest) {
    int src_fd = open(src, O_RDONLY);
    if (src_fd == -1) {
        perror("Error opening source file");
        return -1;
    }

    struct stat st;
    if (fstat(src_fd, &st) == -1) {
        perror("Error getting source file stats");
        close(src_fd);
        return -1;
    }

    int dest_fd = open(dest, O_WRONLY | O_CREAT | O_TRUNC, st.st_mode);
    if (dest_fd == -1) {
        perror("Error opening destination file");
        close(src_fd);
        return -1;
    }

    char buffer[4096];
    ssize_t bytes_read, bytes_written;
    while ((bytes_read = read(src_fd, buffer, sizeof(buffer))) > 0) {
        bytes_written = write(dest_fd, buffer, bytes_read);
        if (bytes_written != bytes_read) {
            perror("Error writing to destination file");
            close(src_fd);
            close(dest_fd);
            return -1;
        }
    }

    if (bytes_read == -1) {
        perror("Error reading source file");
    }

    // Copy file permissions and times (access, modification times)
    if (fchmod(dest_fd, st.st_mode) == -1) {
        perror("Error setting file permissions on destination");
    }
    if (futimes(dest_fd, (struct timeval[]){ {st.st_atime, 0}, {st.st_mtime, 0} }) == -1) {
        perror("Error setting times on destination file");
    }

    close(src_fd);
    close(dest_fd);
    return 0;
}

// Function to copy a directory recursively
int copy_directory1(const char *src, const char *dest) {
    DIR *dir = opendir(src);
    if (dir == NULL) {
        perror("Error opening source directory");
        return -1;
    }

    // Create the destination directory if it doesn't exist
    if (mkdir(dest, 0755) == -1 && errno != EEXIST) {
        perror("Error creating destination directory");
        closedir(dir);
        return -1;
    }

    struct dirent *entry;
    char src_path[1024], dest_path[1024];

    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }

        snprintf(src_path, sizeof(src_path), "%s/%s", src, entry->d_name);
        snprintf(dest_path, sizeof(dest_path), "%s/%s", dest, entry->d_name);

        struct stat st;
        if (stat(src_path, &st) == -1) {
            perror("Error getting stats of source file or directory");
            closedir(dir);
            return -1;
        }

        if (S_ISDIR(st.st_mode)) {
            // Recursively copy subdirectory
            if (copy_directory1(src_path, dest_path) != 0) {
                closedir(dir);
                return -1;
            }
        } else if (S_ISREG(st.st_mode)) {
            // Copy file
            if (copy_file1(src_path, dest_path) != 0) {
                closedir(dir);
                return -1;
            }
        }
    }

    closedir(dir);
    return 0;
}

void handle_client_requests(int client_socket) {
    char operation[BUFFER_SIZE]="";
    char name[BUFFER_SIZE]="";
    char filePath[BUFFER_SIZE]="";
    char is_folder_flag[2] = "";
    char srcPath[BUFFER_SIZE]="";
    char destPath[BUFFER_SIZE]="";
    char buffer_log[4096]="";
    //while(1)
    {
        errorCode=0;
        // Receive the operation from the client
        recv(client_socket, operation, sizeof(operation), 0);
        operation[strcspn(operation, "\n")] = 0; // Remove newline

        if (strcmp(operation, "READ") == 0 || strcmp(operation, "STREAM") == 0 || 
            strcmp(operation, "WRITE") == 0 || strcmp(operation, "INFO") == 0) {
                recv(client_socket, filePath, sizeof(filePath), 0);
                filePath[strcspn(filePath, "\n")] = 0;
                snprintf(buffer_log, sizeof(buffer_log), "%s", filePath);
                logging_data(buffer_log);
                StorageServer storageServerInfo = get_storage_server_info(filePath); 
                printf("index:%d  %d\n", index_server, is_up[index_server]);
                // Retrieve server info based on filePath
                //send(client_socket, &storageServerInfo, sizeof(StorageServer), 0);
                if(strcmp(operation, "READ") == 0 && is_up[index_server]==0)
                {
                    printf("Storage is down, accessing backup storage server to READ\n");
                    errorCode=204;
                    char data[MAX_FILE_SIZE];
                    read_from_backup(index_server, filePath, data);
                    send(client_socket, &(backup_storage_servers1[index_server]), sizeof(StorageServer), 0);
                    send(client_socket, &errorCode, sizeof(int), 0);
                    int index_of_server=index_server;
                    send(client_socket, &index_of_server, sizeof(int), 0);
                    send(client_socket, data, MAX_FILE_SIZE, 0);
                    errorCode=0;
                    //continue;
                    close(client_socket);
                }
                else if(is_up[index_server]==0 && (strcmp(operation, "STREAM") == 0 || 
            strcmp(operation, "WRITE") == 0 || strcmp(operation, "INFO") == 0))
                {
                    printf("Server went down, cannot perform given operation\n");
                    //storageServerInfo={0};
                    errorCode=200;
                    send(client_socket, &storageServerInfo, sizeof(StorageServer), 0);
                    send(client_socket, &errorCode, sizeof(int), 0);
                    //errorCode=0;
                }
                if(errorCode==0)
                {
                    snprintf(buffer_log, sizeof(buffer_log), "Storage server which contains given file is %s: ip %s nm_port %s client_port %s", filePath, storageServerInfo.ip, storageServerInfo.nm_port, storageServerInfo.client_port);
                    logging_data(buffer_log);
                    //send(client_socket, &storageServerInfo, sizeof(StorageServer), 0);   
                }
                else
                {
                    snprintf(buffer_log, sizeof(buffer_log),"No storage server contains the given filepath %s", filePath);
                    logging_data(buffer_log);
                    errorCode=0;
                }
                if(is_up[index_server]==1)
                {
                    send(client_socket, &storageServerInfo, sizeof(StorageServer), 0);
                    send(client_socket, &errorCode, sizeof(int), 0);
                }
                int index_of_server=index_server;
                send(client_socket, &index_of_server, sizeof(int), 0);
                // if(strcmp(operation, "WRITE") == 0 && is_up[index_server]==1)
                // {
                //     backup_write(index_server, client_socket, filePath);
                // }
        }
        else if(strcmp(operation, "DELETE")==0) {
            
            recv(client_socket, filePath, sizeof(filePath), 0);
            filePath[strcspn(filePath, "\n")] = 0;
            int result = delete_file_or_folder(filePath); // Implement this function for deletion
            char response[100];
            if(result==0)
            {
                strcpy(response, "ACK");
                snprintf(buffer_log, sizeof(buffer_log), "DELETE operation was successful");
                logging_data(buffer_log);
            }
            else if(result==101)
            {
                strcpy(response, "101"); 
                snprintf(buffer_log, sizeof(buffer_log), "file not found in any storage server");
                logging_data(buffer_log);
            }
            else if(result==108)
            {
                strcpy(response, "109");   
                snprintf(buffer_log, sizeof(buffer_log), "Storage server failed to delete the file or folder");
                logging_data(buffer_log);
            }
            if(is_up[index_server]==0)
            {
                strcpy(response, "202");
                snprintf(buffer_log, sizeof(buffer_log), "storage server down, try after sometime\n");
                logging_data(buffer_log);
            }
            else
            {
                send(client_socket, response, strlen(response), 0);
            }
        }
        else if (strcmp(operation, "CREATE") == 0) {
            // Receive file path
            recv(client_socket, filePath, sizeof(filePath), 0);
            printf("filePath is %s\n",filePath);

            // Receive the is_folder flag
            recv(client_socket, is_folder_flag, sizeof(is_folder_flag), 0);
            int is_folder = atoi(is_folder_flag);  // Convert flag to integer (0 for file, 1 for folder)
            printf("is_folder is %d\n",is_folder);
            if(is_folder==0)
            {
                printf("creating a file.\n");
                snprintf(buffer_log, sizeof(buffer_log), "creating a file.\n");
                logging_data(buffer_log);
            }
            else
            {
                printf("creating a folder.\n");
                snprintf(buffer_log, sizeof(buffer_log), "creating a folder.\n");
                logging_data(buffer_log);
            }
            // Receive file or folder name
            recv(client_socket, name, sizeof(name), 0);
            //printf("name is %s\n",name);

            // Call the function to handle file/folder creation, passing the is_folder flag
            int result = create_file_or_folder_on_ns(filePath, name, is_folder);

            // Send acknowledgment or stop response based on result
            const char *response = (result == 0) ? "ACK" : "109";
            send(client_socket, response, strlen(response), 0);
        }
        else if (strcmp(operation, "LIST") == 0) {
            list_all_accessible_paths(client_socket); // Implement to send a list of paths, ending with "END_OF_LIST"
        }
        else if (strcmp(operation, "COPY") == 0) {
            recv(client_socket, srcPath, sizeof(srcPath), 0);
            printf("%s",srcPath);
            srcPath[strcspn(srcPath, "\n")] = 0;
            recv(client_socket, destPath, sizeof(destPath), 0);
            printf("%s",destPath);
            destPath[strcspn(destPath, "\n")] = 0;
            StorageServer ss1Info = get_storage_server_info(srcPath);
            int idx1 = index_server;
            StorageServer ss2Info = get_storage_server_info(destPath);
            int idx2 = index_server;
            if(is_up[idx1]==1 && is_up[idx2]==1)
            {
                int result = copy_file_or_directory(ss1Info, ss2Info,srcPath,destPath); // Implement file copy logic
                const char *response = (result == 1) ? "ACK" : "ACK";
                send(client_socket, response, strlen(response), 0);
            }
            else
            {
                char *response;
                strcpy(response, "202");
                snprintf(buffer_log, sizeof(buffer_log), "one of the storage serves is down, cannot perform copy operation\n");
                logging_data(buffer_log);
                send(client_socket, response, strlen(response), 0);
            }
            char full_path1[4096], full_path2[4096];
            snprintf(full_path1, sizeof(full_path1), "backup1/%d/%s", idx1+1, srcPath);
            snprintf(full_path2, sizeof(full_path2), "backup1/%d/%s", idx2+1, destPath);
            struct stat st;
            if (stat(full_path1, &st) == 0) 
            {
                if (S_ISDIR(st.st_mode)) {
                    // If it's a directory, copy the directory recursively
                    if (copy_directory1(full_path1, full_path2) != 0) {
                        fprintf(stderr, "Error copying directory\n");
                        return;
                    }
                } else if (S_ISREG(st.st_mode)) {
                    // If it's a file, copy the file
                    if (copy_file1(full_path1, full_path2) != 0) {
                        fprintf(stderr, "Error copying file\n");
                        return;
                    }
                } else {
                    fprintf(stderr, "Unknown file type\n");
                    return;
                }
            } 
            else 
            {
                perror("Error with source path");
                return;
            }
            //char full_path1[1024], full_path2[1024];
            snprintf(full_path1, sizeof(full_path1), "backup2/%d/%s", idx1+1, srcPath);
            snprintf(full_path2, sizeof(full_path2), "backup2/%d/%s", idx2+1, destPath);
            
            if (stat(full_path1, &st) == 0) {
                if (S_ISDIR(st.st_mode)) {
                    // If it's a directory, copy the directory recursively
                    if (copy_directory1(full_path1, full_path2) != 0) {
                        fprintf(stderr, "Error copying directory\n");
                        return ;
                    }
                } else if (S_ISREG(st.st_mode)) {
                    // If it's a file, copy the file
                    if (copy_file1(full_path1, full_path2) != 0) {
                        fprintf(stderr, "Error copying file\n");
                        return;
                    }
                } else {
                    fprintf(stderr, "Unknown file type\n");
                    return;
                }
            } else {
                perror("Error with source path");
                return;
            }

        }
        // else if(strcmp(operation, "EXIT")==0)
        // {
        //     break;
        // }
    }
    // Close the client socket
    close(client_socket);
}

void* client_thread_handler(void* arg) {
    int client_socket = *(int*)arg;
    free(arg);  // Free the dynamically allocated socket descriptor

    handle_client_requests(client_socket);
    close(client_socket);  // Close the socket after handling the request
    return NULL;
}

// Thread handler for storage server requests
void* storage_thread_handler(void* arg) {
    int storage_socket = *(int*)arg;
    free(arg);  // Free the dynamically allocated socket descriptor

    handle_storage_requests(storage_socket);
    close(storage_socket);  // Close the socket after handling the request
    return NULL;
}

void handle_storage_requests(int storage_socket) {
    char buffer[BUFFER_SIZE] = {0};
    char ip[MAX_IP_LENGTH] = {0};
    char nm_port[MAX_PORT_LENGTH] = {0};
    char client_port[MAX_PORT_LENGTH] = {0};
    char paths_input[BUFFER_SIZE] = {0};
    char data_store[4096];
    // Read the storage server registration information
    ssize_t bytes_read = read(storage_socket, buffer, sizeof(buffer) - 1);
    if (bytes_read < 0) {
        perror("Read error");
        close(storage_socket);
        return;
    }
    buffer[bytes_read] = '\0'; // Ensure null-termination

    // Parse and store the storage server information
    char *ip_start = strstr(buffer, "IP:") + strlen("IP:");
    char *nm_port_start = strstr(buffer, "NM_Port:") + strlen("NM_Port:");
    char *client_port_start = strstr(buffer, "Client_Port:") + strlen("Client_Port:");
    char *paths_start = strstr(buffer, "Paths:") + strlen("Paths:");

    sscanf(ip_start, "%s", ip);
    sscanf(nm_port_start, "%s", nm_port);
    sscanf(client_port_start, "%s", client_port);
    sscanf(paths_start, "%[^\n]", paths_input);

    if (server_count < MAX_SERVERS) {
        StorageServer *new_server = &storage_servers[server_count];
        strncpy(storage_servers[server_count].ip, ip, MAX_IP_LENGTH - 1);
        strncpy(storage_servers[server_count].nm_port, nm_port, MAX_PORT_LENGTH - 1);
        strncpy(storage_servers[server_count].client_port, client_port, MAX_PORT_LENGTH - 1);

        // Parse accessible paths
        char *token = strtok(paths_input, ",");
        storage_servers[server_count].path_count = 0;
        while (token != NULL && storage_servers[server_count].path_count < MAX_PATHS) {
            strncpy(storage_servers[server_count].accessible_paths[storage_servers[server_count].path_count], token, MAX_PATH_LENGTH - 1);
              // Print the parsed accessible path
    printf("Accessible Path %d: %s\n", storage_servers[server_count].path_count,
           storage_servers[server_count].accessible_paths[storage_servers[server_count].path_count]);
            storage_servers[server_count].path_count++;
            token = strtok(NULL, ",");
            file_locks[total_count].write_locked = 0;
            file_locks[total_count].reader_count = 0;
            pthread_mutex_init(&file_locks[total_count].lock, NULL);
            pthread_cond_init(&file_locks[total_count].read_cond, NULL);
            pthread_cond_init(&file_locks[total_count].write_cond, NULL);
            total_count++;
        }
        is_up[server_count]=1;
        create_backups(server_count);
        server_count++;
        // Update hashmap with all paths from this server
        update_hashmap_entries(new_server);
        send(storage_socket, "Storage server registered", strlen("Storage server registered"), 0);
        snprintf(data_store, sizeof(data_store), "Storage server registered");
        logging_data(data_store);
        list_storage_servers();
    } else {
        send(storage_socket, "Server list full, cannot register", strlen("Server list full, cannot register"), 0);
        snprintf(data_store, sizeof(data_store), "Server list full, cannot register");
        logging_data(data_store);
    }

    // Periodic ACL reception
    struct timeval timeout;
    fd_set readfds;
    int result;
    while (1) {
        FD_ZERO(&readfds);
        FD_SET(storage_socket, &readfds);
        timeout.tv_sec = 5;  // 5-second timeout for receiving ACLs
        timeout.tv_usec = 0;

        result = select(storage_socket + 1, &readfds, NULL, NULL, &timeout);
        if (result < 0) {
            perror("Select error");
            break;
        } else if (result == 0) {
            printf("down %d\n", is_up[server_count-1]);
            is_up[server_count-1]=0;
            printf("down %d\n", is_up[server_count-1]);
            // Timeout occurred; no ACK received
            printf("Timeout occurred. No ACK received. Marking server as down.\n");
            printf("Storage server details:\n");
            printf("IP: %s, NM_Port: %s, Client_Port: %s\n", ip, nm_port, client_port);
            printf("Accessible Paths:\n");
            for (int i = 0; i < storage_servers[server_count - 1].path_count; i++) {
                printf("  - %s\n", storage_servers[server_count - 1].accessible_paths[i]);
            }
            send(storage_socket, "Server went down", strlen("Server went down"), 0);
            break;
        } else {
            // ACL received
            bytes_read = recv(storage_socket, buffer, sizeof(buffer) - 1, 0);
            if (bytes_read <= 0) {
                if (bytes_read == 0) {
                    printf("Client disconnected\n");
                } else {
                    perror("Receive error");
                    if (errno == ECONNRESET) {
                        printf("Connection reset by peer detected.\n");
                        // Print storage server information
                        printf("Storage server details:\n");
                        printf("IP: %s, NM_Port: %s, Client_Port: %s\n", ip, nm_port, client_port);
                        printf("Accessible Paths:\n");
                        for (int i = 0; i < storage_servers[server_count - 1].path_count; i++) {
                            printf("  - %s\n", storage_servers[server_count - 1].accessible_paths[i]);
                        }
                    }
                }
                 printf("down %d\n", is_up[server_count-1]);
                is_up[server_count-1]=0;
                printf("down %d\n", is_up[server_count-1]);
                break;
            }
            buffer[bytes_read] = '\0'; // Null-terminate the message
            // printf("Received ACL: %s\n", buffer);

            // Optionally process the ACL here
            send(storage_socket, "ACL received", strlen("ACL received"), 0);
        }
    }

    // Close the socket after processing
    close(storage_socket);
}

void initialize_naming_server() {
    char *local_ip = get_local_ip();
    int client_port, storage_port;

    int storage_fd = initialize_socket(&storage_port);
    int client_fd = initialize_socket(&client_port);

    printf("Naming Server initialized at IP: %s, Client Port: %d, Storage Port: %d\n", local_ip, client_port, storage_port);
    char buffer[4096];
    snprintf(buffer, sizeof(buffer), "Naming Server initialized at IP: %s, Client Port: %d, Storage Port: %d\n", local_ip, client_port, storage_port);
    logging_data(buffer);

    fd_set read_fds;  // Set of file descriptors to monitor
    int max_fd = (client_fd > storage_fd) ? client_fd : storage_fd;  // Keep track of the highest fd

    while (1) {
        FD_ZERO(&read_fds);  // Clear the set
        FD_SET(client_fd, &read_fds);  // Add client socket to the set
        FD_SET(storage_fd, &read_fds);  // Add storage socket to the set

        // Wait for activity on one of the sockets
        if (select(max_fd + 1, &read_fds, NULL, NULL, NULL) < 0) {
            perror("select error");
            continue;  // Handle the error accordingly
        }

        // Check for incoming client connections
        if (FD_ISSET(client_fd, &read_fds)) {
            int* client_socket = malloc(sizeof(int));
            *client_socket = accept(client_fd, NULL, NULL);  // Dynamically allocate memory for the socket
            if (*client_socket >= 0) {
                pthread_t client_thread;
                // Create a new thread to handle the client connection
                if (pthread_create(&client_thread, NULL, client_thread_handler, client_socket) != 0) {
                    perror("pthread_create (client) failed");
                    free(client_socket);  // Clean up if thread creation fails
                }
                pthread_detach(client_thread);  // Detach the thread to handle its own cleanup
            } else {
                free(client_socket);
            }
        }

        // Check for incoming storage server connections
        if (FD_ISSET(storage_fd, &read_fds)) {
            int* storage_socket = malloc(sizeof(int));
            *storage_socket = accept(storage_fd, NULL, NULL);  // Dynamically allocate memory for the socket
            if (*storage_socket >= 0) {
                pthread_t storage_thread;
                // Create a new thread to handle the storage server connection
                if (pthread_create(&storage_thread, NULL, storage_thread_handler, storage_socket) != 0) {
                    perror("pthread_create (storage) failed");
                    free(storage_socket);  // Clean up if thread creation fails
                }
                pthread_detach(storage_thread);  // Detach the thread to handle its own cleanup
            } else {
                free(storage_socket);
            }
        }
    }
}

int create_and_connect_socket(const char* ip, const char* port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) return -1;

    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(atoi(port));
    addr.sin_addr.s_addr = inet_addr(ip);

    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(sock);
        return -1;
    }

    return sock;
}

int send_command(int socket, const char* command, char* response, size_t response_size) {
    send(socket, command, strlen(command), 0);
    return recv(socket, response, response_size, 0);
}

int check_path(StorageServer ss, const char* path, int* is_directory) {
    char command[1024];
    sprintf(command, "CHECK_PATH %s", path);

    int socket = create_and_connect_socket(ss.ip, ss.nm_port);
    if (socket < 0) return 0;

    char response[BUFFER_SIZE];
    if (send_command(socket, command, response, BUFFER_SIZE) <= 0) {
        close(socket);
        return 0;
    }

    close(socket);
    if (strncmp(response, "NOT_FOUND", 9) == 0) return 0;

    *is_directory = (strncmp(response, "DIRECTORY", 9) == 0);
    return 1;
}

int copy_file(StorageServer ss1, StorageServer ss2, const char* srcPath, const char* destPath) {
    const char* filename = basename((char*)srcPath); // Extract the file name
    char full_dest_path[1024];
    sprintf(full_dest_path, "%s/%s", destPath, filename); // Append to the destination path
    char command[1024];
    sprintf(command, "READ_FILE %s", srcPath);

    int src_socket = create_and_connect_socket(ss1.ip, ss1.nm_port);
    if (src_socket < 0) return 0;

    char file_contents[MAX_FILE_SIZE];
    int bytes_received = send_command(src_socket, command, file_contents, MAX_FILE_SIZE);
    if (bytes_received <= 0) {
        close(src_socket);
        return 0;
    }
    close(src_socket);

    int dest_socket = create_and_connect_socket(ss2.ip, ss2.nm_port);
    if (dest_socket < 0) return 0;
        char buffer[2048];
        int offset = 0;

        // Add the command and metadata (path and file size)
        offset += sprintf(buffer, "WRITE_FILE %s %d ", full_dest_path, bytes_received);

        // Add the file contents immediately after the command

        memcpy(buffer + offset, file_contents, bytes_received);
        offset += bytes_received;
        // Send the entire buffer in one go
        send(dest_socket, buffer, offset, 0);

        // Wait for a response
        char response[BUFFER_SIZE];
        if (recv(dest_socket, response, BUFFER_SIZE, 0) <= 0 || strncmp(response, "SUCCESS", 7) != 0) {
            close(dest_socket);
            return 0;
        }
        close(dest_socket);


    return 1;
}

int copy_directory(StorageServer ss1, StorageServer ss2, const char* srcPath, const char* destPath) {
    const char* dir_name = basename((char*)srcPath); // Get the directory name
    char dest_dir_path[MAX_PATH_LENGTH];
    sprintf(dest_dir_path, "%s/%s", destPath, dir_name); // Create the destination directory path

    // Create the destination directory
    int dest_socket = create_and_connect_socket(ss2.ip, ss2.nm_port);
    if (dest_socket < 0) return 0;

    char command[1024], response[BUFFER_SIZE];
    sprintf(command, "DIR_CREATE %s", dest_dir_path);
    if (send_command(dest_socket, command, response, BUFFER_SIZE) <= 0 || strncmp(response, "SUCCESS", 7) != 0) {
        close(dest_socket);
        return 0;
    }
    close(dest_socket);

    // List contents of the source directory
    int src_socket = create_and_connect_socket(ss1.ip, ss1.nm_port);
    if (src_socket < 0) return 0;

    sprintf(command, "LIST_DIR %s", srcPath);
    if (send_command(src_socket, command, response, BUFFER_SIZE) <= 0) {
        close(src_socket);
        return 0;
    }
    close(src_socket);

    // Parse the directory listing
    char* file_list = strdup(response);
    if (file_list == NULL) {
        fprintf(stderr, "Memory allocation for file list failed\n");
        return 0;
    }

    char* token = strtok(file_list, "\n");
    while (token) {
        char src_file_path[MAX_PATH_LENGTH];
        char dest_file_path[MAX_PATH_LENGTH];

        sprintf(src_file_path, "%s/%s", srcPath, token);

        // Recursively copy files or directories
        if (!copy_file_or_directory(ss1, ss2, src_file_path, dest_dir_path)) {
            free(file_list);
            return 0;
        }

        token = strtok(NULL, "\n");
    }

    free(file_list);
    return 1;
}

int copy_file_or_directory(StorageServer ss1Info, StorageServer ss2Info, char* srcPath, char* destPath) {
    // Check if the source path exists and determine if it is a file or directory
    int is_directory;
    if (!check_path(ss1Info, srcPath, &is_directory)) {
        fprintf(stderr, "Source path '%s' not found.\n", srcPath);
        return 0;
    }

    if (is_directory) {
        if (!copy_directory(ss1Info, ss2Info, srcPath, destPath)) {
            fprintf(stderr, "Failed to copy directory '%s' to '%s'.\n", srcPath, destPath);
            return 0;
        }
    } else {
        // Handle file copying
        if (!copy_file(ss1Info, ss2Info, srcPath, destPath)) {
            fprintf(stderr, "Failed to copy file '%s' to '%s'.\n", srcPath, destPath);
            return 0;
        }
    }
    return 1;
}

void create_directory_if_not_exists(const char *path) {
    struct stat st;
    if (stat(path, &st) != 0) {
        // Directory does not exist, create it
        if (mkdir(path, 0755) != 0) {
            perror("Error creating directory");
        }
    }
}

// Function to delete a file or an empty directory
int remove_file_or_directory(const char *path) {
    struct stat path_stat;
    stat(path, &path_stat);

    // If it's a directory, we need to remove its contents first
    if (S_ISDIR(path_stat.st_mode)) {
        // Open the directory
        DIR *dir = opendir(path);
        if (!dir) {
            perror("Unable to open directory");
            return -1;
        }

        struct dirent *entry;
        char full_path[1024];

        // Iterate over all entries in the directory
        while ((entry = readdir(dir)) != NULL) {
            // Skip "." and ".."
            if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
                continue;
            }

            // Construct the full path
            snprintf(full_path, sizeof(full_path), "%s/%s", path, entry->d_name);

            // Recursively remove contents (files or subdirectories)
            if (remove_file_or_directory(full_path) != 0) {
                closedir(dir);
                return -1;
            }
        }

        closedir(dir);

        // Once the directory is empty, remove it
        if (rmdir(path) != 0) {
            perror("Failed to remove directory");
            return -1;
        }

    } else {  // If it's a file, delete it
        if (remove(path) != 0) {
            perror("Failed to remove file");
            return -1;
        }
    }

    return 0;
}

int main(int argc, char const *argv[]) {
    if (getcwd(home, sizeof(home)) != NULL) {
        printf("Current working directory: %s\n", home);
    } else {
        perror("getcwd() error");
    }
    char backup1_dir[4096], backup2_dir[4096];
    snprintf(backup1_dir, sizeof(backup1_dir), "%s/backup1", home);
    snprintf(backup2_dir, sizeof(backup2_dir), "%s/backup2", home);
    create_directory_if_not_exists(backup1_dir);
    create_directory_if_not_exists(backup2_dir);
    initialize_naming_server();
    const char *path = "/home/anagha/IIITH/sem3/operating systems and networks/CourseProject-main(1)/CourseProject-main/backup1";  // Specify the path to the directory

    if (remove_file_or_directory(path) != 0) {
        fprintf(stderr, "Failed to remove directory and its contents\n");
        return 1;
    }
    path = "/home/anagha/IIITH/sem3/operating systems and networks/CourseProject-main(1)/CourseProject-main/backup2";
    if (remove_file_or_directory(path) != 0) {
        fprintf(stderr, "Failed to remove directory and its contents\n");
        return 1;
    }
    cleanup_cache();
    cleanup_hashmap();
    cleanup_locks();
    return 0;
}