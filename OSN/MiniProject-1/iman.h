#ifndef IMAN_H 
#define IMAN_H

// Struct to hold the HTML response
struct HttpResponse {
    char data[100000]; // To hold the HTML content (adjust size based on your needs)
    int length;        // To hold the length of the content
};

// Function prototype for fetching the man page
void fetch_man_page(const char *command, struct HttpResponse *responseStruct);
#endif // IMAN_H