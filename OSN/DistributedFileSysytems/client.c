#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "client.h"
#include <arpa/inet.h>
#include <sys/wait.h>
#include <pthread.h>

StorageServer storage_servers[MAX_SERVERS];
char answer[10];
int indexs=0;
typedef struct {
    int socket;
} ThreadArgs;

// Thread function to listen for the second acknowledgment
void* listen_for_ack(void* args) {
    ThreadArgs* threadArgs = (ThreadArgs*)args;
    int ss_socket = threadArgs->socket;
    char confirmation[BUFFER_SIZE];
    ssize_t bytesReceived;

    // Wait for the final acknowledgment
    bytesReceived = recv(ss_socket, confirmation, sizeof(confirmation) - 1, 0);
    if (bytesReceived > 0) {
        confirmation[bytesReceived] = '\0';
        printf("Final acknowledgment from Storage Server: %s\n", confirmation);
    } else if (bytesReceived == 0) {
        printf("Storage Server closed the connection.\n");
    } else {
        perror("Failed to receive final acknowledgment from Storage Server");
    }

    free(threadArgs);
    return NULL;
}

void handle_read_request(int client, StorageServer storageServerInfo, int ss_socket, const char* filePath) {
    char message[BUFFER_SIZE];
    // Prepare the read request
    snprintf(message, sizeof(message), "%s %s", READ, filePath);
    // Send the read request to the storage server
    if (send(ss_socket, message, strlen(message), 0) < 0) {
        perror("Failed to send read request");
        return; // Exit if sending fails
    }

    char buffer[1024]; // Buffer to hold incoming data
    int bytesRead;

    while (1) {
        // Receive data directly from the storage server
        bytesRead = recv(ss_socket, buffer, sizeof(buffer) - 1, 0);

        if (bytesRead > 0) {
            buffer[bytesRead] = '\0'; // Null-terminate the received data
            printf("Data Packet: %s\n", buffer); // Process the received data

            if(strcmp(buffer, "STOP")==0)
            {
                printf("END OF DATA IN FILE\n");
                break;
            }
        } else {
            // Handle disconnection or error
            printf("Connection closed by server or error occurred.\n");
            break;
        }
    }
}

void handle_stream_request(int client, StorageServer storageServerInfo, int server_socket, const char* filepath) {
    char buffer[8192];
    ssize_t bytes_received;
    int pipe_fd[2];
    pid_t pid;
    
    // Create a pipe for communication between parent and child process
    if (pipe(pipe_fd) == -1) {
        perror("pipe");
        return;
    }
    char message[BUFFER_SIZE];
    // Prepare the read request
    snprintf(message, sizeof(message), "%s %s", STREAM, filepath);
     // Send the read request to the storage server
    if (send(server_socket, message, strlen(message), 0) < 0) {
        perror("Failed to send read request");
        return; // Exit if sending fails
    }
    // Fork a process to handle mpv player
    pid = fork();
    
    if (pid == -1) {
        perror("fork");
        return;
    }
    
    if (pid == 0) {  // Child process
        // Close write end of pipe
        close(pipe_fd[1]);
        
        // Redirect stdin to read end of pipe
        dup2(pipe_fd[0], STDIN_FILENO);
        close(pipe_fd[0]);
        
        // Execute mpv player
        execlp("mpv", "mpv", "-", "--no-terminal", "--no-video", NULL);
        perror("execlp");
        exit(1);
    } else {  // Parent process
        // Close read end of pipe
        close(pipe_fd[0]);
        
        // Receive data from server and write to pipe
        while ((bytes_received = recv(server_socket, buffer, sizeof(buffer), 0)) > 0) {
            write(pipe_fd[1], buffer, bytes_received);
        }
        
        // Close write end of pipe
        close(pipe_fd[1]);
        
        // Wait for child process to finish
        waitpid(pid, NULL, 0);
    }
}

