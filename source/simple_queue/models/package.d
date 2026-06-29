module simple_queue.models;

public
{
    import simple_queue.models.helpers;
    import simple_queue.models.jobs;
    import simple_queue.models.db_versions;
}

const MIGRATIONS = [
    q"[CREATE TABLE simpleQueueJobs(
           id                 BIGSERIAL PRIMARY KEY,
           parentId           BIGINT DEFAULT 0,
           payload            TEXT,
           priority           INTEGER DEFAULT 0,
           workerId           INTEGER,
           state              VARCHAR DEFAULT 'accepted',
           durationMs         BIGINT,
           createdAt          TIMESTAMP DEFAULT current_timestamp,
           claimedAt          TIMESTAMP,
           finishedAt         TIMESTAMP,
           updatedAt          TIMESTAMP DEFAULT current_timestamp
           )]",
    q"[CREATE TABLE simpleQueueReadyJobs(
          jobId       BIGINT REFERENCES simpleQueueJobs(id)
    )]",
    q"[CREATE TABLE simpleQueueClaimedJobs(
          jobId       BIGINT REFERENCES simpleQueueJobs(id),
          workerId    INTEGER
    )]",
    q"[CREATE TABLE simpleQueueFailedJobs(
          jobId       BIGINT REFERENCES simpleQueueJobs(id),
          workerId    INTEGER,
          error       TEXT,
          createdAt   TIMESTAMP DEFAULT current_timestamp
    )]"
    ];

void handleMigrations()
{
    import std.conv;

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
