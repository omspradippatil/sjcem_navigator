function closeOcrDialog() {
  if (!els.ocrDialog) {
    return;
  }
  els.ocrDialog.close();
}

function normalizeSubjectCode(value) {
  return String(value || "")
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");
}

function normalizeLookupToken(value) {
  return normalizeSubjectCode(value);
}

function sanitizeSubjectName(value) {
  return String(value || "")
    .replace(/[_|]/g, " ")
    .replace(/[.,;:()\[\]{}]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
}

function generateSubjectCodeFromName(name, seenCodes) {
  const tokens = sanitizeSubjectName(name)
    .toUpperCase()
    .split(/\s+/)
    .filter(Boolean);

  let prefix = tokens.map((token) => token[0]).join("").slice(0, 4);
  if (prefix.length < 2) {
    prefix = tokens.join("").slice(0, 4);
  }
  if (prefix.length < 2) {
    prefix = "SUB";
  }

  let sequence = 1;
  let candidate = "";
  while (!candidate || seenCodes.has(candidate)) {
    candidate = normalizeSubjectCode(`${prefix}${String(sequence).padStart(3, "0")}`);
    sequence += 1;
  }
  return candidate;
}

function looksLikeSubjectHeaderLine(line) {
  const compact = String(line || "")
    .toLowerCase()
    .replace(/[^a-z0-9 ]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (!compact) {
    return true;
  }

  if (/^semester\s*[1-8]$/.test(compact)) {
    return true;
  }

  if (
    compact.includes("subject code") ||
    compact.includes("subject name") ||
    compact.includes("course code") ||
    compact === "subjects" ||
    compact === "subject"
  ) {
    return true;
  }

  return false;
}

function isTimetableLikeText(text) {
  const source = String(text || "");
  const hasDay = /\b(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i.test(source);
  const hasTimeRange = /\b\d{1,2}:\d{2}\s*(?:-|\u2013|\u2014|to)\s*\d{1,2}:\d{2}/i.test(source);
  return hasDay && hasTimeRange;
}

function dayIndexFromLine(line) {
  const match = String(line || "").match(
    /\b(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b/i
  );
  if (!match) {
    return null;
  }
  const dayName = match[1].toLowerCase();
  return DAY_LABELS.findIndex((label) => label.toLowerCase() === dayName);
}

function parseClockTo24(timeText, meridiemHint = "", previousHour = null) {
  const match = String(timeText || "").match(/^(\d{1,2}):(\d{2})$/);
  if (!match) {
    return null;
  }

  let hour = Number(match[1]);
  const minute = Number(match[2]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute) || minute < 0 || minute > 59) {
    return null;
  }

  const meridiem = String(meridiemHint || "").toUpperCase();
  if (meridiem === "AM") {
    if (hour === 12) {
      hour = 0;
    }
  } else if (meridiem === "PM") {
    if (hour < 12) {
      hour += 12;
    }
  } else if (previousHour !== null && hour <= 7 && previousHour >= 10) {
    hour += 12;
  }

  while (hour >= 24) {
    hour -= 24;
  }

  return {
    hour,
    time: `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`,
  };
}

function looksLikeRoomHint(value) {
  const raw = String(value || "").trim();
  if (!raw) {
    return false;
  }
  return /\d/.test(raw) || /\b(?:cl|lab|room|it[-\s]*l?\d+)\b/i.test(raw);
}

function parseTimetableSlotSegments(slotText) {
  const normalized = String(slotText || "").replace(/\s+/g, " ").trim();
  const isBreak = /^[-\u2013\u2014]+$/.test(normalized) || /^n\/?a$/i.test(normalized);
  if (!normalized || isBreak) {
    return [
      {
        is_break: true,
        break_name: "Break",
      },
    ];
  }

  const splitSegments = normalized
    .split(/\s*\/\s*/)
    .map((segment) => segment.trim())
    .filter(Boolean);

  const linePractical = /\bpractical\b|\blab\b|\bsplit\b/i.test(normalized) || splitSegments.length > 1;

  const parsed = [];
  splitSegments.forEach((segment) => {
    const parenParts = Array.from(segment.matchAll(/\(([^)]+)\)/g)).map((m) =>
      String(m[1] || "").trim()
    );

    let roomHint = "";
    let explicitName = "";
    parenParts.forEach((part) => {
      if (/\bpractical\b|\bsplit\b/i.test(part)) {
        return;
      }
      if (!roomHint && looksLikeRoomHint(part)) {
        roomHint = part;
        return;
      }
      if (!explicitName) {
        explicitName = part;
      }
    });

    const batchMatches = Array.from(segment.matchAll(/\bB\s*([12])\b/gi)).map(
      (m) => `B${m[1]}`
    );
    const uniqueBatches = Array.from(new Set(batchMatches));

    let content = segment
      .replace(/\([^)]*\)/g, " ")
      .replace(/\bpractical\b|\blab\b|\bsplit\b/gi, " ")
      .replace(/[\u2013\u2014]/g, "-")
      .replace(/\bB\s*[12]\b/gi, " ")
      .replace(/\s+/g, " ")
      .trim();

    const codeMatch = content.match(/\b([A-Z]{2,8})\b/);
    const code = codeMatch ? codeMatch[1].toUpperCase() : "";
    const baseNameSource =
      explicitName || (code ? content.replace(new RegExp(`\\b${code}\\b`, "i"), " ") : content);
    const inferredName = sanitizeSubjectName(baseNameSource);
    const name = inferredName || code || sanitizeSubjectName(content);

    const batches = uniqueBatches.length ? uniqueBatches : [null];
    batches.forEach((batch) => {
      parsed.push({
        is_break: false,
        code,
        name,
        batch,
        room_hint: roomHint,
        session_type: linePractical ? "practical" : "lecture",
      });
    });
  });

  return parsed;
}

function parseTimetableFromText(text) {
  const lines = String(text || "")
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean);

  const entries = [];
  const subjectHints = new Map();
  const generatedCodesByName = new Map();
  const usedCodes = new Set();
  const periodByDay = new Map();
  const lastHourByDay = new Map();
  let detectedSemester = null;
  let currentDay = null;

  lines.forEach((line) => {
    const cleanLine = line.replace(/^[^A-Za-z0-9]+/, "").trim();

    if (detectedSemester === null) {
      const semMatch = cleanLine.match(/\bsem(?:ester)?\s*[:\-]?\s*([1-8])\b/i);
      if (semMatch) {
        detectedSemester = Number(semMatch[1]);
      }
    }

    const dayIndex = dayIndexFromLine(cleanLine);
    if (dayIndex !== null && dayIndex >= 0) {
      currentDay = dayIndex;
      return;
    }

    const timeMatch = cleanLine.match(
      /^(\d{1,2}:\d{2})\s*(?:-|\u2013|\u2014|to)\s*(\d{1,2}:\d{2})(?:\s*([AP]M))?\s*(?:->|\u2192)\s*(.+)$/i
    );
    if (!timeMatch || currentDay === null) {
      return;
    }

    const previousHour = lastHourByDay.has(currentDay) ? lastHourByDay.get(currentDay) : null;
    const start = parseClockTo24(timeMatch[1], timeMatch[3], previousHour);
    if (!start) {
      return;
    }

    let end = parseClockTo24(timeMatch[2], timeMatch[3], start.hour);
    if (!end) {
      return;
    }
    if (timeToMinutes(end.time) <= timeToMinutes(start.time)) {
      const startMinutes = timeToMinutes(start.time);
      end = {
        hour: (start.hour + 1) % 24,
        time: minutesToTime(startMinutes + 60),
      };
    }
    lastHourByDay.set(currentDay, start.hour);

    const periodNumber = (periodByDay.get(currentDay) || 0) + 1;
    periodByDay.set(currentDay, periodNumber);

    const segments = parseTimetableSlotSegments(timeMatch[4]);
    segments.forEach((segment) => {
      if (segment.is_break) {
        entries.push({
          day_of_week: currentDay,
          period_number: periodNumber,
          start_time: start.time,
          end_time: end.time,
          is_break: true,
          break_name: segment.break_name || "Break",
          session_type: "break",
          batch: null,
          room_hint: "",
          subject_code: "",
          subject_name: "",
        });
        return;
      }

      let subjectCode = normalizeSubjectCode(segment.code || "");
      const subjectName = sanitizeSubjectName(segment.name || "");

      if (!subjectCode && subjectName) {
        const nameKey = normalizeLookupToken(subjectName);
        if (generatedCodesByName.has(nameKey)) {
          subjectCode = generatedCodesByName.get(nameKey);
        } else {
          subjectCode = generateSubjectCodeFromName(subjectName, usedCodes);
          generatedCodesByName.set(nameKey, subjectCode);
        }
      }

      if (subjectCode) {
        usedCodes.add(subjectCode);
        const prev = subjectHints.get(subjectCode);
        if (!prev) {
          subjectHints.set(subjectCode, {
            code: subjectCode,
            name: subjectName || subjectCode,
            is_lab: segment.session_type === "practical",
          });
        } else {
          if (subjectName.length > String(prev.name || "").length) {
            prev.name = subjectName;
          }
          prev.is_lab = prev.is_lab || segment.session_type === "practical";
        }
      }

      entries.push({
        day_of_week: currentDay,
        period_number: periodNumber,
        start_time: start.time,
        end_time: end.time,
        is_break: false,
        break_name: "",
        session_type: segment.session_type,
        batch: segment.batch || null,
        room_hint: segment.room_hint || "",
        subject_code: subjectCode,
        subject_name: subjectName,
      });
    });
  });

  return {
    entries,
    subjects: Array.from(subjectHints.values()),
    detectedSemester,
  };
}

