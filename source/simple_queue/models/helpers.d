module simple_queue.models.helpers;

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
