module simple_queue.models.helpers;

import std.process;

public
{
    import dpq2;
    import dpq2_serialization;
    import vibe.data.json;
}

class ModelException : Exception
{
    this(string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

void enforceDB(bool cond, string message)
{
    if (!cond)
        throw new ModelException(message);
}

Connection conn;

static this()
{
    import std.string;

    auto dbUrl = environment.get("DATABASE_URL", "");
    if (!dbUrl.empty)
        conn = new Connection(dbUrl);
}

string formatArgs(Targs...)(Targs args)
{
    import std.conv;
    import std.string;

    string[] data;
    string field = "";
    static foreach(idx, arg; args)
    {
        if (is(Targs[idx] == string))
            field = "\"" ~ arg.to!string ~ "\"";
        else
            field = arg.to!string;

        data ~= "$" ~ (idx+1).to!string ~ "=" ~ field;
    }
    return data.join(", ");
}

struct QuerySettings
{
    bool printDebugQuery = true;
}

Answer execute(Targs...)(QuerySettings settings, string query, Targs args)
{
    import std.datetime : Clock, UTC;

    auto startTime = Clock.currTime(UTC());
    QueryParams qps;
    qps.sqlCommand = query;
    qps.argsVariadic(args);
    auto rs = conn.execParams(qps);

    debug
    {
        if (settings.printDebugQuery)
        {
            import std.stdio;
            import std.string;

            auto duration = (Clock.currTime(UTC()) - startTime);
            writefln("SQL (%s) %s [%s]", duration.toString, query.strip, formatArgs(args));
        }
    }

    return rs;
}

Answer execute(Targs...)(string query, Targs args)
{
    return execute(QuerySettings.init, query, args);
}