function renderOcrTimetablePreview(rows) {
  if (!els.ocrSubjectPreview) {
    return;
  }

  if (!rows.length) {
    els.ocrSubjectPreview.innerHTML =
      '<p class="muted mini">No timetable rows detected. Check day headings and time format.</p>';
    return;
  }

  const tableRows = rows
    .map(
      (row) => `<tr>
      <td>${escapeHtml(DAY_LABELS[row.day_of_week] || "-")}</td>
      <td>${escapeHtml(`${row.start_time} - ${row.end_time}`)}</td>
      <td>${escapeHtml(row.session_type || "lecture")}</td>
      <td>${escapeHtml(row.is_break ? row.break_name || "Break" : row.subject_code || row.subject_name || "-")}</td>
      <td>${escapeHtml(row.batch || "-")}</td>
      <td>${escapeHtml(row.room_hint || "-")}</td>
    </tr>`
    )
    .join("");

  els.ocrSubjectPreview.innerHTML = `<div class="ocr-preview-table-wrap">
    <table class="ocr-preview-table">
      <thead>
        <tr>
          <th>Day</th>
          <th>Time</th>
          <th>Type</th>
          <th>Subject / Break</th>
          <th>Batch</th>
          <th>Room Hint</th>
        </tr>
      </thead>
      <tbody>${tableRows}</tbody>
    </table>
  </div>`;
}

