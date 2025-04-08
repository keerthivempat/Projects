// storage_server.c Code
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <sys/stat.h>
#include <dirent.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <asm-generic/socket.h>
#include <sys/select.h>
#include <linux/limits.h>
typedef struct {
    char* nm_ip;
    int nm_port;
    char* ss_ip;
    int nm_ss_port;
    int client_port;
} RegisterArgs;

typedef struct {
    const char* file_path;
    const char* data;
} WriteTask;

#define NAMING_SERVER_INFO_FILE "naming_server_info.txt"
#define MAX_MSG_SIZE 1024
#define BUFFER_SIZE 4096
#define MAX_PATH_LENGTH 1024
#define MAX_FILE_SIZE 1048576 

char global_original_file[8192];
void (*global_acknowledge)(const char *);  // Function pointer for acknowledgment
char global_data[8192];                    // Data to be written
char answer[10];

void handle_read_request(int client_socket, const char* filePath);
void handle_info_request(int client_socket, const char* filePath);
void handle_write_request(int client_socket, const char* filePath);
void handle_stream_request(int client_socket, const char* filePath);
void* naming_server_handler(void* ns_sock);
void handle_copy_request(int client_socket,char buffer[BUFFER_SIZE]);
char accessible_paths[MAX_MSG_SIZE] = ""; // Stores accessible paths

// Function to dynamically get the local IP
char* get_local_ip() {
    static char IPbuffer[INET_ADDRSTRLEN];
    struct hostent *host_entry;
    char hostbuffer[256];

    if (gethostname(hostbuffer, sizeof(hostbuffer)) == -1) {
        perror("gethostname");
        exit(EXIT_FAILURE);
    }

    host_entry = gethostbyname(hostbuffer);
    if (!host_entry) {
        perror("gethostbyname");
        exit(EXIT_FAILURE);
    }

    inet_ntop(AF_INET, host_entry->h_addr_list[0], IPbuffer, INET_ADDRSTRLEN);
    return IPbuffer;
}

// Read naming server info from a file
void read_naming_server_info(char* ip, int* storage_port) {
    FILE *file = fopen(NAMING_SERVER_INFO_FILE, "r");
    if (!file) {
        perror("Naming Server info file open error");
        exit(EXIT_FAILURE);
    }
    if (fscanf(file, "IP:%15s\nClient_Port:%*d\nStorage_Port:%d\n", ip, storage_port) != 2) {
        fprintf(stderr, "Error reading Naming Server info from file\n");
        fclose(file);
        exit(EXIT_FAILURE);
    }
    fclose(file);
}

void register_with_naming_server(char* nm_ip, int nm_port, char* ss_ip, int nm_ss_port, int client_port) {
    int sock;
    struct sockaddr_in nm_address;
    char message[4096];
    char ack_message[] = "ACK from storage server";

    sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("Socket creation error");
        return;
    }

    nm_address.sin_family = AF_INET;
    nm_address.sin_port = htons(nm_port);
    inet_pton(AF_INET, nm_ip, &nm_address.sin_addr);

    if (connect(sock, (struct sockaddr*)&nm_address, sizeof(nm_address)) < 0) {
        perror("Connection to Naming Server failed");
        close(sock);
        return;
    }

    // Initial registration message
    snprintf(message, sizeof(message), "REGISTER SS IP:%s NM_Port:%d Client_Port:%d Paths:%s",
             ss_ip, nm_ss_port, client_port, accessible_paths);
    if (send(sock, message, strlen(message), 0) < 0) {
        perror("Failed to send registration message");
        close(sock);
        return;
    }

    printf("Registration with Naming Server completed\n");

    // Periodic ACK sending loop
    while (1) {
        sleep(5); // Wait for 5 seconds between ACKs
        if (send(sock, ack_message, strlen(ack_message), 0) < 0) {
            perror("Failed to send ACK");
            break; // Exit the loop on failure
        }
        // printf("Sent ACK to Naming Server\n");
    }

    // Close the socket after exiting the loop
    close(sock);
}


