function isInBranchScope(branchId) {
  if (isMainAdmin()) {
    return true;
  }
  const userBranchId = state.currentUser?.branchId;
  if (!userBranchId) {
    return true;
  }
  if (branchId === null || branchId === undefined || branchId === "") {
    return true;
  }
  return String(userBranchId) === String(branchId);
}

function canProcessRealtimeRecord(tableName, record = null) {
  if (isMainAdmin()) {
    return true;
  }

  const userBranchId = state.currentUser?.branchId;
  if (!userBranchId) {
    return true;
  }

  if (tableName === "branches") {
    if (!record?.id) {
      return true;
    }
    return String(record.id) === String(userBranchId);
  }

  const branchField = REALTIME_BRANCH_FIELDS[tableName];
  if (!branchField) {
    return true;
  }

  return isInBranchScope(record?.[branchField]);
}

function clearRealtimeSyncQueue() {
  if (state.live.syncTimerId) {
    clearTimeout(state.live.syncTimerId);
    state.live.syncTimerId = null;
  }
  state.live.pendingTables.clear();
  state.live.syncQueued = false;
}

function updateLiveHealthIndicators() {
  const liveEl = document.getElementById("health-live");
  const syncEl = document.getElementById("health-last-sync");

  if (liveEl) {
    const status = String(state.live.realtimeStatus || "DISCONNECTED").toUpperCase();
    if (status === "SUBSCRIBED") {
      liveEl.textContent = "Live";
      liveEl.style.color = "#29c3af";
    } else if (["CONNECTING", "JOINING"].includes(status)) {
      liveEl.textContent = "Connecting";
      liveEl.style.color = "#ffcc66";
    } else if (["TIMED_OUT", "CHANNEL_ERROR"].includes(status)) {
      liveEl.textContent = "Degraded";
      liveEl.style.color = "#ffcc66";
    } else {
      liveEl.textContent = "Disconnected";
      liveEl.style.color = "#ff6e7d";
    }
  }

  if (syncEl) {
    if (state.live.lastSyncAt) {
      syncEl.textContent = new Date(state.live.lastSyncAt).toLocaleTimeString();
      syncEl.style.color = "var(--text)";
    } else {
      syncEl.textContent = "Waiting...";
      syncEl.style.color = "var(--muted)";
    }
  }
}

function setRealtimeStatus(status) {
  state.live.realtimeStatus = String(status || "DISCONNECTED").toUpperCase();
  updateLiveHealthIndicators();
}

async function runRealtimeSync() {
  state.live.syncTimerId = null;
  if (!state.unlocked || !state.supabase) {
    return;
  }

  if (state.live.syncInProgress) {
    state.live.syncQueued = true;
    return;
  }

  state.live.syncInProgress = true;
  const pendingTables = new Set(state.live.pendingTables);
  state.live.pendingTables.clear();

  try {
    const needsOptionReload =
      pendingTables.has("initial") ||
      pendingTables.has("queued") ||
      Array.from(pendingTables).some((tableName) => OPTION_RELOAD_TABLES.has(tableName));
    const heartbeatOnly = pendingTables.size === 1 && pendingTables.has("heartbeat");

    if (needsOptionReload) {
      await loadOptions();
    }
    await loadKpis();
    await refreshModuleData({
      silent: true,
      skipDashboardCharts: heartbeatOnly,
    });
    state.live.lastSyncAt = Date.now();
    updateLiveHealthIndicators();
  } catch (error) {
    console.error("Realtime sync failed", error);
  } finally {
    state.live.syncInProgress = false;
    if (state.live.syncQueued || state.live.pendingTables.size) {
      state.live.syncQueued = false;
      queueRealtimeSync("queued");
    }
  }
}

function queueRealtimeSync(tableName = "unknown") {
  if (!state.unlocked) {
    return;
  }

  state.live.pendingTables.add(tableName);
  if (state.live.syncTimerId) {
    return;
  }

  state.live.syncTimerId = setTimeout(() => {
    void runRealtimeSync();
  }, REALTIME_SYNC_DEBOUNCE_MS);
}

