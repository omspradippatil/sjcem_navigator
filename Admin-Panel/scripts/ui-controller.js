function updateHeaderAndToolbar() {
  const module = MODULES[state.activeModule];
  els.moduleEyebrow.textContent = module.eyebrow;
  els.moduleTitle.textContent = module.title;

  const isDashboard = module.key === "dashboard";
  const isBackup = module.key === "db_backup";

  els.homeDashboard.classList.toggle("hidden", !isDashboard);
  els.tableSection.classList.toggle("hidden", isDashboard || isBackup);

  // Show/hide the backup panel
  let backupSection = document.getElementById("backup-section");
  if (isBackup && !backupSection) {
    backupSection = document.createElement("section");
    backupSection.id = "backup-section";
    backupSection.className = "grid-card";
    els.tableSection.parentNode.insertBefore(backupSection, els.tableSection.nextSibling);
  }
  if (backupSection) {
    backupSection.classList.toggle("hidden", !isBackup);
  }

  els.searchInput.disabled = isDashboard || isBackup;
  els.searchInput.placeholder =
    isDashboard || isBackup ? "Search disabled here" : "Search records...";

  const showAdd = !isDashboard && !isBackup && canCreateInModule(module);
  els.addBtn.classList.toggle("hidden", !showAdd);
  els.refreshBtn.classList.toggle("hidden", isBackup);
  els.refreshIntervalSelect.classList.toggle("hidden", isBackup);

  const showExportPdf = !isDashboard && !isBackup && !module.noTable;
  els.exportPdfBtn.classList.toggle("hidden", !showExportPdf);

  const showBulkDelete = !isDashboard && !isBackup && !module.noTable && canDeleteInModule(module);
  const showBulkEdit = !isDashboard && !isBackup && !module.noTable && canEditInModule(module);
  els.bulkDeleteBtn.classList.toggle("hidden", !showBulkDelete);
  els.bulkEditBtn.classList.toggle("hidden", !showBulkEdit);

  const showOcrSubjects = ["subjects", "timetable"].includes(module.key) && canCreateInModule(module);
  els.ocrSubjectsBtn.classList.toggle("hidden", !showOcrSubjects);

  updateBulkButtons();
}

function syncSelectAllCheckboxState() {
  const selectAll = document.getElementById("select-all-rows");
  if (!selectAll) {
    return;
  }

  const rowCheckboxes = Array.from(els.dataBody.querySelectorAll(".row-checkbox:not([disabled])"));
  if (!rowCheckboxes.length) {
    selectAll.checked = false;
    selectAll.indeterminate = false;
    selectAll.disabled = true;
    return;
  }

  rowCheckboxes.forEach((checkbox) => {
    checkbox.checked = state.selectedRows.has(String(checkbox.dataset.id));
  });

  const selectedCount = rowCheckboxes.filter((checkbox) => checkbox.checked).length;
  selectAll.disabled = false;
  selectAll.checked = selectedCount === rowCheckboxes.length;
  selectAll.indeterminate = selectedCount > 0 && selectedCount < rowCheckboxes.length;
}

function renderTable() {
  const module = MODULES[state.activeModule];
  if (module.noTable) {
    els.dataHead.innerHTML = "";
    els.dataBody.innerHTML = "";
    return;
  }

  const rows = getFilteredRows();
  const canEdit = canEditInModule(module);
  const canDelete = canDeleteInModule(module);
  const allowBulkOps = canEdit || canDelete;

  els.dataHead.innerHTML = `<tr>
    <th class="bulk-col"><input type="checkbox" id="select-all-rows" title="Select all" ${
      allowBulkOps ? "" : "disabled"
    }></th>
    ${module.columns
      .map((column) => `<th>${escapeHtml(column.label)}</th>`)
      .join("")}
    <th>Actions</th>
  </tr>`;

  if (!rows.length) {
    els.dataBody.innerHTML = `<tr><td colspan="${module.columns.length + 2}">No records found.</td></tr>`;
    syncSelectAllCheckboxState();
    return;
  }

  els.dataBody.innerHTML = rows
    .map((row) => {
      const cells = module.columns
        .map((column) => `<td>${escapeHtml(displayValue(column, row))}</td>`)
        .join("");

      const actionButtons = [
        canEdit
          ? `<button class="tiny" data-action="edit" data-id="${row[module.primaryKey]}">Edit</button>`
          : "",
        canDelete
          ? `<button class="tiny danger" data-action="delete" data-id="${row[module.primaryKey]}">Delete</button>`
          : "",
      ]
        .filter(Boolean)
        .join("");

      return `<tr data-row-id="${row[module.primaryKey]}">
        <td class="bulk-col"><input type="checkbox" class="row-checkbox" data-id="${row[module.primaryKey]}" ${
          allowBulkOps ? "" : "disabled"
        }></td>
        ${cells}
        <td><div class="row-actions">${actionButtons || "-"}</div></td>
      </tr>`;
    })
    .join("");

  syncSelectAllCheckboxState();
}

