function inputValueForField(field, row = null) {
  if (state.activeModule === "timetable" && field.key === "session_type") {
    return deriveTimetableSessionTypeValue(row);
  }

  if (row && row[field.key] !== undefined && row[field.key] !== null) {
    if (field.type === "datetime-local") {
      return String(row[field.key]).slice(0, 16);
    }
    if (field.type === "time") {
      return String(row[field.key]).slice(0, 5);
    }
    return row[field.key];
  }

  if (field.default !== undefined) {
    return field.default;
  }

  if (field.type === "checkbox") {
    return false;
  }

  return "";
}

function renderEditorFields(module, row, mode) {
  els.editorBody.innerHTML = module.fields
    .map((field) => {
      const value = inputValueForField(field, row);
      const required = field.required || (mode === "create" && field.requiredOnCreate);
      const fieldClass = field.full ? "field full" : "field";

      if (field.type === "checkbox") {
        return `<label class="${fieldClass}">
          <span>${escapeHtml(field.label)}</span>
          <input type="checkbox" data-field="${field.key}" ${value ? "checked" : ""} />
        </label>`;
      }

      if (field.type === "select") {
        const options = field.optionsFrom
          ? state.optionCache[field.optionsFrom] || []
          : field.options || [];
        const optionHtml = [`<option value="">-- Select --</option>`]
          .concat(
            options.map((opt) => {
              const optionValue = opt.value ?? opt.id;
              const label = opt.label ?? optionLabel(field.optionsFrom, opt);
              const selected = String(value) === String(optionValue) ? "selected" : "";
              return `<option value="${escapeHtml(optionValue)}" ${selected}>${escapeHtml(
                label
              )}</option>`;
            })
          )
          .join("");

        return `<label class="${fieldClass}">
          <span>${escapeHtml(field.label)}${required ? " *" : ""}</span>
          <select data-field="${field.key}" ${required ? "required" : ""}>${optionHtml}</select>
          ${field.help ? `<small class="muted">${escapeHtml(field.help)}</small>` : ""}
        </label>`;
      }

      if (field.type === "textarea") {
        return `<label class="${fieldClass}">
          <span>${escapeHtml(field.label)}${required ? " *" : ""}</span>
          <textarea data-field="${field.key}" rows="4" ${required ? "required" : ""}>${escapeHtml(
            value
          )}</textarea>
          ${field.help ? `<small class="muted">${escapeHtml(field.help)}</small>` : ""}
        </label>`;
      }

      return `<label class="${fieldClass}">
        <span>${escapeHtml(field.label)}${required ? " *" : ""}</span>
        <input
          data-field="${field.key}"
          type="${field.type || "text"}"
          value="${escapeHtml(value)}"
          ${field.min !== undefined ? `min="${field.min}"` : ""}
          ${field.max !== undefined ? `max="${field.max}"` : ""}
          ${field.step !== undefined ? `step="${field.step}"` : ""}
          ${required ? "required" : ""}
        />
        ${field.help ? `<small class="muted">${escapeHtml(field.help)}</small>` : ""}
      </label>`;
    })
    .join("");
}

function openEditor(mode, row = null) {
  const module = MODULES[state.activeModule];
  if (!canEditInModule(module) && mode === "edit") {
    setStatus(els.dataMessage, "You do not have permission to edit here.", "error");
    return;
  }
  if (!canCreateInModule(module) && mode === "create") {
    setStatus(els.dataMessage, "You do not have permission to add here.", "error");
    return;
  }

  state.editor = { mode, module: module.key, row };
  els.editorTitle.textContent = `${mode === "create" ? "Create" : "Edit"} ${module.title}`;
  renderEditorFields(module, row, mode);
  bindTimetableEditorBehavior();
  els.dialog.showModal();
}

function closeEditor() {
  els.dialog.close();
  state.editor = { mode: "create", module: null, row: null };
}

async function sha256(text) {
  const encoded = new TextEncoder().encode(text);
  const digest = await crypto.subtle.digest("SHA-256", encoded);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function randomAnonymousId() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ0123456789";
  let suffix = "";
  for (let i = 0; i < 4; i += 1) {
    suffix += chars[Math.floor(Math.random() * chars.length)];
  }
  return `User#${suffix}`;
}

function castValue(field, inputEl) {
  if (field.type === "checkbox") {
    return inputEl.checked;
  }

  const raw = inputEl.value;
  if (raw === "") {
    return null;
  }

  if (field.type === "number") {
    return Number(raw);
  }
  if (field.type === "time") {
    return normalizeTime(raw);
  }
  return raw;
}