function stopLiveHealthPolling() {
  if (state.live.healthTimerId) {
    clearInterval(state.live.healthTimerId);
    state.live.healthTimerId = null;
  }
}

function stopLiveHeartbeatSync() {
  if (state.live.heartbeatTimerId) {
    clearInterval(state.live.heartbeatTimerId);
    state.live.heartbeatTimerId = null;
  }
}

function refreshIntervalStorageKey() {
  return "adminPanelRefreshIntervalMs";
}

function normalizeRefreshIntervalMs(value) {
  const allowed = [1000, 5000, 10000];
  const parsed = Number.parseInt(value, 10);
  if (!Number.isFinite(parsed)) {
    return LIVE_HEARTBEAT_SYNC_INTERVAL_MS;
  }
  return allowed.includes(parsed) ? parsed : LIVE_HEARTBEAT_SYNC_INTERVAL_MS;
}

function setLiveRefreshInterval(intervalMs, { persist = true } = {}) {
  const normalizedInterval = normalizeRefreshIntervalMs(intervalMs);
  state.live.heartbeatIntervalMs = normalizedInterval;
  if (els.refreshIntervalSelect) {
    els.refreshIntervalSelect.value = String(normalizedInterval);
  }
  if (persist) {
    localStorage.setItem(refreshIntervalStorageKey(), String(normalizedInterval));
  }
  if (state.unlocked) {
    startLiveHeartbeatSync();
  }
  return normalizedInterval;
}

function loadRefreshIntervalPreference() {
  const saved = localStorage.getItem(refreshIntervalStorageKey());
  setLiveRefreshInterval(saved, { persist: false });
}

function startLiveHeartbeatSync() {
  stopLiveHeartbeatSync();
  if (!state.unlocked) {
    return;
  }

  const intervalMs = normalizeRefreshIntervalMs(state.live.heartbeatIntervalMs);
  state.live.heartbeatIntervalMs = intervalMs;

  state.live.heartbeatTimerId = setInterval(() => {
    queueRealtimeSync("heartbeat");
  }, intervalMs);
}

function startLiveHealthPolling() {
  stopLiveHealthPolling();
  if (!state.unlocked) {
    return;
  }

  state.live.healthTimerId = setInterval(() => {
    void checkSystemHealth();
  }, DASHBOARD_HEALTH_POLL_INTERVAL_MS);
}

function notificationsStorageKey() {
  return "adminPanelNotifications";
}

function saveNotifications() {
  const compact = state.notifications.slice(0, 50).map((notification) => ({
    id: notification.id,
    message: notification.message,
    type: notification.type,
    timestamp: notification.timestamp,
    read: Boolean(notification.read),
  }));
  localStorage.setItem(notificationsStorageKey(), JSON.stringify(compact));
}

function loadNotifications() {
  try {
    const raw = localStorage.getItem(notificationsStorageKey());
    if (!raw) {
      state.notifications = [];
      updateNotificationBadge();
      return;
    }
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) {
      state.notifications = [];
      updateNotificationBadge();
      return;
    }
    state.notifications = parsed
      .filter((item) => item && item.message)
      .slice(0, 50)
      .map((item) => ({
        id: item.id || `${Date.now()}-${Math.random()}`,
        message: item.message,
        type: item.type || "info",
        timestamp: item.timestamp || new Date().toISOString(),
        read: Boolean(item.read),
      }));
  } catch (error) {
    console.error("Failed to load notifications", error);
    state.notifications = [];
  }

  updateNotificationBadge();
}

function handleRealtimeActivity(record) {
  if (!record || !isInBranchScope(record.branch_id)) {
    return;
  }

  const action = String(record.action || "");
  if (!isImportantActivity(action)) {
    return;
  }

  const actorName = String(record.username || "");
  if (actorName && actorName === getActivityActorName()) {
    return;
  }

  const moduleLabel = getActivityModuleLabel(record.module_key);
  addNotification(`${moduleLabel}: ${action}`, "info");
}

