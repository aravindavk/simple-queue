module simple_queue.models.jobs;

import std.json;
import std.typecons;

import simple_queue.models.helpers;

struct Job
{
    long id;
    long parentId;
    string payload;
    string state = "accepted";
    int priority;
    long durationMs;
    int workerId = -1;

    void enqueue()
    {
        beginTx;
        scope(success) endTxWithSuccess;
        scope(failure) endTxWithFailure;

        string query = q"[
            INSERT INTO simpleQueueJobs(parentId, payload, priority, state)
            VALUES ($1, $2, $3, $4) RETURNING *
        ]";

        auto rs = execute(query, parentId, payload, priority, state);
        enforceDB(rs.length > 0, "Failed to add the job");

        id = rs[0]["id"].as!PGbigint;

        query = q"[INSERT INTO simpleQueueReadyJobs(jobId) VALUES($1) RETURNING *]";
        auto rs2 = execute(query, id);
        enforceDB(rs2.length > 0, "Failed to add the job");
    }

    void recordComplete()
    {
        beginTx;
        scope(success) endTxWithSuccess;
        scope(failure) endTxWithFailure;

        string query = q"[
            UPDATE simpleQueueJobs
            SET state = 'complete',
                durationMs = $1,
                finishedAt = current_timestamp,
                updatedAt = current_timestamp
            WHERE id = $2
        ]";
        execute(query, durationMs, id);

        query = "DELETE FROM simpleQueueClaimedJobs WHERE jobId = $1";
        execute(query, id);
    }

    static void beginTx(QuerySettings settings = QuerySettings.init)
    {
        execute(settings, "START TRANSACTION");
    }
    
    static void endTxWithSuccess(QuerySettings settings = QuerySettings.init)
    {
        execute(settings, "COMMIT");
    }

    static void endTxWithFailure(QuerySettings settings = QuerySettings.init)
    {
        execute(settings, "ROLLBACK");
    }

    void recordFailure(string error)
    {
        beginTx;
        scope(success) endTxWithSuccess;
        scope(failure) endTxWithFailure;

        string query = q"[
            UPDATE simpleQueueJobs
            SET state = 'failed',
                durationMs = $1,
                finishedAt = current_timestamp,
                updatedAt = current_timestamp
            WHERE id = $2
        ]";
        execute(query, durationMs, id);

        query = "DELETE FROM simpleQueueClaimedJobs WHERE jobId = $1";
        execute(query, id);

        query = "INSERT INTO simpleQueueFailedJobs(jobId, workerId, error) VALUES($1, $2, $3) RETURNING jobId";
        auto rs = execute(query, id, workerId, error);
        enforceDB(rs.length > 0, "Failed to record error");
    }

    static Nullable!Job getNew(int workerId)
    {
        QuerySettings settings;
        settings.printDebugQuery = false;

        beginTx(settings);
        scope(success) endTxWithSuccess(settings);
        scope(failure) endTxWithFailure(settings);
        
        // Get the Job ID from readyJobs table (Using FOR UPDATE SKIP LOCKED)
        string query = "SELECT * FROM simpleQueueReadyJobs LIMIT 1 FOR UPDATE SKIP LOCKED";
        auto rs = execute(settings, query);
        if (rs.length == 0) return (Nullable!Job).init;

        query = "SELECT * FROM simpleQueueJobs WHERE id = $1";
        auto rs1 = execute(query, rs[0]["jobId"].as!PGbigint);
        auto job = rs1[0].deserializeTo!Job;

        // Update State and Claimed time (Worker Start Time)
        job.state = "started";
        job.workerId = workerId;
        query = "UPDATE simpleQueueJobs SET state = 'started', workerId = $1, claimedAt = current_timestamp WHERE id = $2";
        execute(settings, query, workerId, job.id);

        // Insert the Job ID to claimedJobs table
        query = "INSERT INTO simpleQueueClaimedJobs(jobId, workerId) VALUES($1, $2)";
        auto rs2 = execute(settings, query, job.id, workerId);

        // Remove Job ID from readyJobs table
        query = "DELETE FROM simpleQueueReadyJobs WHERE jobId = $1";
        auto rs3 = execute(settings, query, job.id);

        return job.nullable;
    }
}