function mostFrequentNumber(values, fallback = 1) {
  const counts = new Map();
  values.forEach((value) => {
    if (!Number.isFinite(Number(value))) {
      return;
    }
    const num = Number(value);
    counts.set(num, (counts.get(num) || 0) + 1);
  });

  let selected = fallback;
  let best = 0;
  counts.forEach((count, num) => {
    if (count > best) {
      best = count;
      selected = num;
    }
  });
  return selected;
}

function buildRoomLookup(branchId) {
  const lookup = new Map();
  const rooms = (state.optionCache.rooms || []).filter(
    (room) => String(room.branch_id || "") === String(branchId)
  );

  rooms.forEach((room) => {
    const candidates = [room.room_number, room.name];
    candidates.forEach((candidate) => {
      const token = normalizeLookupToken(candidate);
      if (token && !lookup.has(token)) {
        lookup.set(token, room.id);
      }
    });
  });

  return lookup;
}

async function applyOcrTimetableFromText(rawText) {
  const timetableModule = MODULES.timetable;
  const subjectModule = MODULES.subjects;
  const teacherSubjectsModule = MODULES.teacher_subjects;
  const teacherModule = MODULES.teachers;

  if (!canCreateInModule(timetableModule)) {
    setStatus(els.dataMessage, "You do not have permission to import timetable.", "error");
    return;
  }

  const branchId = els.ocrBranchSelect.value;
  if (!branchId) {
    setStatus(els.dataMessage, "Select target branch.", "error");
    return;
  }

  const parsed = parseTimetableFromText(rawText);
  if (!parsed.entries.length) {
    setStatus(els.dataMessage, "No timetable rows detected from pasted text.", "error");
    return;
  }

  const updateExisting = Boolean(els.ocrUpdateExisting.checked);

  try {
    setStatus(els.dataMessage, "Applying timetable import...");

    const { data: subjectsInBranch, error: subjectLoadError } = await dbFetchSubjectsByBranch(
      branchId,
      subjectModule
    );
    if (subjectLoadError) {
      throw subjectLoadError;
    }

    const subjectByCode = new Map();
    const subjectByName = new Map();
    (subjectsInBranch || []).forEach((subject) => {
      const codeToken = normalizeSubjectCode(subject.code);
      const nameToken = normalizeLookupToken(subject.name);
      if (codeToken) {
        subjectByCode.set(codeToken, subject);
      }
      if (nameToken) {
        subjectByName.set(nameToken, subject);
      }
    });

    const matchedSemesters = parsed.subjects
      .map((item) => subjectByCode.get(normalizeSubjectCode(item.code))?.semester)
      .filter((sem) => Number.isFinite(Number(sem)));
    const targetSemester = mostFrequentNumber(matchedSemesters, parsed.detectedSemester || 1);

    const missingSubjects = [];
    parsed.subjects.forEach((item) => {
      const codeToken = normalizeSubjectCode(item.code);
      const nameToken = normalizeLookupToken(item.name);
      if (subjectByCode.has(codeToken) || subjectByName.has(nameToken)) {
        return;
      }
      missingSubjects.push({
        name: item.name || item.code,
        code: item.code,
        branch_id: branchId,
        semester: targetSemester,
        credits: 3,
        is_lab: Boolean(item.is_lab),
      });
    });

    if (missingSubjects.length) {
      const { error: insertSubjectsError } = await dbInsertSubjects(missingSubjects, subjectModule);
      if (insertSubjectsError) {
        throw insertSubjectsError;
      }

      const { data: refreshedSubjects, error: refreshSubjectsError } = await dbFetchSubjectsByBranch(
        branchId,
        subjectModule
      );
      if (refreshSubjectsError) {
        throw refreshSubjectsError;
      }

      subjectByCode.clear();
      subjectByName.clear();
      (refreshedSubjects || []).forEach((subject) => {
        const codeToken = normalizeSubjectCode(subject.code);
        const nameToken = normalizeLookupToken(subject.name);
        if (codeToken) {
          subjectByCode.set(codeToken, subject);
        }
        if (nameToken) {
          subjectByName.set(nameToken, subject);
        }
      });
    }

    const subjectIds = Array.from(
      new Set(
        parsed.entries
          .filter((entry) => !entry.is_break)
          .map((entry) => {
            const byCode = subjectByCode.get(normalizeSubjectCode(entry.subject_code));
            if (byCode?.id) {
              return byCode.id;
            }
            const byName = subjectByName.get(normalizeLookupToken(entry.subject_name));
            return byName?.id || null;
          })
          .filter(Boolean)
      )
    );

    let teacherMappings = [];
    if (subjectIds.length) {
      const { data, error } = await dbFetchTeacherSubjectMappings(subjectIds, teacherSubjectsModule);
      if (error) {
        throw error;
      }
      teacherMappings = data || [];
    }

    const { data: activeTeachers, error: activeTeachersError } = await dbFetchActiveTeachersByBranch(
      branchId,
      teacherModule
    );
    if (activeTeachersError) {
      throw activeTeachersError;
    }
    const activeTeacherIds = new Set((activeTeachers || []).map((teacher) => String(teacher.id)));

    const subjectTeacherMap = new Map();
    const existingPairKeys = new Set();
    teacherMappings.forEach((mapping) => {
      const pairKey = `${mapping.teacher_id}|${mapping.subject_id}`;
      existingPairKeys.add(pairKey);
      if (!activeTeacherIds.has(String(mapping.teacher_id))) {
        return;
      }
      if (!subjectTeacherMap.has(String(mapping.subject_id))) {
        subjectTeacherMap.set(String(mapping.subject_id), mapping.teacher_id);
      }
    });

    if (subjectIds.length) {
      const { data: historicalRows, error: historicalError } = await dbFetchHistoricalTimetableMappings(
        branchId,
        subjectIds,
        timetableModule
      );
      if (historicalError) {
        throw historicalError;
      }

      const score = new Map();
      (historicalRows || []).forEach((row) => {
        if (!activeTeacherIds.has(String(row.teacher_id))) {
          return;
        }
        const key = `${row.subject_id}|${row.teacher_id}`;
        score.set(key, (score.get(key) || 0) + 1);
      });

      const bySubject = new Map();
      score.forEach((count, key) => {
        const [subjectId, teacherId] = key.split("|");
        const prev = bySubject.get(subjectId);
        if (!prev || count > prev.count) {
          bySubject.set(subjectId, { teacherId, count });
        }
      });

      bySubject.forEach((value, subjectId) => {
        if (!subjectTeacherMap.has(subjectId)) {
          subjectTeacherMap.set(subjectId, value.teacherId);
        }
      });
    }

    const roomLookup = buildRoomLookup(branchId);
    const rows = parsed.entries.map((entry) => {
      const codeToken = normalizeSubjectCode(entry.subject_code);
      const nameToken = normalizeLookupToken(entry.subject_name);
      const subject = codeToken
        ? subjectByCode.get(codeToken) || subjectByName.get(nameToken)
        : subjectByName.get(nameToken);
      const subjectId = entry.is_break ? null : subject?.id || null;
      const teacherId = subjectId ? subjectTeacherMap.get(String(subjectId)) || null : null;
      const roomId = entry.room_hint
        ? roomLookup.get(normalizeLookupToken(entry.room_hint)) || null
        : null;

      return {
        branch_id: branchId,
        semester: targetSemester,
        day_of_week: entry.day_of_week,
        period_number: entry.period_number,
        subject_id: subjectId,
        teacher_id: teacherId,
        room_id: entry.is_break ? null : roomId,
        start_time: entry.start_time,
        end_time: entry.end_time,
        is_break: Boolean(entry.is_break),
        break_name: entry.is_break ? entry.break_name || "Break" : null,
        batch: entry.batch || null,
        is_active: true,
      };
    });

    const daySet = Array.from(new Set(rows.map((row) => row.day_of_week)));
    const { data: existingSlots, error: existingSlotsError } = await dbFetchTimetableSlots(
      branchId,
      targetSemester,
      daySet,
      timetableModule
    );
    if (existingSlotsError) {
      throw existingSlotsError;
    }

    const existingByKey = new Map();
    (existingSlots || []).forEach((row) => {
      const key = `${row.day_of_week}|${row.period_number}|${String(row.batch || "").toUpperCase()}`;
      existingByKey.set(key, row.id);
    });

    let created = 0;
    let updated = 0;
    let skipped = 0;
    let teacherAssigned = 0;
    const missingPairs = [];

    for (const payload of rows) {
      if (payload.teacher_id) {
        teacherAssigned += 1;
        const pairKey = `${payload.teacher_id}|${payload.subject_id}`;
        if (!existingPairKeys.has(pairKey)) {
          existingPairKeys.add(pairKey);
          missingPairs.push({
            teacher_id: payload.teacher_id,
            subject_id: payload.subject_id,
          });
        }
      }

      const key = `${payload.day_of_week}|${payload.period_number}|${String(payload.batch || "").toUpperCase()}`;
      const existingId = existingByKey.get(key);
      if (existingId) {
        if (!updateExisting) {
          skipped += 1;
          continue;
        }
        const { error } = await dbUpdateTimetableById(existingId, payload, timetableModule);
        if (error) {
          throw error;
        }
        updated += 1;
      } else {
        const { error } = await dbInsertTimetable(payload, timetableModule);
        if (error) {
          throw error;
        }
        created += 1;
      }
    }

    if (missingPairs.length) {
      const { error } = await dbUpsertTeacherSubjectPairs(missingPairs, teacherSubjectsModule);
      if (error) {
        throw error;
      }
    }

    addActivity("OCR timetable import complete", {
      moduleKey: "timetable",
      details: `${created} created, ${updated} updated, ${teacherAssigned} teacher-linked`,
    });
    addNotification(
      `Timetable import done: ${created} new, ${updated} updated, ${teacherAssigned} teacher-linked`,
      "success"
    );

    closeOcrDialog();
    await loadOptions();
    await loadKpis();
    if (state.activeModule === "timetable" || state.activeModule === "subjects") {
      await refreshModuleData();
    }
    setStatus(
      els.dataMessage,
      `Timetable import complete. ${created} created, ${updated} updated, ${skipped} skipped.`,
      "success"
    );
  } catch (error) {
    setStatus(els.dataMessage, error?.message || "Failed to apply timetable import.", "error");
  }
}