function handleRealtimeNotice(record) {
  if (!record || !isInBranchScope(record.branch_id)) {
    return;
  }
  if (record.is_active === false) {
    return;
  }

  const priority = String(record.priority || "normal").toLowerCase();
  const type = priority === "urgent" || priority === "high" ? "warning" : "info";
  addNotification(`Notice: ${record.title || "New announcement"}`, type);
}

function handleRealtimeTableChange(tableName, payload) {
  const eventType = String(payload?.eventType || "").toUpperCase();
  const record = payload?.new || payload?.old || null;

  if (!canProcessRealtimeRecord(tableName, record)) {
    return;
  }

  if (tableName === "admin_panel_activity") {
    if (eventType === "INSERT") {
      handleRealtimeActivity(record);
    }
    queueRealtimeSync("admin_panel_activity");
    return;
  }

  if (tableName === "notices") {
    if (["INSERT", "UPDATE"].includes(eventType)) {
      handleRealtimeNotice(record);
    }
    queueRealtimeSync("notices");
    return;
  }

  queueRealtimeSync(tableName);
}

async function unsubscribeRealtimeNotifications() {
  clearRealtimeSyncQueue();
  setRealtimeStatus("DISCONNECTED");

  if (!state.supabase || !state.realtimeChannel) {
    return;
  }
  try {
    await state.supabase.removeChannel(state.realtimeChannel);
  } catch (error) {
    console.error("Failed to unsubscribe realtime channel", error);
  } finally {
    state.realtimeChannel = null;
  }
}

async function subscribeRealtimeNotifications() {
  if (!state.supabase || state.realtimeChannel) {
    return;
  }

  setRealtimeStatus("CONNECTING");

  let channel = state.supabase.channel(`admin-panel-events-${Date.now()}`);
  REALTIME_TABLES.forEach((tableName) => {
    channel = channel.on(
      "postgres_changes",
      { event: "*", schema: "public", table: tableName },
      (payload) => handleRealtimeTableChange(tableName, payload)
    );
  });

  state.realtimeChannel = channel.subscribe((status) => {
    setRealtimeStatus(status);
    if (status === "CHANNEL_ERROR") {
      console.error("Realtime channel error");
    }
    if (status === "SUBSCRIBED") {
      queueRealtimeSync("initial");
    }
  });
}

function toggleNotifications() {
  const isHidden = els.notificationContainer.classList.toggle("hidden");
  if (!isHidden) {
    markAllAsRead();
  }
  renderNotifications();
}

function addNotification(message, type = 'info') {
  const notification = {
    id: `${Date.now()}-${Math.random()}`,
    message,
    type,
    timestamp: new Date().toISOString(),
    read: false
  };

  state.notifications.unshift(notification);

  // Keep only last 50 notifications
  if (state.notifications.length > 50) {
    state.notifications = state.notifications.slice(0, 50);
  }

  saveNotifications();
  renderNotifications();
  updateNotificationBadge();
}

function renderNotifications() {
  if (!els.notificationList) {
    return;
  }
  els.notificationList.innerHTML = state.notifications.map(notification => `
    <div class="notification-item ${notification.read ? '' : 'unread'}">
      <div>${notification.message}</div>
      <div class="notification-time">${new Date(notification.timestamp).toLocaleTimeString()}</div>
    </div>
  `).join('');
}

function updateNotificationBadge() {
  const unreadCount = state.notifications.filter(n => !n.read).length;
  if (unreadCount > 0) {
    els.notificationBtn.textContent = `🔔 (${unreadCount})`;
  } else {
    els.notificationBtn.textContent = '🔔';
  }
}

function clearAllNotifications() {
  state.notifications = [];
  saveNotifications();
  renderNotifications();
  updateNotificationBadge();
}

function markAllAsRead() {
  state.notifications.forEach((n) => {
    n.read = true;
  });
  saveNotifications();
  renderNotifications();
  updateNotificationBadge();
}