async function switchModule(moduleKey) {
  const allowed = getAllowedModuleKeys();
  if (!allowed.includes(moduleKey)) {
    setStatus(els.dataMessage, "This module is not allowed for your account.", "error");
    return;
  }

  state.activeModule = moduleKey;
  state.searchQuery = "";
  els.searchInput.value = "";
  state.selectedRows.clear();
  updateBulkButtons();

  buildModuleNav();
  updateHeaderAndToolbar();
  await refreshModuleData();
}

function toggleTheme() {
  const isLight = document.body.classList.contains("light-theme");
  if (isLight) {
    document.body.classList.remove("light-theme");
    localStorage.setItem("theme", "dark");
    els.themeToggle.title = "Switch to light mode";
    els.themeToggle.textContent = "🌙";
  } else {
    document.body.classList.add("light-theme");
    localStorage.setItem("theme", "light");
    els.themeToggle.title = "Switch to dark mode";
    els.themeToggle.textContent = "☀";
  }

  if (state.activeModule === "dashboard") {
    void renderCharts();
  }
}

function initTheme() {
  const savedTheme = localStorage.getItem("theme") || "dark";
  if (savedTheme === "light") {
    document.body.classList.add("light-theme");
    els.themeToggle.title = "Switch to dark mode";
    els.themeToggle.textContent = "☀";
  } else {
    els.themeToggle.title = "Switch to light mode";
    els.themeToggle.textContent = "🌙";
  }
}

function updateRowSelection(id, selected) {
  const normalizedId = String(id);
  if (selected) {
    state.selectedRows.add(normalizedId);
  } else {
    state.selectedRows.delete(normalizedId);
  }
}

function updateBulkButtons() {
  if (!els.bulkDeleteBtn || !els.bulkEditBtn) {
    return;
  }

  const hasSelection = state.selectedRows.size > 0;
  els.bulkDeleteBtn.disabled = !hasSelection;
  els.bulkEditBtn.disabled = !hasSelection;

  if (hasSelection) {
    els.bulkDeleteBtn.textContent = `Bulk Delete (${state.selectedRows.size})`;
    els.bulkEditBtn.textContent = `Bulk Edit (${state.selectedRows.size})`;
  } else {
    els.bulkDeleteBtn.textContent = 'Bulk Delete';
    els.bulkEditBtn.textContent = 'Bulk Edit';
  }

  syncSelectAllCheckboxState();
}

async function bulkDelete() {
  if (state.selectedRows.size === 0) return;
  
  const module = MODULES[state.activeModule];
  const canDelete = canDeleteInModule(module);
  if (!canDelete) {
    setStatus(els.dataMessage, "You don't have permission to delete records in this module.", "error");
    return;
  }
  
  const confirmMessage = `Are you sure you want to delete ${state.selectedRows.size} selected record(s)?`;
  if (!confirm(confirmMessage)) return;
  
  const ids = Array.from(state.selectedRows);
  try {
    const { error } = await dbBulkDeleteModuleRows(module, ids);
    
    if (error) throw error;
    
    addActivity(`Bulk deleted ${ids.length} ${module.title}`, {
      moduleKey: module.key,
      details: `Deleted IDs: ${ids.join(', ')}`,
    });
    
    state.selectedRows.clear();
    updateBulkButtons();
    await refreshModuleData();
    setStatus(els.dataMessage, `Successfully deleted ${ids.length} record(s).`, "success");
  } catch (error) {
    setStatus(els.dataMessage, `Bulk delete failed: ${error.message}`, "error");
  }
}

function getBulkEditableFields(module) {
  return (module.fields || []).filter(
    (field) =>
      ![
        "password_plain",
        "session_type",
        "apply_break_all_days",
      ].includes(field.key)
  );
}