function shouldSkipRequiredValidation(module, field, context = {}) {
  if (!module || !field) {
    return false;
  }

  // For department users, branch is auto-injected from account scope.
  if (!isMainAdmin() && module.branchField && field.key === module.branchField) {
    return true;
  }

  if (module.key !== "timetable") {
    return false;
  }

  const { timetableIsBreak = false, timetableAllDaysBreak = false } = context;
  if (timetableAllDaysBreak && field.key === "day_of_week") {
    return true;
  }

  if (timetableIsBreak && ["subject_id", "teacher_id", "room_id", "batch"].includes(field.key)) {
    return true;
  }

  return false;
}

async function collectEditorPayload() {
  const module = MODULES[state.activeModule];
  const payload = {};

  const timetableSessionTypeEl =
    module.key === "timetable"
      ? els.editorBody.querySelector('[data-field="session_type"]')
      : null;
  const timetableIsBreakEl =
    module.key === "timetable"
      ? els.editorBody.querySelector('[data-field="is_break"]')
      : null;
  const timetableAllDaysBreakEl =
    module.key === "timetable"
      ? els.editorBody.querySelector('[data-field="apply_break_all_days"]')
      : null;
  const timetableSessionType =
    module.key === "timetable"
      ? timetableSessionTypeEl?.value || (timetableIsBreakEl?.checked ? "break" : "lecture")
      : null;
  const timetableIsBreak = module.key === "timetable" && timetableSessionType === "break";
  const timetableAllDaysBreak =
    module.key === "timetable" && timetableIsBreak && Boolean(timetableAllDaysBreakEl?.checked);

  for (const field of module.fields) {
    const inputEl = els.editorBody.querySelector(`[data-field="${field.key}"]`);
    if (!inputEl) {
      continue;
    }

    let required = field.required || (state.editor.mode === "create" && field.requiredOnCreate);
    if (
      shouldSkipRequiredValidation(module, field, {
        timetableIsBreak,
        timetableAllDaysBreak,
      })
    ) {
      required = false;
    }
    if (required && field.type !== "checkbox" && !inputEl.value) {
      throw new Error(`${field.label} is required.`);
    }

    const value = castValue(field, inputEl);

    if (field.key === "password_plain") {
      if (value) {
        payload.password_hash = await sha256(String(value));
      }
      continue;
    }

    payload[field.key] = value;
  }

  if (module.key === "students" && !payload.anonymous_id) {
    payload.anonymous_id = randomAnonymousId();
  }

  if (module.key === "timetable") {
    const sessionType = payload.session_type || (payload.is_break ? "break" : "lecture");
    const isBreak = sessionType === "break";

    if (isBreak) {
      payload.is_break = true;
      payload.break_name = "Break";
      payload.subject_id = null;
      payload.teacher_id = null;
      payload.room_id = null;
      payload.batch = null;
      payload.apply_break_all_days = Boolean(payload.apply_break_all_days);
    } else {
      payload.is_break = false;
      payload.break_name = null;
      payload.apply_break_all_days = false;

      const startMinutes = timeToMinutes(payload.start_time);
      const endMinutes = timeToMinutes(payload.end_time);
      if (startMinutes === null || endMinutes === null) {
        throw new Error("Start Time and End Time must be valid.");
      }

      const duration = endMinutes - startMinutes;
      const requiredDuration = timetableDurationForType(sessionType);
      const expectedLabel = requiredDuration === 120 ? "2 hours" : "1 hour";
      if (duration !== requiredDuration) {
        const classLabel = sessionType === "practical" ? "Practical" : "Lecture";
        throw new Error(`${classLabel} duration must be exactly ${expectedLabel}.`);
      }

      if (sessionType === "lecture") {
        payload.batch = null;
      }
    }

    delete payload.session_type;
  }

  if (["teachers", "students", "admin_panel_users"].includes(module.key)) {
    payload.updated_at = new Date().toISOString();
  }

  if (!isMainAdmin()) {
    const branchId = state.currentUser?.branchId;
    if (module.branchSelfScoped) {
      throw new Error("Branch creation is restricted for department users.");
    }
    if (module.branchField && branchId) {
      payload[module.branchField] = branchId;
    }
  }

  return payload;
}

