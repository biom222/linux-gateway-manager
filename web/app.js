const state = {
  currentUser: null,
  activeProfile: null,
  backendRuntime: null,
  lastCheck: null,
  lastAction: "—",
  profiles: [],
  logs: []
};

const pageTitle = document.getElementById("pageTitle");
const backendStatusEl = document.getElementById("backendStatus");
const activeProfileEl = document.getElementById("activeProfile");
const lastCheckStatusEl = document.getElementById("lastCheckStatus");
const lastCheckTimeEl = document.getElementById("lastCheckTime");
const backendNameEl = document.getElementById("backendName");
const lastActionEl = document.getElementById("lastAction");
const recentEventsEl = document.getElementById("recentEvents");
const profilesGridEl = document.getElementById("profilesGrid");
const checksTableBodyEl = document.getElementById("checksTableBody");
const checksSummaryBadgeEl = document.getElementById("checksSummaryBadge");
const logsBoxEl = document.getElementById("logsBox");
const currentUserBadgeEl = document.getElementById("currentUserBadge");

const runChecksBtn = document.getElementById("runChecksBtn");
const applyProfileBtn = document.getElementById("applyProfileBtn");
const resetBackendBtn = document.getElementById("resetBackendBtn");
const logoutBtn = document.getElementById("logoutBtn");

const navButtons = document.querySelectorAll(".nav__item");
const sections = {
  dashboard: document.getElementById("dashboardSection"),
  profiles: document.getElementById("profilesSection"),
  checks: document.getElementById("checksSection"),
  logs: document.getElementById("logsSection")
};

const sectionTitles = {
  dashboard: "Главная панель",
  profiles: "Профили конфигурации",
  checks: "Диагностика и проверки",
  logs: "Журнал событий"
};

runChecksBtn.addEventListener("click", runChecks);
applyProfileBtn.addEventListener("click", applyActiveProfile);
resetBackendBtn.addEventListener("click", resetBackend);
logoutBtn.addEventListener("click", logout);
document.getElementById("clearLogsBtn").addEventListener("click", clearLogsView);

navButtons.forEach((button) => {
  button.addEventListener("click", () => {
    const target = button.dataset.section;
    switchSection(target);
  });
});

function switchSection(sectionKey) {
  Object.entries(sections).forEach(([key, section]) => {
    section.classList.toggle("active", key === sectionKey);
  });

  navButtons.forEach((button) => {
    button.classList.toggle("nav__item--active", button.dataset.section === sectionKey);
  });

  pageTitle.textContent = sectionTitles[sectionKey];
}

function isAdmin() {
  return state.currentUser?.role_name === "Администратор";
}

async function apiGet(url) {
  const response = await fetch(url, {
    headers: {
      "Accept": "application/json"
    }
  });

  if (response.status === 401) {
    window.location.href = "/login";
    throw new Error("Не авторизован");
  }

  if (!response.ok) {
    throw new Error(`GET ${url} failed: ${response.status}`);
  }

  return response.json();
}

async function apiPost(url, payload = {}) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Accept": "application/json"
    },
    body: JSON.stringify(payload)
  });

  if (response.status === 401) {
    window.location.href = "/login";
    throw new Error("Не авторизован");
  }

  const data = await response.json().catch(() => ({}));

  if (!response.ok || data.ok === false) {
    const message = data.message || `POST ${url} failed`;
    throw new Error(message);
  }

  return data;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatBackendStatus(status) {
  if (!status) return "—";

  switch (status) {
    case "applied":
      return "Применён";
    case "reset":
      return "Сброшен";
    case "not_applied":
      return "Не применялся";
    default:
      return status;
  }
}

function formatCheckStatus(status) {
  if (!status) return "—";

  switch (status) {
    case "ok":
      return "Успешно";
    case "failed":
      return "Ошибка";
    case "degraded":
      return "Частичные ошибки";
    case "not_run":
      return "Не запускалась";
    default:
      return status;
  }
}

function getChecksBadgeClass(status) {
  switch (status) {
    case "ok":
      return "badge success";
    case "degraded":
      return "badge warning";
    case "failed":
      return "badge danger";
    default:
      return "badge";
  }
}

