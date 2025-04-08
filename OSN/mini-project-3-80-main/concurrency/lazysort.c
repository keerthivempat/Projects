#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <time.h>

#define MAX_FILENAME_LEN 128
#define MAX_TIMESTAMP_LEN 20
#define THRESHOLD 42
#define MAX_THREADS 4

typedef struct {
    char filename[MAX_FILENAME_LEN];
    int id;
    char timestamp[MAX_TIMESTAMP_LEN];
} FileEntry;

typedef struct {
    FileEntry* entries;
    int start;
    int end;
    int column;
} ThreadArgs;

FileEntry* globalEntries;
int* countArray;
pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

// Function to compare timestamps
int compareTimestamps(const char* ts1, const char* ts2) {
    int year1, month1, day1, hour1, min1, sec1;
    int year2, month2, day2, hour2, min2, sec2;
    
    sscanf(ts1, "%d-%d-%dT%d:%d:%d", &year1, &month1, &day1, &hour1, &min1, &sec1);
    sscanf(ts2, "%d-%d-%dT%d:%d:%d", &year2, &month2, &day2, &hour2, &min2, &sec2);
    
    if (year1 != year2) return year1 - year2;
    if (month1 != month2) return month1 - month2;
    if (day1 != day2) return day1 - day2;
    if (hour1 != hour2) return hour1 - hour2;
    if (min1 != min2) return min1 - min2;
    return sec1 - sec2;
}

// Function to compare entries based on different columns
int compareEntries(const void* a, const void* b, int column) {
    FileEntry* entry1 = (FileEntry*)a;
    FileEntry* entry2 = (FileEntry*)b;

    switch(column) {
        case 0: // Name
            return strcmp(entry1->filename, entry2->filename);
        case 1: // ID
            return entry1->id - entry2->id;
        case 2: // Timestamp
            return compareTimestamps(entry1->timestamp, entry2->timestamp);
        default:
            return 0;
    }
}

// Merge function for merge sort
void merge(FileEntry* entries, int left, int mid, int right, int column) {
    int i, j, k;
    int n1 = mid - left + 1;
    int n2 = right - mid;

    FileEntry* L = malloc(n1 * sizeof(FileEntry));
    FileEntry* R = malloc(n2 * sizeof(FileEntry));

    for (i = 0; i < n1; i++)
        L[i] = entries[left + i];
    for (j = 0; j < n2; j++)
        R[j] = entries[mid + 1 + j];

    i = 0;
    j = 0;
    k = left;

    while (i < n1 && j < n2) {
        if (compareEntries(&L[i], &R[j], column) <= 0)
            entries[k++] = L[i++];
        else
            entries[k++] = R[j++];
    }

    while (i < n1)
        entries[k++] = L[i++];
    while (j < n2)
        entries[k++] = R[j++];

    free(L);
    free(R);
}

// Thread function for merge sort
void* mergeSortThread(void* args) {
    ThreadArgs* threadArgs = (ThreadArgs*)args;
    int start = threadArgs->start;
    int end = threadArgs->end;
    int column = threadArgs->column;
    
    if (start < end) {
        int mid = start + (end - start) / 2;
        
        // Create thread arguments for recursive calls
        ThreadArgs leftArgs = {threadArgs->entries, start, mid, column};
        ThreadArgs rightArgs = {threadArgs->entries, mid + 1, end, column};
        
        pthread_t leftThread, rightThread;
        
        // Create threads for each half
        pthread_create(&leftThread, NULL, mergeSortThread, &leftArgs);
        pthread_create(&rightThread, NULL, mergeSortThread, &rightArgs);
        
        // Wait for threads to complete
        pthread_join(leftThread, NULL);
        pthread_join(rightThread, NULL);
        
        // Merge the sorted halves
        merge(threadArgs->entries, start, mid, end, column);
    }
    
    return NULL;
}

void distributedMergeSort(FileEntry* entries, int n, int column) {
    ThreadArgs args = {entries, 0, n - 1, column};
    mergeSortThread(&args);
}

// Count sort implementation (for ID column only)
void* countSortThread(void* args) {
    ThreadArgs* threadArgs = (ThreadArgs*)args;
    int start = threadArgs->start;
    int end = threadArgs->end;
    int column = threadArgs->column;

    if (column == 1) { // Only for ID column
        for (int i = start; i < end; i++) {
            pthread_mutex_lock(&mutex);
            countArray[globalEntries[i].id]++;
            pthread_mutex_unlock(&mutex);
        }
    }
    return NULL;
}

void distributedCountSort(FileEntry* entries, int n, int column) {
    // For non-ID columns, use merge sort
    if (column != 1) {
        distributedMergeSort(entries, n, column);
        return;
    }

    // Initialize count array - find max ID first
    int maxId = entries[0].id;
    for (int i = 1; i < n; i++) {
        if (entries[i].id > maxId) maxId = entries[i].id;
    }
    countArray = calloc(maxId + 1, sizeof(int));
    globalEntries = entries;

    // Create threads
    pthread_t threads[MAX_THREADS];
    ThreadArgs threadArgs[MAX_THREADS];
    int chunk = n / MAX_THREADS;
    if (chunk == 0) chunk = 1;

    for (int i = 0; i < MAX_THREADS && i * chunk < n; i++) {
        threadArgs[i].entries = entries;
        threadArgs[i].start = i * chunk;
        threadArgs[i].end = (i == MAX_THREADS - 1) ? n : ((i + 1) * chunk);
        threadArgs[i].column = column;
        pthread_create(&threads[i], NULL, countSortThread, &threadArgs[i]);
    }

    // Join threads
    for (int i = 0; i < MAX_THREADS && i * chunk < n; i++) {
        pthread_join(threads[i], NULL);
    }

    // Reconstruct sorted array
    int pos = 0;
    FileEntry* temp = malloc(n * sizeof(FileEntry));
    memcpy(temp, entries, n * sizeof(FileEntry));

    // Reconstruct based on count array
    for (int i = 0; i <= maxId; i++) {
        for (int j = 0; j < n; j++) {
            if (temp[j].id == i) {
                entries[pos++] = temp[j];
            }
        }
    }

    free(temp);
    free(countArray);
}

// Main sorting function that decides which algorithm to use
void lazySort(FileEntry* entries, int n, int column) {
    printf("Number of entries: %d\n", n);
    if (n < THRESHOLD) {
        distributedCountSort(entries, n, column);
    } else {
        distributedMergeSort(entries, n, column);
    }
}

int main() {
    int n;
    scanf("%d", &n);
    // printf("Number of entries: %d\n", n);

    FileEntry* entries = malloc(n * sizeof(FileEntry));

    // Read entries
    for (int i = 0; i < n; i++) {
        scanf("%s %d %s", entries[i].filename, &entries[i].id, entries[i].timestamp);
    }

    // Read sorting column
    char column[20];
    scanf("%s", column);
    printf("Sorting by column: %s\n", column);

    // Determine column index
    int columnIndex;
    if (strcmp(column, "Name") == 0) columnIndex = 0;
    else if (strcmp(column, "ID") == 0) columnIndex = 1;
    else if (strcmp(column, "Timestamp") == 0) columnIndex = 2;
    else {
        printf("Invalid column name\n");
        return 1;
    }

    // Sort entries
    lazySort(entries, n, columnIndex);

    // Print sorted entries
    for (int i = 0; i < n; i++) {
        printf("%s %d %s\n", entries[i].filename, entries[i].id, entries[i].timestamp);
    }

    free(entries);
    pthread_mutex_destroy(&mutex);
    return 0;
}