void handle_write_request(int client, StorageServer storageServerInfo, int ss_socket,const char * filePath) {
    char message[BUFFER_SIZE];
    char dataToWrite[8192];
    char confirmation[BUFFER_SIZE];
    ssize_t bytesSent, bytesReceived;

    // Prepare the write request message (check if synchronous)
    printf("Do you want a synchronous write? (yes/no): ");
    fgets(message, sizeof(message), stdin);
    message[strcspn(message, "\n")] = '\0'; // Remove newline character
    int isSync = (strcmp(message, "yes") == 0);

    snprintf(message, sizeof(message), "%s %s %s", "WRITE", filePath, isSync ? "--SYNC" : "--ASYNC");
    printf("%s\n", message);
    // Send the write request to the storage server
    bytesSent=send(ss_socket, message, strlen(message), 0);
    if (bytesSent < 0) {
        perror("Failed to send write request");
        return;
    }

    // Input the data to write
    printf("Enter the data to write to the file: ");
    fgets(dataToWrite, sizeof(dataToWrite), stdin);
    dataToWrite[strcspn(dataToWrite, "\n")] = '\0'; // Remove newline character
    

    // Send the data to the storage server
    bytesSent = send(ss_socket, dataToWrite, strlen(dataToWrite), 0);
    if (bytesSent < 0) {
        perror("Failed to send data to Storage Server");
    } else {
        printf("Data sent to Storage Server: %s\n", dataToWrite);
    }
    send(ss_socket, &indexs, sizeof(indexs), 0);
    char ack[1024];
    recv(ss_socket, ack, sizeof(ack) - 1, 0);
    printf("recieved ack: %s\n",ack);
}

void handle_info_request(int client, StorageServer storageServerInfo, int ss_socket,const char * filePath) {
    char message[BUFFER_SIZE];
    // Prepare the read request
    snprintf(message, sizeof(message), "%s %s", INFO, filePath);
    // Send the read request to the storage server
    if (send(ss_socket, message, strlen(message), 0) < 0) {
        perror("Failed to send info request");
        return; // Exit if sending fails
    }
    char buffer[1024]; // Buffer to hold incoming data
    int bytesRead;

    // Receive data directly from the storage server
    bytesRead = recv(ss_socket, buffer, sizeof(buffer) - 1, 0);

    if (bytesRead > 0) {
        buffer[bytesRead] = '\0'; // Null-terminate the received data
        printf("%s\n", buffer); // Process the received data
    } else {
        // Handle disconnection or error
        printf("No info received.\n");
    }
}

