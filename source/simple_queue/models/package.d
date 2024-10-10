module simple_queue.models;

public
{
    import simple_queue.models.helpers_postgres;
    import simple_queue.models.jobs_postgres;
    import simple_queue.models.db_versions_postgres;
    import simple_queue.models.helpers_sqlite;
    import simple_queue.models.jobs_sqlite;
    import simple_queue.models.db_versions_sqlite;
}

version(Postgres)
{
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
           )]"
        ];
}

version(SQLite)
{
    const MIGRATIONS = [
        q"[CREATE TABLE simpleQueueJobs(
           id                 INTEGER PRIMARY KEY,
           payload            JSON,
           priority           INTEGER,
           threadId           INTEGER,
           state              VARCHAR,
           error              TEXT,
           durationMs         BIGINT,
           createdAt          TIMESTAMP DEFAULT current_timestamp,
           updatedAt          TIMESTAMP DEFAULT current_timestamp
        )]"
        ];
}

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

        _db.execute(MIGRATIONS[idx]);
        DbVersion.set(idx+1);
    }
}
