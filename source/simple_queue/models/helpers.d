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

