#ifndef CLIENT_H
#define CLIENT_H
#include "naming_server.h"
// Constants
#define BUFFER_SIZE 1024
#define MAX_DATA_PACKET_SIZE 2048  // 2 KB data packet size for streaming
#define NAMING_SERVER_INFO_FILE "naming_server_info.txt"

// Define command types as constants
#define READ "READ"
#define STREAM "STREAM"
#define CREATE "CREATE"
#define DELETE "DELETE"
#define COPY "COPY"
#define WRITE "WRITE"
#define INFO "INFO"
#define LIST "LIST"

// Function prototypes
void handle_read_request(int client, StorageServer storageServerInfo, int ss_socket, const char *filePath);
void handle_stream_request(int client, StorageServer storageServerInfo, int ss_socket, const char *filePath);
void handle_write_request(int client, StorageServer storageServerInfo, int ss_socket, const char *filePath);
void establishConnectionWithSS(int client, StorageServer storageServerInfo, const char *operation, const char *filePath);
void retrieve_naming_server_info(char *ip, int *client_port);
void connect_to_naming_server(const char *ip, int client_port);

#endif /* CLIENT_H */
