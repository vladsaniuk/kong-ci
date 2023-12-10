local easter_egg = {
    VERSION  = "1.0.0",
    PRIORITY = 10,
}

local err_500 = { status = 500, message = "Something went very wrong" }
local err_401 = { status = 401, message = "Unauthorized, please, add \"User\" header and set write_to_db as true" }

local function generate_token()
    local dictionary = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local token = ""
    local i = 0
    while i <= 32 do
        local character_index = math.random(1, string.len(dictionary))
        local character = string.sub(dictionary, character_index, character_index)
        token = token .. character
        i = i + 1
    end
    return token
end

local function get_user(username)
    local user_in_db, err = kong.db.easter_egg_table:select({
        user = username
    })

    if not user_in_db then
        return nil
    end

    if err then
        kong.log.err("Error when selecting user from DB: " .. err)
        return kong.response.error(err_500.status, err_500.message)
    end
    return user_in_db, err
end

function easter_egg:access(config)
    local headers = kong.request.get_headers()
    local is_easter_egg_header_sent = false
    local is_user_header_set = false

    for header, header_value in pairs(headers) do
        kong.log.debug("Header is: " .. header .. " , header value is: " .. header_value)

        if header == config.request_header then
            kong.service.request.set_header(header, "this is custom header value added by plugin in request")
            is_easter_egg_header_sent = true
        end

        if header == "user" and config.write_to_db then
            is_user_header_set = true
            kong.log.debug("User is: " .. header_value)
            local cache_key = kong.db.easter_egg_table:cache_key(header_value)
            local cached_user = kong.cache:get(cache_key, { resurrect_ttl = 0.001 }, get_user, header_value)

            local token
            
            if cached_user then
                token = cached_user.token
                kong.log.debug(header_value .. " user found in cache, use cached token")
            end
            
            if not cached_user then
                local user_in_db, err = kong.db.easter_egg_table:select({
                    user = header_value
                })
                
                if err then
                    kong.log.err("Error when selecting user from DB: " .. err)
                    return kong.response.error(err_500.status, err_500.message)
                end

                if not user_in_db then
                    kong.log.debug(header_value .. " user doesn't exist, create user")
                    local generated_token = generate_token()

                    local user_add, err = kong.db.easter_egg_table:insert({
                        user = header_value,
                        token = generated_token
                    })
                    
                    if err then
                        kong.log.err("Error when inserting user to DB: " .. err)
                        return kong.response.error(err_500.status, err_500.message)
                    end
                    
                    if not user_add then
                        kong.log.err("Failed to insert user to DB")
                        return kong.response.error(err_500.status, err_500.message)
                    end

                    user_in_db = user_add
                end

                if user_in_db then
                    token = user_in_db.token
                    kong.log.debug(header_value .. " user wasn't found in cache, but found in DB, use token from DB")
                end
            end
            kong.service.request.set_header("token", token)
        elseif header == "user" and not config.write_to_db then
            kong.log.err("Header \"User\" is set, but write_to_db is false in plugin config")
            return kong.response.error(err_401.status, err_401.message)
        end
    end

    if not is_user_header_set and config.write_to_db then
        kong.log.err("Header \"User\" is not set, please, add header and retry")
        return kong.response.error(err_401.status, err_401.message)
    end
    kong.log.debug("Easter Egg header in config was found: " .. tostring(is_easter_egg_header_sent))

    if not is_easter_egg_header_sent
    then
        kong.service.request.set_header("request-easter-egg-header", "this is custom header and value added by plugin in request")
    end
end

function easter_egg:response(config)
    kong.log.debug("Add Easter Egg header to response")
    kong.response.set_header(config.response_header, "this is custom header and value added by plugin in response")
end

return easter_egg