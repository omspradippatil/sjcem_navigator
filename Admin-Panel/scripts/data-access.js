function applySelectScope(query, module) {
  if (isMainAdmin()) {
    return query;
  }

  const branchId = state.currentUser?.branchId;
  if (!branchId) {
    return query;
  }

  if (module.branchSelfScoped) {
    return query.eq("id", branchId);
  }

  if (module.branchField) {
    return query.eq(module.branchField, branchId);
  }

  return query;
}

function applyWriteScope(query, module) {
  if (isMainAdmin()) {
    return query;
  }

  const branchId = state.currentUser?.branchId;
  if (!branchId) {
    return query;
  }

  if (module.branchSelfScoped) {
    return query.eq("id", branchId);
  }

  if (module.branchField) {
    return query.eq(module.branchField, branchId);
  }

  return query;
}

async function dbInsertActivity(payload) {
  return state.supabase.from("admin_panel_activity").insert(payload);
}

async function dbLoadActivityFeed(limit, branchId) {
  let query = state.supabase
    .from("admin_panel_activity")
    .select("id,username,module_key,action,details,created_at")
    .order("created_at", { ascending: false })
    .limit(limit);

  if (branchId) {
    query = query.eq("branch_id", branchId);
  }

  return query;
}

async function dbFetchStudentAnalyticsRows(branchId) {
  let query = state.supabase.from("students").select("branch_id,semester");
  if (branchId) {
    query = query.eq("branch_id", branchId);
  }
  return query;
}

async function dbFetchRecentActivityRows(startIso, branchId) {
  let query = state.supabase
    .from("admin_panel_activity")
    .select("created_at,branch_id")
    .gte("created_at", startIso);

  if (branchId) {
    query = query.eq("branch_id", branchId);
  }

  return query;
}

async function dbCheckDbHealth() {
  return state.supabase.from("branches").select("id", { head: true, count: "exact" });
}

async function loadOptions() {
  const client = state.supabase;
  const branchScopeId = !isMainAdmin() ? state.currentUser?.branchId : null;

  let branchesQuery = client.from("branches").select("id,name,code").order("name");
  let teachersQuery = client.from("teachers").select("id,name,email,branch_id").order("name");
  let roomsQuery = client.from("rooms").select("id,name,room_number,branch_id").order("name");
  let subjectsQuery = client.from("subjects").select("id,name,code,branch_id,is_lab").order("name");
  let pollsQuery = client.from("polls").select("id,title,branch_id").order("created_at", {
    ascending: false,
  });
  let panelUsersQuery = client
    .from("admin_panel_users")
    .select("id,username,display_name,branch_id")
    .order("created_at", { ascending: false });

  if (branchScopeId) {
    branchesQuery = branchesQuery.eq("id", branchScopeId);
    teachersQuery = teachersQuery.eq("branch_id", branchScopeId);
    roomsQuery = roomsQuery.eq("branch_id", branchScopeId);
    subjectsQuery = subjectsQuery.eq("branch_id", branchScopeId);
    pollsQuery = pollsQuery.eq("branch_id", branchScopeId);
    panelUsersQuery = panelUsersQuery.eq("branch_id", branchScopeId);
  }

  const [branchesRes, teachersRes, roomsRes, subjectsRes, pollsRes, panelUsersRes] =
    await Promise.all([
      branchesQuery,
      teachersQuery,
      roomsQuery,
      subjectsQuery,
      pollsQuery,
      panelUsersQuery,
    ]);

  const errors = [branchesRes, teachersRes, roomsRes, subjectsRes, pollsRes]
    .map((r) => r.error)
    .filter(Boolean);
  if (errors.length) {
    throw errors[0];
  }

  state.optionCache.branches = branchesRes.data || [];
  state.optionCache.teachers = teachersRes.data || [];
  state.optionCache.rooms = roomsRes.data || [];
  state.optionCache.subjects = subjectsRes.data || [];
  state.optionCache.polls = pollsRes.data || [];
  state.optionCache.panelUsers = panelUsersRes.error ? [] : panelUsersRes.data || [];
}

async function loadKpis() {
  const client = state.supabase;
  const branchScopeId = !isMainAdmin() ? state.currentUser?.branchId : null;

  const countQuery = (table, field = "id", scopeField = null) => {
    let query = client.from(table).select(field, { count: "exact", head: true });
    if (branchScopeId && scopeField) {
      query = query.eq(scopeField, branchScopeId);
    }
    return query;
  };

  const [teachers, students, rooms, timetable, branches, subjects, polls, panelUsers] =
    await Promise.all([
      countQuery("teachers", "id", "branch_id"),
      countQuery("students", "id", "branch_id"),
      countQuery("rooms", "id", "branch_id"),
      countQuery("timetable", "id", "branch_id"),
      branchScopeId
        ? client.from("branches").select("id", { count: "exact", head: true }).eq("id", branchScopeId)
        : countQuery("branches"),
      countQuery("subjects", "id", "branch_id"),
      countQuery("polls", "id", "branch_id"),
      isMainAdmin()
        ? countQuery("admin_panel_users")
        : countQuery("admin_panel_users", "id", "branch_id"),
    ]);

  const firstError = [teachers, students, rooms, timetable, branches, subjects, polls]
    .map((res) => res.error)
    .find(Boolean);
  if (firstError) {
    throw firstError;
  }

  els.kpiTeachers.textContent = String(teachers.count ?? 0);
  els.kpiStudents.textContent = String(students.count ?? 0);
  els.kpiRooms.textContent = String(rooms.count ?? 0);
  els.kpiTimetable.textContent = String(timetable.count ?? 0);
  els.kpiBranches.textContent = String(branches.count ?? 0);
  els.kpiSubjects.textContent = String(subjects.count ?? 0);
  els.kpiPolls.textContent = String(polls.count ?? 0);
  els.kpiPanelUsers.textContent = panelUsers.error ? "N/A" : String(panelUsers.count ?? 0);
}

