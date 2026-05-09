from dotenv import load_dotenv
from os import getenv
from mssql_python import connect

load_dotenv()

connection_string = getenv("SQL_CONNECTION_STRING")

print("Подключаюсь к БД...")

with connect(connection_string) as conn:
    cursor = conn.cursor()

    print("Подключение успешно.\n")

    cursor.execute("SELECT DB_NAME() AS CurrentDatabase;")
    row = cursor.fetchone()
    print("Текущая база:", row[0])

    print("\nТаблицы проекта:")
    cursor.execute("""
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
          AND TABLE_NAME LIKE '%0905'
        ORDER BY TABLE_NAME
    """)

    rows = cursor.fetchall()
    for item in rows:
        print("-", item[0])