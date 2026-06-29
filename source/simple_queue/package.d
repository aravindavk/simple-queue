module simple_queue;

import std.process;

import simple_queue.models;

interface SimpleQueue
{
    void perform();
}

void performLater(T)(T jobdata)
{
    import json_serialization;

    Job job;
    auto payload = jobdata.serializeToJSONValue;
    payload["_name"] = __traits(fullyQualifiedName, T);
    job.payload = payload.toString;

    job.enqueue;
}

template registerQueues(QueueTypes...)
{
    import std.stdio;
    import std.logger;
    import std.meta;
    import core.time;
    import std.datetime : Clock, UTC;
    import std.conv;
    import std.concurrency;
    import core.thread : Thread;
    import std.json;

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

    void worker(int workerId)
    {
        infof("Started worker %d", workerId);

        while (true)
        {
            auto job_ = Job.getNew(workerId);
            if (job_.isNull)
            {
                Thread.sleep(dur!("seconds")(5));
                continue;
            }

            auto job = job_.get;

            auto startTime = Clock.currTime(UTC());
            auto payload = parseJSON(job.payload);
            tracef("Worker %d found a Job(%s)", workerId, payload["_name"]);

            try
            {
                payload.perform;
                job.durationMs = (Clock.currTime(UTC()) - startTime).total!"msecs";
                job.recordComplete;
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
        int interval = 1;
    }

    class SimpleQueuePool
    {
        Tid[] workers;
        int currentWorker = 0;
        SimpleQueuePoolSettings settings;

        this(SimpleQueuePoolSettings settings = SimpleQueuePoolSettings.init)
        {
            if (settings.interval <= 0)
                settings.interval = 1;

            if (settings.workersCount <= 0)
                settings.workersCount = 1;

            this.settings = settings;
        }

        void start()
        {
            handleMigrations();

            for (int i = 0; i < settings.workersCount; i++)
                workers ~= spawnLinked(&worker, i+1);

            infof("Started %d worker(s)", settings.workersCount);
            while (true)
            {
                // TODO: Monitor the workers
                Thread.sleep(settings.interval.seconds);
            }
        }
    }
}