function parseSubjectsFromOcrText(text) {
  const rows = [];
  const seenCodes = new Set();
  const lines = String(text || "")
    .split(/\r?\n/)
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter((line) => line.length >= 2);

  let semesterContext = 1;

  lines.forEach((line) => {
    const cleanedLine = line
      .replace(/^\s*(?:\d+\s*[.)\-:]\s*|[-*\u2022]+\s*)/, "")
      .replace(/\s+/g, " ")
      .trim();

    if (!cleanedLine || looksLikeSubjectHeaderLine(cleanedLine)) {
      return;
    }

    const headingSemMatch = cleanedLine.match(/\bsem(?:ester)?\s*[:\-]?\s*([1-8])\b/i);
    if (headingSemMatch && cleanedLine.split(/\s+/).length <= 4) {
      semesterContext = Number(headingSemMatch[1]);
      return;
    }

    const semMatch =
      cleanedLine.match(/\bsem(?:ester)?\s*[:\-]?\s*([1-8])\b/i) ||
      cleanedLine.match(/\b([1-8])\s*(?:st|nd|rd|th)?\s*sem(?:ester)?\b/i);
    const semester = Math.min(8, Math.max(1, Number(semMatch?.[1] || semesterContext || 1)));
    semesterContext = semester;

    const creditsMatch = cleanedLine.match(/\b([1-9])\s*(?:cr|credit|credits)\b/i);
    const credits = Math.min(10, Math.max(1, Number(creditsMatch?.[1] || 3)));

    const isLab = /\blab\b|\bpractical\b|\bprac\b|\bworkshop\b/i.test(cleanedLine);

    const delimitedParts = cleanedLine
      .split(/\s*\|\s*|\t+|\s*,\s*|\s{2,}/)
      .map((part) => part.trim())
      .filter(Boolean);

    const explicitCodeMatch = cleanedLine.match(/\b([A-Z]{2,}\s*[-_/]?\s*\d{2,}[A-Z]?)\b/i);
    let code = normalizeSubjectCode(explicitCodeMatch?.[1] || "");
    if (!code && delimitedParts.length) {
      const tokenCode = delimitedParts.find((part) =>
        /^(?=.*[a-zA-Z])(?=.*\d)[A-Z0-9\-_/]{3,20}$/i.test(part)
      );
      code = normalizeSubjectCode(tokenCode || "");
    }

    const nameFromColumns = delimitedParts
      .filter((part) => sanitizeSubjectName(part).length >= 3)
      .filter((part) => normalizeSubjectCode(part) !== code)
      .filter((part) => !/^\d$/.test(part))
      .filter((part) => !/^(?:lab|practical|prac|workshop)$/i.test(part))
      .filter((part) => !/^sem(?:ester)?\s*[:\-]?\s*[1-8]$/i.test(part))
      .sort((a, b) => b.length - a.length)[0];

    const nameFromInline = cleanedLine
      .replace(explicitCodeMatch?.[0] || "", " ")
      .replace(/\b[A-Z]{2,}\s*[-_/]?\s*\d{2,}[A-Z]?\b/gi, " ")
      .replace(/\b\d+\s*[.)\-:]\s*/g, " ")
      .replace(/sem(?:ester)?\s*[:\-]?\s*[1-8]/gi, " ")
      .replace(/\b[1-8]\s*(?:st|nd|rd|th)?\s*sem(?:ester)?\b/gi, " ")
      .replace(/\b[1-9]\s*(?:cr|credit|credits)\b/gi, " ")
      .replace(/\b(?:lab|practical|prac|workshop)\b/gi, " ");

    const resolvedName = sanitizeSubjectName(nameFromColumns || nameFromInline);

    let name = resolvedName;
    if (name.length < 2 && code) {
      name = `Subject ${code}`;
    }

    if (name.length < 2) {
      return;
    }

    if (!code) {
      code = generateSubjectCodeFromName(name, seenCodes);
    }
    if (!code || seenCodes.has(code)) {
      return;
    }

    rows.push({
      code,
      name,
      semester,
      credits,
      is_lab: isLab,
    });
    seenCodes.add(code);
  });

  return rows;
}