void establishConnectionWithSS(int client, StorageServer storageServerInfo, const char *operation,const char* filePath) {
    int ss_socket;
    struct sockaddr_in ss_addr;

    // Create socket for Storage Server
    if ((ss_socket = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("Socket creation for Storage Server failed");
        exit(EXIT_FAILURE);
    }


    // Configure Storage Server address
    ss_addr.sin_family = AF_INET;
    ss_addr.sin_port = htons(atoi(storageServerInfo.client_port));
    inet_pton(AF_INET, storageServerInfo.ip, &ss_addr.sin_addr);

    // Connect to the Storage Server
    if (connect(ss_socket, (struct sockaddr *)&ss_addr, sizeof(ss_addr)) < 0) {
        perror("Connection to Storage Server failed");
        exit(EXIT_FAILURE);
    } 

    if (strcmp(operation, READ) == 0) {
        handle_read_request(client,storageServerInfo,ss_socket,filePath);
    } 
    else if (strcmp(operation, STREAM) == 0) {
        handle_stream_request(client,storageServerInfo,ss_socket,filePath);
    } 
    else if (strcmp(operation, WRITE) == 0) {
        handle_write_request(client,storageServerInfo,ss_socket,filePath);
    } 
    else if (strcmp(operation, INFO) == 0) {
        handle_info_request(client,storageServerInfo,ss_socket,filePath);
    } 
    
    close(ss_socket);
}


void connect_to_naming_server(const char *ip, int client_port) {
    while(1) {
    int sock;
    struct sockaddr_in server_addr;
    char operation[BUFFER_SIZE]=""; 
    char filePath[BUFFER_SIZE]="";
    char srcPath[BUFFER_SIZE]="";
    char name[BUFFER_SIZE]="";
    char destPath[BUFFER_SIZE]="";

    // Create socket
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        perror("Socket creation error");
        exit(EXIT_FAILURE);
    }

    // Configure server address
    server_addr.sin_family = AF_INET;
    server_addr.sin_port = htons(client_port); // Convert to network byte order

    // Convert IP address from text to binary
    if (inet_pton(AF_INET, ip, &server_addr.sin_addr) <= 0) {
        perror("Invalid address / Address not supported");
        exit(EXIT_FAILURE);
    }

    // Connect to the Naming Server
    if (connect(sock, (struct sockaddr *)&server_addr, sizeof(server_addr)) < 0) {
        perror("Connection failed");
        exit(EXIT_FAILURE);
    }
        printf("Enter the operation you want to perform\n");
        fgets(operation, sizeof(operation), stdin);
        operation[strcspn(operation, "\n")] = 0; // Remove newline character

        if (strcmp(operation, READ) == 0 || strcmp(operation, STREAM) == 0 || 
            strcmp(operation, WRITE) == 0 || strcmp(operation, INFO) == 0) {   
            // Send the operation
            if (send(sock, operation, strlen(operation), 0) < 0) {
                perror("Failed to send operation");
                continue;
            }
            
            // Request and send the file path
            printf("Enter the File Path: ");
            fgets(filePath, sizeof(filePath), stdin);
            filePath[strcspn(filePath, "\n")] = 0; // Remove trailing newline

            // Send the file path
            if (send(sock, filePath, strlen(filePath), 0) < 0) {
                perror("Failed to send file path");
                continue;
            }
        }
        else if(strcmp(operation, "DELETE") == 0) {
            // Send the operation
            if (send(sock, operation, strlen(operation), 0) < 0) {
                perror("Failed to send operation");
                continue;
            }
            // Request and send the file path
            printf("Enter the File Path: ");
            fgets(filePath, sizeof(filePath), stdin);
            filePath[strcspn(filePath, "\n")] = 0; // Remove trailing newline

            // Send the file path
            if (send(sock, filePath, strlen(filePath), 0) < 0) {
                perror("Failed to send file path");
                continue;
            }
        }
        else if(strcmp(operation, "CREATE") == 0) {
            send(sock, operation, strlen(operation), 0);

            printf("Enter the Path to Create in:\n");
            fgets(filePath, sizeof(filePath), stdin);
            filePath[strcspn(filePath, "\n")] = 0; // Remove newline
            send(sock, filePath, strlen(filePath), 0); // Send the path

            int is_folder = 0;
            printf("Enter 0 to create a file, 1 to create a directory: ");
            scanf("%d", &is_folder);
            getchar();

            // Send the is_folder flag to the server
            char folder_flag[2];  // Can hold '0' or '1' and null terminator
            snprintf(folder_flag, sizeof(folder_flag), "%d", is_folder);
            send(sock, folder_flag, strlen(folder_flag), 0); // Send is_folder

            if(is_folder) {
                printf("Enter the Name of Folder to Create:\n");
            } else {
                printf("Enter the Name of File to Create:\n");
            }
            
            fgets(name, sizeof(name), stdin);
            name[strcspn(name, "\n")] = 0; // Remove newline
            send(sock, name, strlen(name), 0);  // Send the name
        }
        else if(strcmp(operation,LIST)==0) {
            send(sock, operation, strlen(operation), 0);
        }
        else if(strcmp(operation,COPY)==0) {
            send(sock, operation, strlen(operation), 0);
            printf("Enter the Source Path\n");
            fgets(srcPath, sizeof(srcPath), stdin);
            srcPath[strcspn(srcPath, "\n")] = 0;
            send(sock, srcPath, strlen(srcPath), 0);
            printf("Enter the Destination Path\n");
            fgets(destPath, sizeof(destPath), stdin);
            destPath[strcspn(destPath, "\n")] = 0;
            send(sock, destPath, strlen(destPath), 0);
        }
        else if(strcmp(operation, "EXIT")==0)
        {
            send(sock, operation, strlen(operation), 0);
            //break;
            return;
        }
        else{
            printf("Invalid Command\n");
            continue;
        }
        // Handling receiving response from naming server part
        if (strcmp(operation, READ) == 0) {
            //printf("hiiii\n");
            // Receive response containing Storage Server information
            StorageServer storageServerInfo;
            recv(sock, &storageServerInfo, sizeof(StorageServer), 0);
            printf("storage info recieved\n");
            int error_code;
            recv(sock, &error_code, sizeof(int), 0);
            printf("error code recieved\n");
            int index_of_server;
            recv(sock, &index_of_server, sizeof(int), 0);
            printf("index recieved\n");
            if(error_code==101)
            {
                printf("Error:101-No matching storage server found for path: %s\n", filePath);
            }
            else if(error_code==204)
            {
                printf("Storage is down, accessing backup storage server to READ\n");
                char data[MAX_FILE_SIZE];
                recv(sock, data, MAX_FILE_SIZE, 0);
                printf("%s\n", data);
            }
            else
            {
                printf("Received Storage Server Info: IP = %s, Port = %s\n", storageServerInfo.ip, storageServerInfo.client_port);

                // Establish a connection to the Storage Server for file request
                //printf("Do you want to write asynchronously?\n");
                establishConnectionWithSS(sock, storageServerInfo, operation,filePath);
            }
        } 
        else if (strcmp(operation, STREAM) == 0) {

            // Receive response containing Storage Server information
            StorageServer storageServerInfo;
            recv(sock, &storageServerInfo, sizeof(StorageServer), 0);
            printf("storage info recieved\n");
            int error_code;
            recv(sock, &error_code, sizeof(int), 0);
            printf("error code recieved\n");
            int index_of_server;
            recv(sock, &index_of_server, sizeof(int), 0);
            printf("index recieved\n");
            if(error_code==101)
            {
                printf("Error:101-No matching storage server found for path: %s\n", filePath);
            }
            else if(error_code==200)
            {
                printf("Server went down, cannot perform given operation\n");
            }
            else
            {
                printf("Received Storage Server Info: IP = %s, Port = %s\n", storageServerInfo.ip, storageServerInfo.client_port);

                // Establish a connection to the Storage Server for file request
                establishConnectionWithSS(sock, storageServerInfo, operation,filePath);
            }

        } 
        else if (strcmp(operation, WRITE) == 0) {

            // Receive response containing Storage Server information
           StorageServer storageServerInfo;
            recv(sock, &storageServerInfo, sizeof(StorageServer), 0);
            printf("storage info recieved\n");
            int error_code;
            recv(sock, &error_code, sizeof(int), 0);
            printf("error code recieved\n");
            int index_of_server;
            recv(sock, &index_of_server, sizeof(int), 0);
            indexs=index_of_server;
            printf("index recieved\n");
            if(error_code==101)
            {
                printf("Error:101-No matching storage server found for path: %s\n", filePath);
            }
            else if(error_code==200)
            {
                printf("Server went down, cannot perform given operation\n");
            }
            else
            {
                printf("Received Storage Server Info: IP = %s, Port = %s\n", storageServerInfo.ip, storageServerInfo.client_port);
                //printf("Do you want to write asynchronously?\n");
                //scanf("%s", answer);
                // Establish a connection to the Storage Server for file request

                establishConnectionWithSS(sock, storageServerInfo,operation,filePath);
            }
        }  
        else if (strcmp(operation, INFO) == 0) {
            // Receive response containing Storage Server information
            StorageServer storageServerInfo;
            recv(sock, &storageServerInfo, sizeof(StorageServer), 0);
            printf("storage info recieved\n");
            int error_code;
            recv(sock, &error_code, sizeof(int), 0);
            printf("error code recieved\n");
            int index_of_server;
            recv(sock, &index_of_server, sizeof(int), 0);
            printf("index recieved\n");
            if(error_code==101)
            {
                printf("Error:101-No matching storage server found for path: %s\n", filePath);
            }
            else if(error_code==200)
            {
                printf("Server went down, cannot perform given operation\n");
            }
            else
            {
                printf("Received Storage Server Info: IP = %s, Port = %s\n", storageServerInfo.ip, storageServerInfo.client_port);

                // Establish a connection to the Storage Server for file request
                establishConnectionWithSS(sock, storageServerInfo,operation,filePath);
            }
        }
        else if(strcmp(operation, CREATE)==0){
            char response[BUFFER_SIZE];
            ssize_t bytes_received = recv(sock, response, sizeof(response) - 1, 0);
            if (bytes_received < 0) {
                perror("Error receiving response from Naming Server");
            } else if (bytes_received > 0) {
                response[bytes_received] = '\0';
                if (strcmp(response, "ACK") == 0) {
                    printf("File/folder created successfully.\n");
                } else if (strcmp(response, "109") == 0) {
                    printf("Error:109-File/folder creation failed.\n");
                } else {
                    printf("Unknown response received: %s\n", response);
                }
            } else {
                printf("No response received from Naming Server.\n");
            }
        }
        else if(strcmp(operation, DELETE)==0){
            char response[256];
            ssize_t bytes_received = recv(sock, response, sizeof(response) - 1, 0); // Leave space for null terminator
            if (bytes_received < 0) {
                perror("Error receiving response from Naming Server");
            } else if (bytes_received > 0) {
                response[bytes_received] = '\0';  // Null-terminate the response for safe printing

                // Check if the response indicates success or failure
                if (strcmp(response, "ACK") == 0) {
                    printf("File/folder created successfully.\n");
                } 
                else if (strcmp(response, "101") == 0) {
                    printf("Error:101-File not found in any storage server.\n");
                } 
                else if (strcmp(response, "108") == 0) {
                    printf("Error:108-Storage server failed to delete the file or folder.\n");
                } 
                else if (strcmp(response, "202") == 0)
                {
                    printf("Error:202-storage server down, Try after sometime\n");
                }
                else {
                    printf("Unknown response received: %s\n", response);
                }
            } else {
                printf("No response received from Naming Server.\n");
            }
        }
        else if (strcmp(operation, COPY) == 0) {
            char response[256];
            ssize_t bytes_received = recv(sock, response, sizeof(response) - 1, 0);  // Leave space for null terminator

            if (bytes_received < 0) {
                perror("Error receiving response from Naming Server");
            } else if (bytes_received > 0) {
                response[bytes_received] = '\0';  // Null-terminate the response for safe printing
                // Check if the response indicates success or failure
                if (strcmp(response, "ACK") == 0) {
                    printf("File/directory copied successfully.\n");
                } else if (strcmp(response, "112") == 0) {
                    printf("File/directory copy operation failed.\n");
                } 
                else if(strcmp(response, "202")==0)
                {
                    printf("Error:202-One of the storage server is down, cannot perform COPY operation\n");
                }
                else {
                    printf("Unknown response received: %s\n", response);
                }
            } else {
                printf("No response received from Naming Server.\n");
            }
        }
        else if (strcmp(operation, LIST) == 0) {
            char response[1024];
            ssize_t bytes_received;

            printf("Accessible paths:\n");
            // Continuously receive data until the Naming Server indicates completion
            bytes_received = recv(sock, response, sizeof(response) - 1, 0);
            if (bytes_received > 0) {
                response[bytes_received] = '\0';  // Null-terminate for safe printing

                char *line = strtok(response, "\n");
                
                while (line != NULL) {
                    printf("%s\n", line);
                    line = strtok(NULL, "\n");  // Move to the next line
                }
            }
            // Check if no data was received or if an error occurred
            if (bytes_received < 0) {
                perror("Error receiving list from Naming Server");
            } else if (bytes_received == 0) {
                printf("No data received; Naming Server may have closed the connection.\n");
            }
        } 
    
    // Close the socket
    close(sock);
    }
}

int main(int argc, char* argv[]) {
    char* nm_ip = argv[1];
    int nm_port = atoi(argv[2]);
    
    printf("naming server port is %d\n",nm_port);
    printf("naming server ip address is %s\n",nm_ip);

    // Connect to Naming Server
    connect_to_naming_server(nm_ip, nm_port);

    // Here, you can proceed with further client functionalities

    return 0;
}