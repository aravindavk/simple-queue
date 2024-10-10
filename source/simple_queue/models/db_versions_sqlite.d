module simple_queue.models.db_versions_sqlite;

version (SQLite):

import simple_queue.models.helpers_sqlite;

struct DbVersion
{
    int id;

    static void initialize()
    {
        string query = q"[
            CREATE TABLE IF NOT EXISTS simpleQueue_schema_migration (
                id            INTEGER NOT NULL,
                createdAt     DATETIME DEFAULT current_timestamp
            )
        ]";
        _db.execute(query);
    }

    void create()
    {
        auto query = "INSERT INTO simpleQueue_schema_migration(id) VALUES(:id)";
        _db.execute(query, id);
    }

    static int get()
    {
        auto query = "SELECT * FROM simpleQueue_schema_migration";
        auto rs = _db.execute(query);
        if (!rs.empty)
            return rs.front["id"].as!int;

        return 0;
    }

    void update()
    {
        auto query = "UPDATE simpleQueue_schema_migration SET id = :id, createdAt = current_timestamp";
        _db.execute(query, id);
    }

    static void set(int versionId)
    {
        auto currentVersion = DbVersion.get;
        auto ver = DbVersion(versionId);
        if (currentVersion == 0)
        {
            ver.create;
            return;
        }

        if (currentVersion == versionId)
            return;

        ver.update;
    }
}
