const form = document.getElementById("loginForm");
const loginInput = document.getElementById("loginInput");
const passwordInput = document.getElementById("passwordInput");
const errorEl = document.getElementById("loginError");

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  errorEl.textContent = "";

  const login = loginInput.value.trim();
  const password = passwordInput.value;

  if (!login || !password) {
    errorEl.textContent = "Введите логин и пароль";
    return;
  }

  try {
    const response = await fetch("/api/login", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: JSON.stringify({ login, password })
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok || data.ok === false) {
      errorEl.textContent = data.message || "Ошибка входа";
      return;
    }

    window.location.href = "/";
  } catch (error) {
    errorEl.textContent = "Не удалось подключиться к серверу";
  }
});