function renderOcrSubjectPreview(rows) {
  if (!els.ocrSubjectPreview) {
    return;
  }

  if (!rows.length) {
    els.ocrSubjectPreview.innerHTML =
      '<p class="muted mini">No valid subjects detected. Try a clearer image or edit extracted text.</p>';
    return;
  }

  const tableRows = rows
    .map(
      (row, index) => `<tr data-ocr-row="${index}">
      <td><input data-field="code" value="${escapeHtml(row.code)}" /></td>
      <td><input data-field="name" value="${escapeHtml(row.name)}" /></td>
      <td><input data-field="semester" type="number" min="1" max="8" value="${escapeHtml(
        row.semester
      )}" /></td>
      <td><input data-field="credits" type="number" min="1" max="10" value="${escapeHtml(
        row.credits
      )}" /></td>
      <td><input data-field="is_lab" type="checkbox" ${row.is_lab ? "checked" : ""} /></td>
    </tr>`
    )
    .join("");

  els.ocrSubjectPreview.innerHTML = `<div class="ocr-preview-table-wrap">
    <table class="ocr-preview-table">
      <thead>
        <tr>
          <th>Code</th>
          <th>Name</th>
          <th>Sem</th>
          <th>Credits</th>
          <th>Lab</th>
        </tr>
      </thead>
      <tbody>${tableRows}</tbody>
    </table>
  </div>`;
}