void* register_with_naming_server_thread(void* args) {
    // Cast void* back to the proper structure
    RegisterArgs* reg_args = (RegisterArgs*)args;

    // Call the registration function
    register_with_naming_server(
        reg_args->nm_ip,
        reg_args->nm_port,
        reg_args->ss_ip,
        reg_args->nm_ss_port,
        reg_args->client_port
    );

    free(reg_args); // Free allocated memory for arguments
    return NULL;
}


// Function to delete a folder and all its contents recursively
int delete_folder_recursive(const char *path) {
    DIR *dir = opendir(path);
    if (!dir) return -1;

    struct dirent *entry;
    char filepath[MAX_PATH_LENGTH];

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

// Main function to delete a file or folder
int delete_file_or_folder(const char *path) {

    struct stat st;
    if (stat(path, &st) != 0) {
        printf("Path does not exist: %s\n", path);
        return -1;
    }

    int result;
    if (S_ISDIR(st.st_mode)) {
        // Delete directory and its contents
        result = delete_folder_recursive(path);
    } else {
        // Delete file
        result = remove(path);
    }

    if (result == 0) {
        printf("Successfully deleted: %s\n", path);
    } else {
        printf("Failed to delete: %s, error: %s\n", path, strerror(errno));
    }
    return result;
}

// Initialize a server socket and return the file descriptor
int initialize_server_socket(int port) {
    int server_fd;
    struct sockaddr_in address;
    int opt = 1;

    server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd == 0) {
        perror("Socket failed");
        exit(EXIT_FAILURE);
    }

    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR | SO_REUSEPORT, &opt, sizeof(opt));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(port);

    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("Bind failed");
        exit(EXIT_FAILURE);
    }
    listen(server_fd, 5);

    return server_fd;
}

// Handle client requests
void* client_handler(void* client_sock) {
    int client_socket= *(int*)client_sock;
    char buffer[MAX_MSG_SIZE] = {0};

    read(client_socket, buffer, MAX_MSG_SIZE);
    
    char operation[10];
    char filePath[1024];
    sscanf(buffer, "%s %s", operation, filePath);
    printf("%s\n", buffer);
    if (strncmp(operation, "READ", 4) == 0) {
        handle_read_request(client_socket, filePath);
    }
    else if (strncmp(operation, "WRITE", 5) == 0) {
        handle_write_request(client_socket, filePath);
    } 
    else if (strncmp(operation, "INFO", 5) == 0) {
        handle_info_request(client_socket, filePath);
    } 
    else if (strncmp(operation, "STREAM", 6) == 0) {
        handle_stream_request(client_socket, filePath);
    } else {
        const char* response = "INVALID REQUEST";
        send(client_socket, response, strlen(response), 0);
    }

    close(client_socket);
    free(client_sock);
    return NULL;
}

int create_file_or_folder(const char* path, const char* name, int is_directory) {
    char full_path[1024]="";
    // Construct the full path by combining the given path and name
    snprintf(full_path, sizeof(full_path), "%s/%s", path, name);

    if (is_directory) {
        // Create a directory
        if (mkdir(full_path, 0777) == -1) {
            if (errno == EEXIST) {
                printf("Directory %s already exists.\n", full_path);
                return -1; // Directory already exists
            } else {
                perror("Failed to create directory");
                return -1;
            }
        }
        printf("Directory created successfully: %s\n", full_path);
    } else {
        // Create a file
        int fd = open(full_path, O_CREAT | O_EXCL | O_WRONLY, 0666);
        if (fd == -1) {
            if (errno == EEXIST) {
                printf("File %s already exists.\n", full_path);
                return -1; // File already exists
            } else {
                perror("Failed to create file");
                return -1;
            }
        }
        close(fd);
        printf("File created successfully: %s\n", full_path);
    }
    return 0; // Success
}

