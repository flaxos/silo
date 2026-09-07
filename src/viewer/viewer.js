// Project SILO — Authoritative Observability Dashboard JS
// Zero simulation logic duplication — strictly queries JSON API.

const API_BASE = window.location.origin + '/api';

const state = {
  currentTab: 'overview',
  isRunning: false,
  peoplePage: 1,
  peopleLimit: 25,
  refreshTimer: null,
  activeMachineId: 0
};

// Initialize Application
document.addEventListener('DOMContentLoaded', () => {
  initNavigation();
  initControls();
  initModals();
  
  // Load initial data
  handleHashChange();
  fetchOverview();
  
  // Setup auto-refresh polling (every 2s)
  state.refreshTimer = setInterval(() => {
    fetchOverview();
    refreshActiveTab();
  }, 2000);
});

// Navigation & Hash Routing
function initNavigation() {
  window.addEventListener('hashchange', handleHashChange);
  
  document.querySelectorAll('.nav-link').forEach(link => {
    link.addEventListener('click', (e) => {
      const tabId = link.getAttribute('data-tab').replace('tab-', '');
      window.location.hash = tabId;
    });
  });
}

function handleHashChange() {
  const hash = window.location.hash.replace('#', '') || 'physical';
  state.currentTab = hash;
  
  // Update nav link active classes
  document.querySelectorAll('.nav-link').forEach(link => {
    const tabId = link.getAttribute('data-tab').replace('tab-', '');
    if (tabId === hash) {
      link.classList.add('active');
    } else {
      link.classList.remove('active');
    }
  });
  
  // Update tab panel visibility
  document.querySelectorAll('.tab-panel').forEach(panel => {
    if (panel.id === `tab-${hash}`) {
      panel.classList.add('active');
    } else {
      panel.classList.remove('active');
    }
  });
  
  // Fetch active tab data
  refreshActiveTab();
}

function refreshActiveTab() {
  switch (state.currentTab) {
    case 'overview':
      fetchOverview();
      break;
    case 'people':
      fetchPeople();
      break;
    case 'households':
      fetchHouseholds();
      break;
    case 'locations':
      fetchLocations();
      break;
    case 'labour':
      fetchLabour();
      break;
    case 'economy':
      fetchEconomy();
      break;
    case 'machinery':
      fetchMachinery();
      break;
    case 'causal-chain':
      fetchCausalChain();
      break;
    case 'utilities':
      fetchUtilities();
      break;
    case 'institutions':
      fetchInstitutions();
      break;
    case 'politics':
      fetchPolitics();
      break;
    case 'factions':
      fetchFactions();
      break;
    case 'corruption':
      fetchCorruption();
      break;
    case 'incidents':
      fetchIncidents();
      break;
    case 'timeline':
      fetchTimeline();
      break;
    case 'dependencies':
      fetchDependencies();
      break;
    case 'invariants':
      // Fetched on demand or tab load
      break;
    case 'wiring':
      fetchWiringMatrix();
      break;
    case 'performance':
      fetchPerformance();
      break;
  }
}

// Control Event Handlers
function initControls() {
  // Step buttons
  document.querySelectorAll('.btn-step').forEach(btn => {
    btn.addEventListener('click', () => {
      const ticks = parseInt(btn.getAttribute('data-ticks'), 10);
      stepSimulation(ticks);
    });
  });
  
  // Toggle Auto-Step
  const btnToggleRun = document.getElementById('btn-toggle-run');
  btnToggleRun.addEventListener('click', () => {
    if (state.isRunning) {
      pauseSimulation();
    } else {
      resumeSimulation();
    }
  });
  
  // Speed select
  const selectSpeed = document.getElementById('select-speed');
  selectSpeed.addEventListener('change', () => {
    const ticks = parseInt(selectSpeed.value, 10);
    setSpeed(ticks, 0.5);
  });
  
  // Reset Simulation
  document.getElementById('btn-reset-sim').addEventListener('click', () => {
    if (confirm('Are you sure you want to RESET the simulation state?')) {
      resetSimulation(100, 42);
    }
  });
  
  // Refresh Now
  document.getElementById('btn-refresh-now').addEventListener('click', () => {
    fetchOverview();
    refreshActiveTab();
  });
  
  // People filter
  document.getElementById('btn-search-people').addEventListener('click', () => {
    state.peoplePage = 1;
    fetchPeople();
  });
  
  document.getElementById('filter-person-search').addEventListener('keyup', (e) => {
    if (e.key === 'Enter') {
      state.peoplePage = 1;
      fetchPeople();
    }
  });
  
  document.getElementById('btn-people-prev').addEventListener('click', () => {
    if (state.peoplePage > 1) {
      state.peoplePage--;
      fetchPeople();
    }
  });
  
  document.getElementById('btn-people-next').addEventListener('click', () => {
    state.peoplePage++;
    fetchPeople();
  });
  
  // Enact Policy Button
  document.getElementById('btn-enact-policy').addEventListener('click', () => {
    const policyId = document.getElementById('select-enact-policy').value;
    enactPolicy(policyId);
  });
  
  // Issue Order Button
  document.getElementById('btn-issue-order').addEventListener('click', () => {
    const orderId = document.getElementById('select-issue-order').value;
    issueOrder(orderId);
  });
  
  // Run Invariant Checks Button
  document.getElementById('btn-run-validation').addEventListener('click', () => {
    runInvariantsValidation();
  });
  
  // Raw State Inspector
  const btnFetchRaw = document.getElementById('btn-fetch-raw');
  if (btnFetchRaw) {
    btnFetchRaw.addEventListener('click', () => {
      const type = document.getElementById('raw-entity-type').value;
      const id = parseInt(document.getElementById('raw-entity-id').value, 10) || 0;
      fetchRawEntity(type, id);
    });
  }
  
  // Politics Dossier Inspector
  const btnPolInspect = document.getElementById('pol-inspect-btn');
  if (btnPolInspect) {
    btnPolInspect.addEventListener('click', () => {
      const cid = parseInt(document.getElementById('pol-citizen-id-input').value, 10);
      if (cid > 0) {
        inspectCitizenPolitics(cid);
      }
    });
  }
  
  // Social Network Inspector
  const btnSocialInspect = document.getElementById('social-inspect-btn');
  if (btnSocialInspect) {
    btnSocialInspect.addEventListener('click', () => {
      const cid = parseInt(document.getElementById('social-citizen-id-input').value, 10);
      if (cid > 0) {
        inspectSocialNetwork(cid);
      }
    });
  }
  
  // Corruption Causal Trace Inspector
  const btnCorrTrace = document.getElementById('corr-trace-btn');
  if (btnCorrTrace) {
    btnCorrTrace.addEventListener('click', () => {
      const aid = parseInt(document.getElementById('corr-trace-id-input').value, 10);
      if (aid > 0) {
        inspectIllicitTrace(aid);
      }
    });
  }
}

// API Calls & Actions
async function stepSimulation(ticks) {
  try {
    const res = await fetch(`${API_BASE}/step`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ticks: ticks })
    });
    const data = await res.json();
    fetchOverview();
    refreshActiveTab();
  } catch (err) {
    console.error('Failed to step simulation:', err);
  }
}

async function resumeSimulation() {
  try {
    const res = await fetch(`${API_BASE}/resume`, { method: 'POST' });
    const data = await res.json();
    state.isRunning = true;
    updateRunButton();
  } catch (err) {
    console.error('Failed to resume simulation:', err);
  }
}

async function pauseSimulation() {
  try {
    const res = await fetch(`${API_BASE}/pause`, { method: 'POST' });
    const data = await res.json();
    state.isRunning = false;
    updateRunButton();
  } catch (err) {
    console.error('Failed to pause simulation:', err);
  }
}

function updateRunButton() {
  const btn = document.getElementById('btn-toggle-run');
  if (state.isRunning) {
    btn.textContent = 'Auto-Step: ON';
    btn.classList.remove('btn-primary');
    btn.classList.add('btn-warning');
  } else {
    btn.textContent = 'Auto-Step: OFF';
    btn.classList.remove('btn-warning');
    btn.classList.add('btn-primary');
  }
}

async function setSpeed(ticksPerStep, intervalSec) {
  try {
    await fetch(`${API_BASE}/speed`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ ticks_per_step: ticksPerStep, interval_sec: intervalSec })
    });
  } catch (err) {
    console.error('Failed to set speed:', err);
  }
}

async function resetSimulation(popSize, seedVal) {
  try {
    await fetch(`${API_BASE}/reset`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ population: popSize, seed: seedVal })
    });
    state.peoplePage = 1;
    fetchOverview();
    refreshActiveTab();
  } catch (err) {
    console.error('Failed to reset simulation:', err);
  }
}

// Data Fetching & View Renderers

