# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -I. # Include current directory for header files

# Source files
SRCS = main.c hop.c reveal.c utilities.c prompt.c log.c proclore.c seek.c pipes.c activities.c mysignal.c iman.c foreground_background.c myshrc.c neonate.c
OBJS = $(SRCS:.c=.o)

# Output executable
TARGET = myshell

# Default rule
all: $(TARGET)

# Link the object files to create the executable
$(TARGET): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

# Compile each .c file into a .o file
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Clean up build artifacts
clean:
	rm -f $(TARGET) $(OBJS)

# Phony targets (not actual files)
.PHONY: all clean
