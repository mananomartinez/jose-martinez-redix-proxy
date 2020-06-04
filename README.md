# Candidate: Jose L. Martinez
## Coding exercise - Redis Proxy

## Introduction
This project implements a read-through proxy for a Redis to maintain a cache of user-requested values.

The original document with the description of the problem and its requirements can be found in the [here](./candidateBrief/README.md).
 
### Requirement overview
- External requests come into the proxy via a web server/service listening for them.
- If a requested value is not present in the cache, a query to Redis is triggered. If found, the value is added to the cache.
- Any entry added the cache is subject to eviction/deletion whenever the cache reaches its pre-defined capacity.
- To prevent stale data in the cache, each entry will have a set expiration time. When this time is reached, a request 
for the entry will trigger a query to Redis to obtain the value and replace it in the cache. 
  
## Architecture overview
- Language: Ruby (v 2.6.0).
- 3rd Party Dependencies: minitest, mocha and rake

The project is made up of 4 main areas of functionality : **Entry Point, Server, Cache and Redis Client**. 
### Sequence Diagram 
![Sequence Diagram](/docs/diagram.png)

### Overview of  functionality 
 - Entry point (`main.rb`) 
    - Parses and validates the arguments/options passed to the program.
    - Starts the `Server` functionality.
 
 - Server (`web_server.rb`)
    - Starts a TCP server, on an infinite loop, to listen for incoming client.
    - Handles one client request at the time, queuing up waiting requests.
    - Validates that the request is formatted properly. Returns an error if not.
    - Queries the `Cache` for matches to the key provided by the client request.
    - Builds a response for the client.
     
 - Cache (`cache_controller.rb`)
    - Initializes a cache object
    - Locally stores requested values from Redis.
    - Retrieves a value in the cache, if its key matches the one passed to it by the caller.
    - Enforces the global expiration time and queries Redis for elements.   
    - Ensures that the capacity of the cache is not exceeded.
        - This is done by evicting stored elements when they have not been accessed recently. 
 
 - Redis Client (`redis_client.rb`)
    - Handles queries to a Redis instance.
    - Creates `RESP` protocol commands.
    - Decodes responses from Redis into plain strings.
    - Returns string response to caller or raises an error if problems encountered.  
        - Assumption: Since the client request includes only the key, it seemed natural that the proxy returns the plain 
        string value, stripped of RESP characters.
                
    
### Algorithmic complexity - Cache operations.
The cache storage is a Ruby Hash object. The operations to read and insert elements use the default Ruby's methods for 
retrieval and assignment. These methods are rated to have, at worst, O(n) complexity. 

Deletion of a key during eviction is equally at worst an O(n) complexity given that all the items are traversed and 
compared for the lowest value of the `last_accessed_time`.
 
### Instructions for proxy and tests.
#### Pre-requisites
 - Ensure that Ruby (v 2.6.0 or greater) is installed in the system.
 - Install the bundler gem (`gem install bundler`) and execute the command `bundle install` at the root level of the project to install the dependencies. 
 - Set the PROXY_ADDRESS and PROXY_PORT environment variables to indicate the address and port to be used by the server. 
   - If these are not defined, the server will start by binding to 0.0.0.0 and claiming port 9090
   
#### Executing the proxy 
To execute the server, execute the following in the command line, at the root directory of the project. 
`ruby ./src/main.rb --redis_host_address localhost --port 6379 --expiry 10 --capacity 100` 

Running `ruby ./src/main.rb` will print out a usage listing for the app and the arguments.
```shell_script
Usage: main.rb [options]
    -r redis_host_address,           Host address for Redis backing instance
        --redis_host_address
    -p, --port port                  Port for Redis backing instance
    -e, --expiry seconds             Seconds to expire items in cache
    -c, --capacity capacity          Capacity of keys in cache
    -t, --threads threads            Number of parallel requests to process at one time. 10 is default
    -h, --help                       Displays Help
```
#### Executing the tests
To run both the unit and system_tests with the necessary redis instance and proxy, use the  `make test` command. 

To execute the unit tests, simply run `rake`, in the command line, with the parameter `test` while in the root directory of the project.

`rake test`

The system tests require that a proxy server as well as a Redis instance are running and accessible from the machine.  

`rake system_tests`

### Time breakdown.
These times include research as well as development time, spread over several days. 

 - Core functionality 
    - Redis Client - 4 hours
    - Cache Controller - 3 hours
    - Web Server - 2 hours
    - Main - 2 hours 
 - System Tests 
    - Docker and docker-compose - 4 hours
    - Tests - 2 hours
 - Additional requirements
    - Layer 7 to Redis - 1 hour
    - Parallel/concurrent processing - 2 hours  

### Additional Requirements  implemented
#### Parallel concurrent processing
Making use of the `concurrent-ruby` library, I was able to add a fixed size thread pool. The capacity of this thread pool 
is an option passed as an argument in the command line when starting the proxy (defaults at 10). 
I also leveraged the `concurrent-ruby` library to easily add write and read locks around the critical areas that access 
the cache storage to avoid race conditions. 
 
#### Redis client protocol
After some further investigation on the OSI network model, I realized that one protocol that runs at this layer is Telnet.
I initially was making all my calls through the L4 (TCP) but it was simple matter of using a 3rd party gem that enabled
the Telnet functionality.  
