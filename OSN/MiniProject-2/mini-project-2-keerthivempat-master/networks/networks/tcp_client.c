#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>

#define PORT 8080
#define BOARD_SIZE 9

void display_board(char board[]) {
    printf(" %c | %c | %c\n", board[0], board[1], board[2]);
    printf("---|---|---\n");
    printf(" %c | %c | %c\n", board[3], board[4], board[5]);
    printf("---|---|---\n");
    printf(" %c | %c | %c\n", board[6], board[7], board[8]);
}

int main() {
    int sock = 0;
    struct sockaddr_in serv_addr;
    char buffer[1024] = {0};
    char move[10];  // To accommodate row and column input (e.g., "1 1")

    // Create socket
    if ((sock = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        printf("\n Socket creation error \n");
        return -1;
    }

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_port = htons(PORT);

    // Convert IPv4 and IPv6 addresses from text to binary
    if (inet_pton(AF_INET, "127.0.0.1", &serv_addr.sin_addr) <= 0) {
        printf("\nInvalid address/ Address not supported \n");
        return -1;
    }

    // Connect to the server
    if (connect(sock, (struct sockaddr *)&serv_addr, sizeof(serv_addr)) < 0) {
        printf("\nConnection Failed \n");
        return -1;
    }

    while (1) {
        memset(buffer, 0, sizeof(buffer));
        int recv_size = recv(sock, buffer, sizeof(buffer), 0);
        if (recv_size <= 0) {
            printf("Failed to receive data or connection closed by server.\n");
            break;
        }
        buffer[recv_size] = '\0'; // Null-terminate the received string
        printf("%s\n", buffer);  // Display message from the server

        // Check if the server is asking for a move
        if (strstr(buffer, "Your turn!") != NULL) {
            printf("Enter your move (row and column): ");
            fgets(move, sizeof(move), stdin);
            move[strcspn(move, "\n")] = 0;  // Strip newline character

            // Validate the input format (two numbers)
            int row, col;
            if (sscanf(move, "%d %d", &row, &col) == 2) {
                // Validate row and column values (1-3 for 1-9 grid)
                if (row >= 1 && row <= 3 && col >= 1 && col <= 3) {
                    // Convert row and column to board position (0-8)
                    int position = (row - 1) * 3 + (col - 1);
                    // Send the position (1-9) to the server
                    char position_str[3];
                    sprintf(position_str, "%d", position + 1); // Convert to 1-based index
                    send(sock, position_str, strlen(position_str), 0);
                } else {
                    printf("Invalid input! Please enter a position (row and column) between 1 and 3.\n");
                }
            } else {
                printf("Invalid input format! Please enter two numbers (row and column).\n");
            }
        }

        // Check if the server is asking whether the player wants to play again
        if (strstr(buffer, "Do you want to play again?") != NULL) {
            char response[10];

            // Get response from player
            printf("Enter your response (yes/no): ");
            fgets(response, sizeof(response), stdin);
            response[strcspn(response, "\n")] = '\0';  // Strip newline character

            // Send response to the server
            if (send(sock, response, strlen(response), 0) <= 0) {
                printf("Failed to send response to the server.\n");
            }
        }

        // Check if the server is closing the connection
        if (strstr(buffer, "Closing connection") != NULL) {
            printf("Game over. Disconnecting from server.\n");
            break;
        }
        else if(strstr(buffer, "Opponent don't want to play") != NULL){
            printf("Game Ends...\n");
            break;
        }
    }

    close(sock);
    return 0;
}