function parseCheckResults(rawText) {
  if (!rawText) return [];

  return rawText
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .map((line) => {
      const parts = line.split("|").map((part) => part.trim());

      const target = parts[0] || "—";
      let http = "—";
      let tls12 = "—";
      let tls13 = "—";
      let ping = "—";
      let finalStatus = "Доступен";

      for (const part of parts.slice(1)) {
        if (part.startsWith("HTTP:")) http = part.replace("HTTP:", "").trim();
        else if (part.startsWith("TLS1.2:")) tls12 = part.replace("TLS1.2:", "").trim();
        else if (part.startsWith("TLS1.3:")) tls13 = part.replace("TLS1.3:", "").trim();
        else if (part.startsWith("PING:")) ping = part.replace("PING:", "").trim();
        else if (part.startsWith("STATUS:")) finalStatus = part.replace("STATUS:", "").trim();
      }

      let status = "Доступен";
      const values = `${http} ${tls12} ${tls13} ${ping} ${finalStatus}`.toUpperCase();

      if (values.includes("FAILED") || values.includes("FAIL") || values.includes("ERROR") || values.includes("TIMEOUT")) {
        status = "Есть ошибки";
      } else if (values.includes("DEGRADED") || values.includes("WARN") || values.includes("PARTIAL") || values.includes("UNSUP")) {
        status = "Частичная поддержка";
      }

      return { target, http, tls12, tls13, ping, status };
    });
}

function showTransientMessage(text) {
  state.lastAction = text;
  renderStats();
}

function renderUserInfo() {
  if (!state.currentUser) {
    currentUserBadgeEl.textContent = "—";
    return;
  }

  currentUserBadgeEl.textContent = `${state.currentUser.login} · ${state.currentUser.role_name}`;

  const admin = isAdmin();
  runChecksBtn.hidden = !admin;
  applyProfileBtn.hidden = !admin;
  resetBackendBtn.hidden = !admin;
}

function renderStats() {
  backendStatusEl.textContent = formatBackendStatus(state.backendRuntime?.status || "not_applied");
  activeProfileEl.textContent = state.activeProfile?.name || "—";
  lastCheckStatusEl.textContent = formatCheckStatus(state.lastCheck?.status || "not_run");
  lastCheckTimeEl.textContent = state.lastCheck?.time || "—";
  backendNameEl.textContent = state.backendRuntime?.backend_name || "gateway-runtime";
  lastActionEl.textContent = state.lastAction || "—";
}

function renderEvents() {
  recentEventsEl.innerHTML = "";

  const latestLogs = [...state.logs].slice(0, 5);

  if (!latestLogs.length) {
    const li = document.createElement("li");
    li.textContent = "События отсутствуют";
    recentEventsEl.appendChild(li);
    return;
  }

  latestLogs.forEach((line) => {
    const li = document.createElement("li");
    li.textContent = line;
    recentEventsEl.appendChild(li);
  });
}

function renderProfiles() {
  profilesGridEl.innerHTML = "";

  if (!state.profiles.length) {
    profilesGridEl.innerHTML = `<p class="muted">Профили не найдены.</p>`;
    return;
  }

  state.profiles.forEach((profile) => {
    const card = document.createElement("article");
    card.className = "profile-card";

    if (state.activeProfile && profile.id === state.activeProfile.id) {
      card.classList.add("active");
    }

    const buttonHtml = isAdmin()
      ? `<div class="topbar__actions">
           <button class="btn btn--secondary" data-profile-id="${escapeHtml(profile.id)}">Сделать активным</button>
         </div>`
      : "";

    card.innerHTML = `
      <h4>${escapeHtml(profile.name)}</h4>
      <p>${escapeHtml(profile.description || "Описание отсутствует")}</p>
      <div class="profile-meta">
        <span><strong>Backend:</strong> ${escapeHtml(profile.backend || "—")}</span>
        <span><strong>Check set:</strong> ${escapeHtml(profile.check_set || "—")}</span>
        <span><strong>Priority:</strong> ${escapeHtml(profile.priority || "—")}</span>
      </div>
      ${buttonHtml}
    `;

    const button = card.querySelector("button");
    if (button) {
      button.addEventListener("click", async () => {
        try {
          await apiPost("/api/actions/select-profile", { profile_id: profile.id });
          await refreshAll();
          showTransientMessage(`Выбран профиль: ${profile.name}`);
        } catch (error) {
          alert(`Ошибка выбора профиля: ${error.message}`);
        }
      });
    }

    profilesGridEl.appendChild(card);
  });
}

