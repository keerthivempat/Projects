# Networking
Multiplayer Game using TCP & UDP Sockets
This project is a simple two-player multiplayer game implemented in C using both TCP and UDP socket programming. It demonstrates how to build interactive client-server applications over a network using two different transport protocols.

# Features
**Two-player game played over the network.**

**Implemented using both TCP and UDP.**

**Real-time board updates.**

**Turn-based logic with proper synchronization.**

**Server waits for two clients to connect.**

**Clear win/draw detection logic.**

**Clean separation of client and server logic.**

**Handles disconnections and invalid inputs gracefully.**

⚙️ **How to Run**

**🖧 TCP Version**

**Compile the server and client:**

Edit
gcc tcp_server.c -o server
gcc tcp_client.c -o client
Run the server (in one terminal):

./server
Run the clients (in two separate terminals):


./client

📡 UDP Version

Compile the server and client:


gcc udp_server.c -o server

gcc udp_client.c -o client

Run the server:


./server

Run the clients (in two separate terminals):

./client

📝 Note: Make sure both clients connect successfully before the game begins. The game will not proceed until both players are connected.

🧠 Concepts Demonstrated

Socket creation and connection (TCP & UDP)

Data transmission and reliability

Synchronization between clients

Basic game state management

Error handling and graceful exits

Blocking vs Non-blocking behavior (especially in UDP)

🎮 Game Rules
(Update this based on your game logic. Here's an example for Tic-Tac-Toe)

Each player is assigned a symbol: X or O.

Players take turns to choose a position on a 3x3 board.

The first player to align three of their symbols (horizontally, vertically, or diagonally) wins.

If the board is full and no one wins, it's a draw.