int is_directory(const char *path) {
    struct stat path_stat;
    // Get file or directory information
    if (stat(path, &path_stat) != 0) {
        perror("stat"); // Error handling if stat fails
        return -1;
    }
    // Check if it's a directory
    return S_ISDIR(path_stat.st_mode);
}

// Handle READ request
void handle_read_request(int client_socket, const char* filePath) {
    FILE* file = fopen(filePath, "r");
    if (!file) {
        perror("File not found");
        const char* msg = "File not found";
        send(client_socket, msg, strlen(msg), 0);
        return;
    }

    char buffer[MAX_MSG_SIZE];
    while (fgets(buffer, sizeof(buffer), file) != NULL) {
        send(client_socket, buffer, strlen(buffer), 0);
        sleep(1);
    }

    const char* stop_signal = "STOP";
    send(client_socket, stop_signal, strlen(stop_signal), 0);
    fclose(file);
}

void handle_info_request(int client_socket, const char* filePath) {
    struct stat file_stat;
    if (stat(filePath, &file_stat) == -1) {
        perror("File not found or inaccessible");
        const char* msg = "File not found or inaccessible";
        send(client_socket, msg, strlen(msg), 0);
        return;
    }

    // Get file size and permissions
    char buffer[MAX_MSG_SIZE];
    snprintf(buffer, sizeof(buffer), "Size: %ld bytes\nPermissions: ", file_stat.st_size);

    // Append permission details
    strcat(buffer, (file_stat.st_mode & S_IRUSR) ? "r" : "-");
    strcat(buffer, (file_stat.st_mode & S_IWUSR) ? "w" : "-");
    strcat(buffer, (file_stat.st_mode & S_IXUSR) ? "x" : "-");
    strcat(buffer, (file_stat.st_mode & S_IRGRP) ? "r" : "-");
    strcat(buffer, (file_stat.st_mode & S_IWGRP) ? "w" : "-");
    strcat(buffer, (file_stat.st_mode & S_IXGRP) ? "x" : "-");
    strcat(buffer, (file_stat.st_mode & S_IROTH) ? "r" : "-");
    strcat(buffer, (file_stat.st_mode & S_IWOTH) ? "w" : "-");
    strcat(buffer, (file_stat.st_mode & S_IXOTH) ? "x" : "-");

    // Send information to client
    send(client_socket, buffer, strlen(buffer), 0);

    // Send stop signal to indicate end of information
    const char* stop_signal = "STOP";
    send(client_socket, stop_signal, strlen(stop_signal), 0);
}
// Function to handle asynchronous writing
void* write_data_to_original(void* arg) {
    printf("cmg into thread function\n");
    int client_socket = *(int*)arg; // Get the client socket

    FILE* file = fopen(global_original_file, "w");
    if (!file) {
        perror("Error opening original file");
        pthread_exit(NULL);
    }

    // Simulate chunk-wise writing
    size_t chunkSize = 512;
    size_t dataLen = strlen(global_data);
    size_t written = 0;

    while (written < dataLen) {
        size_t toWrite = (dataLen - written) < chunkSize ? (dataLen - written) : chunkSize;
        fwrite(global_data + written, sizeof(char), toWrite, file);
        written += toWrite;
        fflush(file); // Flush data periodically to ensure persistence
        sleep(1); // Simulate delay for chunked writing
    }
    char* ack = "file is being writing asynchronously";
    send(client_socket,ack , strlen(ack), 0);
    fclose(file);
    pthread_exit(NULL);
}

void* write_to_file_async(void* arg) {
    WriteTask* task = (WriteTask*)arg;
    
    // Open the file in write mode
    FILE* file = fopen(task->file_path, "w");
    if (file == NULL) {
        //perror("Error opening file");
        return NULL;
    }

    // Write data to the file
    fwrite(task->data, sizeof(char), strlen(task->data), file);

    // Close the file
    fclose(file);

    //printf("Data written to: %s\n", task->file_path);
    return NULL;
}