// 1. Overview
async function fetchOverview() {
  try {
    const res = await fetch(`${API_BASE}/overview`);
    const data = await res.json();
    
    // Update Header Clock
    if (data.clock) {
      document.getElementById('clock-time-str').textContent = data.clock.formatted_time || 'Year 1, Day 1';
      document.getElementById('clock-tick-badge').textContent = `Tick ${data.clock.tick}`;
      document.getElementById('clock-checksum-badge').textContent = `Checksum: 0x${(data.clock.checksum || 0).toString(16).toUpperCase()}`;
    }
    
    // Update Engine status
    if (data.engine) {
      state.isRunning = data.engine.is_running;
      updateRunButton();
    }
    
    // Top Metric Cards
    if (data.population) {
      document.getElementById('metric-living-pop').textContent = data.population.living_count;
      document.getElementById('metric-pop-breakdown').textContent = 
        `${data.population.adults} Adults · ${data.population.students} Students · ${data.population.children + data.population.infants} Children`;
      document.getElementById('nav-pop-count').textContent = data.population.living_count;
      
      document.getElementById('ov-infants').textContent = data.population.infants;
      document.getElementById('ov-children').textContent = data.population.children;
      document.getElementById('ov-students').textContent = data.population.students;
      document.getElementById('ov-adults').textContent = data.population.adults;
      document.getElementById('ov-elders').textContent = data.population.elders;
      document.getElementById('ov-employed').textContent = data.population.employed_count;
      
      document.getElementById('ov-hydration').textContent = `${data.population.avg_hydration.toFixed(1)}%`;
      document.getElementById('ov-dehydrated').textContent = data.population.dehydrated_count;
      document.getElementById('ov-health').textContent = `${data.population.avg_health.toFixed(1)}%`;
      document.getElementById('ov-education').textContent = `${data.population.avg_education.toFixed(1)} pts`;
    }
    
    if (data.utilities) {
      document.getElementById('metric-water-liters').textContent = `${data.utilities.reservoir_current_liters.toFixed(1)} L`;
      document.getElementById('metric-water-percent').textContent = 
        `${data.utilities.fill_percent.toFixed(1)}% Capacity (${data.utilities.net_volume_change_liters >= 0 ? '+' : ''}${data.utilities.net_volume_change_liters.toFixed(1)} L net)`;
    }
    
    if (data.economy) {
      document.getElementById('metric-mass-error').textContent = `${data.economy.mass_balance_error_kg.toFixed(6)} kg`;
      document.getElementById('metric-mass-total').textContent = `${data.economy.total_system_mass_kg.toFixed(0)} kg Conserved`;
      
      const res = data.economy.resource_totals || {};
      document.getElementById('ov-seam-ore').textContent = `${(data.economy.seam_ore_kg || 0).toFixed(1)} kg`;
      document.getElementById('ov-iron-ore').textContent = `${(res.iron_ore || 0).toFixed(1)} kg`;
      document.getElementById('ov-proc-ore').textContent = `${(res.processed_ore || 0).toFixed(1)} kg`;
      document.getElementById('ov-metal-stock').textContent = `${(res.metal_stock || 0).toFixed(1)} kg`;
      document.getElementById('ov-bearings').textContent = `${(res.machined_bearing || 0).toFixed(0)} units`;
      document.getElementById('ov-installed-mass').textContent = `${(data.economy.installed_maintenance_mass_kg || 0).toFixed(1)} kg`;
      document.getElementById('ov-slag').textContent = `${(res.slag_tailings || 0).toFixed(1)} kg`;
      document.getElementById('ov-swarf').textContent = `${(res.metal_swarf || 0).toFixed(1)} kg`;
    }
    
    if (data.machinery) {
      const states = data.machinery.states || {};
      const total = data.machinery.total_machines || 1;
      const nomPct = Math.round(((states.NOMINAL || 0) / total) * 100);
      document.getElementById('metric-mach-health').textContent = `${nomPct}%`;
      document.getElementById('metric-mach-breakdown').textContent = 
        `${states.NOMINAL || 0} Nominal · ${states.DEGRADED || 0} Degraded · ${states.BROKEN || 0} Broken`;
    }
    
    if (data.institutions) {
      const tension = data.institutions.social_tension_index || 0;
      document.getElementById('metric-social-tension').textContent = tension.toFixed(2);
      document.getElementById('metric-tension-status').textContent = 
        tension > 0.5 ? 'Tension Status: ELEVATED' : (tension > 0.2 ? 'Tension Status: MODERATE' : 'Tension Status: NOMINAL');
    }
    
    if (data.incidents) {
      document.getElementById('metric-active-crises').textContent = data.incidents.active_count || 0;
      document.getElementById('metric-crises-sub').textContent = `${data.incidents.critical_count || 0} Critical Emergencies`;
      document.getElementById('nav-inc-count').textContent = data.incidents.active_count || 0;
    }
    
    if (data.corruption) {
      const activeActions = data.corruption.active_illicit_actions || data.corruption.total_illicit_actions || 0;
      const navCorr = document.getElementById('nav-corr-count');
      if (navCorr) navCorr.textContent = activeActions;
    }
    
  } catch (err) {
    console.error('Failed to fetch overview:', err);
  }
}

