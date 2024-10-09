module simple_queue.models.helpers_sqlite;

version (SQLite):

import std.process;

public
{
    import d2sqlite3;
    import json_serialization;

    import simple_queue.models.helpers;
}

import std.json;
import std.traits;

Database _db;

static this()
{
    import std.string;

    auto dbUrl = environment.get("DATABASE_URL", "").replace("sqlite:///", "");
    if (!dbUrl.empty)
    {
        _db = Database(dbUrl);
        execute("PRAGMA journal_mode = WAL");
        execute("PRAGMA synchronous = NORMAL");
        execute("PRAGMA journal_size_limit = 67108864"); // 64MiB
        execute("PRAGMA mmap_size = 134217728"); // 128MiB
        execute("PRAGMA cache_size = 2000");
        execute("PRAGMA busy_timeout = 5000"); // 5s
    }
}

/// UDA
struct sqliteColumn
{
    string name;
}

string columnName(T, string member)()
{
    static if (getUDAs!(__traits(getMember, T, member), sqliteColumn).length > 0)
        return getUDAs!(__traits(getMember, T, member), sqliteColumn)[0].name;

    return member;
}

T deserializeTo(T)(Row data)
{
    static if (is(T == struct))
        T result;
    else
        T result = new T;

    alias fieldTypes = FieldTypeTuple!(T);
    alias fieldNames = FieldNameTuple!(T);

    static foreach(idx, fieldName; fieldNames)
    {
        {
            // Field name same as memberName unless @JSONFieldName
            // attribute added to the member.
            enum name = columnName!(T, fieldName);

            // Add to Struct if exists in the input JSONValue
            static if (fieldTypes[idx].stringof == "JSONValue")
                mixin("result." ~ fieldName ~ " = parseJSON(data[\"" ~ name ~ "\"].as!string);");
            else
                mixin("result." ~ fieldName ~ " = data[\"" ~ name ~ "\"].as!" ~ fieldTypes[idx].stringof ~ ";");
        }
    }

    return result;
}

ResultRange execute(Targs...)(QuerySettings settings, string query, Targs args)
{
    import std.datetime : Clock, UTC;

    auto startTime = Clock.currTime(UTC());

    scope(exit)
    {
        debug
        {
            if (settings.printDebugQuery)
            {
                import std.string;
                import std.logger;

                auto duration = (Clock.currTime(UTC()) - startTime);
                tracef("SQL (%s) %s [%s]", duration.toString, query.strip, formatArgs(args));
            }
        }
    }

    Statement statement = _db.prepare(query);
    statement.bindAll(args);
    return statement.execute;
}

ResultRange execute(Targs...)(string query, Targs args)
{
    return execute(QuerySettings.init, query, args);
}
