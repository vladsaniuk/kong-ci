-- daos.lua defines how are the different fields of the entity named and what are their types
-- Compared to plugin configuration schemas, custom entity schemas require additional metadata

local typedefs = require "kong.db.schema.typedefs"

return {
  {
    name                  = "easter_egg_table", -- the actual table in the database
    endpoint_key          = "token",
    primary_key           = { "user" },
    cache_key             = { "token" },
    generate_admin_api    = true,
    fields = {
        -- a value to be inserted by the DAO itself
        -- (think of serial id and the uniqueness of such required here)
      { id = typedefs.uuid, },
      -- also inserted by the DAO itself
      { created_at = typedefs.auto_timestamp_s, },
      { user = {
          type      = "string",
          required  = true,
          unique    = true,
        }, },
      { token = {
          type      = "string",
          required  = false,
          unique    = true,
        },
      },
    },
  },
}