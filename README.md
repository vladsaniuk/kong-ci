# CI for Kong Community Edition

For local development you can use docker compose: `docker compose up --build --detach`  
To view logs: `docker logs <container ID>`  
To get container ID: `docker ps` or `docker ps -a` later will print out all containers, including exited ones  
To bring the stack down: `docker compose down`  
To remove PostgreSQL volume: `sudo rm -rf docker-compose-volume`  

# Certificates  
Certs in this repo are locally generated and intended only for local dev environment purpose.  