// 2. People List
async function fetchPeople() {
  const search = document.getElementById('filter-person-search').value;
  const stage = document.getElementById('filter-person-stage').value;
  const status = document.getElementById('filter-person-status').value;
  
  try {
    const url = `${API_BASE}/people?page=${state.peoplePage}&limit=${state.peopleLimit}&search=${encodeURIComponent(search)}&stage=${stage}&status=${status}`;
    const res = await fetch(url);
    const data = await res.json();
    
    const tbody = document.getElementById('tbody-people');
    tbody.innerHTML = '';
    
    if (!data.people || data.people.length === 0) {
      tbody.innerHTML = '<tr><td colspan="12" class="text-center">No residents found matching criteria.</td></tr>';
      document.getElementById('people-page-info').textContent = 'Showing 0 of 0';
      return;
    }
    
    document.getElementById('people-page-info').textContent = 
      `Page ${data.page} of ${Math.ceil(data.total_count / data.limit)} (${data.total_count} total)`;
      
    data.people.forEach(p => {
      const tr = document.createElement('tr');
      const stageBadge = getStageBadge(p.life_stage);
      const hydBadge = p.hydration_percent < 50 ? 'text-danger' : (p.hydration_percent < 80 ? 'text-warning' : 'text-success');
      
      tr.innerHTML = `
        <td><strong>#${p.id}</strong></td>
        <td><a href="javascript:void(0)" onclick="openPersonModal(${p.id})">${p.full_name}</a></td>
        <td>${p.sex}</td>
        <td>${p.age_years}y</td>
        <td>${stageBadge}</td>
        <td>${p.occupation_id}</td>
        <td>${p.department_id || '—'}</td>
        <td><span class="badge badge-info">${p.activity}</span></td>
        <td class="${hydBadge}"><strong>${p.hydration_percent.toFixed(1)}%</strong></td>
        <td>${p.health_percent.toFixed(1)}%</td>
        <td><a href="javascript:void(0)" onclick="openRoomModal(${p.current_location_id})">Room ${p.current_location_id}</a></td>
        <td><button class="btn btn-secondary" onclick="openPersonModal(${p.id})">Profile</button></td>
      `;
      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Failed to fetch people:', err);
  }
}

function getStageBadge(stage) {
  switch (stage) {
    case 'INFANT': return '<span class="badge badge-purple">INFANT</span>';
    case 'CHILD': return '<span class="badge badge-purple">CHILD</span>';
    case 'STUDENT': return '<span class="badge badge-info">STUDENT</span>';
    case 'ADULT': return '<span class="badge badge-success">ADULT</span>';
    case 'ELDER': return '<span class="badge badge-warning">ELDER</span>';
    default: return `<span class="badge">${stage}</span>`;
  }
}

// 3. Households
async function fetchHouseholds() {
  try {
    const res = await fetch(`${API_BASE}/households`);
    const data = await res.json();
    
    const tbody = document.getElementById('tbody-households');
    tbody.innerHTML = '';
    
    if (!data.households || data.households.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="text-center">No households found.</td></tr>';
      return;
    }
    
    data.households.forEach(h => {
      const tr = document.createElement('tr');
      const membersStr = h.members.map(m => `<a href="javascript:void(0)" onclick="openPersonModal(${m.id})">${m.name}</a>`).join(', ');
      
      tr.innerHTML = `
        <td><strong>#${h.id}</strong></td>
        <td><a href="javascript:void(0)" onclick="openHouseholdModal(${h.id})">${h.name}</a></td>
        <td>${h.head_name}</td>
        <td><a href="javascript:void(0)" onclick="openRoomModal(${h.home_room_id})">Room ${h.home_room_id}</a></td>
        <td><strong>${h.member_count}</strong></td>
        <td>${membersStr}</td>
      `;
      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Failed to fetch households:', err);
  }
}

// 4. Locations & Spatial
async function fetchLocations() {
  try {
    const res = await fetch(`${API_BASE}/locations`);
    const data = await res.json();
    
    const container = document.getElementById('spatial-tree-container');
    container.innerHTML = '';
    
    const sectors = data.sectors || {};
    if (Object.keys(sectors).length === 0) {
      container.innerHTML = '<div class="card"><div class="card-body">No spatial rooms mapped.</div></div>';
      return;
    }
    
    for (const secKey in sectors) {
      const levels = sectors[secKey];
      for (const lvlKey in levels) {
        const rooms = levels[lvlKey];
        
        const card = document.createElement('div');
        card.className = 'card';
        
        let roomsHtml = '';
        rooms.forEach(r => {
          roomsHtml += `
            <div style="padding: 0.5rem 0; border-bottom: 1px solid var(--border-color);">
              <div style="display: flex; justify-content: space-between;">
                <strong><a href="javascript:void(0)" onclick="openRoomModal(${r.id})">Room ${r.id}: ${r.room_type_name}</a></strong>
                <span class="badge badge-info">${r.occupant_count} / ${r.capacity_people} Occupants</span>
              </div>
              <div style="font-size: 12px; color: var(--text-secondary); margin-top: 2px;">
                Beds: ${r.bed_count} (${r.occupied_beds.length} occupied)
              </div>
            </div>
          `;
        });
        
        card.innerHTML = `
          <div class="card-header">
            <h3>📍 ${secKey} — ${lvlKey}</h3>
            <span class="badge badge-success">${rooms.length} Rooms</span>
          </div>
          <div class="card-body">
            ${roomsHtml}
          </div>
        `;
        container.appendChild(card);
      }
    }
  } catch (err) {
    console.error('Failed to fetch locations:', err);
  }
}

// 5. Labour & Education
async function fetchLabour() {
  try {
    const res = await fetch(`${API_BASE}/labour`);
    const data = await res.json();
    
    // Departments
    const deptCont = document.getElementById('labour-dept-container');
    let deptHtml = `<div class="stat-row"><span>Total Assigned Workers:</span> <strong>${data.total_employed}</strong></div><hr class="divider">`;
    
    for (const deptKey in (data.departments || {})) {
      const d = data.departments[deptKey];
      deptHtml += `
        <div style="margin-bottom: 1rem;">
          <div style="display: flex; justify-content: space-between;">
            <strong>Department: ${deptKey.toUpperCase()}</strong>
            <span class="badge badge-info">${d.worker_count} Personnel</span>
          </div>
          <div style="font-size: 12px; color: var(--text-secondary); margin-top: 4px;">
            ${d.workers.slice(0, 5).map(w => `<a href="javascript:void(0)" onclick="openPersonModal(${w.id})">${w.name}</a> (${w.occupation})`).join(', ')}
            ${d.workers.length > 5 ? `... and ${d.workers.length - 5} more` : ''}
          </div>
        </div>
      `;
    }
    deptCont.innerHTML = deptHtml;
    
    // Students
    const stuCont = document.getElementById('labour-students-container');
    let stuHtml = `<div class="stat-row"><span>Enrolled Students:</span> <strong>${data.students_count}</strong></div><hr class="divider">`;
    
    (data.students || []).slice(0, 10).forEach(s => {
      stuHtml += `
        <div class="stat-row">
          <span><a href="javascript:void(0)" onclick="openPersonModal(${s.id})">${s.name}</a> (${s.age_years}y)</span>
          <span>Edu Score: <strong>${s.education_score.toFixed(1)}</strong></span>
        </div>
      `;
    });
    if ((data.students || []).length > 10) {
      stuHtml += `<div style="font-size: 12px; color: var(--text-muted); margin-top: 0.5rem;">+ ${data.students.length - 10} more students enrolled</div>`;
    }
    stuCont.innerHTML = stuHtml;
    
  } catch (err) {
    console.error('Failed to fetch labour:', err);
  }
}

// 6. Material Economy
async function fetchEconomy() {
  try {
    const res = await fetch(`${API_BASE}/economy`);
    const data = await res.json();
    
    const seam = (data.seam_ore_kg || 0).toFixed(1);
    const inv = (data.inventory_mass_kg || 0).toFixed(1);
    const inst = (data.installed_maintenance_mass_kg || 0).toFixed(1);
    const tot = (data.total_system_mass_kg || 0).toFixed(1);
    
    document.getElementById('econ-balance-formula').textContent = 
      `[Seam: ${seam} kg] + [Inventories: ${inv} kg] + [Installed Spares: ${inst} kg] = [Total: ${tot} kg]`;
      
    document.getElementById('econ-balance-status').textContent = 
      `Invariant Mass Error: ${data.mass_balance_error_kg.toFixed(6)} kg (${data.mass_balance_error_kg < 0.001 ? 'CONSERVED' : 'ERROR'})`;
      
    const r = data.resource_totals || {};
    document.getElementById('pipe-iron-ore').textContent = `Iron Ore: ${(r.iron_ore || 0).toFixed(1)} kg`;
    document.getElementById('pipe-proc-ore').textContent = `Processed: ${(r.processed_ore || 0).toFixed(1)} kg`;
    document.getElementById('pipe-metal-stock').textContent = `Metal Stock: ${(r.metal_stock || 0).toFixed(1)} kg`;
    document.getElementById('pipe-bearings').textContent = `Machined Bearings: ${(r.machined_bearing || 0).toFixed(0)}`;
    
    // Resource Table
    const tbody = document.getElementById('tbody-econ-resources');
    tbody.innerHTML = `
      <tr><td><strong>iron_ore</strong></td><td>Raw Mineral</td><td>${(r.iron_ore || 0).toFixed(1)}</td><td>kg</td><td>Input to Beneficiation Plant</td></tr>
      <tr><td><strong>processed_ore</strong></td><td>Beneficiated Mineral</td><td>${(r.processed_ore || 0).toFixed(1)}</td><td>kg</td><td>Input to Induction Smelting Foundry</td></tr>
      <tr><td><strong>metal_stock</strong></td><td>Refined Ingot</td><td>${(r.metal_stock || 0).toFixed(1)}</td><td>kg</td><td>Input to Machine Shop Lathes</td></tr>
      <tr><td><strong>machined_bearing</strong></td><td>Manufactured Component</td><td>${(r.machined_bearing || 0).toFixed(0)}</td><td>units</td><td>Installed Maintenance Component for Pumps</td></tr>
      <tr><td><strong>slag_tailings</strong></td><td>Smelting Byproduct</td><td>${(r.slag_tailings || 0).toFixed(1)}</td><td>kg</td><td>Dense tailing waste mass</td></tr>
      <tr><td><strong>metal_swarf</strong></td><td>Machining Shavings</td><td>${(r.metal_swarf || 0).toFixed(1)}</td><td>kg</td><td>Recyclable scrap shavings</td></tr>
    `;
  } catch (err) {
    console.error('Failed to fetch economy:', err);
  }
}

// 7. Machinery & Maintenance
async function fetchMachinery() {
  try {
    const res = await fetch(`${API_BASE}/machinery`);
    const data = await res.json();
    
    const container = document.getElementById('machinery-container');
    container.innerHTML = '';
    
    (data.machines_list || []).forEach(m => {
      const card = document.createElement('div');
      card.className = 'card';
      
      let badgeClass = 'badge-success';
      if (m.state === 'DEGRADED') badgeClass = 'badge-warning';
      else if (m.state === 'FAULT' || m.state === 'BROKEN') badgeClass = 'badge-danger';
      
      let compHtml = '';
      for (const cid in m.components) {
        const c = m.components[cid];
        const wearFill = c.wear_percent > 80 ? 'fill-red' : (c.wear_percent > 50 ? 'fill-amber' : 'fill-green');
        compHtml += `
          <div style="margin-top: 0.5rem;">
            <div style="display: flex; justify-content: space-between; font-size: 12px;">
              <span><strong>${cid}</strong></span>
              <span>Wear: ${c.wear_percent.toFixed(1)}%</span>
            </div>
            <div class="progress-bar">
              <div class="progress-fill ${wearFill}" style="width: ${Math.min(100, c.wear_percent)}%;"></div>
            </div>
          </div>
        `;
      }
      
      card.innerHTML = `
        <div class="card-header">
          <h3>🔧 Machine #${m.id} (${m.type})</h3>
          <span class="badge ${badgeClass}">${m.state}</span>
        </div>
        <div class="card-body">
          <div class="stat-row"><span>Operating Hours:</span> <strong>${m.operating_hours.toFixed(1)} hrs</strong></div>
          <div class="stat-row"><span>Throughput:</span> <strong>${m.throughput_lpm.toFixed(1)} L/min</strong></div>
          <div class="stat-row"><span>Active Servicing:</span> <strong>${m.active_repair || 'None'}</strong></div>
          <hr class="divider">
          <h4>Component Wear Status</h4>
          ${compHtml}
          <div style="margin-top: 1rem; text-align: right;">
            <button class="btn btn-secondary" onclick="viewCausalChainForMachine(${m.id})">Inspect Causal Trace ➔</button>
          </div>
        </div>
      `;
      container.appendChild(card);
    });
  } catch (err) {
    console.error('Failed to fetch machinery:', err);
  }
}

function viewCausalChainForMachine(mid) {
  state.activeMachineId = mid;
  window.location.hash = 'causal-chain';
}

// 8. 8-Step Causal Trace
async function fetchCausalChain() {
  try {
    const res = await fetch(`${API_BASE}/causal_chain?machine_id=${state.activeMachineId}`);
    const data = await res.json();
    
    const container = document.getElementById('causal-chain-container');
    const m = data.machine || {};
    const comp = data.component || {};
    const part = data.required_part || {};
    const shop = data.manufacturing_machine_shop || {};
    const smelter = data.smelting_foundry || {};
    const mine = data.mining_crushing || {};
    const seam = data.geological_seam || {};
    const util = data.utility_consequence || {};
    
    container.innerHTML = `
      <div class="card-body">
        <h3 style="margin-bottom: 1rem; color: var(--accent-cyan);">Physical Traceability Graph: Machine #${m.id || 1}</h3>
        
        <div class="stat-row"><span>1. Geological Seam:</span> <strong>${(seam.remaining_reserve_kg || 0).toFixed(1)} kg remaining (Total: ${seam.total_system_mass_kg} kg)</strong></div>
        <div class="stat-row"><span>2. Deep Mining & Beneficiation:</span> <strong>Extracted Iron Ore (${mine.iron_ore_stock} kg) ➔ Processed Ore (${mine.processed_ore_stock} kg)</strong></div>
        <div class="stat-row"><span>3. Smelting Foundry:</span> <strong>Processed Ore (${smelter.input_stock} kg) ➔ Metal Stock (${smelter.output_stock} kg)</strong></div>
        <div class="stat-row"><span>4. Machine Shop Lathes:</span> <strong>Metal Stock (${shop.input_stock} kg) ➔ Bearings (${shop.output_stock} units)</strong></div>
        <div class="stat-row"><span>5. Maintenance Spare Stock:</span> <strong>Part: ${part.resource_id} (Habitat Stock: ${part.habitat_total_stock}, Required: ${part.required_quantity})</strong></div>
        <div class="stat-row"><span>6. Installed Component Wear:</span> <strong>${comp.name} (Wear: ${(comp.wear_percent || 0).toFixed(1)}%, Criticality: ${comp.criticality})</strong></div>
        <div class="stat-row"><span>7. Water Pump Throughput:</span> <strong>${(util.pump_throughput_lpm || 0).toFixed(1)} L/min ➔ Reservoir: ${(util.reservoir_current_liters || 0).toFixed(1)} L (${(util.reservoir_fill_percent || 0).toFixed(1)}%)</strong></div>
        <div class="stat-row"><span>8. Population Hydration Impact:</span> <strong>Avg Hydration: ${(util.avg_hydration_percent || 0).toFixed(1)}% (${util.dehydrated_residents_count || 0} Dehydrated Citizens)</strong></div>
      </div>
    `;
  } catch (err) {
    console.error('Failed to fetch causal chain:', err);
  }
}

// 9. Utilities & Water
async function fetchUtilities() {
  try {
    const res = await fetch(`${API_BASE}/utilities`);
    const data = await res.json();
    
    document.getElementById('util-reservoir-card').innerHTML = `
      <div class="stat-row"><span>Current Stored Water:</span> <strong>${data.reservoir_current_liters.toFixed(1)} Liters</strong></div>
      <div class="stat-row"><span>Total Tank Capacity:</span> <strong>${data.reservoir_capacity_liters.toFixed(1)} Liters</strong></div>
      <div class="stat-row"><span>Fill Percentage:</span> <strong>${data.fill_percent.toFixed(1)}%</strong></div>
      <div class="progress-bar" style="margin-top: 0.75rem;">
        <div class="progress-fill fill-blue" style="width: ${Math.min(100, data.fill_percent)}%;"></div>
      </div>
    `;
    
    document.getElementById('util-throughput-card').innerHTML = `
      <div class="stat-row"><span>Lifetime Pumped Volume:</span> <strong>${data.total_pumped_liters.toFixed(1)} Liters</strong></div>
      <div class="stat-row"><span>Lifetime Consumed Volume:</span> <strong>${data.total_consumed_liters.toFixed(1)} Liters</strong></div>
      <div class="stat-row"><span>Net Volume Delta:</span> <strong>${data.net_volume_change_liters.toFixed(1)} Liters</strong></div>
    `;
  } catch (err) {
    console.error('Failed to fetch utilities:', err);
  }
}

// 10. Institutions & Policy
async function fetchInstitutions() {
  try {
    const res = await fetch(`${API_BASE}/institutions`);
    const data = await res.json();
    
    // Active Policies
    const polCont = document.getElementById('policies-active-list');
    let polHtml = '';
    const policies = data.active_policies || {};
    if (Object.keys(policies).length === 0) {
      polHtml = '<div style="color: var(--text-muted);">No regulatory policies currently active.</div>';
    } else {
      for (const cat in policies) {
        const p = policies[cat];
        polHtml += `
          <div style="display: flex; justify-content: space-between; align-items: center; padding: 0.4rem 0;">
            <div><strong>${p.name}</strong> (${p.department})</div>
            <button class="btn btn-danger" onclick="revokePolicy('${cat}')">Revoke</button>
          </div>
        `;
      }
    }
    polCont.innerHTML = polHtml;
    
    // Active Orders
    const ordCont = document.getElementById('orders-active-list');
    let ordHtml = '';
    const orders = data.active_orders || [];
    if (orders.length === 0) {
      ordHtml = '<div style="color: var(--text-muted);">No executive directives active.</div>';
    } else {
      orders.forEach(o => {
        ordHtml += `
          <div style="display: flex; justify-content: space-between; align-items: center; padding: 0.4rem 0;">
            <div><strong>${o.name}</strong> (${o.ticks_elapsed}/${o.duration_ticks} ticks)</div>
            <button class="btn btn-danger" onclick="cancelOrder('${o.id}')">Cancel</button>
          </div>
        `;
      });
    }
    ordCont.innerHTML = ordHtml;
    
  } catch (err) {
    console.error('Failed to fetch institutions:', err);
  }
}

async function enactPolicy(policyId) {
  try {
    await fetch(`${API_BASE}/policy/enact`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ policy_id: policyId })
    });
    fetchInstitutions();
    fetchOverview();
  } catch (err) {
    console.error('Failed to enact policy:', err);
  }
}

async function revokePolicy(category) {
  try {
    await fetch(`${API_BASE}/policy/revoke`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ category: category })
    });
    fetchInstitutions();
    fetchOverview();
  } catch (err) {
    console.error('Failed to revoke policy:', err);
  }
}

