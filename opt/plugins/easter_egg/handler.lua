local easter_egg = {
    VERSION  = "1.0.0",
    PRIORITY = 10,
}

function easter_egg:access(config)
    local headers = kong.request.get_headers()
    for _, v in ipairs(headers) do
        print(v)
    end
end