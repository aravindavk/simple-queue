module simple_queue;

import std.process;

import simple_queue.models;

interface SimpleQueue
{
    void perform();
}

long performLater(T)(T jobdata)
{
    import json_serialization;

    Job job;
    auto payload = jobdata.serializeToJSONValue;
    payload["_name"] = __traits(fullyQualifiedName, T);
    job.payload = payload.toString;

    job.enqueue;

    return job.id;
}

template registerQueues(QueueTypes...)
{
    import std.stdio;
    import std.logger;
    import std.meta;
    import core.time : msecs, seconds;
    import std.datetime : Clock, UTC;
    import std.conv;
    import std.concurrency;
    import core.thread : Thread;
    import std.json;
    import std.file : thisExePath;
    import std.format : format;

    import json_serialization;

    import simple_queue.models;

    void perform(JSONValue jobData)
    {
        SimpleQueue payload;

    sw: switch(jobData["_name"].str)
        {
            static foreach(T; QueueTypes)
            {
                mixin("
                case \"" ~ __traits(fullyQualifiedName, T) ~ "\":
                    payload = deserializeJSONValue!(" ~ __traits(fullyQualifiedName, T) ~")(jobData);
                    break sw;
            ");
            }
        default:
            throw new Exception("Unsupported Job " ~ jobData["_name"].str);
        }

        payload.perform;
    }

    void startWorker(SimpleQueuePoolSettings settings, int workerId)
    {
        infof("Started [id: %d]", workerId);

        while (true)
        {
            auto job_ = Job.getNew(workerId);
            if (job_.isNull)
            {
                Thread.sleep(1.seconds);
                continue;
            }

            auto job = job_.get;

            auto startTime = Clock.currTime(UTC());
            auto payload = parseJSON(job.payload);
            tracef("Found a Job [id: %d, job: %s]", workerId, payload["_name"]);

            try
            {
                payload.perform;
                job.durationMs = (Clock.currTime(UTC()) - startTime).total!"msecs";
                job.recordComplete(preserveFinished: settings.preserveFinishedJobs);
            }
            catch (Exception ex)
            {
                string error = ex.to!string;
                job.durationMs = (Clock.currTime(UTC()) - startTime).total!"msecs";
                job.recordFailure(error);
            }
        }
    }

    struct SimpleQueuePoolSettings
    {
        int workersCount = 3;
        bool preserveFinishedJobs = true;
    }

    class SimpleQueuePool
    {
        Pid[] workers;
        int currentWorker = 0;
        SimpleQueuePoolSettings settings;

        this(SimpleQueuePoolSettings settings = SimpleQueuePoolSettings.init)
        {
            if (settings.workersCount <= 0)
                settings.workersCount = 1;

            this.settings = settings;
        }

        void start()
        {
            if (environment.get("SIMPLE_QUEUE_WORKER", "0") == "1")
            {
                startWorker(
                    settings, environment.get("SIMPLE_QUEUE_WORKER_ID").to!int);
                return;
            }

            handleMigrations();

            // Self executable path
            string exe = thisExePath();

            foreach (i; 0 .. settings.workersCount)
            {
                auto pid = spawnProcess(
                    [exe, "/", "worker", format("[id: %d]", i)],
                    stdin, stdout, stderr,
                    ["SIMPLE_QUEUE_WORKER" : "1",
                     "SIMPLE_QUEUE_WORKER_ID": i.to!string]
                    );
                workers ~= pid;
            }

            // Wait for any child, restart it if it dies unexpectedly
            while (true)
            {
                foreach (idx, pid; workers)
                {
                    auto res = tryWait(pid);
                    if (res.terminated)
                    {
                        infof("Worker exited, restarting.. [id: %s, status: %s]",
                              idx, res.status);

                        workers[idx] = spawnProcess(
                            [exe, "/", "worker", format("[id: %d]", idx)],
                            stdin, stdout, stderr,
                            ["SIMPLE_QUEUE_WORKER" : "1",
                             "SIMPLE_QUEUE_WORKER_ID": idx.to!string]
                            );
                    }
                }

                Thread.sleep(500.msecs);
            }
        }
    }
}
