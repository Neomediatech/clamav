# clamav-alpine
Dockerized version of clamav daemon, based on Alpine Linux

## Usage
You can run this container with this command:  
`docker run -d --name clamav-alpine neomediatech/clamav-alpine`  

Logs are written inside the container, in /var/log/clamav/, and on stdout. You can see realtime logs running this command:  
`docker logs -f clamav-alpine`  
`CTRL c` to stop seeing logs.  

If you want to map logs outside the container you can add:  
`-v /folder/path/on-host/logs/:/var/log/clamav/`  
Where "/folder/path/on-host/logs/" is a folder inside your host. You have to create the host folder manually.  

You can run it on a compose file like this:  

```
version: '3'  

services:  
  clamav:  
    image: neomediatech/clamav-alpine:latest  
    hostname: clamav  
```
Save on a file and then run:  
`docker stack deploy -c /your-docker-compose-file-just-created.yml clamav`

If you want to map logs outside the container you can add:  
```
    volumes:
      - /folder/path/on-host/logs/:/var/log/clamav/
```
Where "/folder/path/on-host/logs/" is a folder inside your host. You have to create the host folder manually.

Save on a file and then run:  
`docker stack deploy -c /your-docker-compose-file-just-created.yml clamav-honey`  