void handle_write_request(int client_socket, const char* filePath) {
    char dataToWrite[8192];
    ssize_t bytesReceived;
    int isSync = 0;
    char file_path[BUFFER_SIZE];
    char flag[100];
    int idx_server;
    printf("filepath is %s\n",filePath);
    if (strstr(filePath, "--SYNC") != NULL) {
        isSync = 1; // Synchronous write requested
    }
    printf("sync no is %d\n",isSync);

    sscanf(filePath, "%s %s", file_path, flag);

    // Receive the data to write
    bytesReceived = recv(client_socket, dataToWrite, sizeof(dataToWrite) - 1, 0);
    if (bytesReceived <= 0) {
        perror("Failed to receive data from client");
        return;
    }
    dataToWrite[bytesReceived] = '\0';
    recv(client_socket, &idx_server, sizeof(idx_server), 0);
    if (isSync || strlen(dataToWrite) < 1000) {
        printf("file writing synchrounously\n");
        FILE* file = fopen(file_path, "w");
        if (!file) {
            perror("Failed to open file for writing");
            const char* response = "ERROR OPENING FILE";
            return;
        }

        // Write the received data to the file
        if (fwrite(dataToWrite, sizeof(char), bytesReceived, file) != bytesReceived) {
            perror("Failed to write data to file");
            const char* response = "ERROR WRITING TO FILE";
            fclose(file);
            return;
        }
        fclose(file);
        char* ack = "Completed synchronous write of file";
        send(client_socket,ack , strlen(ack), 0);
    } else {
        char* ack = "file is being writing asynchronously";
        send(client_socket,ack , strlen(ack), 0);
        printf("cmg into asynchrounous\n");
        // Asynchronous write for large data
        strncpy(global_original_file, file_path, sizeof(global_original_file) - 1);
        strncpy(global_data, dataToWrite, sizeof(global_data) - 1);

        // Create a thread for asynchronous writing
        pthread_t write_thread;
        if (pthread_create(&write_thread, NULL, write_data_to_original, &client_socket) != 0) {
            perror("Error creating thread for asynchronous writing");
            return;
        }

        // Detach the thread to allow it to clean up after itself
        pthread_detach(write_thread);
    }
    char full_path1[1024], full_path2[1024];
    snprintf(full_path1, sizeof(full_path1), "backup1/%d/%s", idx_server+1, filePath);
    snprintf(full_path2, sizeof(full_path2), "backup2/%d/%s", idx_server+1, filePath);

    // Create a WriteTask for backup1
    WriteTask task1 = { full_path1, dataToWrite };

    // Create a WriteTask for backup2
    WriteTask task2 = { full_path2, dataToWrite };

    pthread_t write_thread1, write_thread2;

    // Thread for backup1
    if (pthread_create(&write_thread1, NULL, write_to_file_async, (void*)&task1) != 0) {
        //perror("Failed to create thread for backup1");
        return;
    }

    // Thread for backup2
    if (pthread_create(&write_thread2, NULL, write_to_file_async, (void*)&task2) != 0) {
        //perror("Failed to create thread for backup2");
        return;
    }

    // Detach the threads so they can run independently
    pthread_detach(write_thread1);
    pthread_detach(write_thread2);
}


