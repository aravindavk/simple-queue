module simple_queue.models.db_versions;

import simple_queue.models.helpers;

struct DbVersion
{
    int id;

    static void initialize()
    {
        string query = q"[
            CREATE TABLE IF NOT EXISTS simpleQueue_schema_migration (
                id            INTEGER NOT NULL,
                createdAt     TIMESTAMP DEFAULT current_timestamp
            )
        ]";
        execute(query);
    }

    void create()
    {
        auto query = "INSERT INTO simpleQueue_schema_migration(id) VALUES($1)";
        execute(query, id);
    }

    static int get()
    {
        auto query = "SELECT * FROM simpleQueue_schema_migration";
        auto rs = execute(query);
        if (rs.length > 0)
            return rs[0]["id"].as!PGinteger;

        return 0;
    }

    void update()
    {
        auto query = "UPDATE simpleQueue_schema_migration SET id = $1, createdAt = current_timestamp";
        execute(query, id);
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
