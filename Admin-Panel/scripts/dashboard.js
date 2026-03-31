function renderQuickAccess(options = {}) {
  const { forceRebuild = false, skipCharts = false } = options;
  if (!els.quickAccessGrid) {
    return;
  }
  if (!state.live.dashboardCardsBuilt || forceRebuild) {
    const allowed = getAllowedModuleKeys().filter((key) => key !== "dashboard");
    let html = allowed
      .map((key) => {
        const module = MODULES[key];
        return `<article class="quick-card" data-module-quick="${module.key}">
          <h5>${escapeHtml(module.title)}</h5>
          <p>${escapeHtml(module.description || "Open module")}</p>
        </article>`;
      })
      .join("");

    // Add system health card
    html += `
    <article class="quick-card health-card">
      <h5>System Health</h5>
      <div class="health-status">
        <div class="health-item">
          <span class="health-label">Live Sync:</span>
          <span class="health-value" id="health-live">Connecting...</span>
        </div>
        <div class="health-item">
          <span class="health-label">Last Sync:</span>
          <span class="health-value" id="health-last-sync">Waiting...</span>
        </div>
        <div class="health-item">
          <span class="health-label">Database:</span>
          <span class="health-value" id="health-db">Checking...</span>
        </div>
        <div class="health-item">
          <span class="health-label">API:</span>
          <span class="health-value" id="health-api">Checking...</span>
        </div>
        <div class="health-item">
          <span class="health-label">Last Backup:</span>
          <span class="health-value" id="health-backup">-</span>
        </div>
      </div>
      <button class="btn btn-secondary btn-sm" onclick="checkSystemHealth()">Refresh Health</button>
    </article>
  `;

    els.quickAccessGrid.innerHTML = html;
    state.live.dashboardCardsBuilt = true;
  }

  updateLiveHealthIndicators();
  void checkSystemHealth();

  const now = Date.now();
  const shouldRenderCharts =
    !skipCharts &&
    (forceRebuild ||
      !state.live.lastChartRenderAt ||
      now - state.live.lastChartRenderAt >= DASHBOARD_CHART_REFRESH_INTERVAL_MS);

  if (shouldRenderCharts) {
    state.live.lastChartRenderAt = now;
    void renderCharts();
  }
}

let charts = {};

function destroyCharts() {
  Object.values(charts).forEach((chart) => {
    if (chart && typeof chart.destroy === "function") {
      chart.destroy();
    }
  });
  charts = {};
}

async function getDashboardAnalyticsData() {
  const analytics = {
    students: [],
    activityRows: [],
    teacherCount: Number.parseInt(els.kpiTeachers?.textContent || "0", 10) || 0,
    studentCount: Number.parseInt(els.kpiStudents?.textContent || "0", 10) || 0,
  };

  if (!state.supabase || !state.unlocked) {
    return analytics;
  }

  try {
    const branchId = !isMainAdmin() ? state.currentUser?.branchId : null;
    const { data: studentsData, error: studentsError } = await dbFetchStudentAnalyticsRows(branchId);
    if (studentsError) {
      throw studentsError;
    }
    analytics.students = studentsData || [];
  } catch (error) {
    console.error("Unable to load student analytics", error);
  }

  try {
    const start = new Date();
    start.setDate(start.getDate() - 6);
    start.setHours(0, 0, 0, 0);
    const branchId = !isMainAdmin() ? state.currentUser?.branchId : null;
    const { data: activityData, error: activityError } = await dbFetchRecentActivityRows(
      start.toISOString(),
      branchId
    );
    if (activityError) {
      throw activityError;
    }
    analytics.activityRows = activityData || [];
  } catch (error) {
    console.error("Unable to load activity trend analytics", error);
  }

  return analytics;
}