function readSubjectsFromPreview() {
  const rows = Array.from(els.ocrSubjectPreview.querySelectorAll("tbody tr"));
  const parsed = [];

  rows.forEach((row) => {
    const codeInput = row.querySelector('[data-field="code"]');
    const nameInput = row.querySelector('[data-field="name"]');
    const semInput = row.querySelector('[data-field="semester"]');
    const creditsInput = row.querySelector('[data-field="credits"]');
    const labInput = row.querySelector('[data-field="is_lab"]');

    const code = normalizeSubjectCode(codeInput?.value || "");
    const name = String(nameInput?.value || "").trim();
    const semester = Math.min(8, Math.max(1, Number(semInput?.value || 1)));
    const credits = Math.min(10, Math.max(1, Number(creditsInput?.value || 3)));
    const is_lab = Boolean(labInput?.checked);

    if (!code || name.length < 3) {
      return;
    }

    parsed.push({ code, name, semester, credits, is_lab });
  });

  return parsed;
}

function fillOcrBranchOptions() {
  if (!els.ocrBranchSelect) {
    return;
  }

  const isScopedDeptUser = !isMainAdmin() && state.currentUser?.branchId;
  const branchOptions = state.optionCache.branches || [];
  const optionHtml = branchOptions
    .map(
      (branch) =>
        `<option value="${escapeHtml(branch.id)}">${escapeHtml(branch.name || "Branch")} (${escapeHtml(
          branch.code || "-"
        )})</option>`
    )
    .join("");

  els.ocrBranchSelect.innerHTML = optionHtml;

  if (isScopedDeptUser) {
    els.ocrBranchSelect.value = String(state.currentUser.branchId);
    els.ocrBranchSelect.disabled = true;
  } else {
    els.ocrBranchSelect.disabled = false;
  }
}

