-- schema.lua defines plugin config

local typedefs = require "kong.db.schema.typedefs"

return {
  name = "easter_egg",
  fields = {
    -- this plugin will only be applied to Services or Routes
    { consumer = typedefs.no_consumer },
    -- this plugin will only run within Nginx HTTP module
    { protocols = typedefs.protocols_http },
    {
      config = {
        type = "record",
        fields = {
          -- Describe your plugin's configuration's schema here.   
          -- a standard defined field (typedef), with some customizations
          { request_header = typedefs.header_name {
              required = true,
              default = "Request-Easter-Egg-Header" } },
          { response_header = typedefs.header_name {
              required = true,
              default = "Response-Easter-Egg-Header" } },
          { write_to_db = {
              type = "boolean",
              default = false } },
        },
      },
    },
  },
}