async function renderCharts() {
  if (typeof window.Chart === "undefined") {
    return;
  }

  destroyCharts();

  const branchCtx = document.getElementById("branch-distribution-chart");
  const semesterCtx = document.getElementById("semester-distribution-chart");
  const ratioCtx = document.getElementById("teacher-student-ratio-chart");
  const activityCtx = document.getElementById("activity-trend-chart");

  if (!branchCtx && !semesterCtx && !ratioCtx && !activityCtx) {
    return;
  }

  const css = getComputedStyle(document.body);
  const textColor = (css.getPropertyValue("--text") || "#e8f4ff").trim();
  const mutedColor = (css.getPropertyValue("--muted") || "#9fb9cf").trim();
  const lineColor = (css.getPropertyValue("--line") || "rgba(167, 213, 255, 0.1)").trim();
  const primaryColor = (css.getPropertyValue("--primary") || "#29c3af").trim();
  const accentColor = (css.getPropertyValue("--accent") || "#35a6ea").trim();
  const warningColor = (css.getPropertyValue("--warning") || "#ffcc66").trim();

  const analytics = await getDashboardAnalyticsData();

  const chartOptions = {
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: {
        labels: {
          color: textColor,
          font: { size: 11 },
        },
      },
    },
    scales: {
      x: {
        ticks: { color: mutedColor, font: { size: 10 } },
        grid: { color: lineColor },
      },
      y: {
        ticks: { color: mutedColor, font: { size: 10 }, precision: 0 },
        grid: { color: lineColor },
      },
    },
  };

  const branchCounts = new Map();
  analytics.students.forEach((student) => {
    const key = student.branch_id ? String(student.branch_id) : "unknown";
    branchCounts.set(key, (branchCounts.get(key) || 0) + 1);
  });

  let branchLabels = state.optionCache.branches.map((branch) => branch.name || String(branch.id));
  let branchValues = state.optionCache.branches.map((branch) =>
    branchCounts.get(String(branch.id)) || 0
  );
  if (!branchLabels.length) {
    branchLabels = ["No Data"];
    branchValues = [1];
  }

  if (branchCtx) {
    charts.branch = new Chart(branchCtx, {
      type: "doughnut",
      data: {
        labels: branchLabels,
        datasets: [
          {
            data: branchValues,
            backgroundColor: [
              primaryColor,
              accentColor,
              "#ff6e7d",
              warningColor,
              "#34d399",
              "#f59e0b",
              "#2dd4bf",
              "#60a5fa",
            ],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: textColor, font: { size: 10 }, padding: 8 },
          },
          title: {
            display: true,
            text: "Students By Branch",
            color: textColor,
            font: { size: 13 },
          },
        },
      },
    });
  }

  const semesterCounts = Array(8).fill(0);
  analytics.students.forEach((student) => {
    const sem = Number.parseInt(student.semester, 10);
    if (Number.isInteger(sem) && sem >= 1 && sem <= 8) {
      semesterCounts[sem - 1] += 1;
    }
  });

  if (semesterCtx) {
    charts.semester = new Chart(semesterCtx, {
      type: "bar",
      data: {
        labels: ["Sem 1", "Sem 2", "Sem 3", "Sem 4", "Sem 5", "Sem 6", "Sem 7", "Sem 8"],
        datasets: [
          {
            label: "Students",
            data: semesterCounts,
            backgroundColor: primaryColor,
            borderRadius: 4,
          },
        ],
      },
      options: {
        ...chartOptions,
        plugins: {
          ...chartOptions.plugins,
          title: { display: true, text: "Semester Distribution", color: textColor, font: { size: 13 } },
        },
      },
    });
  }

  const teacherCount = analytics.teacherCount;
  const studentCount = analytics.studentCount;

  if (ratioCtx) {
    charts.ratio = new Chart(ratioCtx, {
      type: "pie",
      data: {
        labels: ["Teachers", "Students"],
        datasets: [
          {
            data: [teacherCount, studentCount],
            backgroundColor: [accentColor, primaryColor],
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: textColor, font: { size: 10 }, padding: 8 },
          },
          title: {
            display: true,
            text:
              teacherCount > 0
                ? `Teacher:Student Ratio (1:${Math.max(1, Math.round(studentCount / teacherCount))})`
                : "Teacher:Student Ratio",
            color: textColor,
            font: { size: 13 },
          },
        },
      },
    });
  }

  const trendLabels = [];
  const trendCounts = [];
  const trendMap = new Map();
  for (let i = 6; i >= 0; i -= 1) {
    const day = new Date();
    day.setDate(day.getDate() - i);
    day.setHours(0, 0, 0, 0);
    const key = day.toISOString().slice(0, 10);
    trendLabels.push(day.toLocaleDateString(undefined, { weekday: "short" }));
    trendMap.set(key, 0);
  }
  analytics.activityRows.forEach((entry) => {
    const key = String(entry.created_at || "").slice(0, 10);
    if (trendMap.has(key)) {
      trendMap.set(key, (trendMap.get(key) || 0) + 1);
    }
  });
  for (const key of trendMap.keys()) {
    trendCounts.push(trendMap.get(key) || 0);
  }

  if (activityCtx) {
    charts.activity = new Chart(activityCtx, {
      type: "line",
      data: {
        labels: trendLabels,
        datasets: [
          {
            label: "Admin Actions",
            data: trendCounts,
            borderColor: warningColor,
            backgroundColor: "rgba(255, 204, 102, 0.12)",
            fill: true,
            tension: 0.35,
          },
        ],
      },
      options: {
        ...chartOptions,
        plugins: {
          ...chartOptions.plugins,
          title: { display: true, text: "Weekly Activity Trend", color: textColor, font: { size: 13 } },
        },
      },
    });
  }
}

