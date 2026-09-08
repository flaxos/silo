/* operations.js — Project SILO Playable Operations Loop V0.1 Client Controller */
(() => {
  'use strict';
  const API = `${window.location.origin}/api`;
  const $ = id => document.getElementById(id);

  const state = {
    brief: { active_count: 0, active: [], archive: [] },
    selectedCaseId: '',
    currentDetail: null,
    archiveMode: false,
    autoPause: true,
    availableActions: [],
    selectedActionIdx: 0,
    isPlaying: false
  };

  function escapeHTML(str) {
    const d = document.createElement('div');
    d.textContent = str == null ? '' : String(str);
    return d.innerHTML;
  }

  function initOperations() {
    // Top mobile actions
    const btnPlay = $('ops-btn-play');
    if (btnPlay) {
      btnPlay.onclick = togglePlayPause;
    }
    const btnStep = $('ops-btn-step');
    if (btnStep) {
      btnStep.onclick = () => stepSim(1);
    }
    const btnStepHour = $('ops-btn-step-hour');
    if (btnStepHour) {
      btnStepHour.onclick = () => stepSim(6);
    }
    const selSpeed = $('ops-select-speed');
    if (selSpeed) {
      selSpeed.onchange = (e) => setSpeed(Number(e.target.value));
    }

    // Filter pills
    const btnActive = $('ops-btn-active');
    const btnArchive = $('ops-btn-archive');
    if (btnActive && btnArchive) {
      btnActive.onclick = () => {
        state.archiveMode = false;
        btnActive.classList.add('active');
        btnArchive.classList.remove('active');
        renderQueue();
      };
      btnArchive.onclick = () => {
        state.archiveMode = true;
        btnArchive.classList.add('active');
        btnActive.classList.remove('active');
        renderQueue();
      };
    }

    // Auto-pause toggle
    const chkAuto = $('ops-autopause');
    if (chkAuto) {
      chkAuto.onchange = (e) => { state.autoPause = e.target.checked; };
    }

    // Action choice dropdown
    const selAction = $('ops-action-select');
    if (selAction) {
      selAction.onchange = (e) => {
        state.selectedActionIdx = Number(e.target.value);
        updateActionExplainer();
      };
    }

    // Dispatch button
    const btnDispatch = $('ops-btn-dispatch');
    if (btnDispatch) {
      btnDispatch.onclick = handleDispatch;
    }

    // Locate button
    const btnLocate = $('ops-btn-locate');
    if (btnLocate) {
      btnLocate.onclick = handleLocateInSilo;
    }

    // Dossier tab buttons
    document.querySelectorAll('.ops-dossier-tab').forEach(tab => {
      tab.onclick = () => {
        document.querySelectorAll('.ops-dossier-tab').forEach(t => t.classList.remove('active'));
        document.querySelectorAll('.ops-dossier-panel').forEach(p => p.classList.remove('active'));
        tab.classList.add('active');
        const targetId = `ops-tab-${tab.dataset.dossierTab}`;
        const p = $(targetId);
        if (p) p.classList.add('active');
      };
    });

    // Save & load buttons
    const btnSave = $('ops-btn-save');
    if (btnSave) {
      btnSave.onclick = saveSession;
    }
    const btnLoad = $('ops-btn-load');
    if (btnLoad) {
      btnLoad.onclick = loadSession;
    }

    // Mobile navigation bar
    initMobileNav();

    // Initial fetch and periodic polling
    fetchBrief();
    setInterval(pollOperations, 1500);
  }

  function initMobileNav() {
    document.querySelectorAll('.mobile-nav-btn').forEach(btn => {
      btn.onclick = () => {
        const tabTarget = btn.dataset.tab;
        if (!tabTarget) return;
        
        // Update active nav button
        document.querySelectorAll('.mobile-nav-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        // Switch hash
        window.location.hash = tabTarget.replace('tab-', '');
      };
    });

    // Synchronize mobile nav with desktop hash changes
    window.addEventListener('hashchange', () => {
      const current = window.location.hash.replace('#', '') || 'operations';
      document.querySelectorAll('.mobile-nav-btn').forEach(b => {
        const target = b.dataset.tab.replace('tab-', '');
        if (target === current) {
          b.classList.add('active');
        } else {
          b.classList.remove('active');
        }
      });
    });
  }

  async function pollOperations() {
    if (document.hidden) return;
    await fetchBrief(false);
  }

  async function fetchBrief(autoSelect = true) {
    try {
      const res = await fetch(`${API}/operations/brief`);
      if (!res.ok) return;
      const data = await res.json();
      state.brief = data;

      // Update badge counts
      const openCount = data.active_count || 0;
      const badgeOpen = $('ops-open-count');
      if (badgeOpen) badgeOpen.textContent = `${openCount} OPEN`;
      const navBadge = $('nav-ops-badge');
      if (navBadge) navBadge.textContent = openCount;

      renderQueue();

      if (autoSelect && !state.selectedCaseId && data.active && data.active.length > 0) {
        selectCase(data.active[0].id);
      } else if (state.selectedCaseId) {
        fetchDetail(state.selectedCaseId);
      }
    } catch (e) {
      console.error('Error fetching operations brief:', e);
    }
  }

  async function fetchDetail(caseId) {
    if (!caseId) return;
    try {
      const res = await fetch(`${API}/operations/detail?id=${encodeURIComponent(caseId)}`);
      if (!res.ok) return;
      const detail = await res.json();
      if (detail && detail.id) {
        state.currentDetail = detail;
        renderDetail(detail);
      }
    } catch (e) {
      console.error('Error fetching case detail:', e);
    }
  }

  function renderQueue() {
    const listRoot = $('ops-case-list');
    if (!listRoot) return;

    const cases = state.archiveMode ? (state.brief.archive || []) : (state.brief.active || []);
    if (cases.length === 0) {
      listRoot.innerHTML = `<div class="ops-empty-state">No ${state.archiveMode ? 'outcomes' : 'open incidents'}. Time advances smoothly.</div>`;
      return;
    }

    listRoot.innerHTML = cases.map(c => {
      const isSelected = String(c.id) === String(state.selectedCaseId);
      const sevClass = `ops-sev-${c.severity >= 3 ? 'CRITICAL' : (c.severity >= 2 ? 'HIGH' : 'REVIEW')}`;
      const sevText = escapeHTML(c.severity_text || (c.severity >= 3 ? 'CRITICAL' : 'REVIEW'));
      const statusText = escapeHTML(c.status_text || c.status || '');

      return `
        <div class="ops-case-card ${isSelected ? 'active' : ''}" data-case-id="${escapeHTML(c.id)}">
          <div class="ops-card-top">
            <span class="ops-sev-pill ${sevClass}">${sevText}</span>
            <span class="ops-card-age">Age: ${Math.floor(c.age_ticks / 6)}h</span>
          </div>
          <div class="ops-card-title">${escapeHTML(c.title)}</div>
          <div class="ops-card-meta">
            <span>${escapeHTML(c.location || 'Level ?')}</span>
            <span>${statusText}</span>
          </div>
        </div>
      `;
    }).join('');

    // Attach click listeners to case cards
    listRoot.querySelectorAll('.ops-case-card').forEach(card => {
      card.onclick = () => selectCase(card.dataset.caseId);
    });
  }

  function selectCase(caseId) {
    state.selectedCaseId = String(caseId);
    renderQueue();
    fetchDetail(caseId);
  }

  function renderDetail(d) {
    const emptyEl = $('ops-detail-empty');
    const contentEl = $('ops-detail-content');
    if (!d || !d.id) {
      if (emptyEl) emptyEl.classList.remove('hidden');
      if (contentEl) contentEl.classList.add('hidden');
      return;
    }

    if (emptyEl) emptyEl.classList.add('hidden');
    if (contentEl) contentEl.classList.remove('hidden');

    // Header values
    const sevClass = `ops-sev-${d.severity >= 3 ? 'CRITICAL' : (d.severity >= 2 ? 'HIGH' : 'REVIEW')}`;
    const sevEl = $('ops-case-severity');
    if (sevEl) {
      sevEl.className = `ops-case-severity ops-sev-pill ${sevClass}`;
      sevEl.textContent = d.severity_text || 'ATTENTION';
    }
    const ageEl = $('ops-case-age');
    if (ageEl) {
      ageEl.textContent = `Age: ${Math.floor(d.age_ticks / 6)}h ${(d.age_ticks % 6) * 10}m`;
    }
    const statusEl = $('ops-case-status');
    if (statusEl) {
      statusEl.textContent = `Status: ${d.status_text || d.status}`;
    }
    const titleEl = $('ops-case-title');
    if (titleEl) {
      titleEl.textContent = (d.title || '').toUpperCase();
    }
    const locEl = $('ops-case-location');
    if (locEl) {
      locEl.textContent = d.location || 'Location Unknown';
    }

    // Top status summary for mobile sticky bar
    const topSum = $('ops-top-summary');
    if (topSum) {
      topSum.textContent = `${d.title} [${d.severity_text || 'ALERT'}]`;
    }

    // 1. OS Vital Signs & Telemetry Box
    const os = d.os_telemetry || {};
    const gaugesRoot = $('ops-gauges');
    if (gaugesRoot) {
      const gauges = os.gauges || [];
      gaugesRoot.innerHTML = gauges.map(g => `
        <div class="ops-gauge-row">
          <span class="ops-gauge-label">${escapeHTML(g.label)}:</span>
          <span class="ops-gauge-bar" style="color:${escapeHTML(g.color)}">${escapeHTML(g.bar)}</span>
          <span class="ops-gauge-val" style="color:${escapeHTML(g.color)}">${escapeHTML(g.val)}</span>
          <span class="ops-gauge-limit">(${escapeHTML(g.limit)})</span>
        </div>
      `).join('');
    }

    const chipsRoot = $('ops-chips');
    if (chipsRoot) {
      const chips = os.chips || [];
      chipsRoot.innerHTML = chips.map(ch => `
        <span class="ops-chip">
          <span>${escapeHTML(ch.icon)}</span>
          <span style="color:${escapeHTML(ch.color)}">${escapeHTML(ch.text)}</span>
        </span>
      `).join('');
    }

    const sitEl = $('ops-situation-text');
    if (sitEl) sitEl.textContent = os.situation || d.summary || '—';
    const stkEl = $('ops-stakes-text');
    if (stkEl) stkEl.textContent = os.stakes || 'Monitor situation.';

    // 2. Directive Console
    state.availableActions = d.available_actions || [];
    const selAction = $('ops-action-select');
    if (selAction) {
      selAction.innerHTML = state.availableActions.map((act, i) => `
        <option value="${i}" ${i === state.selectedActionIdx ? 'selected' : ''}>
          ${escapeHTML(act.label)}
        </option>
      `).join('');
    }
    updateActionExplainer();

    // 3. Deep Dossier
    renderDossier(d);
  }

  function updateActionExplainer() {
    if (!state.availableActions || state.availableActions.length === 0) return;
    const act = state.availableActions[state.selectedActionIdx] || state.availableActions[0];
    if (!act) return;

    const descEl = $('ops-exp-desc');
    if (descEl) descEl.textContent = act.description || '—';
    const whyEl = $('ops-exp-why');
    if (whyEl) whyEl.textContent = act.why_do_it || '—';
    const tradeEl = $('ops-exp-tradeoff');
    if (tradeEl) tradeEl.textContent = act.trade_off || '—';
    const boundEl = $('ops-exp-boundary');
    if (boundEl) boundEl.textContent = act.does_not_do || 'Does not bypass physical laws.';

    const blockedEl = $('ops-exp-blocked');
    const btnDispatch = $('ops-btn-dispatch');
    if (!act.enabled) {
      if (blockedEl) {
        blockedEl.textContent = `⛔ BLOCKED: ${act.reason || 'Requirement unmet'}`;
        blockedEl.classList.remove('hidden');
      }
      if (btnDispatch) btnDispatch.disabled = true;
    } else {
      if (blockedEl) blockedEl.classList.add('hidden');
      if (btnDispatch) btnDispatch.disabled = false;
    }
  }

  function renderDossier(d) {
    const brief = d.briefing || {};
    let fullHtml = '';

    if (brief.whats_happening) {
      fullHtml += `<strong>WHAT'S HAPPENING</strong>\n${escapeHTML(brief.whats_happening)}\n\n`;
    }
    if (brief.why) {
      fullHtml += `<strong>WHY? (WHY IT'S HAPPENING)</strong>\n${escapeHTML(brief.why)}\n\n`;
    }
    if (brief.why_it_matters) {
      fullHtml += `<strong>WHY IT MATTERS</strong>\n${escapeHTML(brief.why_it_matters)}\n\n`;
    }
    if (brief.root_problem) {
      fullHtml += `<span style="color:#ff3366"><strong>ROOT PROBLEM (FACILITY):</strong></span>\n${escapeHTML(brief.root_problem)}\n\n`;
      fullHtml += `<span style="color:#ff3366"><strong>INFORMATION STATUS (OFFICIAL):</strong></span>\n${escapeHTML(brief.information_problem)}\n\n`;
    }
    if (brief.player_authority) {
      fullHtml += `<span style="color:#ffd166"><strong>YOUR AUTHORITY (HEAD OF IT):</strong></span>\n${escapeHTML(brief.player_authority)}\n\n`;
    }
    if (brief.outside_authority) {
      fullHtml += `<span style="color:#06d6a0"><strong>OUTSIDE DIRECT IT AUTHORITY:</strong></span>\n${escapeHTML(brief.outside_authority)}\n\n`;
    }
    if (brief.what_we_know && brief.what_we_know.length > 0) {
      fullHtml += `<strong>WHAT WE KNOW</strong>\n${brief.what_we_know.map(k => '• ' + escapeHTML(k)).join('\n')}\n\n`;
    }

    const fullEl = $('ops-dossier-text');
    if (fullEl) fullEl.innerHTML = fullHtml || 'No detailed dossier recorded.';

    // History tab
    let histHtml = '';
    if (d.pending) {
      histHtml += `<span style="color:#ffd166">QUEUED DECISION: ${escapeHTML(String(d.pending).replace('_', ' '))} (executing next tick)</span>\n\n`;
    }
    histHtml += `<strong>DIRECTIVES ISSUED</strong>\n`;
    const actions = d.actions || [];
    if (actions.length === 0) {
      histHtml += 'No directives issued yet for this case.\n\n';
    } else {
      actions.forEach(a => {
        histHtml += `• Hour ${Math.floor(a.tick / 6)} · Directive: ${escapeHTML(String(a.action).replace('_', ' '))}\n  ${escapeHTML(a.effect)}\n\n`;
      });
    }
    histHtml += `<strong>SYSTEM LOGS & CONSEQUENCES</strong>\n`;
    const logs = [...(d.history || [])].reverse();
    logs.forEach(e => {
      histHtml += `• Hour ${Math.floor(e.tick / 6)}: ${escapeHTML(e.text)}\n`;
    });
    const histEl = $('ops-history-text');
    if (histEl) histEl.innerHTML = histHtml;

    // Tech telemetry tab
    let techHtml = `<strong>TECHNICAL DETAILS & ENGINE IDENTIFIERS</strong>\n\n`;
    const tech = d.technical_details || {};
    for (const [k, v] of Object.entries(tech)) {
      techHtml += `• <strong>${escapeHTML(k)}:</strong> ${escapeHTML(typeof v === 'object' ? JSON.stringify(v) : v)}\n`;
    }
    const techEl = $('ops-tech-text');
    if (techEl) techEl.innerHTML = techHtml;
  }

  async function handleDispatch() {
    if (!state.selectedCaseId || !state.availableActions || state.availableActions.length === 0) return;
    const act = state.availableActions[state.selectedActionIdx];
    if (!act || !act.enabled) return;

    setFeedback(`Queuing directive: ${act.label}…`);
    try {
      const res = await fetch(`${API}/operations/action`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ case_id: state.selectedCaseId, action: act.id })
      });
      const data = await res.json();
      setFeedback(data.message || (data.success ? 'Directive queued! Advancing time 1 tick…' : 'Failed to queue.'));

      // Automatically advance 1 tick so user sees the decision take effect
      await stepSim(1);
    } catch (e) {
      setFeedback(`Error: ${e.message}`);
    }
  }

  function handleLocateInSilo() {
    if (!state.currentDetail || !state.currentDetail.focus) {
      setFeedback('No physical location mapped for this case.');
      return;
    }
    const focus = state.currentDetail.focus;
    window.location.hash = 'physical';

    // Call physical viewer focus
    if (window.PhysicalViewer && typeof window.PhysicalViewer.focus === 'function') {
      window.PhysicalViewer.focus(focus.type || 'room', focus.id || focus.room_id);
    }
  }

  async function stepSim(ticks = 1) {
    try {
      const res = await fetch(`${API}/step`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticks: ticks })
      });
      const data = await res.json();
      if (data.operations_brief) {
        state.brief = data.operations_brief;
        renderQueue();
      }
      if (state.selectedCaseId) {
        await fetchDetail(state.selectedCaseId);
      }
      // Update top bar clock if present
      if (data.formatted_time) {
        const timeEl = $('clock-time-str');
        if (timeEl) timeEl.textContent = data.formatted_time;
        const tickEl = $('clock-tick-badge');
        if (tickEl) tickEl.textContent = `Tick ${data.current_tick}`;
      }
    } catch (e) {
      console.error('Error stepping sim:', e);
    }
  }

  async function togglePlayPause() {
    state.isPlaying = !state.isPlaying;
    const btn = $('ops-btn-play');
    if (btn) btn.textContent = state.isPlaying ? '⏸ Pause' : '▶ Play';
    try {
      await fetch(`${API}/${state.isPlaying ? 'resume' : 'pause'}`, { method: 'POST' });
    } catch (e) {
      console.error('Error toggling play:', e);
    }
  }

  async function setSpeed(ticks) {
    try {
      await fetch(`${API}/speed`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ticks_per_step: ticks, interval_sec: 0.5 })
      });
    } catch (e) {
      console.error('Error setting speed:', e);
    }
  }

  async function saveSession() {
    setFeedback('Saving session to host disk…');
    try {
      const res = await fetch(`${API}/operations/save`, { method: 'POST' });
      const data = await res.json();
      setFeedback(data.success ? `Session saved: ${data.path}` : `Save failed: ${data.error}`);
    } catch (e) {
      setFeedback(`Error saving: ${e.message}`);
    }
  }

  async function loadSession() {
    setFeedback('Restoring session from host disk…');
    try {
      const res = await fetch(`${API}/operations/load`, { method: 'POST' });
      const data = await res.json();
      if (data.success) {
        setFeedback(`Session restored at tick ${data.current_tick}!`);
        await fetchBrief();
      } else {
        setFeedback(`Load failed: ${data.error}`);
      }
    } catch (e) {
      setFeedback(`Error loading: ${e.message}`);
    }
  }

  function setFeedback(msg) {
    const el = $('ops-feedback');
    if (el) el.textContent = msg;
  }

  document.addEventListener('DOMContentLoaded', initOperations);
})();
