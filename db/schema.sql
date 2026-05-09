USE user176_db;
GO

/* =========================
   Удаление таблиц в правильном порядке
   ========================= */
IF OBJECT_ID('dbo.check_results', 'U') IS NOT NULL
    DROP TABLE dbo.check_results;
GO

IF OBJECT_ID('dbo.check_runs', 'U') IS NOT NULL
    DROP TABLE dbo.check_runs;
GO

IF OBJECT_ID('dbo.system_logs', 'U') IS NOT NULL
    DROP TABLE dbo.system_logs;
GO

IF OBJECT_ID('dbo.backend_state', 'U') IS NOT NULL
    DROP TABLE dbo.backend_state;
GO

IF OBJECT_ID('dbo.users', 'U') IS NOT NULL
    DROP TABLE dbo.users;
GO

IF OBJECT_ID('dbo.profiles', 'U') IS NOT NULL
    DROP TABLE dbo.profiles;
GO

IF OBJECT_ID('dbo.roles', 'U') IS NOT NULL
    DROP TABLE dbo.roles;
GO

/* =========================
   1. Таблица ролей
   ========================= */
CREATE TABLE dbo.roles (
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) NOT NULL UNIQUE
);
GO

/* =========================
   2. Таблица пользователей
   ========================= */
CREATE TABLE dbo.users (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Login NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    RoleID INT NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_users_roles FOREIGN KEY (RoleID)
        REFERENCES dbo.roles(RoleID)
);
GO

/* =========================
   3. Таблица профилей
   ========================= */
CREATE TABLE dbo.profiles (
    ProfileID INT IDENTITY(1,1) PRIMARY KEY,
    ProfileName NVARCHAR(100) NOT NULL UNIQUE,
    Description NVARCHAR(500) NULL,
    BackendName NVARCHAR(100) NOT NULL,
    Arguments NVARCHAR(MAX) NULL,
    CheckSet NVARCHAR(100) NULL,
    Priority INT NOT NULL DEFAULT 0,
    IsActive BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME()
);
GO

/* =========================
   4. Таблица состояния backend
   ========================= */
CREATE TABLE dbo.backend_state (
    StateID INT IDENTITY(1,1) PRIMARY KEY,
    BackendName NVARCHAR(100) NOT NULL,
    Status NVARCHAR(100) NOT NULL,
    AppliedProfileID INT NULL,
    AppliedAt DATETIME2 NULL,
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_backend_state_profiles FOREIGN KEY (AppliedProfileID)
        REFERENCES dbo.profiles(ProfileID)
);
GO

/* =========================
   5. Таблица запусков проверок
   ========================= */
CREATE TABLE dbo.check_runs (
    RunID INT IDENTITY(1,1) PRIMARY KEY,
    StartedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FinishedAt DATETIME2 NULL,
    Status NVARCHAR(100) NOT NULL,
    Details NVARCHAR(MAX) NULL,
    StartedByUserID INT NULL,
    CONSTRAINT FK_check_runs_users FOREIGN KEY (StartedByUserID)
        REFERENCES dbo.users(UserID)
);
GO

/* =========================
   6. Таблица результатов проверок
   ========================= */
CREATE TABLE dbo.check_results (
    ResultID INT IDENTITY(1,1) PRIMARY KEY,
    RunID INT NOT NULL,
    TargetName NVARCHAR(200) NOT NULL,
    HttpResult NVARCHAR(50) NULL,
    Tls12Result NVARCHAR(50) NULL,
    Tls13Result NVARCHAR(50) NULL,
    PingResult NVARCHAR(50) NULL,
    FinalStatus NVARCHAR(100) NOT NULL,
    CONSTRAINT FK_check_results_runs FOREIGN KEY (RunID)
        REFERENCES dbo.check_runs(RunID)
        ON DELETE CASCADE
);
GO

/* =========================
   7. Таблица системного журнала
   ========================= */
CREATE TABLE dbo.system_logs (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    LogLevel NVARCHAR(20) NOT NULL,
    Message NVARCHAR(MAX) NOT NULL,
    UserID INT NULL,
    CONSTRAINT FK_system_logs_users FOREIGN KEY (UserID)
        REFERENCES dbo.users(UserID)
);
GO

/* =========================
   Начальные данные: роли
   ========================= */
INSERT INTO dbo.roles (RoleName)
VALUES
(N'Администратор'),
(N'Пользователь');
GO

/* =========================
   Начальные данные: пользователи
   Временно храним пароли в простом виде,
   потом заменим на хеширование в Flask
   ========================= */
INSERT INTO dbo.users (Login, PasswordHash, RoleID)
VALUES
(N'admin', N'admin123', 1),
(N'user', N'user123', 2);
GO

/* =========================
   Начальные данные: профили
   ========================= */
INSERT INTO dbo.profiles (ProfileName, Description, BackendName, Arguments, CheckSet, Priority, IsActive)
VALUES
(N'basic', N'Базовый профиль для начального тестирования', N'zapret', N'--dpi-desync=fake', N'standard', 10, 1),
(N'universal', N'Универсальный профиль для повседневного использования', N'zapret', N'--dpi-desync=fake --dpi-desync-fooling=badseq', N'standard', 20, 0);
GO

/* =========================
   Начальные данные: состояние backend
   ========================= */
INSERT INTO dbo.backend_state (BackendName, Status, AppliedProfileID, AppliedAt)
VALUES
(N'zapret', N'applied', 1, SYSDATETIME());
GO

/* =========================
   Начальные данные: системный журнал
   ========================= */
INSERT INTO dbo.system_logs (LogLevel, Message, UserID)
VALUES
(N'INFO', N'Система инициализирована', 1),
(N'INFO', N'Созданы начальные роли пользователей и профили конфигурации', 1);
GO