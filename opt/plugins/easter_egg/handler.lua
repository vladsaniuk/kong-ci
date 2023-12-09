local easter_egg = {
    VERSION  = "1.0.0",
    PRIORITY = 10,
}

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

function easter_egg:access(config)
    local headers = kong.request.get_headers()
    local is_easter_egg_header_sent = false

    for header, header_value in pairs(headers) do
        kong.log.debug("Header is: " .. header .. " , header value is: " .. header_value)
        if header == config.request_header then
            kong.service.request.set_header(header, "this is custom header value added by plugin")
            is_easter_egg_header_sent = true
        end

        if header == "user" then
            kong.log.debug("User is: " .. header_value)
            
            local user_in_db, err = kong.db.easter_egg_table:select({
                user = header_value
            })
            
            if err then
                kong.log.err("Error when selecting user from DB: " .. err)
                return nil
            end

            if not user_in_db then
                kong.log.debug(header_value .. " user doesn't exist")
                local generated_token = generate_token()

                local user_add, err = kong.db.easter_egg_table:insert({
                    user = header_value,
                    token = generated_token
                })
                
                if err then
                    kong.log.err("Error when inserting user to DB: " .. err)
                    return nil
                end
                
                if not user_add then
                    kong.log.err("Failed to insert user to DB")
                end

                -- kong.service.request.set_header("token", user_add.token)
                -- return nil
                user_in_db = user_add
            end
            kong.service.request.set_header("token", user_in_db.token)
        end
    end

    kong.log.debug("Header in config was found: " .. tostring(is_easter_egg_header_sent))

    if not is_easter_egg_header_sent
    then
        kong.service.request.set_header("request-easter-egg-header", "this is custom header and value added by plugin")
    end
end

return easter_egg