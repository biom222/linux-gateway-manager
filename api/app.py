from pathlib import Path
import re
import subprocess
from functools import wraps
from os import getenv

from flask import Flask, jsonify, request, send_from_directory, session, redirect
from dotenv import load_dotenv

from db import (
    get_profiles,
    get_active_profile,
    set_active_profile,
    get_backend_runtime,
    upsert_backend_state,
    get_logs,
    insert_log,
    get_last_check,
    get_connection,
    sql_escape,
    get_user_by_login,
)

load_dotenv()

BASE_DIR = Path(__file__).resolve().parent.parent
WEB_DIR = BASE_DIR / "web"
STATE_DIR = BASE_DIR / "state"
SCRIPTS_DIR = BASE_DIR / "scripts"

ACTIONS_SCRIPT = SCRIPTS_DIR / "api_actions.sh"

app = Flask(__name__)
app.secret_key = getenv("SESSION_SECRET", "lgm-dev-secret-0905")


def read_text_file(path: Path, default: str = "") -> str:
    if not path.exists():
        return default
    return path.read_text(encoding="utf-8").strip()


def sql_value(value):
    if value is None or value == "":
        return "NULL"
    return f"N'{sql_escape(value)}'"


def current_user():
    return session.get("user")


def is_admin():
    user = current_user()
    return bool(user and user.get("role_name") == "Администратор")