async function dbDeleteTimetableBreakByDay(module, payload, day) {
  let query = state.supabase
    .from(module.table)
    .delete()
    .eq("branch_id", payload.branch_id)
    .eq("semester", payload.semester)
    .eq("day_of_week", day)
    .eq("period_number", payload.period_number);
  query = applyWriteScope(query, module);
  return query;
}

async function dbInsertModuleRow(module, payload) {
  let query = state.supabase.from(module.table).insert(payload);
  query = applyWriteScope(query, module);
  return query;
}

async function dbUpdateModuleRowById(module, id, payload) {
  let query = state.supabase
    .from(module.table)
    .update(payload)
    .eq(module.primaryKey, id);
  query = applyWriteScope(query, module);
  return query;
}

async function dbDeleteModuleRowById(module, id) {
  let query = state.supabase
    .from(module.table)
    .delete()
    .eq(module.primaryKey, id);
  query = applyWriteScope(query, module);
  return query;
}

async function dbSelectModuleRows(module) {
  let query = state.supabase.from(module.table).select(module.select);
  query = applySelectScope(query, module);

  if (module.orderBy) {
    query = query.order(module.orderBy.column, { ascending: module.orderBy.ascending });
  }

  return query;
}

async function dbBulkDeleteModuleRows(module, ids) {
  let query = state.supabase
    .from(module.table)
    .delete()
    .in(module.primaryKey, ids);
  query = applyWriteScope(query, module);
  return query;
}

async function dbBulkUpdateModuleRows(module, ids, payload) {
  let query = state.supabase.from(module.table).update(payload).in(module.primaryKey, ids);
  query = applyWriteScope(query, module);
  return query;
}

async function fetchTableData(tDef) {
  const { data, error } = await state.supabase.from(tDef.key).select(tDef.select);
  if (error) {
    throw new Error(`Failed to fetch ${tDef.key}: ${error.message}`);
  }
  return data || [];
}

async function dbUpsertRestoreChunk(tableKey, chunk) {
  return state.supabase
    .from(tableKey)
    .upsert(chunk, { onConflict: "id", ignoreDuplicates: false });
}

async function dbFetchSubjectsByBranch(branchId, subjectModule) {
  let query = state.supabase
    .from("subjects")
    .select("id,name,code,branch_id,semester,is_lab")
    .eq("branch_id", branchId);
  query = applySelectScope(query, subjectModule);
  return query;
}

async function dbInsertSubjects(rows, subjectModule) {
  let query = state.supabase.from("subjects").insert(rows);
  query = applyWriteScope(query, subjectModule);
  return query;
}

async function dbFetchTeacherSubjectMappings(subjectIds, teacherSubjectsModule) {
  let query = state.supabase
    .from("teacher_subjects")
    .select("teacher_id,subject_id")
    .in("subject_id", subjectIds);
  query = applySelectScope(query, teacherSubjectsModule);
  return query;
}

async function dbFetchActiveTeachersByBranch(branchId, teacherModule) {
  let query = state.supabase
    .from("teachers")
    .select("id,branch_id,is_active")
    .eq("branch_id", branchId)
    .eq("is_active", true);
  query = applySelectScope(query, teacherModule);
  return query;
}

async function dbFetchHistoricalTimetableMappings(branchId, subjectIds, timetableModule) {
  let query = state.supabase
    .from("timetable")
    .select("subject_id,teacher_id")
    .eq("branch_id", branchId)
    .not("subject_id", "is", null)
    .not("teacher_id", "is", null)
    .in("subject_id", subjectIds);
  query = applySelectScope(query, timetableModule);
  return query;
}

async function dbFetchTimetableSlots(branchId, semester, daySet, timetableModule) {
  let query = state.supabase
    .from("timetable")
    .select("id,day_of_week,period_number,batch")
    .eq("branch_id", branchId)
    .eq("semester", semester)
    .in("day_of_week", daySet);
  query = applySelectScope(query, timetableModule);
  return query;
}

async function dbUpdateTimetableById(existingId, payload, timetableModule) {
  let query = state.supabase.from("timetable").update(payload).eq("id", existingId);
  query = applyWriteScope(query, timetableModule);
  return query;
}

async function dbInsertTimetable(payload, timetableModule) {
  let query = state.supabase.from("timetable").insert(payload);
  query = applyWriteScope(query, timetableModule);
  return query;
}

async function dbUpsertTeacherSubjectPairs(missingPairs, teacherSubjectsModule) {
  let query = state.supabase
    .from("teacher_subjects")
    .upsert(missingPairs, { onConflict: "teacher_id,subject_id" });
  query = applyWriteScope(query, teacherSubjectsModule);
  return query;
}

async function dbFetchSubjectCodeRowsByBranch(branchId, subjectModule) {
  let query = state.supabase
    .from("subjects")
    .select("id,code,branch_id")
    .eq("branch_id", branchId);
  query = applySelectScope(query, subjectModule);
  return query;
}

async function dbUpdateSubjectById(subjectId, payload, subjectModule) {
  let query = state.supabase
    .from("subjects")
    .update(payload)
    .eq("id", subjectId);
  query = applyWriteScope(query, subjectModule);
  return query;
}

async function dbInsertSubject(payload, subjectModule) {
  let query = state.supabase.from("subjects").insert(payload);
  query = applyWriteScope(query, subjectModule);
  return query;
}
