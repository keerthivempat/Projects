#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>
#include "iman.h"

#define BUFFER_SIZE 1024
#define MAX_RESPONSE_SIZE 100000 

// Color macros
#define COLOR_RESET "\x1b[0m"
#define COLOR_ERROR "\x1b[31m" // Red color for error messages

void strip_html_tags(char *str) {
    char *src = str;
    char *dst = str;
    int in_tag = 0;

    while (*src) {
        if (*src == '<') {
            in_tag = 1;
        } else if (*src == '>') {
            in_tag = 0;
            src++;
            continue;
        }

        if (!in_tag) {
            *dst++ = *src;
        }
        src++;
    }
    *dst = '\0';
}

void fetch_man_page(const char *command, struct HttpResponse *responseStruct) {
    int sock;
    struct sockaddr_in server;
    struct hostent *host;
    char request[BUFFER_SIZE];
    char response[BUFFER_SIZE];
    int bytes_received;
    int response_len = 0;
    int header_end = 0;
    char *body_start = NULL;
    const char *hostname = "man.he.net";

    // Resolve hostname
    if ((host = gethostbyname(hostname)) == NULL) {
        fprintf(stderr, COLOR_ERROR "Error: Unable to resolve hostname\n" COLOR_RESET);
        return;
    }

    // Create socket
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        fprintf(stderr, COLOR_ERROR "Error: Socket creation error: %s\n" COLOR_RESET, strerror(errno));
        return;
    }

    server.sin_family = AF_INET;
    server.sin_port = htons(80); // HTTP default port
    memcpy(&server.sin_addr, host->h_addr_list[0], host->h_length);

    // Connect to server
    if (connect(sock, (struct sockaddr *)&server, sizeof(server)) < 0) {
        fprintf(stderr, COLOR_ERROR "Error: Connection error: %s\n" COLOR_RESET, strerror(errno));
        close(sock);
        return;
    }

    // Send HTTP request
    snprintf(request, sizeof(request),
             "GET /?topic=%s&section=all HTTP/1.1\r\n"
             "Host: man.he.net\r\n"
             "Connection: close\r\n\r\n", 
             command);
    if (send(sock, request, strlen(request), 0) < 0) {
        fprintf(stderr, COLOR_ERROR "Error: Send error: %s\n" COLOR_RESET, strerror(errno));
        close(sock);
        return;
    }

    // Clear the response buffer
    memset(responseStruct->data, 0, MAX_RESPONSE_SIZE);

    // Receive and process response
    while ((bytes_received = recv(sock, response, sizeof(response) - 1, 0)) > 0) {
        response[bytes_received] = '\0';

        if (!header_end) {
            char *header_end_pos = strstr(response, "\n\n");
            if (header_end_pos) {
                header_end = 1;
                body_start = header_end_pos + 4;

                int body_size = bytes_received - (body_start - response);
                if (response_len + body_size > MAX_RESPONSE_SIZE) {
                    fprintf(stderr, COLOR_ERROR "Error: Response too large\n" COLOR_RESET);
                    close(sock);
                    return;
                }
                memcpy(responseStruct->data + response_len, body_start, body_size);
                response_len += body_size;
            }
        } else {
            if (response_len + bytes_received > MAX_RESPONSE_SIZE) {
                fprintf(stderr, COLOR_ERROR "Error: Response too large\n" COLOR_RESET);
                close(sock);
                return;
            }
            memcpy(responseStruct->data + response_len, response, bytes_received);
            response_len += bytes_received;
        }
    }

    if (bytes_received < 0) {
        fprintf(stderr, COLOR_ERROR "Error: Receive error: %s\n" COLOR_RESET, strerror(errno));
    }

    responseStruct->data[response_len] = '\0';

    // Strip HTML tags
    strip_html_tags(responseStruct->data);

    // Print the man page content
    printf("Man page content:\n%s\n", responseStruct->data);

    close(sock);
}