function renderBulkValueInput(field) {
  if (!field) {
    return "";
  }

  if (field.type === "checkbox") {
    return `<label class="field">
      <span>Value</span>
      <select id="bulk-edit-value">
        <option value="true">True</option>
        <option value="false">False</option>
      </select>
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
          return `<option value="${escapeHtml(optionValue)}">${escapeHtml(label)}</option>`;
        })
      )
      .join("");
    return `<label class="field">
      <span>Value</span>
      <select id="bulk-edit-value">${optionHtml}</select>
    </label>`;
  }

  if (field.type === "textarea") {
    return `<label class="field full">
      <span>Value</span>
      <textarea id="bulk-edit-value" rows="4"></textarea>
    </label>`;
  }

  return `<label class="field">
    <span>Value</span>
    <input id="bulk-edit-value" type="${field.type || "text"}" ${
      field.min !== undefined ? `min="${field.min}"` : ""
    } ${field.max !== undefined ? `max="${field.max}"` : ""} ${
      field.step !== undefined ? `step="${field.step}"` : ""
    } />
  </label>`;
}

function castBulkValue(field, valueEl, shouldClearValue) {
  if (shouldClearValue) {
    return null;
  }

  if (!valueEl) {
    return null;
  }

  if (field.type === "checkbox") {
    return valueEl.value === "true";
  }

  if (valueEl.value === "") {
    return null;
  }

  if (field.type === "number") {
    return Number(valueEl.value);
  }
  if (field.type === "time") {
    return normalizeTime(valueEl.value);
  }
  return valueEl.value;
}

function closeBulkEditDialog() {
  const dialog = document.getElementById("bulk-edit-dialog");
  if (!dialog) {
    return;
  }
  dialog.close();
  dialog.remove();
}

async function applyBulkEdit() {
  const module = MODULES[state.activeModule];
  const ids = Array.from(state.selectedRows);
  if (!ids.length) {
    return;
  }

  const fields = getBulkEditableFields(module);
  const fieldSelect = document.getElementById("bulk-edit-field");
  const clearValueEl = document.getElementById("bulk-clear-value");

  if (!fieldSelect) {
    return;
  }

  const selectedField = fields.find((field) => field.key === fieldSelect.value);
  if (!selectedField) {
    setStatus(els.dataMessage, "Please choose a valid field for bulk edit.", "error");
    return;
  }

  if (!isMainAdmin() && module.branchField && selectedField.key === module.branchField) {
    setStatus(els.dataMessage, "Branch cannot be modified by department users.", "error");
    return;
  }

  const shouldClearValue = Boolean(clearValueEl?.checked) && selectedField.type !== "checkbox";
  const valueEl = document.getElementById("bulk-edit-value");
  const value = castBulkValue(selectedField, valueEl, shouldClearValue);

  if (
    selectedField.required &&
    selectedField.type !== "checkbox" &&
    (value === null || value === "")
  ) {
    setStatus(els.dataMessage, `${selectedField.label} cannot be empty.`, "error");
    return;
  }

  const payload = {
    [selectedField.key]: value,
  };
  if (["teachers", "students", "admin_panel_users"].includes(module.key)) {
    payload.updated_at = new Date().toISOString();
  }

  try {
    const { error } = await dbBulkUpdateModuleRows(module, ids, payload);
    if (error) {
      throw error;
    }

    addActivity(`Bulk updated ${ids.length} ${module.title} record(s)`, {
      moduleKey: module.key,
      details: `Field ${selectedField.key} updated for IDs: ${ids.join(", ")}`,
    });

    closeBulkEditDialog();
    state.selectedRows.clear();
    updateBulkButtons();
    await refreshModuleData();
    setStatus(els.dataMessage, `Bulk edit applied to ${ids.length} record(s).`, "success");
  } catch (error) {
    setStatus(els.dataMessage, `Bulk edit failed: ${error.message}`, "error");
  }
}

function openBulkEditDialog() {
  const module = MODULES[state.activeModule];
  const fields = getBulkEditableFields(module);

  if (!fields.length) {
    setStatus(els.dataMessage, "No editable fields available for bulk edit.", "error");
    return;
  }

  closeBulkEditDialog();

  const dialog = document.createElement("dialog");
  dialog.id = "bulk-edit-dialog";
  dialog.className = "editor-dialog";
  dialog.innerHTML = `
    <form method="dialog" class="editor-shell">
      <header class="editor-header">
        <h4>Bulk Edit ${escapeHtml(module.title)}</h4>
        <button type="button" class="icon-btn" id="bulk-edit-close">✕</button>
      </header>
      <div class="editor-body" style="grid-template-columns:1fr;">
        <p class="muted">Apply one field change to <strong>${state.selectedRows.size}</strong> selected records.</p>
        <label class="field">
          <span>Field</span>
          <select id="bulk-edit-field">
            ${fields
              .map((field) => `<option value="${escapeHtml(field.key)}">${escapeHtml(field.label)}</option>`)
              .join("")}
          </select>
        </label>
        <div id="bulk-edit-value-wrap">${renderBulkValueInput(fields[0])}</div>
        <label class="field" id="bulk-clear-wrap">
          <span>
            <input type="checkbox" id="bulk-clear-value" />
            Clear value (set NULL)
          </span>
        </label>
      </div>
      <footer class="editor-footer">
        <button type="button" class="btn btn-ghost" id="bulk-edit-cancel">Cancel</button>
        <button type="button" class="btn btn-primary" id="bulk-edit-apply">Apply</button>
      </footer>
    </form>`;

  document.body.appendChild(dialog);
  dialog.showModal();

  const fieldSelect = dialog.querySelector("#bulk-edit-field");
  const valueWrap = dialog.querySelector("#bulk-edit-value-wrap");
  const clearWrap = dialog.querySelector("#bulk-clear-wrap");

  const refreshValueInput = () => {
    const selectedField = fields.find((field) => field.key === fieldSelect.value);
    valueWrap.innerHTML = renderBulkValueInput(selectedField);
    clearWrap.classList.toggle("hidden", selectedField?.type === "checkbox");
  };

  fieldSelect.addEventListener("change", refreshValueInput);
  dialog.querySelector("#bulk-edit-close").addEventListener("click", closeBulkEditDialog);
  dialog.querySelector("#bulk-edit-cancel").addEventListener("click", closeBulkEditDialog);
  dialog.querySelector("#bulk-edit-apply").addEventListener("click", () => {
    void applyBulkEdit();
  });
  dialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    closeBulkEditDialog();
  });
}

function bulkEdit() {
  if (state.selectedRows.size === 0) return;

  const module = MODULES[state.activeModule];
  const canEdit = canEditInModule(module);
  if (!canEdit) {
    setStatus(els.dataMessage, "You don't have permission to edit records in this module.", "error");
    return;
  }

  openBulkEditDialog();
}

function exportToPdf() {
  const module = MODULES[state.activeModule];
  if (module.noTable) {
    setStatus(els.dataMessage, "This module doesn't have data to export.", "error");
    return;
  }

  const rows = getFilteredRows();
  if (!rows.length) {
    setStatus(els.dataMessage, "No data to export.", "error");
    return;
  }

  const { jsPDF } = window.jspdf;
  const doc = new jsPDF();
  
  // Title
  doc.setFontSize(18);
  doc.text(`${module.title} Export`, 14, 22);
  
  // Date
  doc.setFontSize(10);
  doc.text(`Generated: ${new Date().toLocaleString()}`, 14, 30);
  
  // Table data
  const tableData = rows.map(row => 
    module.columns.map(column => {
      const value = displayValue(column, row);
      return value || '';
    })
  );
  
  const headers = module.columns.map(column => column.label);
  
  // Generate table
  doc.autoTable({
    startY: 35,
    head: [headers],
    body: tableData,
    theme: 'grid',
    headStyles: {
      fillColor: [41, 195, 175],
      textColor: [255, 255, 255],
      fontStyle: 'bold'
    },
    alternateRowStyles: {
      fillColor: [245, 245, 245]
    },
    margin: { top: 35 }
  });
  
  // Save PDF
  const filename = `${module.title.toLowerCase()}_export_${new Date().toISOString().split('T')[0]}.pdf`;
  doc.save(filename);
  
  addActivity(`Exported ${module.title} to PDF`, {
    moduleKey: module.key,
    details: `Exported ${rows.length} records to ${filename}`,
  });
  
  setStatus(els.dataMessage, `Exported ${rows.length} records to PDF.`, "success");
}