// Main function
int main(int argc, char* argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <dir1> <dir2> [...]\n", argv[0]);
        exit(EXIT_FAILURE);
    }

    // Concatenate accessible paths from arguments
    for (int i = 3; i < argc; i++) {
        strcat(accessible_paths, argv[i]);
        if (i < argc - 1) strcat(accessible_paths, ",");
    }


    int client_port, naming_server_port ;
    char* nm_ip = argv[1];
    int nm_port = atoi(argv[2]);
    char *ss_ip = get_local_ip();

    struct sockaddr_in client_addr;
    socklen_t addr_len = sizeof(client_addr);

    int client_server_fd = initialize_server_socket(0); // Dynamic port for client
    getsockname(client_server_fd, (struct sockaddr*)&client_addr, &addr_len);
    client_port = ntohs(client_addr.sin_port);

    struct sockaddr_in naming_server_addr;
    addr_len = sizeof(naming_server_addr); 

    int naming_server_fd = initialize_server_socket(naming_server_port); // Dynamic port for naming server
    getsockname(naming_server_fd, (struct sockaddr*)&naming_server_addr, &addr_len); // Get the assigned port
    naming_server_port = ntohs(naming_server_addr.sin_port); // Update the variable with the assigned port
    // Allocate and populate arguments for the thread
    RegisterArgs* args = malloc(sizeof(RegisterArgs));
    if (!args) {
        perror("Failed to allocate memory for thread arguments");
        exit(EXIT_FAILURE);
    }

    args->nm_ip = nm_ip;
    args->nm_port = nm_port;
    args->ss_ip = ss_ip;
    args->nm_ss_port = naming_server_port;
    args->client_port = client_port;

    // Create a thread for registration
    pthread_t thread_id;
    if (pthread_create(&thread_id, NULL, register_with_naming_server_thread, args) != 0) {
        perror("Failed to create thread");
        free(args); // Free arguments in case of thread creation failure
        exit(EXIT_FAILURE);
    }
    printf("Storage Server listening on ports - Client: %d, Naming Server: %d\n", client_port, naming_server_port);
    fd_set read_fds;
    int max_fd = (client_server_fd > naming_server_fd) ? client_server_fd : naming_server_fd;

    while (1) {
        FD_ZERO(&read_fds);
        FD_SET(client_server_fd, &read_fds);
        FD_SET(naming_server_fd, &read_fds);

        select(max_fd + 1, &read_fds, NULL, NULL, NULL);

        if (FD_ISSET(client_server_fd, &read_fds)) {
            int* new_client_socket = malloc(sizeof(int));
            *new_client_socket = accept(client_server_fd, NULL, NULL);

            if (*new_client_socket >= 0) {
                pthread_t client_thread;
                if (pthread_create(&client_thread, NULL, client_handler, new_client_socket) != 0) {
                    perror("Client thread creation failed");
                    free(new_client_socket);
                }
                pthread_detach(client_thread);
            }
        }

        if (FD_ISSET(naming_server_fd, &read_fds)) {
            int* new_ns_socket = malloc(sizeof(int));
            *new_ns_socket = accept(naming_server_fd, NULL, NULL);

            if (*new_ns_socket >= 0) {
                pthread_t ns_thread;
                if (pthread_create(&ns_thread, NULL, naming_server_handler, new_ns_socket) != 0) {
                    perror("Naming Server thread creation failed");
                    free(new_ns_socket);
                }
                pthread_detach(ns_thread);
            }
        }
    }

    return 0;
}

void handle_stream_request(int client_socket, const char* filePath) {
    char buffer[8192];
    ssize_t bytes_read;
    FILE *audio_file;
    
    // Debug print to see what path we're trying to open
    printf("Attempting to open file: %s\n", filePath);
    
    // Check if file exists before trying to open it
    if (access(filePath, F_OK) == -1) {
        printf("Error: File does not exist at path: %s\n", filePath);
        // Send error message to client
        const char* error_msg = "FILE_NOT_FOUND";
        send(client_socket, error_msg, strlen(error_msg), 0);
        return;
    }
    
    // Check if we have read permissions
    if (access(filePath, R_OK) == -1) {
        printf("Error: No read permission for file: %s\n", filePath);
        const char* error_msg = "NO_PERMISSION";
        send(client_socket, error_msg, strlen(error_msg), 0);
        return;
    }
    
    // Open the audio file
    audio_file = fopen(filePath, "rb");
    if (audio_file == NULL) {
        printf("Error opening file: %s\n", strerror(errno));
        const char* error_msg = "OPEN_FAILED";
        send(client_socket, error_msg, strlen(error_msg), 0);
        return;
    }
    
    printf("Successfully opened file. Beginning streaming...\n");
    
    // Read file content and send to client
    while ((bytes_read = fread(buffer, 1, sizeof(buffer), audio_file)) > 0) {
        ssize_t bytes_sent = 0;
        while (bytes_sent < bytes_read) {
            ssize_t result = send(client_socket, buffer + bytes_sent, 
                                bytes_read - bytes_sent, 0);
            if (result < 0) {
                printf("Error sending data: %s\n", strerror(errno));
                fclose(audio_file);
                return;
            }
            bytes_sent += result;
        }
    }
    
    printf("Finished streaming file\n");
    
    // Close the file
    fclose(audio_file);
}

