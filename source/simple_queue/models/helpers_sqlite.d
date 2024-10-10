module simple_queue.models.helpers_sqlite;

version (SQLite):

import std.process;

public
{
    import sqlite_utils;
    import json_serialization;

    import simple_queue.models.helpers;
}

import std.json;
import std.traits;

SQLiteDriver _db;

static this()
{
    import std.range;

    auto dbUrl = environment.get("DATABASE_URL", "");
    if (!dbUrl.empty)
    {
        _db = SQLiteDriver(dbUrl);
        _db.setWebappPragmaSettings;
    }
}
