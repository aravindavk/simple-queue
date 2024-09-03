module simple_queue;

interface SimpleQueue
{
    void perform();
}

void performLater(T)(T jobdata)
{
    import vibe.data.json;

    import simple_queue.models;

    Job job;
    job.payload = jobdata.serializeToJson;
    job.payload["_name"] = __traits(fullyQualifiedName, T);

    job.enqueue;
}

const MIGRATIONS = [
    q"[CREATE TABLE simpleQueueJobs(
           id                 BIGSERIAL PRIMARY KEY,
           payload            JSON,
           priority           INTEGER,
           threadId           INTEGER,
           state              VARCHAR,
           error              TEXT,
           durationMs         BIGINT,
           createdAt          TIMESTAMP DEFAULT current_timestamp,
           updatedAt          TIMESTAMP DEFAULT current_timestamp
       )
      ]"
];

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

    import vibe.data.json;

    import simple_queue.models;

    void perform(Json jobData)
    {
        SimpleQueue payload;

    sw: switch(jobData["_name"].to!string)
        {
            static foreach(T; QueueTypes)
            {
                mixin("
                case \"" ~ __traits(fullyQualifiedName, T) ~ "\":
                    payload = deserializeJson!(" ~ __traits(fullyQualifiedName, T) ~")(jobData);
                    break sw;
            ");
            }
        default:
            throw new Exception("Unsupported Job " ~ jobData["_name"].to!string);
        }

        payload.perform;
    }

    void worker(int workerId)
    {
        while (true)
        {
            auto job = cast(Job) receiveOnly!(immutable(Job));
            // Update the started state
            job.state = "started";
            job.threadId = workerId;
            job.update;

            auto startTime = Clock.currTime(UTC());

            try
            {
                job.payload.perform;
                job.state = "completed";
            }
            catch (Exception ex)
            {
                job.error = ex.to!string;
                job.state = "failed";
            }

            job.durationMs = (Clock.currTime(UTC()) - startTime).total!"msecs";

            job.update;
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

        private Tid nextWorker()
        {
            auto worker = workers[currentWorker];
            currentWorker++;
            if (currentWorker >= workers.length)
                currentWorker = 0;

            return worker;
        }

        private void handleMigrations()
        {
            DbVersion.initialize; 
            auto currentVersion = DbVersion.get;

            foreach(idx; 0 .. MIGRATIONS.length.to!int)
            {
                // Already applied version
                if (idx + 1 <= currentVersion)
                    continue;

                execute(MIGRATIONS[idx]);
                DbVersion.set(idx+1);
            }
        }

        void start()
        {
            handleMigrations();

            for (int i = 0; i < settings.workersCount; i++)
                workers ~= spawnLinked(&worker, i+1);

            Job[] jobs;
            while (true)
            {
                jobs = Job.listNew;
                if (jobs.length > 0)
                    infof("Received %d job(s)", jobs.length);

                foreach (job; jobs)
                {
                    auto nw = nextWorker;
                    infof("Job %d assigned to Worker %d", job.id, currentWorker);
                    job.state = "assigned";
                    job.threadId = currentWorker;
                    job.update;

                    nw.send(cast(immutable) job);
                }

                Thread.sleep(settings.interval.seconds);
            }
        }
    }
}