void handle_copy_request(int client_socket, char buffer[4096]) {
    char command[MAX_MSG_SIZE] = "";
    char path[MAX_PATH_LENGTH] = "";
    sscanf(buffer, "%s %s", command, path);

    if (strcmp(command, "CHECK_PATH") == 0) {
        struct stat path_stat;
        if (stat(path, &path_stat) == 0) {
            if (S_ISDIR(path_stat.st_mode)) {
                send(client_socket, "DIRECTORY", 9, 0);
            } else {
                send(client_socket, "FILE", 4, 0);
            }
        } else {
            printf("[ERROR] stat() failed for path '%s': %s\n", path, strerror(errno));
            send(client_socket, "NOT_FOUND", 9, 0);
        }
    }
    else if (strcmp(command, "LIST_DIR") == 0) {
        DIR* dir = opendir(path);
        if (dir == NULL) {
            printf("[ERROR] opendir() failed for path '%s': %s\n", path, strerror(errno));
            send(client_socket, "ERROR", 5, 0);
            return;
        }

        char file_list[BUFFER_SIZE] = "";
        struct dirent* entry;
        while ((entry = readdir(dir)) != NULL) {
            if (strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0) {
                strcat(file_list, entry->d_name);
                strcat(file_list, "\n");
            }
        }
        closedir(dir);

        if (strlen(file_list) == 0) {
            printf("[DEBUG] Directory '%s' is empty.\n", path);
        }

        send(client_socket, file_list, strlen(file_list), 0);
    }
    else if (strcmp(command, "DIR_CREATE") == 0) {
        if (mkdir(path, 0777) == 0) {
            send(client_socket, "SUCCESS", 7, 0);
        } else {
            printf("[ERROR] mkdir() failed for path '%s': %s\n", path, strerror(errno));
            send(client_socket, "ERROR", 5, 0);
        }
    }
    else if (strcmp(command, "READ_FILE") == 0) {
        FILE* file = fopen(path, "rb");
        if (file == NULL) {
            printf("[ERROR] fopen() failed for path '%s': %s\n", path, strerror(errno));
            send(client_socket, "ERROR", 5, 0);
            return;
        }

        char file_contents[MAX_FILE_SIZE];
        size_t bytes_read = fread(file_contents, 1, MAX_FILE_SIZE, file);
        fclose(file);
        send(client_socket, file_contents, bytes_read, 0);
    }
    else if (strncmp(buffer, "WRITE_FILE", 10) == 0) {
        char path[256];
        int file_size;

        // Tokenize the buffer
        char *command = strtok(buffer, " "); // Extract command
        char *path_token = strtok(NULL, " "); // Extract path
        char *file_size_token = strtok(NULL, " "); // Extract file size
        char *file_contents = strtok(NULL, ""); // Extract remaining content (file contents)

        // Validate parsed tokens
        if (command == NULL || path_token == NULL || file_size_token == NULL || file_contents == NULL) {
            printf("[ERROR] Invalid WRITE_FILE command format.\n");
            send(client_socket, "ERROR", 5, 0);
            return;
        }

        // Convert file_size_token to an integer
        file_size = atoi(file_size_token);
        strncpy(path, path_token, PATH_MAX - 1);
        path[PATH_MAX - 1] = '\0'; // Ensure null-termination

        // Open the file for writing
        FILE *file = fopen(path, "wb");
        if (file == NULL) {
            printf("[ERROR] fopen() failed for path '%s': %s\n", path, strerror(errno));
            send(client_socket, "ERROR", 5, 0);
            return;
        }

        // Write the file content to the destination file
        fwrite(file_contents, 1, file_size, file);
        fclose(file);

        // Send success response to the client
        send(client_socket, "SUCCESS", 7, 0);
    }
    else {
        printf("[WARNING] Unknown command '%s' received.\n", command);
        send(client_socket, "UNKNOWN_COMMAND", 15, 0);
    }

}