function openOcrDialog() {
  const targetModule = state.activeModule === "timetable" ? MODULES.timetable : MODULES.subjects;
  if (!canCreateInModule(targetModule)) {
    setStatus(els.dataMessage, "You do not have permission to import data.", "error");
    return;
  }

  state.ocr.mode = targetModule.key === "timetable" ? "timetable" : "subjects";

  const dialogTitle = els.ocrDialog.querySelector(".editor-header h4");
  if (dialogTitle) {
    dialogTitle.textContent =
      state.ocr.mode === "timetable"
        ? "Import Timetable Using OCR / Text"
        : "Import Subjects Using OCR";
  }

  fillOcrBranchOptions();
  if (!els.ocrBranchSelect.value) {
    setStatus(els.dataMessage, "No branch available. Create branch first.", "error");
    return;
  }

  els.ocrImageInput.value = "";
  els.ocrTextOutput.value = "";
  els.ocrProgress.textContent = "";
  els.ocrUpdateExisting.checked = true;
  renderOcrSubjectPreview([]);
  els.ocrDialog.showModal();
}

async function runFreeOcr() {
  if (!window.Tesseract || typeof window.Tesseract.recognize !== "function") {
    setStatus(els.dataMessage, "OCR library failed to load. Refresh and try again.", "error");
    return;
  }

  const file = els.ocrImageInput.files?.[0];
  if (!file) {
    setStatus(els.dataMessage, "Choose image first (camera or upload).", "error");
    return;
  }

  try {
    els.ocrProgress.textContent = "Running OCR...";
    const result = await window.Tesseract.recognize(file, "eng", {
      logger: (message) => {
        if (message?.status === "recognizing text" && Number.isFinite(message.progress)) {
          const percentage = Math.round(message.progress * 100);
          els.ocrProgress.textContent = `OCR progress: ${percentage}%`;
        }
      },
    });
    const text = result?.data?.text || "";
    els.ocrTextOutput.value = text;
    parseOcrTextToPreview();
  } catch (error) {
    els.ocrProgress.textContent = "";
    setStatus(els.dataMessage, error?.message || "OCR failed.", "error");
  }
}

