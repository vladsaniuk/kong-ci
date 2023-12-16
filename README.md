# CI for Kong Community Edition

For local development you can use docker compose: `docker compose up --build --detach`  
To view logs: `docker logs <container ID>`  
To get container ID: `docker ps` or `docker ps -a` later will print out all containers, including exited ones  
To bring the stack down: `docker compose down`  
To remove PostgreSQL volume: `sudo rm -rf docker-compose-volume`  

## Certificates  
Certs in this repo are locally generated and intended only for local dev environment purpose.  

## Scanning       
Pipeline uses luacheck to scan custom plugin for Kong in lua and OSS tool Clair monitor the security of containers through the analysis of vulnerabilities.      
Both scanners run as containers with Docker besides Docker.        

## Run docker-compose     
Kong Dockerfile would expect Kong docker-entrypoint.sh in the root folder, you can grab it with:      
`curl https://raw.githubusercontent.com/Kong/docker-kong/master/docker-entrypoint.sh -o kong-docker-entrypoint.sh`  
And Kong deb package, to change version you can check Kong website and Jenkinsfile:      
`curl https://packages.konghq.com/public/gateway-34/deb/ubuntu/pool/jammy/main/k/ko/kong-enterprise-edition_3.4.1.1/kong-enterprise-edition_3.4.1.1_amd64.deb --output kong-enterprise-edition-3.4.1.1.deb`     

You can also change values for:
* KONG_LOG_LEVEL, default = info;    
* KONG_VERSION, default = 3.4.1.1;       
* RUN_MIGRATIONS, default = true.      