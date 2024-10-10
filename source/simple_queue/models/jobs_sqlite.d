module simple_queue.models.jobs_sqlite;

version (SQLite):
import std.json;
import simple_queue.models.helpers_sqlite;

struct Job
{
    long id;
    JSONValue payload;
    string state = "accepted";
    string error;
    int priority;
    long durationMs;
    int threadId;

    void enqueue()
    {
        string query = q"[
            INSERT INTO simpleQueueJobs(payload, priority, threadId, state, error)
            VALUES (:payload, :priority, :threadId, :state, :error) RETURNING *
        ]";

        auto rs = _db.execute(query, payload, priority, threadId, state, error);
        enforceDB(!rs.empty, "Failed to add the job");

        id = rs.front["id"].as!long;
    }

    void update()
    {
        string query = q"[
            UPDATE simpleQueueJobs
            SET state = :state,
                error = :error,
                durationMs = :durationMs,
                threadId = :threadId,
                updatedAt = current_timestamp
            WHERE id = :id
            ]";
        _db.execute(query, state, error, durationMs, threadId, id);
    }

    static Job[] listNew()
    {
        string query = q"[
                SELECT * FROM simpleQueueJobs WHERE state = :state
            ]";
        QuerySettings settings;
        settings.printDebugQuery = false;
        auto rs = _db.execute(settings, query, "accepted");

        Job[] jobs;
        foreach (row; rs)
            jobs ~= row.deserializeTo!Job;

        return jobs;
    }
}
