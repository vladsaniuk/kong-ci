local easter_egg = {
    VERSION  = "1.0.0",
    PRIORITY = 10,
}

function easter_egg:access(config)
    local headers = kong.request.get_headers()
    local is_easter_egg_header_sent = false

    for header, header_value in pairs(headers) do
        kong.log("Header is: " .. header .. " , header value is: " .. header_value)
        if header == config.request_header
        then
            kong.service.request.set_header(header, "this is custom header value added by plugin")
            is_easter_egg_header_sent = true
        end
    end

    kong.log("Header in config was found: " .. tostring(is_easter_egg_header_sent))

    if not is_easter_egg_header_sent
    then
        kong.service.request.set_header("request-easter-egg-header", "this is custom header and value added by plugin")
    end
end

return easter_egg