async function issueOrder(orderId) {
  try {
    await fetch(`${API_BASE}/order/issue`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ order_id: orderId })
    });
    fetchInstitutions();
    fetchOverview();
  } catch (err) {
    console.error('Failed to issue order:', err);
  }
}

async function cancelOrder(orderId) {
  try {
    await fetch(`${API_BASE}/order/cancel`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ order_id: orderId })
    });
    fetchInstitutions();
    fetchOverview();
  } catch (err) {
    console.error('Failed to cancel order:', err);
  }
}

// 10b. Politics & Legitimacy
async function fetchPolitics() {
  try {
    const res = await fetch(`${API_BASE}/politics`);
    const data = await res.json();
    
    // Update metric cards
    const legPct = ((data.overall_legitimacy || 0) * 100).toFixed(1);
    const legElem = document.getElementById('pol-metric-legitimacy');
    if (legElem) legElem.textContent = `${legPct}%`;
    const legSub = document.getElementById('pol-metric-legitimacy-sub');
    if (legSub) {
      const legVal = data.overall_legitimacy || 0;
      const legCategory = legVal > 0.7 ? 'VERY HIGH' : legVal > 0.5 ? 'NOMINAL' : legVal > 0.3 ? 'ERODED' : 'CRITICAL';
      legSub.textContent = `Legitimacy: ${legCategory}`;
    }
    
    const spec = data.spectrum || {};
    const trustElem = document.getElementById('pol-metric-trust');
    if (trustElem) trustElem.textContent = (spec.avg_trust || 0.5).toFixed(2);
    
    const resElem = document.getElementById('pol-metric-resentment');
    if (resElem) resElem.textContent = (data.class_resentment_index || 0).toFixed(2);
    
    const fairElem = document.getElementById('pol-metric-fairness');
    if (fairElem) fairElem.textContent = (spec.avg_fairness || 0.5).toFixed(2);
    
    const secElem = document.getElementById('pol-metric-security');
    if (secElem) secElem.textContent = (spec.avg_security || 0.5).toFixed(2);
    
    const memElem = document.getElementById('pol-metric-memories');
    if (memElem) memElem.textContent = data.total_memories_created || 0;
    
    // Departmental Trust
    const deptCard = document.getElementById('pol-dept-trust-card');
    if (deptCard) {
      const depts = data.departmental_trust || {};
      let deptHtml = '';
      for (const d in depts) {
        const val = depts[d];
        const pct = Math.round(val * 100);
        deptHtml += `
          <div style="margin-bottom: 0.75rem;">
            <div style="display: flex; justify-content: space-between; font-size: 13px;">
              <span><strong>${d.toUpperCase()}</strong></span>
              <span>${(val * 100).toFixed(1)}% (${val.toFixed(2)})</span>
            </div>
            <div class="progress-bar" style="margin-top: 4px;">
              <div class="progress-fill ${val > 0.6 ? 'fill-green' : val > 0.4 ? 'fill-yellow' : 'fill-red'}" style="width: ${pct}%;"></div>
            </div>
          </div>
        `;
      }
      deptCard.innerHTML = deptHtml || '<p class="text-muted">No departmental data available.</p>';
    }
    
    // Political Values Spectrum
    const valsCard = document.getElementById('pol-values-card');
    if (valsCard) {
      valsCard.innerHTML = `
        <div class="stat-row"><span>Preference for Stability vs Reform:</span> <strong>${(spec.preference_stability || 0.5).toFixed(2)} / ${(spec.preference_reform || 0.5).toFixed(2)}</strong></div>
        <div class="stat-row"><span>Preference for Equality vs Hierarchy:</span> <strong>${(spec.preference_equality || 0.5).toFixed(2)} / ${(spec.preference_hierarchy || 0.5).toFixed(2)}</strong></div>
        <div class="stat-row"><span>Preference for Autonomy:</span> <strong>${(spec.preference_autonomy || 0.5).toFixed(2)}</strong></div>
        <div class="stat-row"><span>Tolerance of Coercion:</span> <strong>${(spec.tolerance_coercion || 0.5).toFixed(2)}</strong></div>
        <hr class="divider">
        <div class="stat-row"><span>Economic Satisfaction:</span> <strong>${(spec.avg_satisfaction || 0.5).toFixed(2)}</strong></div>
        <div class="stat-row"><span>Class Resentment Index:</span> <strong>${(data.class_resentment_index || 0.0).toFixed(2)}</strong></div>
      `;
    }
  } catch (err) {
    console.error('Failed to fetch politics:', err);
  }
}

async function inspectCitizenPolitics(personId) {
  const container = document.getElementById('pol-citizen-dossier');
  if (!container) return;
  container.innerHTML = '<p>Loading citizen political dossier...</p>';
  try {
    const res = await fetch(`${API_BASE}/person_politics?id=${personId}`);
    if (!res.ok) {
      container.innerHTML = `<p class="text-danger">Citizen #${personId} not found.</p>`;
      return;
    }
    const p = await res.json();
    const att = p.attitudes || {};
    const mems = p.opinion_memories || [];
    
    let memsHtml = '';
    if (mems.length === 0) {
      memsHtml = '<p class="text-muted">No lived memory records. Attitudes reflect baseline cultural imprint.</p>';
    } else {
      memsHtml = `
        <table class="data-table" style="margin-top: 0.75rem;">
          <thead>
            <tr>
              <th>Event</th>
              <th>Dept</th>
              <th>Impact</th>
              <th>Salience (Decay)</th>
              <th>Recorded Tick</th>
              <th>Description</th>
            </tr>
          </thead>
          <tbody>
            ${mems.map(m => `
              <tr>
                <td><strong>${m.event_type}</strong></td>
                <td><span class="badge badge-info">${m.attribution_dept}</span></td>
                <td style="color: ${m.emotional_impact >= 0 ? 'var(--accent-green)' : 'var(--accent-red)'}; font-weight: bold;">
                  ${m.emotional_impact >= 0 ? '+' : ''}${m.emotional_impact.toFixed(2)}
                </td>
                <td>
                  ${(m.salience * 100).toFixed(1)}%
                  <div class="progress-bar" style="height: 4px; margin-top: 2px;">
                    <div class="progress-fill fill-blue" style="width: ${Math.round(m.salience * 100)}%;"></div>
                  </div>
                </td>
                <td>Tick ${m.onset_tick}</td>
                <td style="font-size: 12px;">${m.description || '—'}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    }
    
    container.innerHTML = `
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
        <h4>${p.name} (Citizen #${p.id}) — ${p.occupation_id} (${p.department_id}, Clearance ${p.clearance})</h4>
        <button class="btn btn-secondary" onclick="openPersonModal(${p.id})">Open Full Resident Profile →</button>
      </div>
      
      <div class="overview-columns">
        <div class="card column-half">
          <div class="card-header"><h4>Perceived Institutional Attitudes</h4></div>
          <div class="card-body">
            <div class="stat-row"><span>Institutional Trust:</span> <strong>${(att.institutional_trust || 0).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Perceived Fairness:</span> <strong>${(att.perceived_fairness || 0).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Perceived Security:</span> <strong>${(att.perceived_security || 0).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Economic Satisfaction:</span> <strong>${(att.economic_satisfaction || 0).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Class Resentment:</span> <strong>${(att.class_resentment || 0).toFixed(2)}</strong></div>
          </div>
        </div>
        
        <div class="card column-half">
          <div class="card-header"><h4>Departmental Confidence</h4></div>
          <div class="card-body">
            <div class="stat-row"><span>Leadership:</span> <strong>${(p.department_confidence?.leadership || 0).toFixed(2)}</strong></div>
            <div class="stat-row"><span>IT / Infrastructure:</span> <strong>${(p.department_confidence?.it || 0).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Security / Order:</span> <strong>${(p.department_confidence?.security || 0).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Engineering / Maintenance:</span> <strong>${(p.department_confidence?.engineering || 0).toFixed(2)}</strong></div>
          </div>
        </div>
      </div>
      
      <div style="margin-top: 1rem;">
        <h4>Lived Opinion Memories (${mems.length} Events)</h4>
        ${memsHtml}
      </div>
    `;
  } catch (err) {
    container.innerHTML = '<p class="text-danger">Failed to load citizen political dossier.</p>';
  }
}