def login_required_json(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not current_user():
            return jsonify({"ok": False, "message": "Требуется авторизация"}), 401
        return fn(*args, **kwargs)

    return wrapper


def admin_required_json(fn):
    @wraps(fn)
    def wrapper(*args, **kwargs):
        if not current_user():
            return jsonify({"ok": False, "message": "Требуется авторизация"}), 401
        if not is_admin():
            return jsonify({"ok": False, "message": "Недостаточно прав"}), 403
        return fn(*args, **kwargs)

    return wrapper


def run_action(*args: str) -> tuple[bool, str]:
    try:
        result = subprocess.run(
            ["bash", str(ACTIONS_SCRIPT), *args],
            cwd=str(BASE_DIR),
            capture_output=True,
            text=True,
            timeout=120,
        )
        ok = result.returncode == 0
        output = (result.stdout or result.stderr).strip()
        return ok, output
    except Exception as exc:
        return False, str(exc)


def get_last_action_text() -> str:
    logs = get_logs(1)
    if not logs:
        return "—"

    line = logs[0]
    match = re.match(r"^\[.*?\]\s+\[.*?\]\s+(.*)$", line)
    if match:
        return match.group(1)
    return line


def normalize_check_status(raw_status: str) -> str:
    value = (raw_status or "").strip().lower()

    if value in ("ok", "success", "passed", "done"):
        return "ok"

    if value in ("not_run", "not run", "none", "idle", ""):
        return "not_run"

    if value in ("failed", "fail", "error", "errors"):
        return "failed"

    if value in ("degraded", "warning", "warn", "partial"):
        return "degraded"

    if "failed" in value or "error" in value:
        return "failed"

    if "partial" in value or "warn" in value:
        return "degraded"

    if "ok" in value or "success" in value:
        return "ok"

    return raw_status or "not_run"


def parse_check_results_text(text: str):
    items = []

    if not text:
        return items

    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue

        parts = [part.strip() for part in line.split("|")]

        item = {
            "TargetName": parts[0] if parts else "unknown",
            "HttpResult": None,
            "Tls12Result": None,
            "Tls13Result": None,
            "PingResult": None,
            "FinalStatus": None,
        }

        for part in parts[1:]:
            if ":" not in part:
                continue

            key, value = part.split(":", 1)
            key = key.strip().upper()
            value = value.strip()

            if key == "HTTP":
                item["HttpResult"] = value
            elif key == "TLS1.2":
                item["Tls12Result"] = value
            elif key == "TLS1.3":
                item["Tls13Result"] = value
            elif key == "PING":
                item["PingResult"] = value
            elif key == "STATUS":
                item["FinalStatus"] = value

        if not item["FinalStatus"]:
            combined = " ".join(
                filter(
                    None,
                    [
                        item["HttpResult"],
                        item["Tls12Result"],
                        item["Tls13Result"],
                        item["PingResult"],
                    ],
                )
            ).upper()

            if "FAIL" in combined or "ERROR" in combined or "TIMEOUT" in combined:
                item["FinalStatus"] = "failed"
            elif "UNSUP" in combined:
                item["FinalStatus"] = "degraded"
            else:
                item["FinalStatus"] = "ok"

        items.append(item)

    return items


def sync_last_check_from_state():
    status_raw = read_text_file(STATE_DIR / "last_check_status.state", "not_run")
    details = read_text_file(STATE_DIR / "last_check_details.state", "—")
    results_text = read_text_file(STATE_DIR / "last_check_results.txt", "")

    status = normalize_check_status(status_raw)
    parsed_results = parse_check_results_text(results_text)

    user = current_user()
    started_by_user_id = user.get("user_id") if user else None

    with get_connection() as conn:
        cursor = conn.cursor()

        cursor.execute(
            f"""
            INSERT INTO dbo.check_runs0905
                (StartedAt, FinishedAt, Status, Details, StartedByUserID)
            VALUES
                (SYSDATETIME(), SYSDATETIME(), {sql_value(status)}, {sql_value(details)}, {started_by_user_id if started_by_user_id else 'NULL'})
            """
        )
        conn.commit()

        cursor.execute("SELECT TOP 1 RunID FROM dbo.check_runs0905 ORDER BY RunID DESC")
        run_row = cursor.fetchone()
        run_id = run_row[0]

        for item in parsed_results:
            cursor.execute(
                f"""
                INSERT INTO dbo.check_results0905
                    (RunID, TargetName, HttpResult, Tls12Result, Tls13Result, PingResult, FinalStatus)
                VALUES
                    (
                        {run_id},
                        {sql_value(item["TargetName"])},
                        {sql_value(item["HttpResult"])},
                        {sql_value(item["Tls12Result"])},
                        {sql_value(item["Tls13Result"])},
                        {sql_value(item["PingResult"])},
                        {sql_value(item["FinalStatus"])}
                    )
                """
            )

        conn.commit()

    return {
        "status": status,
        "details": details,
        "results_count": len(parsed_results),
    }


@app.route("/")
def index():
    if not current_user():
        return redirect("/login")
    return send_from_directory(WEB_DIR, "index.html")


@app.route("/login")
def login_page():
    if current_user():
        return redirect("/")
    return send_from_directory(WEB_DIR, "login.html")


@app.route("/logout", methods=["POST"])
def logout():
    session.clear()
    return jsonify({"ok": True})


@app.route("/api/login", methods=["POST"])
def api_login():
    data = request.get_json(silent=True) or {}

    login = (data.get("login") or "").strip()
    password = data.get("password") or ""

    if not login or not password:
        return jsonify({"ok": False, "message": "Введите логин и пароль"}), 400

    user = get_user_by_login(login)

    if not user or user.get("password_hash") != password:
        insert_log("WARNING", f"Неуспешная попытка входа: {login}", None)
        return jsonify({"ok": False, "message": "Неверный логин или пароль"}), 401

    session["user"] = {
        "user_id": user["user_id"],
        "login": user["login"],
        "role_id": user["role_id"],
        "role_name": user["role_name"],
    }

    insert_log("INFO", f"Пользователь вошёл в систему: {user['login']}", user["user_id"])

    return jsonify({
        "ok": True,
        "user": session["user"]
    })


@app.route("/api/me")
@login_required_json
def api_me():
    return jsonify({
        "ok": True,
        "user": current_user()
    })


@app.route("/<path:path>")
def static_files(path):
    return send_from_directory(WEB_DIR, path)


@app.route("/api/status")
@login_required_json
def api_status():
    return jsonify(
        {
            "active_profile": get_active_profile(),
            "backend_runtime": get_backend_runtime(),
            "last_check": get_last_check(),
            "last_action": get_last_action_text(),
        }
    )


@app.route("/api/profiles")
@login_required_json
def api_profiles():
    return jsonify({"profiles": get_profiles()})


@app.route("/api/logs")
@login_required_json
def api_logs():
    limit = request.args.get("limit", default=50, type=int)
    return jsonify({"logs": get_logs(limit)})


@app.route("/api/check-results")
@login_required_json
def api_check_results():
    return jsonify(get_last_check())


@app.route("/api/actions/select-profile", methods=["POST"])
@admin_required_json
def api_select_profile():
    data = request.get_json(silent=True) or {}
    profile_id = data.get("profile_id", "").strip()

    if not profile_id:
        return jsonify({"ok": False, "message": "Не указан profile_id"}), 400

    ok, output = run_action("select-profile", profile_id)

    if ok:
        set_active_profile(profile_id)
        insert_log("INFO", f"Выбран профиль: {profile_id}", current_user()["user_id"])
        return jsonify({"ok": True, "message": output or "OK"})

    insert_log("ERROR", f"Ошибка выбора профиля: {profile_id}. {output}", current_user()["user_id"])
    return jsonify({"ok": False, "message": output or "PROFILE_SELECT_FAILED"}), 400


@app.route("/api/actions/apply-profile", methods=["POST"])
@admin_required_json
def api_apply_profile():
    active_profile = get_active_profile()

    if not active_profile:
        return jsonify({"ok": False, "message": "Нет активного профиля"}), 400

    ok, output = run_action("apply-active")

    if ok:
        upsert_backend_state(
            active_profile.get("backend") or "gateway-runtime",
            "applied",
            active_profile.get("name"),
        )
        insert_log("INFO", f"Профиль применён через backend: {active_profile.get('name')}", current_user()["user_id"])
        return jsonify({"ok": True, "message": output or "OK"})

    insert_log("ERROR", f"Ошибка применения профиля: {active_profile.get('name')}. {output}", current_user()["user_id"])
    return jsonify({"ok": False, "message": output or "BACKEND_APPLY_FAILED"}), 400


@app.route("/api/actions/reset-backend", methods=["POST"])
@admin_required_json
def api_reset_backend():
    backend_runtime = get_backend_runtime()
    backend_name = backend_runtime.get("backend_name") or "gateway-runtime"

    ok, output = run_action("reset-backend")

    if ok:
        upsert_backend_state(backend_name, "reset", None)
        insert_log("WARNING", "Выполнен сброс backend", current_user()["user_id"])
        return jsonify({"ok": True, "message": output or "OK"})

    insert_log("ERROR", f"Ошибка сброса backend. {output}", current_user()["user_id"])
    return jsonify({"ok": False, "message": output or "BACKEND_RESET_FAILED"}), 400


@app.route("/api/actions/run-checks", methods=["POST"])
@admin_required_json
def api_run_checks():
    ok, output = run_action("run-checks")

    sync_info = sync_last_check_from_state()
    check_status = sync_info.get("status", "not_run")

    if ok:
        insert_log("INFO", f"Проверка выполнена. Статус: {check_status}", current_user()["user_id"])
        return jsonify({"ok": True, "message": output or "OK"})

    insert_log("ERROR", f"Проверка завершилась с ошибкой. Статус: {check_status}. {output}", current_user()["user_id"])
    return jsonify({"ok": False, "message": output or "CHECKS_FAILED"}), 400


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)