return {
  postgres = {
    up = [[
      CREATE TABLE IF NOT EXISTS "easter_egg_table" (
        "id"           UUID                         PRIMARY KEY,
        "created_at"   TIMESTAMP WITHOUT TIME ZONE,
        "user"         TEXT,
        "token"        TEXT
      );

      DO $$
      BEGIN
        CREATE INDEX IF NOT EXISTS "easter_egg_table_user"
                                ON "easter_egg_table" ("user");
      EXCEPTION WHEN UNDEFINED_COLUMN THEN
        -- Do nothing, accept existing state
      END$$;
    ]],
  }
}