function renderChecks() {
  checksTableBodyEl.innerHTML = "";

  const rows = parseCheckResults(state.lastCheck?.results || "");

  if (!rows.length) {
    checksTableBodyEl.innerHTML = `
      <tr>
        <td colspan="6" class="muted">Проверки ещё не запускались.</td>
      </tr>
    `;
    checksSummaryBadgeEl.textContent = "Проверка не запускалась";
    checksSummaryBadgeEl.className = getChecksBadgeClass("not_run");
    return;
  }

  rows.forEach((row) => {
    const tr = document.createElement("tr");

    let statusClass = "result-ok";
    if (row.status === "Есть ошибки") statusClass = "result-fail";
    if (row.status === "Частичная поддержка") statusClass = "result-warn";

    tr.innerHTML = `
      <td>${escapeHtml(row.target)}</td>
      <td>${escapeHtml(row.http)}</td>
      <td>${escapeHtml(row.tls12)}</td>
      <td>${escapeHtml(row.tls13)}</td>
      <td>${escapeHtml(row.ping)}</td>
      <td class="${statusClass}">${escapeHtml(row.status)}</td>
    `;

    checksTableBodyEl.appendChild(tr);
  });

  checksSummaryBadgeEl.textContent = `Статус: ${formatCheckStatus(state.lastCheck?.status || "not_run")}`;
  checksSummaryBadgeEl.className = getChecksBadgeClass(state.lastCheck?.status || "not_run");
}

function renderLogs() {
  if (!state.logs.length) {
    logsBoxEl.textContent = "Журнал пуст.";
    return;
  }

  logsBoxEl.textContent = [...state.logs].reverse().join("\n");
}

async function refreshMe() {
  const data = await apiGet("/api/me");
  state.currentUser = data.user || null;
}

async function refreshStatus() {
  const data = await apiGet("/api/status");
  state.activeProfile = data.active_profile;
  state.backendRuntime = data.backend_runtime;
  state.lastCheck = data.last_check;
  state.lastAction = data.last_action || "—";
}

async function refreshProfiles() {
  const data = await apiGet("/api/profiles");
  state.profiles = data.profiles || [];
}

async function refreshLogs() {
  const data = await apiGet("/api/logs?limit=100");
  state.logs = data.logs || [];
}

async function refreshAll() {
  await Promise.all([refreshMe(), refreshStatus(), refreshProfiles(), refreshLogs()]);
  render();
}

async function applyActiveProfile() {
  try {
    await apiPost("/api/actions/apply-profile");
    await refreshAll();
    showTransientMessage("Активный профиль применён");
  } catch (error) {
    alert(`Ошибка применения профиля: ${error.message}`);
  }
}

async function resetBackend() {
  try {
    await apiPost("/api/actions/reset-backend");
    await refreshAll();
    showTransientMessage("Backend сброшен");
  } catch (error) {
    alert(`Ошибка сброса backend: ${error.message}`);
  }
}

async function runChecks() {
  try {
    await apiPost("/api/actions/run-checks");
    await refreshAll();
    showTransientMessage("Проверка выполнена");
    switchSection("checks");
  } catch (error) {
    await refreshAll();
    switchSection("checks");
    alert(`Проверка завершилась с ошибками: ${error.message}`);
  }
}

async function logout() {
  await fetch("/logout", { method: "POST" });
  window.location.href = "/login";
}

function clearLogsView() {
  logsBoxEl.textContent = "Очистка журнала через интерфейс пока не реализована.";
}

function render() {
  renderUserInfo();
  renderStats();
  renderEvents();
  renderProfiles();
  renderChecks();
  renderLogs();
}

async function init() {
  try {
    await refreshAll();
    render();
    switchSection("dashboard");
  } catch (error) {
    console.error(error);
  }
}

init();Ы