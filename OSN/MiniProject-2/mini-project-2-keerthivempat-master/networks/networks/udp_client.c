#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <arpa/inet.h>

#define PORT 8080
#define MAXLINE 1024

int main() {
    int sockfd;
    char buffer[MAXLINE];
    struct sockaddr_in servaddr;

    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }

    memset(&servaddr, 0, sizeof(servaddr));
    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(PORT);

    // Connect to the server
    printf("Connecting to the server...\n");

    // Notify server of player connection
    sendto(sockfd, "Player connected", strlen("Player connected"), MSG_CONFIRM, (const struct sockaddr *)&servaddr, sizeof(servaddr));

    while (1) {
        // Receive messages from the server
        int n = recvfrom(sockfd, buffer, MAXLINE, MSG_WAITALL, NULL, NULL);
        buffer[n] = '\0';
        printf("%s", buffer); // Display the message

        // If prompted for a move
        if (strstr(buffer, "your turn")) {
            int row, col;
            printf("Enter your move (row and column): ");
            scanf("%d %d", &row, &col);
            sprintf(buffer, "%d %d", row, col);
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&servaddr, sizeof(servaddr));
        } 
        
        // If prompted to play again
        if (strstr(buffer, "play again?")) {
            char response[3];
            printf("Do you want to play again? (yes/no): ");
            scanf("%s", response);
            sendto(sockfd, response, strlen(response), MSG_CONFIRM, (const struct sockaddr *)&servaddr, sizeof(servaddr));
        }

        // If the server says both players said "no"
        if (strstr(buffer, "Your opponent chose not to play again. Ending the game.") || strstr(buffer,"You chose not to play again. Ending the game.")) {
            // printf("Both players chose not to play again. Exiting...\n");
            break; // Exit the loop
        }
        else if(strstr(buffer,"Both players chose not to play again. Closing the game.")){
            printf("Both players chose not to play again. Exiting...\n");
            break;
        }
    }

    close(sockfd);
    return 0;
}
