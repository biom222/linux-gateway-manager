USE user176_db;
GO

/* =========================
   1. Таблица ролей
   ========================= */
CREATE TABLE dbo.roles0905 (
    RoleID INT IDENTITY(1,1) PRIMARY KEY,
    RoleName NVARCHAR(50) NOT NULL UNIQUE
);
GO

/* =========================
   2. Таблица пользователей
   ========================= */
CREATE TABLE dbo.users0905 (
    UserID INT IDENTITY(1,1) PRIMARY KEY,
    Login NVARCHAR(100) NOT NULL UNIQUE,
    PasswordHash NVARCHAR(255) NOT NULL,
    RoleID INT NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_users0905_roles0905 FOREIGN KEY (RoleID)
        REFERENCES dbo.roles0905(RoleID)
);
GO

/* =========================
   3. Таблица профилей
   ========================= */
CREATE TABLE dbo.profiles0905 (
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
CREATE TABLE dbo.backend_state0905 (
    StateID INT IDENTITY(1,1) PRIMARY KEY,
    BackendName NVARCHAR(100) NOT NULL,
    Status NVARCHAR(100) NOT NULL,
    AppliedProfileID INT NULL,
    AppliedAt DATETIME2 NULL,
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT FK_backend_state0905_profiles0905 FOREIGN KEY (AppliedProfileID)
        REFERENCES dbo.profiles0905(ProfileID)
);
GO

/* =========================
   5. Таблица запусков проверок
   ========================= */
CREATE TABLE dbo.check_runs0905 (
    RunID INT IDENTITY(1,1) PRIMARY KEY,
    StartedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    FinishedAt DATETIME2 NULL,
    Status NVARCHAR(100) NOT NULL,
    Details NVARCHAR(MAX) NULL,
    StartedByUserID INT NULL,
    CONSTRAINT FK_check_runs0905_users0905 FOREIGN KEY (StartedByUserID)
        REFERENCES dbo.users0905(UserID)
);
GO

/* =========================
   6. Таблица результатов проверок
   ========================= */
CREATE TABLE dbo.check_results0905 (
    ResultID INT IDENTITY(1,1) PRIMARY KEY,
    RunID INT NOT NULL,
    TargetName NVARCHAR(200) NOT NULL,
    HttpResult NVARCHAR(50) NULL,
    Tls12Result NVARCHAR(50) NULL,
    Tls13Result NVARCHAR(50) NULL,
    PingResult NVARCHAR(50) NULL,
    FinalStatus NVARCHAR(100) NOT NULL,
    CONSTRAINT FK_check_results0905_runs0905 FOREIGN KEY (RunID)
        REFERENCES dbo.check_runs0905(RunID)
        ON DELETE CASCADE
);
GO

/* =========================
   7. Таблица системного журнала
   ========================= */
CREATE TABLE dbo.system_logs0905 (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    LogLevel NVARCHAR(20) NOT NULL,
    Message NVARCHAR(MAX) NOT NULL,
    UserID INT NULL,
    CONSTRAINT FK_system_logs0905_users0905 FOREIGN KEY (UserID)
        REFERENCES dbo.users0905(UserID)
);
GO

/* =========================
   Начальные данные: роли
   ========================= */
INSERT INTO dbo.roles0905 (RoleName)
VALUES
(N'Администратор'),
(N'Пользователь');
GO

/* =========================
   Начальные данные: пользователи
   Временно пароли храним как текст,
   позже заменим на хеширование в Flask
   ========================= */
INSERT INTO dbo.users0905 (Login, PasswordHash, RoleID)
VALUES
(N'admin', N'admin123', 1),
(N'user', N'user123', 2);
GO

/* =========================
   Начальные данные: профили
   ========================= */
INSERT INTO dbo.profiles0905 (ProfileName, Description, BackendName, Arguments, CheckSet, Priority, IsActive)
VALUES
(N'basic', N'Базовый профиль для начального тестирования', N'zapret', N'--dpi-desync=fake', N'standard', 10, 1),
(N'universal', N'Универсальный профиль для повседневного использования', N'zapret', N'--dpi-desync=fake --dpi-desync-fooling=badseq', N'standard', 20, 0);
GO

/* =========================
   Начальные данные: состояние backend
   ========================= */
INSERT INTO dbo.backend_state0905 (BackendName, Status, AppliedProfileID, AppliedAt)
VALUES
(N'zapret', N'applied', 1, SYSDATETIME());
GO

/* =========================
   Начальные данные: системный журнал
   ========================= */
INSERT INTO dbo.system_logs0905 (LogLevel, Message, UserID)
VALUES
(N'INFO', N'Система инициализирована', 1),
(N'INFO', N'Созданы начальные роли пользователей и профили конфигурации', 1);
GO