async function applyBreakToAllDays(module, payload) {
  for (let day = 0; day < DAY_LABELS.length; day += 1) {
    const { error: deleteError } = await dbDeleteTimetableBreakByDay(module, payload, day);
    if (deleteError) {
      throw deleteError;
    }

    const dayPayload = {
      ...payload,
      day_of_week: day,
    };

    const { error: insertError } = await dbInsertModuleRow(module, dayPayload);
    if (insertError) {
      throw insertError;
    }
  }
}

async function saveEditor() {
  const module = MODULES[state.activeModule];
  try {
    const payload = await collectEditorPayload();
    delete payload[module.primaryKey];
    const applyBreakAllDays =
      module.key === "timetable" && payload.is_break && payload.apply_break_all_days;
    delete payload.apply_break_all_days;
    setStatus(els.dataMessage, "Saving...");

    if (applyBreakAllDays) {
      await applyBreakToAllDays(module, payload);
      addActivity(`Applied ${module.title} break to all days`, {
        moduleKey: module.key,
        details: "Synchronized break details for every day",
      });
      setStatus(els.dataMessage, `${module.title} break applied for all days.`, "success");
      closeEditor();
      await loadOptions();
      await loadKpis();
      await refreshModuleData();
      return;
    }

    if (state.editor.mode === "create") {
      const { error } = await dbInsertModuleRow(module, payload);
      if (error) {
        throw error;
      }
      addActivity(`Created ${module.title} record`, {
        moduleKey: module.key,
        details: `${module.title} creation via panel`,
      });
      setStatus(els.dataMessage, `${module.title} record created.`, "success");
    } else {
      const id = state.editor.row[module.primaryKey];
      const { error } = await dbUpdateModuleRowById(module, id, payload);
      if (error) {
        throw error;
      }
      addActivity(`Updated ${module.title} record`, {
        moduleKey: module.key,
        details: `${module.title} update via panel`,
      });
      setStatus(els.dataMessage, `${module.title} record updated.`, "success");
    }

    closeEditor();
    await loadOptions();
    await loadKpis();
    await refreshModuleData();
  } catch (error) {
    setStatus(els.dataMessage, error?.message || "Failed to save record.", "error");
  }
}

async function deleteRow(id) {
  const module = MODULES[state.activeModule];
  if (!canDeleteInModule(module)) {
    setStatus(els.dataMessage, "Delete permission denied.", "error");
    return;
  }

  const confirmed = confirm(`Delete this ${module.title} record? This cannot be undone.`);
  if (!confirmed) {
    return;
  }

  try {
    const { error } = await dbDeleteModuleRowById(module, id);
    if (error) {
      throw error;
    }

    addActivity(`Deleted ${module.title} record`, {
      moduleKey: module.key,
      details: `${module.title} deletion via panel`,
    });
    setStatus(els.dataMessage, `${module.title} record deleted.`, "success");
    await loadOptions();
    await loadKpis();
    await refreshModuleData();
  } catch (error) {
    setStatus(els.dataMessage, error?.message || "Failed to delete record.", "error");
  }
}

async function refreshModuleData(options = {}) {
  const { silent = false, forceDashboardRebuild = false, skipDashboardCharts = false } = options;
  const module = MODULES[state.activeModule];
  
  // Clear selected rows when refreshing data
  state.selectedRows.clear();
  updateBulkButtons();

  if (module.isBackup) {
    renderBackupModule();
    if (!silent) {
      setStatus(els.dataMessage, "");
    }
    state.live.lastSyncAt = Date.now();
    updateLiveHealthIndicators();
    return;
  }

  if (module.noTable) {
    await loadActivityFeed();
    renderQuickAccess({
      forceRebuild: forceDashboardRebuild,
      skipCharts: skipDashboardCharts,
    });
    renderActivityLog();
    renderTable();
    if (!silent) {
      setStatus(els.dataMessage, "Dashboard ready.", "success");
    }
    state.live.lastSyncAt = Date.now();
    updateLiveHealthIndicators();
    return;
  }

  if (!silent) {
    setStatus(els.dataMessage, `Loading ${module.title.toLowerCase()}...`);
  }
  const { data, error } = await dbSelectModuleRows(module);
  if (error) {
    throw error;
  }

  state.rows = data || [];
  renderTable();
  if (!silent) {
    setStatus(els.dataMessage, `${module.title} loaded.`, "success");
  }
  state.live.lastSyncAt = Date.now();
  updateLiveHealthIndicators();
}

// ─── DB BACKUP ──────────────────────────────────────────────────────────────

