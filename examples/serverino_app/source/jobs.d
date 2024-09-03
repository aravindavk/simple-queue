module jobs;

import std.process;

import simple_queue;

class ReportGenerateJob : SimpleQueue
{
    string path;

    void perform()
    {
        if (path != "")
        {
            auto cmd = executeShell("free -h > " ~ path);
            if (cmd.status != 0)
                throw new Exception("Failed to run the free command");
        }
    }
}

mixin registerQueues!(ReportGenerateJob);
