# Network File System (NFS)

## **Introduction**

This project is a distributed file system designed from scratch to provide seamless file storage and access across a network of clients and servers. It consists of three main components: 

1. **Clients**: Interact with the system for file-related operations.
2. **Naming Server (NM)**: Acts as the orchestrator, directing clients to the appropriate Storage Server (SS).
3. **Storage Servers (SS)**: Handle the actual storage, retrieval, and management of file data.

This README provides a detailed description of the system's functionality, components, installation, and usage.

---

## **System Components**

### **1. Clients**
- **Primary Role**: Users or systems that send requests to the NFS to perform operations like reading, writing, creating, deleting, and streaming files.
- **Key Features**:
  - Synchronous and asynchronous writing.
  - Streaming of audio files.
  - Multiple client support for concurrent access.
  - Error handling with descriptive error codes.

---

### **2. Naming Server (NM)**
- **Primary Role**: Directory service and central coordinator.
- **Key Features**:
  - Maintains metadata about files and their storage locations.
  - Handles client requests and redirects them to the correct SS.
  - Implements efficient search with Tries or Hashmaps.
  - Supports Least Recently Used (LRU) caching for frequent queries.
  - Logs all operations and communications for traceability.

---

### **3. Storage Servers (SS)**
- **Primary Role**: Store files and folders.
- **Key Features**:
  - File and folder creation, deletion, reading, and writing.
  - Replication for fault tolerance (each file is stored on three servers if possible).
  - Asynchronous duplication for improved performance.
  - Recovery and re-synchronization upon reconnection after failure.

---

## **Core Functionalities**

### WRITE
- Asynchronous write is done when size of data to be written is greater than a threshold value(1024 here) or if specified by the client. 
- Client need not wait for this write to complete and can perform other operations. 
- In the other case i.e, if size of data to be written is less than threshold value or if specified by the client, synchronous write is performed.
-  In this case, client cannot perform any other operation until write operation terminates. 

### READ
- Opens given file path from its storage server and displays data in the file as it is.

### LIST
- LIST command is handled by naming server. When LIST command is sent to ns by client, ns displays all the accessible paths across all storage servers.

### INFO
- it give information about the file data,file size and its permissions etc.
### COPY
- When a client issues a command, the Naming Server (NS) locates both the source and destination paths and orchestrates the operation.  
- If the paths span multiple SS, the NS coordinates data transfer between them by providing necessary connection details. 
- For copies within the same SS, the operation is handled locally. The system dynamically updates the list of accessible paths and ensures data integrity throughout the process. 
- This implementation supports seamless scalability and adaptability in a distributed environment.
### STREAM
- Clients request the Naming Server (NS) with a command, and the NS identifies the appropriate Storage Server (SS) where the file resides. 
- The client then connects to the designated SS to receive audio data in binary format, which can be directly fed into a music player for real-time playback.
-  The implementation ensures efficient packetized delivery of data, allowing uninterrupted streaming, even for large files.
-  This feature enhances user experience by minimizing delays and enabling seamless access to multimedia content.
---

### **Command-Line Interface (CLI) Commands**

#### **1. Basic File Operations**
- **Read a File**:
  ```bash
  READ <path>
  ```
- **Write to a File**:
  ```bash
  WRITE <path> --data "Sample data" [--SYNC/ASYNC]
  ```
- **Create a File/Folder**:
  ```bash
  CREATE <path> <name>
  ```
- **Delete a File/Folder**:
  ```bash
  DELETE <path>
  ```
- **Stream an Audio File**:
  ```bash
  STREAM <path>
  ```
- **Copy Files**:
  ```bash
  COPY <source_path> <destination_path>
  ```
- **List All Paths**:
  ```bash
  LIST <path>
  ```

#### **3. Logs and Debugging**
- **View Logs**:
  Logs are saved in `logs/naming_server.log` and `logs/storage_server_<ID>.log`.

---

## **Error Codes**
- 101 file not found in any storage server
- 102 Invalid server address
- 103 connection to storage server failed
- 104 failed to send request
- 105 failed to recieve response
- 106 path does not exist
- 107 error opening the directory
- 108 Storage server failed to delete the file or folder
- 109 failed to create file/folder in ss
- 110 no storage server available
- 111 path is not accessible
- 112 failed to copy 
- 202 storage server down, Try after sometime
- 204 Storage is down, accessing backup storage server to READ
- 200 Server went down, cannot perform given operation
---

## **Features and Implementation Notes**

### 1. Asynchronous and Synchronous Writing
- **Asynchronous Writing**: Clients receive an immediate acknowledgment after submitting a write request. Data is stored in memory and flushed to persistent storage in chunks.
- **Priority Writes**: A `--SYNC` flag allows clients to request synchronous writes for critical operations.
- **Failure Handling**: If a write fails midway (e.g., SS goes down), the Naming Server (NM) informs the client.

---

### 2. Handling Multiple Clients
- **Concurrent Access**: NM handles simultaneous requests by using initial and final acknowledgments, ensuring it doesn’t block while processing.
- **Read-Write Locking**: 
  - Multiple clients can read the same file concurrently.
  - Only one client can write to a file at a time. During asynchronous writes, the file is locked for reading.

---

### 3. Error Codes
- Clear and descriptive error codes for various scenarios, including:
  - File not found
  - File locked for writing
  - Storage Server failure
  - Request timeout

---

### 4. Efficient Search in Naming Servers
- **Optimized Search**: Implements Tries or Hashmaps to improve the lookup of files and folders compared to linear search.
- **LRU Caching**: Caches recent searches to expedite repeated queries, enhancing performance.

---

### 5. Data Backup and Fault Tolerance
- **Failure Detection**: NM continuously monitors SS health and detects failures.
- **Replication**: Data is duplicated asynchronously to two additional SS for fault tolerance.
- **Asynchronous Duplication**: Write requests are mirrored without waiting for acknowledgment, ensuring redundancy.

---
---

### 7. Bookkeeping
- **Logging**: NM records every request and acknowledgment, including:
  - Timestamp
  - IP addresses and ports
  - Operation status
- **Message Display**: System logs include success or error messages for each operation, aiding in debugging and monitoring.

---

### **Directory Structure**
```
.
├── client.c                # Client-side script
├── naming_server.c         # Naming Server script
├── storage_server.c        # Storage Server script
├── naming_server.h         # headers
├── README.md               # Documentation
├── client.h                # headers
```

### **Testing**
- First run naming server which gives us IP ,client_port and storage_server port.
- Next run storage server with ip and port from naming server and add accesible paths each one sepereated by "," 
- Next run client with IP and client port from naming server and perform the desired operations. 
---
### Assumptions:
- BUFFER_SIZE 1024
- MAX_DATA_PACKET_SIZE 2048  // 2 KB data packet size for streaming
- define NAMING_SERVER_INFO_FILE "naming_server_info.txt"
- MAX_SERVERS 100
- MAX_IP_LENGTH 16
- MAX_PORT_LENGTH 6
- MAX_PATHS 100
- MAX_PATH_LENGTH 256
- MAX_FILE_SIZE 1048576 
- MAX_FILES 1000
- MAX_PENDING_OPS 1000 
- FILE_LOCKED -1
- FILE_AVAILABLE 0
## **Future Improvements**
- Redundancy Management: Synchronize replicated data during SS recovery.
- File Locking Mechanism: Enhance concurrency by adding granular file locking.
- Scalability: Implement dynamic load balancing among servers.
- Enhanced User Interface: Provide a GUI for better user experience.
- not JUST streaming audio files we can also implement to send large videofoiles.
---

## **DONE BY:**
- **Team_12**