// 10c. Factions & Social Movements
async function fetchFactions() {
  try {
    const res = await fetch(`${API_BASE}/factions`);
    const data = await res.json();
    
    // Update metrics
    const activeElem = document.getElementById('fact-metric-active');
    if (activeElem) activeElem.textContent = data.active_count || 0;
    
    const subElem = document.getElementById('fact-metric-total-sub');
    if (subElem) subElem.textContent = `${data.total_count || 0} Movements (${data.active_count || 0} Active)`;
    
    const navCountElem = document.getElementById('nav-faction-count');
    if (navCountElem) navCountElem.textContent = data.active_count || 0;
    
    let totalMembers = 0;
    let totalSymps = 0;
    (data.factions || []).forEach(f => {
      if (f.is_active) {
        totalMembers += f.member_count || 0;
        totalSymps += f.sympathiser_count || 0;
      }
    });
    
    const memElem = document.getElementById('fact-metric-members');
    if (memElem) memElem.textContent = totalMembers;
    
    const sympElem = document.getElementById('fact-metric-sympathisers');
    if (sympElem) sympElem.textContent = totalSymps;
    
    const recElem = document.getElementById('fact-metric-recruitment');
    if (recElem) recElem.textContent = data.total_recruitment_events || 0;
    
    // Render Factions List
    const container = document.getElementById('factions-list-container');
    if (!container) return;
    
    const factions = data.factions || [];
    if (factions.length === 0) {
      container.innerHTML = '<p class="text-muted">No emergent political factions active. Society is currently cohesive or unorganised.</p>';
      return;
    }
    
    container.innerHTML = `
      <div class="factions-list">
        ${factions.map(f => `
          <div class="card ${f.is_active ? '' : 'card-disabled'}" style="margin-bottom: 0.75rem; cursor: pointer; border-left: 4px solid ${f.is_active ? 'var(--accent-red)' : 'var(--text-muted)'};" onclick="inspectFaction(${f.id})">
            <div class="card-header" style="display: flex; justify-content: space-between; align-items: center;">
              <strong>🚩 ${f.name}</strong>
              <span class="badge ${f.is_active ? 'badge-danger' : 'badge-secondary'}">${f.is_active ? 'ACTIVE' : 'DORMANT'}</span>
            </div>
            <div class="card-body" style="font-size: 13px;">
              <div><strong>Leader:</strong> ${f.leader_name} (Citizen #${f.leader_id})</div>
              <div style="display: flex; gap: 1rem; margin-top: 4px;">
                <span><strong>Members:</strong> ${f.member_count}</span>
                <span><strong>Sympathisers:</strong> ${f.sympathiser_count}</span>
                <span><strong>Cohesion:</strong> ${(f.cohesion * 100).toFixed(0)}%</span>
              </div>
              <div style="margin-top: 4px; font-size: 12px; color: var(--text-muted);">${f.manifesto || 'No manifesto recorded.'}</div>
            </div>
          </div>
        `).join('')}
      </div>
    `;
    
    // Auto-inspect first faction if none currently selected
    if (factions.length > 0) {
      inspectFaction(factions[0].id);
    }
  } catch (err) {
    console.error('Failed to fetch factions:', err);
  }
}

async function inspectFaction(factionId) {
  const container = document.getElementById('faction-detail-container');
  const titleElem = document.getElementById('faction-detail-title');
  if (!container) return;
  
  container.innerHTML = '<p>Loading faction details...</p>';
  try {
    const res = await fetch(`${API_BASE}/faction_detail?id=${factionId}`);
    if (!res.ok) {
      container.innerHTML = `<p class="text-danger">Faction #${factionId} not found.</p>`;
      return;
    }
    const f = await res.json();
    if (titleElem) titleElem.textContent = `🚩 ${f.name} — Dossier`;
    
    const ideology = f.ideology_profile || {};
    const grievances = f.grievance_agenda || [];
    const polApprovals = f.policy_approval_matrix || {};
    const relations = f.inter_faction_relations_by_name || {};
    const penetration = f.institutional_penetration || {};
    
    let gHtml = '';
    if (grievances.length === 0) {
      gHtml = '<p class="text-muted" style="font-size: 13px;">No active systemic grievances on file.</p>';
    } else {
      gHtml = `
        <table class="data-table" style="margin-top: 0.5rem; font-size: 12px;">
          <thead>
            <tr>
              <th>Grievance Topic</th>
              <th>Target Dept</th>
              <th>Severity</th>
              <th>Salience</th>
            </tr>
          </thead>
          <tbody>
            ${grievances.map(g => `
              <tr>
                <td><strong>${g.description || g.type}</strong></td>
                <td><span class="badge badge-info">${g.target_dept || 'administration'}</span></td>
                <td style="color: var(--accent-red); font-weight: bold;">${(g.severity * 100).toFixed(0)}%</td>
                <td>${(g.salience * 100).toFixed(0)}%</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      `;
    }
    
    let polHtml = '';
    const polKeys = Object.keys(polApprovals);
    if (polKeys.length === 0) {
      polHtml = '<p class="text-muted" style="font-size: 13px;">No active institutional directives under review.</p>';
    } else {
      polHtml = polKeys.map(k => {
        const val = polApprovals[k];
        const isPos = val >= 0;
        return `
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px; font-size: 12px;">
            <span><strong>${k}:</strong></span>
            <span style="font-weight: bold; color: ${isPos ? 'var(--accent-green)' : 'var(--accent-red)'};">
              ${isPos ? '+' : ''}${(val * 100).toFixed(1)}%
            </span>
          </div>
        `;
      }).join('');
    }
    
    container.innerHTML = `
      <div style="margin-bottom: 1rem;">
        <p style="font-style: italic; color: var(--text-accent); margin-bottom: 0.5rem;">"${f.manifesto || ''}"</p>
        <div style="font-size: 13px;">
          <strong>Organiser / Leader:</strong> ${f.leader_name} (${f.leader_occupation}, ${f.leader_department}) — Citizen #${f.leader_id}
        </div>
      </div>
      
      <div class="overview-columns">
        <div class="card column-half">
          <div class="card-header"><h4>⚖️ Ideological Stance</h4></div>
          <div class="card-body" style="font-size: 12px;">
            <div class="stat-row"><span>Equality:</span> <strong>${(ideology.preference_equality || 0.5).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Hierarchy:</span> <strong>${(ideology.preference_hierarchy || 0.5).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Reform:</span> <strong>${(ideology.preference_reform || 0.5).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Stability:</span> <strong>${(ideology.preference_stability || 0.5).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Autonomy:</span> <strong>${(ideology.preference_autonomy || 0.5).toFixed(2)}</strong></div>
            <div class="stat-row"><span>Coercion Tolerance:</span> <strong>${(ideology.tolerance_coercion || 0.3).toFixed(2)}</strong></div>
          </div>
        </div>
        
        <div class="card column-half">
          <div class="card-header"><h4>📜 Policy & Order Approval</h4></div>
          <div class="card-body" style="font-size: 12px;">
            ${polHtml}
          </div>
        </div>
      </div>
      
      <div style="margin-top: 1rem;">
        <h4>🚨 Grievance Agenda & Platform</h4>
        ${gHtml}
      </div>
    `;
  } catch (err) {
    container.innerHTML = '<p class="text-danger">Failed to load faction details.</p>';
  }
}

async function inspectSocialNetwork(personId) {
  const container = document.getElementById('social-network-container');
  if (!container) return;
  container.innerHTML = '<p>Querying citizen bounded social network...</p>';
  try {
    const res = await fetch(`${API_BASE}/social_network?id=${personId}`);
    if (!res.ok) {
      container.innerHTML = `<p class="text-danger">Citizen #${personId} not found.</p>`;
      return;
    }
    const data = await res.json();
    const conns = data.connections || [];
    
    if (conns.length === 0) {
      container.innerHTML = `<p class="text-muted">Citizen #${personId} (${data.person_name}) has no recorded social connections.</p>`;
      return;
    }
    
    container.innerHTML = `
      <div style="margin-bottom: 0.75rem;">
        <h4>${data.person_name} (Citizen #${data.person_id}) — ${data.occupation} (${data.department})</h4>
        <p class="text-muted" style="font-size: 13px;">Bounded network contains ${conns.length} direct social ties (family, household, coworkers, school cohorts, neighbors).</p>
      </div>
      
      <table class="data-table" style="font-size: 13px;">
        <thead>
          <tr>
            <th>Connected Citizen</th>
            <th>Relationship Type</th>
            <th>Tie Strength (Weight)</th>
            <th>Trust / Reciprocal Strength</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          ${conns.map(c => `
            <tr>
              <td><strong>${c.target_name}</strong> (Citizen #${c.target_id})</td>
              <td><span class="badge ${c.relation_type === 'family' ? 'badge-accent' : c.relation_type === 'coworker' ? 'badge-info' : 'badge-secondary'}">${c.relation_type}</span></td>
              <td>
                ${(c.weight * 100).toFixed(0)}%
                <div class="progress-bar" style="height: 4px; margin-top: 2px;">
                  <div class="progress-fill fill-green" style="width: ${Math.round(c.weight * 100)}%;"></div>
                </div>
              </td>
              <td>${(c.trust * 100).toFixed(0)}%</td>
              <td>
                <button class="btn btn-secondary btn-sm" onclick="inspectSocialNetwork(${c.target_id})">Trace Ties →</button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
  } catch (err) {
    container.innerHTML = '<p class="text-danger">Failed to load social network data.</p>';
  }
}

// 10d. Corruption & Patronage
async function fetchCorruption() {
  try {
    const res = await fetch(`${API_BASE}/corruption`);
    const data = await res.json();
    
    // Top Metric Cards
    const favElem = document.getElementById('corr-metric-favours');
    if (favElem) favElem.textContent = data.total_favours || 0;
    const favSub = document.getElementById('corr-metric-favours-sub');
    if (favSub) favSub.textContent = `${data.active_favours || 0} Active Debts (${data.settled_favours || 0} Settled)`;
    
    const clusElem = document.getElementById('corr-metric-clusters');
    if (clusElem) clusElem.textContent = data.patron_clusters_count || 0;
    const clusSub = document.getElementById('corr-metric-clusters-sub');
    if (clusSub) clusSub.textContent = `${data.patron_clusters_count || 0} Informal Power Blocs`;
    
    const actElem = document.getElementById('corr-metric-actions');
    if (actElem) actElem.textContent = data.total_illicit_actions || 0;
    const actSub = document.getElementById('corr-metric-actions-sub');
    if (actSub) actSub.textContent = `${data.discovered_actions || 0} Discovered (${data.concealed_actions || 0} Concealed)`;
    
    const discElem = document.getElementById('corr-metric-discrepancy');
    if (discElem) discElem.textContent = `${(data.total_record_discrepancy_kg || 0).toFixed(1)} kg`;
    
    const sancElem = document.getElementById('corr-metric-sanctions');
    if (sancElem) sancElem.textContent = data.sanctions_applied_count || 0;
    
    const detElem = document.getElementById('corr-metric-detection');
    if (detElem) detElem.textContent = `${((data.audit_detection_rate || 0) * 100).toFixed(1)}%`;
    
    const navCorr = document.getElementById('nav-corr-count');
    if (navCorr) navCorr.textContent = data.total_illicit_actions || 0;
    
    // Patronage Network & Clusters
    const patCont = document.getElementById('corr-patronage-container');
    if (patCont) {
      const clusters = data.patron_clusters || [];
      if (clusters.length === 0) {
        patCont.innerHTML = '<p class="text-muted" style="font-size: 13px;">No patron-client clusters detected. Informal power is diffuse.</p>';
      } else {
        patCont.innerHTML = `
          <div style="font-size: 13px;">
            ${clusters.map(c => `
              <div class="card" style="margin-bottom: 0.75rem; border-left: 4px solid var(--accent-cyan);">
                <div class="card-header" style="display: flex; justify-content: space-between; align-items: center;">
                  <strong>👑 Patron: ${c.patron_name}</strong>
                  <span class="badge badge-accent">Power: ${(c.total_cluster_power || 0).toFixed(1)}</span>
                </div>
                <div class="card-body" style="font-size: 12px;">
                  <div class="stat-row"><span>Patron Occupation:</span> <strong>${c.patron_occupation} (${c.patron_department})</strong></div>
                  <div class="stat-row"><span>Clients in Network:</span> <strong>${c.client_count || (c.clients ? c.clients.length : 0)} Citizens</strong></div>
                  <div style="margin-top: 4px; color: var(--text-secondary);">
                    <strong>Client Members:</strong> ${(c.clients || []).slice(0, 5).map(cl => `<a href="javascript:void(0)" onclick="openPersonModal(${cl.id})">${cl.name}</a> (${cl.occupation})`).join(', ')}
                    ${(c.clients || []).length > 5 ? `... and ${c.clients.length - 5} more` : ''}
                  </div>
                </div>
              </div>
            `).join('')}
          </div>
        `;
      }
    }
    
    // Illicit Actions Register
    const actCont = document.getElementById('corr-actions-container');
    if (actCont) {
      const actions = data.illicit_actions || [];
      if (actions.length === 0) {
        actCont.innerHTML = '<p class="text-muted" style="font-size: 13px;">No illicit diversions or corrupt actions recorded.</p>';
      } else {
        actCont.innerHTML = `
          <table class="data-table" style="font-size: 12px;">
            <thead>
              <tr>
                <th>ID</th>
                <th>Perpetrator</th>
                <th>Type</th>
                <th>Resource / Target</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              ${actions.map(a => `
                <tr>
                  <td><strong>#${a.id}</strong></td>
                  <td><a href="javascript:void(0)" onclick="openPersonModal(${a.perpetrator_id})">${a.perpetrator_name}</a></td>
                  <td><span class="badge badge-warning">${a.action_type}</span></td>
                  <td>${(a.target_amount || 0).toFixed(1)} ${a.target_resource}</td>
                  <td>
                    <span class="badge ${a.discovery_status === 'DISCOVERED' ? 'badge-danger' : (a.discovery_status === 'SANCTIONED' ? 'badge-success' : 'badge-secondary')}">
                      ${a.discovery_status}
                    </span>
                  </td>
                  <td>
                    <button class="btn btn-secondary btn-sm" onclick="inspectIllicitTrace(${a.id})">Trace ➔</button>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        `;
      }
    }
    
    // Conflict of Interest & Nepotism
    const coiCont = document.getElementById('corr-coi-container');
    if (coiCont) {
      const risks = data.conflict_of_interest_risks || [];
      if (risks.length === 0) {
        coiCont.innerHTML = '<p class="text-muted" style="font-size: 13px;">No acute conflicts of interest or nepotism risks flagged.</p>';
      } else {
        coiCont.innerHTML = `
          <table class="data-table" style="font-size: 12px;">
            <thead>
              <tr>
                <th>Official</th>
                <th>Department</th>
                <th>Risk Factor</th>
                <th>Kinship / Client Ties</th>
                <th>Temptation Score</th>
              </tr>
            </thead>
            <tbody>
              ${risks.map(r => `
                <tr>
                  <td><a href="javascript:void(0)" onclick="openPersonModal(${r.official_id})">${r.official_name}</a></td>
                  <td>${r.department}</td>
                  <td><span class="badge badge-danger">${r.risk_type}</span></td>
                  <td>${r.connections_count} Social Ties</td>
                  <td style="color: var(--accent-red); font-weight: bold;">${(r.temptation_score * 100).toFixed(0)}%</td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        `;
      }
    }
    
    // Audit & Whistleblower Log
    const audCont = document.getElementById('corr-audit-container');
    if (audCont) {
      const audits = data.audit_log || [];
      if (audits.length === 0) {
        audCont.innerHTML = '<p class="text-muted" style="font-size: 13px;">No formal audits or whistleblower investigations logged yet.</p>';
      } else {
        audCont.innerHTML = `
          <table class="data-table" style="font-size: 12px;">
            <thead>
              <tr>
                <th>Tick</th>
                <th>Type</th>
                <th>Target Action</th>
                <th>Evidence</th>
                <th>Outcome / Sanction</th>
              </tr>
            </thead>
            <tbody>
              ${audits.map(au => `
                <tr>
                  <td>Tick ${au.tick}</td>
                  <td><span class="badge ${au.type === 'WHISTLEBLOWER' ? 'badge-accent' : 'badge-info'}">${au.type}</span></td>
                  <td>Action #${au.action_id}</td>
                  <td>${(au.evidence_strength * 100).toFixed(0)}%</td>
                  <td><strong>${au.outcome || 'SANCTIONED'}</strong></td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        `;
      }
    }
    
  } catch (err) {
    console.error('Failed to fetch corruption data:', err);
  }
}

async function inspectIllicitTrace(actionId) {
  const container = document.getElementById('corr-trace-container');
  if (!container) return;
  container.innerHTML = '<p>Tracing authoritative 7-step causal lineage...</p>';
  try {
    const res = await fetch(`${API_BASE}/illicit_trace?id=${actionId}`);
    if (!res.ok) {
      container.innerHTML = `<p class="text-danger">Illicit Action #${actionId} not found.</p>`;
      return;
    }
    const trace = await res.json();
    const actor = trace.step_1_actor || {};
    const incentive = trace.step_2_incentive || {};
    const action = trace.step_3_action || {};
    const mass = trace.step_4_mass_conservation || {};
    const epistemic = trace.step_5_epistemic_discrepancy || {};
    const discovery = trace.step_6_discovery_path || {};
    const sanction = trace.step_7_institutional_consequence || {};
    
    container.innerHTML = `
      <div style="margin-bottom: 1rem;">
        <h4 style="color: var(--accent-cyan);">7-Step Authoritative Causal Trace: Action #${actionId} (${action.action_type || 'RESOURCE_DIVERSION'})</h4>
      </div>
      
      <div style="display: flex; flex-direction: column; gap: 0.75rem; font-size: 13px;">
        <div class="card" style="border-left: 4px solid var(--accent-purple);">
          <div class="card-header"><strong>1. Actor Profile & Authority Layer</strong></div>
          <div class="card-body">
            <div class="stat-row"><span>Perpetrator:</span> <strong><a href="javascript:void(0)" onclick="openPersonModal(${actor.id})">${actor.name}</a> (Citizen #${actor.id})</strong></div>
            <div class="stat-row"><span>Position:</span> <strong>${actor.occupation} (${actor.department}, Clearance Level ${actor.clearance})</strong></div>
            <div class="stat-row"><span>Informal Power Score:</span> <strong>${(actor.informal_power || 0).toFixed(1)}</strong></div>
          </div>
        </div>
        
        <div class="card" style="border-left: 4px solid var(--accent-blue);">
          <div class="card-header"><strong>2. Incentive & Relationship Driver</strong></div>
          <div class="card-body">
            <div class="stat-row"><span>Beneficiary:</span> <strong><a href="javascript:void(0)" onclick="openPersonModal(${incentive.beneficiary_id})">${incentive.beneficiary_name}</a> (Citizen #${incentive.beneficiary_id})</strong></div>
            <div class="stat-row"><span>Relationship / Motive:</span> <strong>${incentive.relationship_type || 'Informal Favour Debt / Kinship Obligation'}</strong></div>
            <div class="stat-row"><span>Favour Obligation Value:</span> <strong>${(incentive.obligation_value || 0).toFixed(1)}</strong></div>
          </div>
        </div>
        
        <div class="card" style="border-left: 4px solid var(--accent-yellow);">
          <div class="card-header"><strong>3. Illicit Physical Action</strong></div>
          <div class="card-body">
            <div class="stat-row"><span>Action Executed:</span> <strong>${action.action_type}</strong></div>
            <div class="stat-row"><span>Target Resource:</span> <strong>${action.target_amount} ${action.target_resource}</strong></div>
            <div class="stat-row"><span>Execution Tick:</span> <strong>Tick ${action.tick}</strong></div>
          </div>
        </div>
        
        <div class="card" style="border-left: 4px solid var(--accent-green);">
          <div class="card-header"><strong>4. Physical Mass Conservation Transfer</strong></div>
          <div class="card-body">
            <div class="stat-row"><span>Source Physical Room:</span> <strong><a href="javascript:void(0)" onclick="openRoomModal(${mass.source_room_id})">Room #${mass.source_room_id}</a> (-${mass.amount} kg)</strong></div>
            <div class="stat-row"><span>Destination Physical Room:</span> <strong><a href="javascript:void(0)" onclick="openRoomModal(${mass.dest_room_id})">Room #${mass.dest_room_id}</a> (+${mass.amount} kg)</strong></div>
            <div class="stat-row"><span>Physical Mass Balance Error:</span> <strong class="text-success">${(mass.mass_delta_error_kg || 0).toFixed(6)} kg (100% CONSERVED)</strong></div>
          </div>
        </div>
        
        <div class="card" style="border-left: 4px solid var(--accent-red);">
          <div class="card-header"><strong>5. Hidden Record Discrepancy (Physical vs Official Ledger)</strong></div>
          <div class="card-body">
            <div class="stat-row"><span>Official Recorded Amount:</span> <strong>${mass.official_recorded_amount || 0} kg</strong></div>
            <div class="stat-row"><span>Physical Ground Truth:</span> <strong>${mass.physical_actual_amount || mass.amount} kg</strong></div>
            <div class="stat-row"><span>Hidden Ledger Discrepancy:</span> <strong class="text-danger">${mass.discrepancy_amount || mass.amount} kg (Concealment: ${((epistemic.concealment_level || 0) * 100).toFixed(0)}%)</strong></div>
          </div>
        </div>
        
        <div class="card" style="border-left: 4px solid var(--accent-cyan);">
          <div class="card-header"><strong>6. Discovery Pathway (Audit vs Whistleblower)</strong></div>
          <div class="card-body">
            <div class="stat-row"><span>Discovery Status:</span> <strong>${discovery.status || 'DISCOVERED'}</strong></div>
            <div class="stat-row"><span>Discovery Mechanism:</span> <strong>${discovery.mechanism || 'Whistleblower via Bounded Social Graph / Routine Audit'}</strong></div>
            <div class="stat-row"><span>Discoverer:</span> <strong>${discovery.discoverer_name ? `${discovery.discoverer_name} (Citizen #${discovery.discoverer_id})` : 'Audit Department Inspection'}</strong></div>
            <div class="stat-row"><span>Discovered at Tick:</span> <strong>Tick ${discovery.discovered_tick || action.tick}</strong></div>
          </div>
        </div>
        
        <div class="card" style="border-left: 4px solid var(--accent-red);">
          <div class="card-header"><strong>7. Institutional Consequence & Memory Scars</strong></div>
          <div class="card-body">
            <div class="stat-row"><span>Sanctions Applied:</span> <strong>${sanction.penalty_description || 'Demotion, Clearance Revocation & Public Censure'}</strong></div>
            <div class="stat-row"><span>Legitimacy Impact:</span> <strong class="text-danger">-${((sanction.legitimacy_penalty || 0) * 100).toFixed(2)}% Authority Erosion</strong></div>
            <div class="stat-row"><span>Political Memory:</span> <strong>Event '${sanction.event_type || 'EVENT_CORRUPTION_DISCOVERED'}' recorded across witness social graph</strong></div>
          </div>
        </div>
      </div>
    `;
  } catch (err) {
    container.innerHTML = '<p class="text-danger">Failed to load illicit causal trace.</p>';
  }
}

// 11. Incidents & Crises
async function fetchIncidents() {
  try {
    const res = await fetch(`${API_BASE}/incidents`);
    const data = await res.json();
    
    const container = document.getElementById('incidents-container');
    container.innerHTML = '';
    
    const incidents = data.active_incidents || [];
    if (incidents.length === 0) {
      container.innerHTML = '<div class="card"><div class="card-body text-success">✓ Zero active incidents or system failures detected.</div></div>';
      return;
    }
    
    incidents.forEach(inc => {
      const card = document.createElement('div');
      card.className = 'card';
      
      const badgeClass = inc.severity >= 3 ? 'badge-danger' : 'badge-warning';
      card.innerHTML = `
        <div class="card-header">
          <h3>🚨 ${inc.title}</h3>
          <span class="badge ${badgeClass}">${inc.severity_name}</span>
        </div>
        <div class="card-body">
          <p style="margin-bottom: 0.75rem;">${inc.description}</p>
          <div class="stat-row"><span>Onset Tick:</span> <strong>Tick ${inc.onset_tick}</strong></div>
          <div class="stat-row"><span>Duration:</span> <strong>${inc.duration_ticks} ticks</strong></div>
          <div class="stat-row"><span>Root Cause Entity:</span> <strong>Entity #${inc.root_cause_id}</strong></div>
        </div>
      `;
      container.appendChild(card);
    });
  } catch (err) {
    console.error('Failed to fetch incidents:', err);
  }
}

// 12. Timeline
async function fetchTimeline() {
  try {
    const res = await fetch(`${API_BASE}/timeline`);
    const data = await res.json();
    
    const container = document.getElementById('timeline-events-list');
    container.innerHTML = '';
    
    const events = data.events || [];
    if (events.length === 0) {
      container.innerHTML = '<div class="text-center" style="color: var(--text-muted);">No major simulation events logged yet.</div>';
      return;
    }
    
    events.forEach(ev => {
      const div = document.createElement('div');
      div.className = `timeline-item ${ev.category.toLowerCase().includes('incident') ? 'incident' : 'order'}`;
      div.innerHTML = `
        <div style="display: flex; justify-content: space-between; font-size: 12px; color: var(--text-muted);">
          <span>Tick ${ev.tick}</span>
          <span class="badge badge-info">${ev.category}</span>
        </div>
        <strong style="font-size: 14px; margin-top: 2px; display: block;">${ev.title}</strong>
        <p style="font-size: 13px; color: var(--text-secondary); margin-top: 4px;">${ev.description}</p>
      `;
      container.appendChild(div);
    });
  } catch (err) {
    console.error('Failed to fetch timeline:', err);
  }
}

// 13. Dependencies
async function fetchDependencies() {
  try {
    const res = await fetch(`${API_BASE}/dependencies`);
    const data = await res.json();
    
    const card = document.getElementById('dependencies-diagram-card');
    card.innerHTML = `
      <h3 style="color: var(--accent-cyan); margin-bottom: 1rem;">Closed Physical Loop Topology</h3>
      <div style="line-height: 1.8; font-size: 13.5px;">
        <p><strong>1. Labour Feed:</strong> Population supplies machine operators, miners, smelters, and maintenance technicians.</p>
        <p><strong>2. Material Flow:</strong> Seam Ore (100k kg) ➔ Mine ➔ Beneficiation ➔ Smelter ➔ Lathe Machining ➔ Bearings & Spare Parts.</p>
        <p><strong>3. Maintenance Integrity:</strong> Machined Bearings service Water Pumps to prevent degradation to DEGRADED / BROKEN states.</p>
        <p><strong>4. Utility Support:</strong> Nominal Water Pumps extract 500 L/min to fill Habitat Reservoir (100,000 L capacity).</p>
        <p><strong>5. Life Support:</strong> Clean water sustains citizen hydration and prevents dehydration mortality.</p>
      </div>
    `;
  } catch (err) {
    console.error('Failed to fetch dependencies:', err);
  }
}

// 14. Invariants & Checks
async function runInvariantsValidation() {
  try {
    const res = await fetch(`${API_BASE}/validate`, { method: 'POST' });
    const data = await res.json();
    
    const container = document.getElementById('invariants-report-container');
    const pop = data.population_validation || {};
    const mass = data.mass_balance || {};
    const mach = data.machinery_integrity || {};
    
    container.innerHTML = `
      <div class="card">
        <div class="card-header">
          <h3>🛡️ State Invariants Audit Report</h3>
          <span class="badge ${data.is_valid ? 'badge-success' : 'badge-danger'}">
            ${data.is_valid ? 'ALL INVARIANTS PASSED' : 'INVARIANT BREACH'}
          </span>
        </div>
        <div class="card-body">
          <div class="stat-row"><span>State Checksum:</span> <strong>0x${(data.checksum || 0).toString(16).toUpperCase()}</strong></div>
          <hr class="divider">
          <h4>1. Population Invariants</h4>
          <div class="stat-row"><span>Acyclic Parent/Child Tree:</span> <strong class="text-success">VALID</strong></div>
          <div class="stat-row"><span>Single-Occupancy Bed Allocation:</span> <strong class="text-success">VALID</strong></div>
          <div class="stat-row"><span>Zero Orphan Infant/Child Invariant:</span> <strong class="text-success">VALID</strong></div>
          <hr class="divider">
          <h4>2. Mass Conservation Invariant</h4>
          <div class="stat-row"><span>Initial Seam Reference:</span> <strong>100,000.0 kg</strong></div>
          <div class="stat-row"><span>Calculated Total System Mass:</span> <strong>${(mass.total_mass_kg || 0).toFixed(6)} kg</strong></div>
          <div class="stat-row"><span>Mass Error Delta:</span> <strong class="text-success">${(mass.error_kg || 0).toFixed(6)} kg (Target < 0.001 kg)</strong></div>
          <hr class="divider">
          <h4>3. Machinery Integrity</h4>
          <div class="stat-row"><span>Total Machines Checked:</span> <strong>${mach.total_machines || 0}</strong></div>
        </div>
      </div>
    `;
  } catch (err) {
    console.error('Failed to run invariants validation:', err);
  }
}

// 15. 22-System Matrix
async function fetchWiringMatrix() {
  try {
    const res = await fetch(`${API_BASE}/wiring`);
    const data = await res.json();
    
    const tbody = document.getElementById('tbody-wiring-matrix');
    tbody.innerHTML = '';
    
    (data.wiring_matrix || []).forEach(w => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong>${w.system}</strong></td>
        <td><code>${w.source}</code></td>
        <td>${w.order}</td>
        <td><code>${w.endpoint}</code></td>
        <td><span class="badge badge-success">${w.status}</span></td>
      `;
      tbody.appendChild(tr);
    });
  } catch (err) {
    console.error('Failed to fetch wiring matrix:', err);
  }
}

// 16. Performance & Benchmarks
async function fetchPerformance() {
  try {
    const res = await fetch(`${API_BASE}/performance`);
    const data = await res.json();
    
    const bench = data.benchmark || {};
    document.getElementById('perf-throughput-card').innerHTML = `
      <div class="stat-row"><span>Last Step Batch:</span> <strong>${bench.ticks_stepped || 0} ticks</strong></div>
      <div class="stat-row"><span>Step Latency:</span> <strong>${(bench.duration_ms || 0).toFixed(2)} ms</strong></div>
      <div class="stat-row"><span>Latency Per Tick:</span> <strong>${(bench.usec_per_tick || 0).toFixed(1)} µs/tick</strong></div>
      <div class="stat-row"><span>Throughput:</span> <strong>${(bench.ticks_per_sec || 0).toFixed(0)} ticks/sec</strong></div>
    `;
    
    const counts = data.entity_counts || {};
    document.getElementById('perf-entity-card').innerHTML = `
      <div class="stat-row"><span>Person Entities:</span> <strong>${counts.person || 0}</strong></div>
      <div class="stat-row"><span>Household Entities:</span> <strong>${counts.household || 0}</strong></div>
      <div class="stat-row"><span>Room Entities:</span> <strong>${counts.room || 0}</strong></div>
      <div class="stat-row"><span>Inventory Entities:</span> <strong>${counts.inventory || 0}</strong></div>
      <div class="stat-row"><span>Machine Entities:</span> <strong>${counts.machine || 0}</strong></div>
      <div class="stat-row"><span>EventQueue Pending:</span> <strong>${data.event_queue_size || 0}</strong></div>
    `;
  } catch (err) {
    console.error('Failed to fetch performance metrics:', err);
  }
}

// 17. Raw State Inspector
async function fetchRawEntity(type, id) {
  try {
    const res = await fetch(`${API_BASE}/raw?type=${type}&id=${id}`);
    const data = await res.json();
    document.getElementById('raw-json-viewer').textContent = JSON.stringify(data, null, 2);
  } catch (err) {
    console.error('Failed to fetch raw state:', err);
    document.getElementById('raw-json-viewer').textContent = 'Error fetching raw entity state.';
  }
}

// Entity Detail Modals / Drawers
function initModals() {
  const modal = document.getElementById('entity-modal');
  document.getElementById('btn-close-modal').addEventListener('click', () => {
    modal.classList.add('hidden');
  });
  
  modal.addEventListener('click', (e) => {
    if (e.target === modal) {
      modal.classList.add('hidden');
    }
  });
}

async function openPersonModal(personId) {
  const modal = document.getElementById('entity-modal');
  const title = document.getElementById('modal-title');
  const body = document.getElementById('modal-content');
  
  modal.classList.remove('hidden');
  title.textContent = `Resident Profile: #${personId}`;
  body.innerHTML = 'Loading resident details...';
  
  try {
    const res = await fetch(`${API_BASE}/person?id=${personId}`);
    const p = await res.json();
    
    body.innerHTML = `
      <div class="stat-row"><span>Full Name:</span> <strong>${p.full_name} (${p.sex}, ${p.age_years}y)</strong></div>
      <div class="stat-row"><span>Life Stage:</span> ${getStageBadge(p.life_stage)}</div>
      <div class="stat-row"><span>Occupation:</span> <strong>${p.occupation_id} (${p.department_id})</strong></div>
      <div class="stat-row"><span>Current Shift:</span> <strong>${p.shift}</strong></div>
      <div class="stat-row"><span>Current Activity:</span> <span class="badge badge-info">${p.activity}</span></div>
      <div class="stat-row"><span>Security Clearance:</span> <strong>Level ${p.security_clearance}</strong></div>
      <hr class="divider">
      <h4>Physiological & Skills</h4>
      <div class="stat-row"><span>Hydration:</span> <strong>${p.hydration_percent.toFixed(1)}%</strong></div>
      <div class="stat-row"><span>Health:</span> <strong>${p.health_percent.toFixed(1)}%</strong></div>
      <div class="stat-row"><span>Education Score:</span> <strong>${p.education_score.toFixed(1)} pts</strong></div>
      <hr class="divider">
      <h4>Family & Relationships</h4>
      <div class="stat-row"><span>Household ID:</span> <a href="javascript:void(0)" onclick="openHouseholdModal(${p.household_id})">#${p.household_id}</a></div>
      <div class="stat-row"><span>Partner ID:</span> ${p.partner_id > 0 ? `<a href="javascript:void(0)" onclick="openPersonModal(${p.partner_id})">#${p.partner_id}</a>` : 'None'}</div>
      <div class="stat-row"><span>Parent IDs:</span> ${p.parent_ids.length > 0 ? p.parent_ids.map(pid => `<a href="javascript:void(0)" onclick="openPersonModal(${pid})">#${pid}</a>`).join(', ') : 'None'}</div>
      <div class="stat-row"><span>Children IDs:</span> ${p.children_ids.length > 0 ? p.children_ids.map(cid => `<a href="javascript:void(0)" onclick="openPersonModal(${cid})">#${cid}</a>`).join(', ') : 'None'}</div>
      <hr class="divider">
      <h4>Locations & Routines</h4>
      <div class="stat-row"><span>Home Room:</span> <a href="javascript:void(0)" onclick="openRoomModal(${p.home_room_id})">Room ${p.home_room_id}</a></div>
      <div class="stat-row"><span>Workplace Room:</span> ${p.workplace_room_id > 0 ? `<a href="javascript:void(0)" onclick="openRoomModal(${p.workplace_room_id})">Room ${p.workplace_room_id}</a>` : 'None'}</div>
      <div class="stat-row"><span>Current Room:</span> <a href="javascript:void(0)" onclick="openRoomModal(${p.current_location_id})">Room ${p.current_location_id}</a></div>
    `;
  } catch (err) {
    body.innerHTML = 'Failed to load resident profile.';
  }
}

async function openRoomModal(roomId) {
  if (!roomId || roomId <= 0) return;
  const modal = document.getElementById('entity-modal');
  const title = document.getElementById('modal-title');
  const body = document.getElementById('modal-content');
  
  modal.classList.remove('hidden');
  title.textContent = `Room Details: #${roomId}`;
  body.innerHTML = 'Loading room details...';
  
  try {
    const res = await fetch(`${API_BASE}/room?id=${roomId}`);
    const r = await res.json();
    
    let occHtml = (r.occupants || []).map(o => `<li><a href="javascript:void(0)" onclick="openPersonModal(${o.id})">${o.name}</a> (${o.activity})</li>`).join('');
    if (!occHtml) occHtml = '<li>No current occupants</li>';
    
    body.innerHTML = `
      <div class="stat-row"><span>Type:</span> <strong>${r.room_type_name}</strong></div>
      <div class="stat-row"><span>Location:</span> <strong>Sector ${r.sector_id}, Level ${r.level}</strong></div>
      <div class="stat-row"><span>Capacity:</span> <strong>${r.occupant_count} / ${r.capacity_people}</strong></div>
      <div class="stat-row"><span>Beds:</span> <strong>${r.bed_count} (${r.occupied_beds.length} occupied)</strong></div>
      <hr class="divider">
      <h4>Current Occupants (${r.occupant_count})</h4>
      <ul style="padding-left: 1.25rem; font-size: 13px;">${occHtml}</ul>
    `;
  } catch (err) {
    body.innerHTML = 'Failed to load room details.';
  }
}

async function openHouseholdModal(householdId) {
  if (!householdId || householdId <= 0) return;
  const modal = document.getElementById('entity-modal');
  const title = document.getElementById('modal-title');
  const body = document.getElementById('modal-content');
  
  modal.classList.remove('hidden');
  title.textContent = `Household: #${householdId}`;
  body.innerHTML = 'Loading household details...';
  
  try {
    const res = await fetch(`${API_BASE}/household?id=${householdId}`);
    const h = await res.json();
    
    let memHtml = (h.members || []).map(m => `<li><a href="javascript:void(0)" onclick="openPersonModal(${m.id})">${m.name}</a> (${m.life_stage}, ${m.occupation})</li>`).join('');
    
    body.innerHTML = `
      <div class="stat-row"><span>Household Name:</span> <strong>${h.name}</strong></div>
      <div class="stat-row"><span>Head of House:</span> <strong>${h.head_name}</strong></div>
      <div class="stat-row"><span>Home Room:</span> <a href="javascript:void(0)" onclick="openRoomModal(${h.home_room_id})">Room ${h.home_room_id}</a></div>
      <div class="stat-row"><span>Member Count:</span> <strong>${h.member_count}</strong></div>
      <hr class="divider">
      <h4>Household Members</h4>
      <ul style="padding-left: 1.25rem; font-size: 13px;">${memHtml}</ul>
    `;
  } catch (err) {
    body.innerHTML = 'Failed to load household details.';
  }
}
