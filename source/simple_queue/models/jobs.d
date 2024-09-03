module simple_queue.models.jobs;

import simple_queue.models.helpers;

struct Job
{
    long id;
    Json payload;
    string state = "accepted";
    string error;
    int priority;
    long durationMs;
    int threadId;

    void enqueue()
    {
        string query = q"[
            INSERT INTO simpleQueueJobs(payload, priority, threadId, state, error)
            VALUES ($1, $2, $3, $4, $5) RETURNING *
        ]";

        auto rs = execute(query, payload, priority, threadId, state, error);
        enforceDB(rs.length > 0, "Failed to add the job");

        id = rs[0]["id"].as!PGbigint;
    }

    void update()
    {
        string query = q"[
            UPDATE simpleQueueJobs
            SET state = $1,
                error = $2,
                durationMs = $3,
                threadId = $4,
                updatedAt = current_timestamp
            WHERE id = $5
        ]";
        execute(query, state, error, durationMs, threadId, id);
    }

    static Job[] listNew()
    {
        string query = q"[
            SELECT * FROM simpleQueueJobs WHERE state = $1
        ]";
        QuerySettings settings;
        settings.printDebugQuery = false;
        auto rs = execute(settings, query, "accepted");

        Job[] jobs;
        foreach (idx; 0 .. rs.length)
            jobs ~= rs[idx].deserializeTo!Job;

        return jobs;
    }
}