async function checkSystemHealth() {
  const dbEl = document.getElementById("health-db");
  const apiEl = document.getElementById("health-api");
  const backupEl = document.getElementById("health-backup");

  if (!dbEl || !apiEl || !backupEl) {
    return;
  }

  // Check database connection
  try {
    if (state.supabase) {
      const start = Date.now();
      const { error } = await dbCheckDbHealth();
      const duration = Date.now() - start;

      if (error) {
        dbEl.textContent = "Error";
        dbEl.style.color = "#ff6e7d";
      } else {
        dbEl.textContent = `OK (${duration}ms)`;
        dbEl.style.color = "#29c3af";
      }
    } else {
      dbEl.textContent = "Not connected";
      dbEl.style.color = "#ffcc66";
    }
  } catch (e) {
    dbEl.textContent = "Error";
    dbEl.style.color = "#ff6e7d";
  }

  // Check API reachability
  try {
    if (!navigator.onLine) {
      apiEl.textContent = "Offline";
      apiEl.style.color = "#ffcc66";
    } else {
      const baseUrl = deobfuscate(state.env.SUPABASE_URL);
      const anonKey = deobfuscate(state.env.SUPABASE_ANON_KEY);
      if (!baseUrl || !anonKey) {
        apiEl.textContent = "Config missing";
        apiEl.style.color = "#ffcc66";
      } else {
        const start = Date.now();
        const response = await fetch(`${baseUrl}/rest/v1/`, {
          method: "GET",
          headers: {
            apikey: anonKey,
            Authorization: `Bearer ${anonKey}`,
          },
          cache: "no-store",
        });
        const duration = Date.now() - start;
        if (response.ok || response.status === 401 || response.status === 404) {
          apiEl.textContent = `OK (${duration}ms)`;
          apiEl.style.color = "#29c3af";
        } else {
          apiEl.textContent = `Error (${response.status})`;
          apiEl.style.color = "#ff6e7d";
        }
      }
    }
  } catch (e) {
    apiEl.textContent = "Error";
    apiEl.style.color = "#ff6e7d";
  }

  // Check last backup
  const lastBackup = localStorage.getItem("lastBackup");
  if (lastBackup) {
    const backupDate = new Date(parseInt(lastBackup));
    backupEl.textContent = backupDate.toLocaleString();
    backupEl.style.color = "var(--text)";
  } else {
    backupEl.textContent = "Never";
    backupEl.style.color = "#ffcc66";
  }

  state.live.lastHealthCheckAt = Date.now();
  updateLiveHealthIndicators();
}


