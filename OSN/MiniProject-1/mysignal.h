#ifndef MYSIGNAL_H
#define MYSIGNAL_H
extern pid_t pid_fg;
// Signal handler function declarations
void sigint_handler(int sig);   // Handler for Ctrl+C (SIGINT)
void sigtstp_handler(int sig);  // Handler for Ctrl+Z (SIGTSTP)
void sigquit_handler(int sig);  // Handler for Ctrl+D (to terminate the shell)
void handle_ping_command(const char *command);
void process_command(char *user_input);

// Function to initialize the signal handlers
void initialize_signal_handlers();

// Function to send a signal to a process
void send_signal_to_process(pid_t pid, int signal);

#endif
