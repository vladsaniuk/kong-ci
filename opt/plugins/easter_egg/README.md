# Easter Egg plugin     
This is a plugin to learn Kong custom plugin development and lua.    
Plugin adds header in request and responce, hence being called in different places of request cycle.    
If header "User" is set and write_to_db is false in plugin config, you'll get an error.   
Plugin use cache to get token and DB to store it.    
Response header will be added only for http requests.    