void* naming_server_handler(void* ns_sock) {
   int ns_socket = *(int*)ns_sock;
    char buffer[BUFFER_SIZE]="";
    ssize_t bytes_received;

    // Receive the full message from Naming Server
    memset(buffer, 0, sizeof(buffer));
    bytes_received = recv(ns_socket, buffer, sizeof(buffer) - 1, 0);
    if (bytes_received <= 0) {
        printf("Connection closed by Naming Server.\n");
        close(ns_socket);
        return NULL;
    }
    buffer[bytes_received] = '\0';
    if (strncmp(buffer, "CREATE", 6) == 0) {
         char* token; // Define token here
        char path[MAX_PATH_LENGTH]="";
        char name[1024]="";
        int is_folder;
        // Tokenize buffer to parse command arguments
        token = strtok(buffer + 6, " ");  // Skip the "CREATE" part to get the next tokens

        // Parse the path
        if (token == NULL) {
            printf("Failed to parse path.\n");
            close(ns_socket);
            return NULL;
        }
        strncpy(path, token, sizeof(path) - 1);
        path[sizeof(path) - 1] = '\0';  // Ensure null termination

        // Parse the name
        token = strtok(NULL, " ");
        if (token == NULL) {
            printf("Failed to parse name.\n");
            close(ns_socket);
            return NULL;
        }
        strncpy(name, token, sizeof(name) - 1);
        name[sizeof(name) - 1] = '\0';  // Ensure null termination

        // Parse the is_folder flag
        token = strtok(NULL, " ");
        if (token == NULL) {
            printf("Failed to parse is_folder flag.\n");
            close(ns_socket);
            return NULL;
        }
        is_folder = atoi(token);  // Convert flag to integer (0 or 1)

        // Call create_file_or_folder function
        int result = create_file_or_folder(path, name, is_folder);

        // Send response based on result
        const char* response = (result == 0) ? "ACK" : "STOP";
        send(ns_socket, response, strlen(response), 0);
    }

    else if (strncmp(buffer, "DELETE", 6) == 0) {
        char* token; // Define token here
        char path[MAX_PATH_LENGTH]="";
        // Tokenize buffer to parse arguments
        token = strtok(buffer + 6, " ");  // Skip the "DELETE" part to get the next token (path)

        // Parse the path
        if (token == NULL) {
            printf("Failed to parse path.\n");
            close(ns_socket);
            return NULL;
        }
        strncpy(path, token, sizeof(path) - 1);
        path[sizeof(path) - 1] = '\0';  // Ensure null termination

        // Call delete_file_or_folder function
        int result = delete_file_or_folder(path);

        // Send response based on result
        const char* response = (result == 0) ? "ACK" : "STOP";
        send(ns_socket, response, strlen(response), 0);
    }

    else if (strncmp(buffer, "CHECK_PATH", 10) == 0 ||
        strncmp(buffer, "LIST_DIR", 8) == 0 ||
        strncmp(buffer, "DIR_CREATE", 10) == 0 ||
        strncmp(buffer, "READ_FILE", 9) == 0 ||
        strncmp(buffer, "WRITE_FILE", 10) == 0) {
        handle_copy_request(ns_socket,buffer);
    }

    else{
        printf("Unknown operation received:\n");
    }
    close(ns_socket);
    return NULL;
}
