function unlockUI() {
  state.unlocked = true;
  els.authCard.classList.add("hidden");
  els.dashboard.classList.remove("hidden");
  setCurrentUserBadge();
}

async function lockUI() {
  if (state.unlocked) {
    addActivity("Panel locked", {
      moduleKey: "auth",
      details: "User logged out",
    });
  }

  await unsubscribeRealtimeNotifications();
  stopLiveHealthPolling();
  stopLiveHeartbeatSync();

  state.unlocked = false;
  state.currentUser = null;
  state.activeModule = "dashboard";
  state.rows = [];
  state.searchQuery = "";
  state.activityFeed = [];
  state.selectedRows.clear();
  state.live.lastSyncAt = null;
  state.live.lastHealthCheckAt = null;
  state.live.dashboardCardsBuilt = false;
  state.live.lastChartRenderAt = null;

  els.usernameInput.value = "";
  els.passwordInput.value = "";
  els.searchInput.value = "";

  els.dashboard.classList.add("hidden");
  els.authCard.classList.remove("hidden");
  els.notificationContainer.classList.add("hidden");
  setCurrentUserBadge();
  updateLiveHealthIndicators();
  setStatus(els.authMessage, "Panel locked.", "success");

  addNotification("Panel locked successfully", "info");
}

async function loginAsPanelUser(username, password) {
  const { data, error } = await state.supabase
    .from("admin_panel_users")
    .select("id,username,password_hash,role,branch_id,is_active,display_name")
    .eq("username", username)
    .maybeSingle();

  if (error) {
    const raw = String(error.message || "").toLowerCase();
    if (raw.includes("permission denied") && raw.includes("admin_panel_users")) {
      throw new Error(
        "Permission denied on admin_panel_users. Run database/admin_panel_users.sql in Supabase SQL Editor."
      );
    }
    if (raw.includes("admin_panel_users")) {
      throw new Error(
        "admin_panel_users table is missing. Run database/admin_panel_users.sql in Supabase SQL Editor."
      );
    }
    throw error;
  }

  if (!data || data.is_active === false) {
    throw new Error("User not found or inactive.");
  }

  const hashed = await sha256(password);
  if (hashed !== data.password_hash) {
    throw new Error("Invalid username/password.");
  }

  if (!data.branch_id) {
    throw new Error("This user has no branch assigned. Contact main admin.");
  }

  state.currentUser = {
    kind: "dept",
    userId: data.id,
    username: data.username,
    displayName: data.display_name || data.username,
    role: data.role || "teacher",
    branchId: data.branch_id,
  };
}

async function handleLogin() {
  const username = els.usernameInput.value.trim();
  const password = els.passwordInput.value.trim();

  if (!password) {
    setStatus(els.authMessage, "Password is required.", "error");
    return;
  }

  initSupabase();

  const mainLoginAttempt = !username || username.toLowerCase() === "main";
  if (mainLoginAttempt) {
    const hashedInput = await sha256(password);
    const configuredHash = state.env.ADMIN_PASSWORD_HASH;
    const legacyPassword = state.env.ADMIN_PASSWORD;

    let isValid = false;

    if (configuredHash) {
      if (hashedInput === configuredHash.toLowerCase()) {
        isValid = true;
      }
    } else if (legacyPassword) {
      if (password === legacyPassword) {
        isValid = true;
      }
    } else {
      const fallbackHash = await sha256(MAIN_ADMIN_PASSWORD_FALLBACK);
      if (hashedInput === fallbackHash) {
        isValid = true;
      }
    }

    if (!isValid) {
      setStatus(els.authMessage, "Invalid main admin password.", "error");
      return;
    }

    state.currentUser = {
      kind: "main",
      userId: null,
      username: "main",
      displayName: "Main Admin",
      role: "main-admin",
      branchId: null,
    };
  } else {
    await loginAsPanelUser(username, password);
  }

  await unsubscribeRealtimeNotifications();
  unlockUI();
  buildModuleNav();
  updateHeaderAndToolbar();
  await loadOptions();
  await loadKpis();
  await refreshModuleData();
  await subscribeRealtimeNotifications();
  startLiveHealthPolling();
  startLiveHeartbeatSync();
  state.live.lastSyncAt = Date.now();
  updateLiveHealthIndicators();
  addActivity(`Logged in as ${state.currentUser.username}`, {
    moduleKey: "auth",
    details: `Role: ${state.currentUser.role}`,
  });
  addNotification(`Welcome back, ${state.currentUser.username}!`, "success");
  setStatus(els.authMessage, "Access granted.", "success");
}