function parseOcrTextToPreview() {
  const rawText = els.ocrTextOutput.value || "";
  const useTimetableMode = state.ocr.mode === "timetable" || isTimetableLikeText(rawText);
  if (useTimetableMode) {
    const parsedTimetable = parseTimetableFromText(rawText);
    renderOcrTimetablePreview(parsedTimetable.entries);
    els.ocrProgress.textContent = `Parsed ${parsedTimetable.entries.length} timetable row(s).`;
    state.ocr.mode = "timetable";
    return;
  }

  const parsed = parseSubjectsFromOcrText(rawText);
  renderOcrSubjectPreview(parsed);
  els.ocrProgress.textContent = `Parsed ${parsed.length} candidate subject(s).`;
  state.ocr.mode = "subjects";
}

async function applyOcrSubjects() {
  const rawText = els.ocrTextOutput.value || "";
  if (state.activeModule === "timetable" || state.ocr.mode === "timetable" || isTimetableLikeText(rawText)) {
    await applyOcrTimetableFromText(rawText);
    return;
  }

  const subjectModule = MODULES.subjects;
  if (!canCreateInModule(subjectModule)) {
    setStatus(els.dataMessage, "You do not have permission to import subjects.", "error");
    return;
  }

  let subjects = readSubjectsFromPreview();
  if (!subjects.length) {
    const parsedFromText = parseSubjectsFromOcrText(els.ocrTextOutput.value || "");
    if (parsedFromText.length) {
      renderOcrSubjectPreview(parsedFromText);
      subjects = parsedFromText;
    }
  }

  if (!subjects.length) {
    setStatus(
      els.dataMessage,
      "No valid subjects to apply. Paste text in a line-by-line format and try again.",
      "error"
    );
    return;
  }

  const branchId = els.ocrBranchSelect.value;
  if (!branchId) {
    setStatus(els.dataMessage, "Select target branch.", "error");
    return;
  }

  const updateExisting = Boolean(els.ocrUpdateExisting.checked);

  try {
    setStatus(els.dataMessage, "Applying OCR subject changes...");

    const codes = subjects.map((item) => item.code);
    let existingMap = new Map();

    if (updateExisting && codes.length) {
      const { data: existingRows, error: existingError } = await dbFetchSubjectCodeRowsByBranch(
        branchId,
        subjectModule
      );
      if (existingError) {
        throw existingError;
      }
      existingMap = new Map(
        (existingRows || [])
          .map((row) => [normalizeSubjectCode(row.code), row])
          .filter(([code]) => codes.includes(code))
      );
    }

    let created = 0;
    let updated = 0;

    for (const item of subjects) {
      const payload = {
        name: item.name,
        code: item.code,
        branch_id: branchId,
        semester: item.semester,
        credits: item.credits,
        is_lab: item.is_lab,
      };

      const existing = existingMap.get(item.code);
      if (existing) {
        const { error } = await dbUpdateSubjectById(existing.id, payload, subjectModule);
        if (error) {
          throw error;
        }
        updated += 1;
      } else {
        const { error } = await dbInsertSubject(payload, subjectModule);
        if (error) {
          throw error;
        }
        created += 1;
      }
    }

    addActivity(`OCR subject import complete`, {
      moduleKey: "subjects",
      details: `${created} created, ${updated} updated`,
    });
    addNotification(`OCR import done: ${created} new, ${updated} updated`, "success");

    closeOcrDialog();
    await loadOptions();
    await loadKpis();
    if (state.activeModule === "subjects") {
      await refreshModuleData();
    }
    setStatus(
      els.dataMessage,
      `OCR import complete. ${created} created, ${updated} updated.`,
      "success"
    );
  } catch (error) {
    setStatus(els.dataMessage, error?.message || "Failed to apply OCR changes.", "error");
  }
}


