from os import getenv
from dotenv import load_dotenv
from mssql_python import connect

load_dotenv()

CONNECTION_STRING = getenv("SQL_CONNECTION_STRING")


def get_connection():
    return connect(CONNECTION_STRING)


def fetch_all(query: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        return cursor.fetchall()


def fetch_one(query: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        return cursor.fetchone()


def execute_non_query(query: str):
    with get_connection() as conn:
        cursor = conn.cursor()
        cursor.execute(query)
        conn.commit()


def sql_escape(value):
    if value is None:
        return ""
    return str(value).replace("'", "''")


def get_profiles():
    rows = fetch_all("""
        SELECT
            ProfileID,
            ProfileName,
            Description,
            BackendName,
            Arguments,
            CheckSet,
            Priority,
            IsActive
        FROM dbo.profiles0905
        ORDER BY Priority ASC, ProfileName ASC
    """)

    profiles = []
    for row in rows:
        profiles.append({
            "db_id": row[0],
            "id": row[1],
            "name": row[1],
            "description": row[2] or "",
            "backend": row[3] or "",
            "args": row[4] or "",
            "check_set": row[5] or "",
            "priority": row[6] or 0,
            "is_active": bool(row[7]),
        })

    return profiles


def get_active_profile():
    row = fetch_one("""
        SELECT TOP 1
            ProfileID,
            ProfileName,
            Description,
            BackendName,
            Arguments,
            CheckSet,
            Priority,
            IsActive
        FROM dbo.profiles0905
        WHERE IsActive = 1
        ORDER BY ProfileID ASC
    """)

    if not row:
        return None

    return {
        "db_id": row[0],
        "id": row[1],
        "name": row[1],
        "description": row[2] or "",
        "backend": row[3] or "",
        "args": row[4] or "",
        "check_set": row[5] or "",
        "priority": row[6] or 0,
        "is_active": bool(row[7]),
    }


def set_active_profile(profile_name: str):
    profile_name = sql_escape(profile_name)

    execute_non_query("""
        UPDATE dbo.profiles0905
        SET IsActive = 0
    """)

    execute_non_query(f"""
        UPDATE dbo.profiles0905
        SET IsActive = 1
        WHERE ProfileName = '{profile_name}'
    """)


def get_backend_runtime():
    row = fetch_one("""
        SELECT TOP 1
            bs.StateID,
            bs.BackendName,
            bs.Status,
            bs.AppliedProfileID,
            bs.AppliedAt,
            bs.UpdatedAt,
            p.ProfileName
        FROM dbo.backend_state0905 bs
        LEFT JOIN dbo.profiles0905 p
            ON bs.AppliedProfileID = p.ProfileID
        ORDER BY bs.StateID DESC
    """)

    if not row:
        return {
            "backend_name": "gateway-runtime",
            "status": "not_applied",
            "applied_profile_name": "",
            "applied_profile_id": None,
            "applied_at": "",
            "updated_at": "",
        }

    return {
        "backend_name": row[1] or "gateway-runtime",
        "status": row[2] or "not_applied",
        "applied_profile_id": row[3],
        "applied_at": str(row[4]) if row[4] else "",
        "updated_at": str(row[5]) if row[5] else "",
        "applied_profile_name": row[6] or "",
    }


def upsert_backend_state(backend_name: str, status: str, applied_profile_name: str | None):
    backend_name = sql_escape(backend_name)
    status = sql_escape(status)
    applied_profile_name = sql_escape(applied_profile_name or "")

    profile_id = "NULL"
    if applied_profile_name:
        row = fetch_one(f"""
            SELECT TOP 1 ProfileID
            FROM dbo.profiles0905
            WHERE ProfileName = '{applied_profile_name}'
        """)
        if row:
            profile_id = str(row[0])

    existing = fetch_one("""
        SELECT TOP 1 StateID
        FROM dbo.backend_state0905
        ORDER BY StateID DESC
    """)

    if existing:
        execute_non_query(f"""
            UPDATE dbo.backend_state0905
            SET
                BackendName = '{backend_name}',
                Status = '{status}',
                AppliedProfileID = {profile_id},
                AppliedAt = CASE
                    WHEN '{status}' = 'applied' THEN SYSDATETIME()
                    ELSE AppliedAt
                END,
                UpdatedAt = SYSDATETIME()
            WHERE StateID = {existing[0]}
        """)
    else:
        execute_non_query(f"""
            INSERT INTO dbo.backend_state0905
                (BackendName, Status, AppliedProfileID, AppliedAt, UpdatedAt)
            VALUES
                (
                    '{backend_name}',
                    '{status}',
                    {profile_id},
                    CASE WHEN '{status}' = 'applied' THEN SYSDATETIME() ELSE NULL END,
                    SYSDATETIME()
                )
        """)


def get_logs(limit: int = 50):
    rows = fetch_all(f"""
        SELECT TOP {int(limit)}
            CreatedAt,
            LogLevel,
            Message
        FROM dbo.system_logs0905
        ORDER BY CreatedAt DESC, LogID DESC
    """)

    logs = []
    for row in rows:
        created_at = str(row[0]) if row[0] else ""
        level = row[1] or "INFO"
        message = row[2] or ""
        logs.append(f"[{created_at}] [{level}] {message}")

    return logs


def insert_log(level: str, message: str, user_id=None):
    level = sql_escape(level)
    message = sql_escape(message)

    user_sql = "NULL" if user_id is None else str(int(user_id))

    execute_non_query(f"""
        INSERT INTO dbo.system_logs0905
            (CreatedAt, LogLevel, Message, UserID)
        VALUES
            (SYSDATETIME(), '{level}', '{message}', {user_sql})
    """)


def get_last_check():
    row = fetch_one("""
        SELECT TOP 1
            RunID,
            StartedAt,
            FinishedAt,
            Status,
            Details
        FROM dbo.check_runs0905
        ORDER BY RunID DESC
    """)

    if not row:
        return {
            "status": "not_run",
            "time": "—",
            "details": "—",
            "results": ""
        }

    run_id = row[0]

    result_rows = fetch_all(f"""
        SELECT
            TargetName,
            HttpResult,
            Tls12Result,
            Tls13Result,
            PingResult,
            FinalStatus
        FROM dbo.check_results0905
        WHERE RunID = {run_id}
        ORDER BY ResultID ASC
    """)

    result_lines = []
    for item in result_rows:
        result_lines.append(
            f"{item[0]} | HTTP:{item[1] or '—'} | TLS1.2:{item[2] or '—'} | TLS1.3:{item[3] or '—'} | PING:{item[4] or '—'} | STATUS:{item[5] or '—'}"
        )

    check_time = row[2] or row[1]

    return {
        "status": row[3] or "not_run",
        "time": str(check_time) if check_time else "—",
        "details": row[4] or "—",
        "results": "\n".join(result_lines)
    }


def get_user_by_login(login: str):
    login = sql_escape(login)

    row = fetch_one(f"""
        SELECT TOP 1
            u.UserID,
            u.Login,
            u.PasswordHash,
            r.RoleID,
            r.RoleName
        FROM dbo.users0905 u
        INNER JOIN dbo.roles0905 r
            ON u.RoleID = r.RoleID
        WHERE u.Login = '{login}'
    """)

    if not row:
        return None

    return {
        "user_id": row[0],
        "login": row[1],
        "password_hash": row[2],
        "role_id": row[3],
        "role_name": row[4],
    }