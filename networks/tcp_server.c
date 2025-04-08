#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

#define PORT 8080
#define BOARD_SIZE 9
char board[BOARD_SIZE];
int game_over = 0;

void initialize_board() {
    for (int i = 0; i < BOARD_SIZE; i++) {
        board[i] = ' ';
    }
}

void print_board() {
    printf("\n");
    printf(" %c | %c | %c\n", board[0], board[1], board[2]);
    printf("---|---|---\n");
    printf(" %c | %c | %c\n", board[3], board[4], board[5]);
    printf("---|---|---\n");
    printf(" %c | %c | %c\n", board[6], board[7], board[8]);
}

void format_board(char* board_string) {
    snprintf(board_string, 100, 
             " %c | %c | %c\n---|---|---\n %c | %c | %c\n---|---|---\n %c | %c | %c\n", 
             board[0], board[1], board[2],
             board[3], board[4], board[5],
             board[6], board[7], board[8]);
}

int check_winner() {
    const int win_combinations[8][3] = {
        {0, 1, 2}, {3, 4, 5}, {6, 7, 8},  // rows
        {0, 3, 6}, {1, 4, 7}, {2, 5, 8},  // columns
        {0, 4, 8}, {2, 4, 6}              // diagonals
    };
    for (int i = 0; i < 8; i++) {
        if (board[win_combinations[i][0]] != ' ' &&
            board[win_combinations[i][0]] == board[win_combinations[i][1]] &&
            board[win_combinations[i][1]] == board[win_combinations[i][2]]) {
            return board[win_combinations[i][0]] == 'X' ? 1 : 2;
        }
    }
    for (int i = 0; i < BOARD_SIZE; i++) {
        if (board[i] == ' ') {
            return 0;  // game continues
        }
    }
    return -1;  // draw
}

void update_board(int move, char symbol) {
    board[move] = symbol;
}

// Function to reset the game state
void reset_game_state() {
    initialize_board();
    game_over = 0;
}

int main() {
    int server_fd, new_socket1, new_socket2;
    struct sockaddr_in address;
    int addrlen = sizeof(address);
    char buffer[1024] = {0};
    char turn_msg[50];
    char invalid_move[30];
    char result_msg[50];
    char board_string[100];  // Increased buffer size
    int player_turn = 1;
    int move;

    // Create socket file descriptor
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        exit(EXIT_FAILURE);
    }
    // Bind the socket to the port
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(PORT);
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        exit(EXIT_FAILURE);
    }
    // Listen for connections
    if (listen(server_fd, 2) < 0) {
        perror("listen failed");
        exit(EXIT_FAILURE);
    }
    printf("Waiting for two players to connect...\n");

    // Accept connections from two players
    new_socket1 = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
    printf("Player 1 connected!\n");
    send(new_socket1, "Welcome Player 1 (X)!\n", 22, 0);
    new_socket2 = accept(server_fd, (struct sockaddr *)&address, (socklen_t*)&addrlen);
    printf("Player 2 connected!\n");
    send(new_socket2, "Welcome Player 2 (O)!\n", 22, 0);

    // Initialize the board and format the initial state
    // reset_game_state(); // Initialize the game state
    // format_board(board_string); // Prepare the initial board string
    // // Send the initial board state to both players
    // send(new_socket1, board_string, strlen(board_string), 0);
    // send(new_socket2, board_string, strlen(board_string), 0);

    // Game loop
while (1) {
    reset_game_state(); // Reset the game state for a new game
    format_board(board_string); // Format the board string
    // Send the initial board state to both players
    send(new_socket1, board_string, strlen(board_string), 0);
    send(new_socket2, board_string, strlen(board_string), 0);

    while (!game_over) {
        int player_socket = player_turn == 1 ? new_socket1 : new_socket2;
        char symbol = player_turn == 1 ? 'X' : 'O';

        // Send turn message to the current player
        snprintf(turn_msg, sizeof(turn_msg), "Your turn! Player %d (%c).Enter your move: ", player_turn, symbol);
        send(player_socket, turn_msg, strlen(turn_msg), 0);

        // Receive the move from the current player
        memset(buffer, 0, sizeof(buffer)); // Clear the buffer
        recv(player_socket, buffer, sizeof(buffer), 0);

        // Parse the move from 1-9 into row and column
        int move;
        sscanf(buffer, "%d", &move);
        move--;  // Convert to 0-indexed

        // Validate the move
        if (move >= 0 && move < 9 && board[move] == ' ') {
            update_board(move, symbol);
            format_board(board_string);
            // Send the updated board state to both players
            send(new_socket1, board_string, strlen(board_string), 0);
            send(new_socket2, board_string, strlen(board_string), 0);
            send(player_socket, "Move registered. Wait for your turn...\n", 39, 0);
            
            int winner = check_winner();
            if (winner == 1) {
                snprintf(result_msg, sizeof(result_msg), "Player 1 Wins!\n");
                send(new_socket1, result_msg, strlen(result_msg), 0);
                send(new_socket2, result_msg, strlen(result_msg), 0);
                game_over = 1;
            } else if (winner == 2) {
                snprintf(result_msg, sizeof(result_msg), "Player 2 Wins!\n");
                send(new_socket1, result_msg, strlen(result_msg), 0);
                send(new_socket2, result_msg, strlen(result_msg), 0);
                game_over = 1;
            } else if (winner == -1) {
                snprintf(result_msg, sizeof(result_msg), "It's a draw!\n");
                send(new_socket1, result_msg, strlen(result_msg), 0);
                send(new_socket2, result_msg, strlen(result_msg), 0);
                game_over = 1;
            }
            // Switch players
            player_turn = player_turn == 1 ? 2 : 1;
        } else {
            send(player_socket, "Invalid move! Try again.\n", 25, 0);
        }
    }

    // Ask if players want to play again
    char response1[10], response2[10];
    send(new_socket1, "Do you want to play again? (yes/no)\n", 36, 0);
    send(new_socket2, "Do you want to play again? (yes/no)\n", 36, 0);

    // Get responses from both players
    memset(response1, 0, sizeof(response1));
    memset(response2, 0, sizeof(response2));
    recv(new_socket1, response1, sizeof(response1), 0);
    recv(new_socket2, response2, sizeof(response2), 0);

    // Debugging Output
    printf("Response from Player 1: %s\n", response1);
    printf("Response from Player 2: %s\n", response2);

    // Check for player responses
    if (strncmp(response1, "no", 2) == 0 && strncmp(response2, "no", 2) == 0) {
        send(new_socket1, "Closing connection\n", 18, 0);
        send(new_socket2, "Closing connection\n", 18, 0);
        break; // Exit the game loop
    }
    if(strncmp(response1,"no",2)==0 && strncmp(response2,"yes",3)==0){
        send(new_socket2,"Opponent don't want to play\n",27,0);
        break;
    }
    if(strncmp(response1,"yes",3)==0 && strncmp(response2,"no",2)==0){
        send(new_socket1,"Opponent don't want to play\n",27,0);
        break;
    }
        else {
        // Reset the game state for a new game
        reset_game_state(); // Reset for a new game
        player_turn = 1; // Set the starting player
        game_over = 0; // Reset game_over flag
    }
}

    close(new_socket1);
    close(new_socket2);
    close(server_fd);
    return 0;
}
