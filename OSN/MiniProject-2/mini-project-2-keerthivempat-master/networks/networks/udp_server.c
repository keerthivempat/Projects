#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <arpa/inet.h>

#define PORT 8080
#define MAXLINE 1024

char board[3][3];   // Game board
int currentPlayer = 1;  // Keeps track of whose turn it is (1 = Player 1, 2 = Player 2)

void initBoard() {
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            board[i][j] = ' ';
        }
    }
}

void displayBoard(char *buffer) {
    sprintf(buffer, 
        " %c | %c | %c \n---|---|---\n %c | %c | %c \n---|---|---\n %c | %c | %c \n",
        board[0][0], board[0][1], board[0][2], 
        board[1][0], board[1][1], board[1][2], 
        board[2][0], board[2][1], board[2][2]);
}

int checkWin() {
    for (int i = 0; i < 3; i++) {
        if (board[i][0] == board[i][1] && board[i][1] == board[i][2] && board[i][0] != ' ') return 1;
        if (board[0][i] == board[1][i] && board[1][i] == board[2][i] && board[0][i] != ' ') return 1;
    }
    if (board[0][0] == board[1][1] && board[1][1] == board[2][2] && board[0][0] != ' ') return 1;
    if (board[0][2] == board[1][1] && board[1][1] == board[2][0] && board[0][2] != ' ') return 1;
    return 0;
}

int checkDraw() {
    for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
            if (board[i][j] == ' ') return 0;
        }
    }
    return 1;
}

int askToPlayAgain(int sockfd, struct sockaddr_in cliaddr[], socklen_t addrlen) {
    char buffer[MAXLINE];
    char response1[MAXLINE], response2[MAXLINE];

    // Ask both players if they want to play again
    strcpy(buffer, "Game over! Do you want to play again? (yes/no):\n");
    for (int i = 0; i < 2; i++) {
        sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
    }

    // Get responses from both players
    recvfrom(sockfd, response1, MAXLINE, MSG_WAITALL, (struct sockaddr *)&cliaddr[0], &addrlen);
    response1[strlen(response1)] = '\0';  // Null-terminate the response

    recvfrom(sockfd, response2, MAXLINE, MSG_WAITALL, (struct sockaddr *)&cliaddr[1], &addrlen);
    response2[strlen(response2)] = '\0';  // Null-terminate the response

    // If both players say yes, reset the board and start a new game
    if (strstr(response1, "yes") && strstr(response2, "yes")) {
        initBoard();
        currentPlayer = 1;
        strcpy(buffer, "Both players agreed! Starting a new game...\n");
        for (int i = 0; i < 2; i++) {
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
        }
        return 1; // Indicates the game should continue
    }
    // If both players say no, end the game and close the connection
    else if (strstr(response1, "no") && strstr(response2, "no")) {
        strcpy(buffer, "Both players chose not to play again. Closing the game.\n");
        for (int i = 0; i < 2; i++) {
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
        }
        close(sockfd);
        return 0; // Indicates the game should end
    }
    // If one player says yes and the other says no
    else {
        if (strstr(response1, "yes") && strstr(response2, "no")) {
            strcpy(buffer, "Your opponent chose not to play again. Ending the game.\n");
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[0], addrlen);
            strcpy(buffer, "You chose not to play again. Ending the game.\n");
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[1], addrlen);
        } else if (strstr(response1, "no") && strstr(response2, "yes")) {
            strcpy(buffer, "You chose not to play again. Ending the game.\n");
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[0], addrlen);
            strcpy(buffer, "Your opponent chose not to play again. Ending the game.\n");
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[1], addrlen);
        }
        // else if(strstr(response1, "no") && strstr(response2, "no")){
        //     strcpy(buffer,"Both players choose not to play again. Ending the game.\n");
        //     sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[0], addrlen);
        // }
        // Close the connection for both players and end the game
        close(sockfd);
        return 0; // Indicates the game should end
    }
}

int main() {
    int sockfd;
    char buffer[MAXLINE];
    struct sockaddr_in servaddr, cliaddr[2];
    int len, playerCount = 0;
    int row, col, n;
    socklen_t addrlen = sizeof(cliaddr[0]);

    // Socket creation and binding
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0) {
        perror("Socket creation failed");
        exit(EXIT_FAILURE);
    }

    memset(&servaddr, 0, sizeof(servaddr));

    servaddr.sin_family = AF_INET;
    servaddr.sin_addr.s_addr = INADDR_ANY;
    servaddr.sin_port = htons(PORT);

    if (bind(sockfd, (const struct sockaddr *)&servaddr, sizeof(servaddr)) < 0) {
        perror("Bind failed");
        close(sockfd);
        exit(EXIT_FAILURE);
    }

    printf("Waiting for players...\n");

    // Wait for 2 players to connect
    while (playerCount < 2) {
        n = recvfrom(sockfd, buffer, MAXLINE, MSG_WAITALL, (struct sockaddr *)&cliaddr[playerCount], &addrlen);
        buffer[n] = '\0';
        printf("Player %d connected\n", playerCount + 1);
        sprintf(buffer, "You are Player %d\n", playerCount + 1);
        sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[playerCount], addrlen);
        playerCount++;
    }

    initBoard();  // Initialize the game board

    // Start the game loop
    while (1) {
        // Display the current board
        displayBoard(buffer);
        for (int i = 0; i < 2; i++) {
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
        }

        sprintf(buffer, "Player %d, it's your turn. Enter row and column (1-3):\n", currentPlayer);
        sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[currentPlayer - 1], addrlen);

        // Receive move from the current player
        n = recvfrom(sockfd, buffer, MAXLINE, MSG_WAITALL, (struct sockaddr *)&cliaddr[currentPlayer - 1], &addrlen);
        buffer[n] = '\0';
        sscanf(buffer, "%d %d", &row, &col);

        // Adjusting for 1-based index to 0-based index
        row -= 1;
        col -= 1;

        // Check if the move is valid
        if (row < 0 || row > 2 || col < 0 || col > 2 || board[row][col] != ' ') {
            sprintf(buffer, "Invalid move, Player %d. Please try again.\n", currentPlayer);
            sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[currentPlayer - 1], addrlen);
            continue;  // Ask for the move again without displaying the board
        }

        // Make the move
        board[row][col] = (currentPlayer == 1) ? 'X' : 'O';

        // Check if the current player won
        if (checkWin()) {
    displayBoard(buffer);
    for (int i = 0; i < 2; i++) {
        sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
    }
    sprintf(buffer, "Player %d wins!\n", currentPlayer);
    for (int i = 0; i < 2; i++) {
        sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
    }
    // Check if players want to play again
    if (askToPlayAgain(sockfd, cliaddr, addrlen) == 0) {
        break;  // Exit the game loop if players don't want to continue
    }
}

        // Check for a draw
        if (checkDraw()) {
    displayBoard(buffer);
    for (int i = 0; i < 2; i++) {
        sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
    }
    strcpy(buffer, "It's a draw!\n");
    for (int i = 0; i < 2; i++) {
        sendto(sockfd, buffer, strlen(buffer), MSG_CONFIRM, (const struct sockaddr *)&cliaddr[i], addrlen);
    }
    // Check if players want to play again
    if (askToPlayAgain(sockfd, cliaddr, addrlen) == 0) {
        break;  // Exit the game loop if players don't want to continue
    }
}

        // Switch to the next player
        currentPlayer = (currentPlayer == 1) ? 2 : 1;
    }

    close(sockfd);
    return 0;
}
