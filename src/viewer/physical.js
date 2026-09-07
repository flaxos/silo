/* SILO physical viewer. Rendering and interpolation consume server projections only. */
(() => {
  'use strict';
  const API = `${window.location.origin}/api`;
  const $ = id => document.getElementById(id);
  const canvas = $('physical-canvas');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  const model = {
    snapshot: null, revision: -1, resetRevision: -1, rooms: new Map(), geometry: new Map(),
    people: new Map(), households: new Map(), machines: new Map(), incidents: [],
    selected: null, detail: null, isolatedLevel: null, hiddenLevels: new Set(), follow: null,
    overlays: {people:true,homes:true,work:true,industry:true,machines:true,resources:false,water:false,incidents:true,institutions:false},
    camera: {x:0,y:0,zoom:1}, hits: [], polling:false, apiMs:0, lastError:'', drawStats:{rooms:0,people:0,clusters:0,machines:0}, fps:0
  };
  const roomColors = {
    RESIDENTIAL_APARTMENT:'#587565',DORMITORY:'#536b62',SCHOOL:'#53758b',CANTEEN:'#907348',KITCHEN:'#806844',HYGIENE_FACILITY:'#477582',
    CLINIC:'#55866d',SERVER_ROOM:'#5d668c',MACHINE_SHOP:'#846346',FOUNDRY:'#8d503d',DEEP_MINE:'#514c49',WATER_PUMP_STATION:'#366b82'
  };
  let dpr=1, lastFrame=performance.now(), frameSamples=[];

  function escapeHTML(v){const d=document.createElement('div');d.textContent=v == null ? '—' : String(v);return d.innerHTML;}
  function title(v){return String(v||'unknown').replaceAll('_',' ').toLowerCase().replace(/(^|\s)\S/g,m=>m.toUpperCase());}
  function checksum(v){ return typeof v === 'string' ? v : (v == null ? '—' : String(v)); }
  function roomName(id){const r=model.rooms.get(Number(id)); return r ? `${title(r.room_type_name)} R${id}` : (id ? `Unresolved room ${id}` : 'Unassigned');}
  function entityName(type,id){id=Number(id); if(type==='person')return model.people.get(id)?.name||`Person ${id}`;if(type==='household')return model.households.get(id)?.name||`Household ${id}`;if(type==='room')return roomName(id);if(type==='machine')return `${title(model.machines.get(id)?.type)} M${id}`;return `${title(type)} ${id}`;}
  function roomCategory(r){const n=r.room_type_name||'';if(/RESIDENT|DORM/.test(n))return'homes';if(/MINE|SHOP|FOUNDRY/.test(n))return'industry';if(/SCHOOL|CLINIC|CANTEEN|KITCHEN|SERVER/.test(n))return'work';return null;}
  function levelVisible(level){return model.isolatedLevel===null ? !model.hiddenLevels.has(level) : Number(level)===Number(model.isolatedLevel);}
  function endpoint(paths){return fetch(paths[0]).then(r=>{if(r.ok)return r; if(paths.length>1)return fetch(paths[1]);return r;});}
  async function getJSON(paths){const started=performance.now(),res=await endpoint(paths);model.apiMs=Math.round(performance.now()-started);if(!res.ok)throw new Error(`API ${res.status}: ${await res.text()}`);return res.json();}

  async function loadSnapshot(){
    if(model.polling)return; model.polling=true;
    try{const data=await getJSON([`${API}/physical_snapshot`,`${API}/spatial`]); applySnapshot(data); clearError();}
    catch(e){showError(`Physical state unavailable: ${e.message}`);} finally{model.polling=false;}
  }
  async function poll(){
    if(!model.snapshot||model.polling||document.hidden)return; model.polling=true;
    try{const d=await getJSON([`${API}/physical_delta?since=${model.revision}`,`${API}/spatial_updates?since=${model.revision}`]);
      if(Number(d.reset_revision)!==model.resetRevision||Number(d.revision)<model.revision){model.polling=false;await loadSnapshot();return;} applyDelta(d);clearError();
    }catch(e){showError(`Live update delayed: ${e.message}`);}finally{model.polling=false;}
  }
  function applySnapshot(s){
    model.snapshot=s;model.revision=Number(s.revision||0);model.resetRevision=Number(s.reset_revision||0);
    model.rooms=new Map((s.rooms||[]).map(r=>[Number(r.id),r]));model.geometry=new Map((s.geometry?.rooms||[]).map(r=>[Number(r.id),r]));
    model.people=new Map((s.people||[]).map(p=>[Number(p.id),p]));model.households=new Map((s.households||[]).map(h=>[Number(h.id),h]));model.machines=new Map((s.machines||[]).map(m=>[Number(m.id),m]));
    model.incidents=Array.isArray(s.incidents)?s.incidents:(s.incidents?.incidents||[]); buildLevels();buildOverlays();updateStatus(s.clock);resize();fitWorld();
  }
  function applyDelta(d){
    model.revision=Number(d.revision??model.revision);for(const p of d.people||[])model.people.set(Number(p.id),{...(model.people.get(Number(p.id))||{}),...p});
    for(const id of d.removed_person_ids||[])model.people.delete(Number(id));for(const m of d.machines||[])model.machines.set(Number(m.id),m);
    if(d.incidents)model.incidents=Array.isArray(d.incidents)?d.incidents:(d.incidents.incidents||[]);updateStatus(d.clock);
    if(model.follow)followCamera(); if(model.selected?.type==='person') renderSelectedSummary();
  }
  function updateStatus(clock){
    const s=model.snapshot||{}; const formatted=clock?.formatted_time||clock?.display||`Tick ${model.revision}`;
    $('physical-status-clock').textContent=formatted;$('physical-status-pop').textContent=`${model.people.size} RESIDENTS`;$('physical-status-seed').textContent=`SEED ${s.seed??'—'}`;
    $('physical-status-checksum').textContent=`CHECKSUM ${checksum(clock?.checksum??s.checksum)}`;$('physical-transport').textContent='LIVE • DELTA';
  }
  function showError(text){model.lastError=text;$('physical-error').textContent=text;$('physical-error').classList.remove('hidden');$('physical-transport').textContent='API DEGRADED';}
  function clearError(){model.lastError='';$('physical-error').classList.add('hidden');}

  function buildLevels(){const root=$('physical-levels');root.innerHTML='';for(const l of model.snapshot?.geometry?.levels||[]){const b=document.createElement('button');b.dataset.level=l.id;b.innerHTML=`<i class="level-swatch"></i><span>Level ${escapeHTML(l.id)}</span><small>${l.room_count} rooms</small>`;b.onclick=()=>{model.isolatedLevel=model.isolatedLevel===Number(l.id)?null:Number(l.id);model.hiddenLevels.clear();buildLevels();fitWorld();};b.oncontextmenu=e=>{e.preventDefault();model.isolatedLevel=null;model.hiddenLevels.has(Number(l.id))?model.hiddenLevels.delete(Number(l.id)):model.hiddenLevels.add(Number(l.id));buildLevels();};if(model.isolatedLevel===Number(l.id))b.classList.add('active');if(model.hiddenLevels.has(Number(l.id)))b.style.opacity='.35';root.appendChild(b);} $('physical-level-chip').textContent=model.isolatedLevel===null?'WHOLE SILO':`LEVEL ${model.isolatedLevel} ISOLATED`;}
  function buildOverlays(){
    const caps=model.snapshot?.capabilities||{}, available={people:true,homes:true,work:true,industry:true,machines:model.machines.size>0,resources:(model.snapshot?.dependency_links||[]).length>0,water:(caps.utilities||[]).includes('water'),incidents:!!caps.incidents,institutions:!!caps.institutions};
    const root=$('physical-overlays');root.innerHTML='';for(const [key,label] of Object.entries({people:'People',homes:'Homes',work:'Work & services',industry:'Industry',machines:'Machines',resources:'Resource dependencies',water:'Water utility',incidents:'Incidents',institutions:'Institutions'})){const l=document.createElement('label');if(!available[key])l.classList.add('physical-overlay-unavailable');l.innerHTML=`<input type="checkbox" data-overlay="${key}" ${model.overlays[key]&&available[key]?'checked':''} ${available[key]?'':'disabled'}> ${label}`;root.appendChild(l);}root.onchange=e=>{if(e.target.dataset.overlay)model.overlays[e.target.dataset.overlay]=e.target.checked;};
  }
  function resize(){const r=canvas.getBoundingClientRect();dpr=Math.min(devicePixelRatio||1,2);canvas.width=Math.max(1,Math.round(r.width*dpr));canvas.height=Math.max(1,Math.round(r.height*dpr));}
  function fitWorld(){const b=model.snapshot?.geometry?.bounds;if(!b)return;const rect=canvas.getBoundingClientRect();let minY=0,h=b.height;if(model.isolatedLevel!==null){const gs=[...model.geometry.values()].filter(g=>Number(g.level)===model.isolatedLevel);if(gs.length){minY=Math.min(...gs.map(g=>g.y))-30;h=Math.max(...gs.map(g=>g.y+g.height))-minY+30;}}model.camera.zoom=Math.max(.12,Math.min(2,Math.min((rect.width-70)/Math.max(1,b.width),(rect.height-70)/Math.max(1,h))));model.camera.x=(rect.width/model.camera.zoom-b.width)/2;model.camera.y=(rect.height/model.camera.zoom-h)/2-minY;}
  function worldToScreen(x,y){return{x:(x+model.camera.x)*model.camera.zoom,y:(y+model.camera.y)*model.camera.zoom};}
  function screenToWorld(x,y){return{x:x/model.camera.zoom-model.camera.x,y:y/model.camera.zoom-model.camera.y};}
  function hash(n){n=Math.imul(n^61,n^n>>>16);n=n+Math.imul(n<<3,1);n^=n>>>4;return((Math.imul(n,0x27d4eb2d)^n>>>15)>>>0)/4294967295;}
  function personPosition(p){
    const a=model.geometry.get(Number(p.location_id)),b=model.geometry.get(Number(p.destination_id));let g=a||b;if(!g)return null;
    let x=g.x+12+hash(Number(p.id))*Math.max(8,g.width-24),y=g.y+g.height-11-hash(Number(p.id)*13)*20;
    if(a&&b&&p.activity==='TRAVELING'&&Number.isFinite(Number(p.travel_progress))){const q=Math.max(0,Math.min(1,Number(p.travel_progress)));x=(a.x+a.width/2)*(1-q)+(b.x+b.width/2)*q;y=(a.y+a.height/2)*(1-q)+(b.y+b.height/2)*q;}
    return{x,y,room:g};
  }
  function personColor(p){const d=String(p.department_id||p.occupation_id||'').toLowerCase();if(p.life_stage==='STUDENT'||p.life_stage==='CHILD'||p.life_stage==='INFANT')return'#78c9ed';if(d.includes('security'))return'#e9796d';if(d.includes('medical')||d.includes('health'))return'#8de1b4';if(/engineer|maintenance|mine|machine/.test(d))return'#eaa35b';return'#e8ce83';}
  function beginWorld(){ctx.setTransform(dpr*model.camera.zoom,0,0,dpr*model.camera.zoom,dpr*model.camera.x*model.camera.zoom,dpr*model.camera.y*model.camera.zoom);}
  function draw(){
    const rect=canvas.getBoundingClientRect();ctx.setTransform(dpr,0,0,dpr,0,0);ctx.clearRect(0,0,rect.width,rect.height);drawRock(rect);beginWorld();model.hits=[];model.drawStats={rooms:0,people:0,clusters:0,machines:0};
    drawConnectors();drawDependencies();for(const g of model.geometry.values())if(levelVisible(g.level))drawRoom(g);drawMachines();drawIncidents();drawPeople();
    ctx.setTransform(dpr,0,0,dpr,0,0);$('physical-metrics').textContent=`${model.fps} FPS • API ${model.apiMs}ms • ${model.drawStats.people} PEOPLE DRAWN`;
    const now=performance.now(),dt=now-lastFrame;lastFrame=now;frameSamples.push(dt);if(frameSamples.length>30)frameSamples.shift();model.fps=Math.round(1000/(frameSamples.reduce((a,b)=>a+b,0)/frameSamples.length));requestAnimationFrame(draw);
  }
  function drawRock(rect){ctx.fillStyle='#06090a';ctx.fillRect(0,0,rect.width,rect.height);ctx.strokeStyle='#101718';ctx.lineWidth=1;for(let x=-40;x<rect.width+80;x+=58){ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x-45,rect.height);ctx.stroke();}}
  function drawConnectors(){ctx.save();ctx.setLineDash([4,4]);ctx.strokeStyle='#506058';ctx.lineWidth=8/model.camera.zoom;for(const c of model.snapshot?.geometry?.connectors||[]){const levels=model.snapshot.geometry.levels||[],a=levels.find(l=>Number(l.id)===Number(c.from_level)),b=levels.find(l=>Number(l.id)===Number(c.to_level));if(!a||!b)continue;ctx.beginPath();ctx.moveTo(c.x,a.y+36);ctx.lineTo(c.x,b.y+36);ctx.stroke();}ctx.restore();}
  function drawRoom(g){
    const r=model.rooms.get(Number(g.id))||g,cat=roomCategory(r);if(cat&&!model.overlays[cat])return;const color=roomColors[r.room_type_name]||'#506167',depth=8;
    ctx.fillStyle='#182125';ctx.beginPath();ctx.moveTo(g.x+g.width,g.y+8);ctx.lineTo(g.x+g.width+depth,g.y);ctx.lineTo(g.x+g.width+depth,g.y+g.height-depth);ctx.lineTo(g.x+g.width,g.y+g.height);ctx.fill();
    ctx.fillStyle=color+'b5';ctx.fillRect(g.x,g.y+8,g.width,g.height-8);ctx.strokeStyle=model.selected?.type==='room'&&Number(model.selected.id)===Number(g.id)?'#d7f5dc':'#7e9187';ctx.lineWidth=(model.selected?.type==='room'&&Number(model.selected.id)===Number(g.id)?3:1)/model.camera.zoom;ctx.strokeRect(g.x,g.y+8,g.width,g.height-8);
    ctx.fillStyle='#d8e2da';ctx.font=`${Math.max(7,10/model.camera.zoom)}px monospace`;if(model.camera.zoom>.28)ctx.fillText(`${title(r.room_type_name)} • R${g.id}`,g.x+6,g.y+21);
    if((r.bed_count||0)>0&&model.overlays.homes)drawBeds(g,r);drawRoomActivity(g,r);model.hits.push({type:'room',id:Number(g.id),x:g.x,y:g.y,w:g.width,h:g.height});model.drawStats.rooms++;
  }
  function drawBeds(g,r){const beds=Math.min(Number(r.bed_count),18),used=Object.keys(r.occupied_beds||{}).length;for(let i=0;i<beds;i++){const x=g.x+7+(i%9)*12,y=g.y+g.height-12-Math.floor(i/9)*9;ctx.fillStyle=i<used?'#c9b487':'#26383a';ctx.fillRect(x,y,9,5);ctx.fillStyle='#e2d9bc';ctx.fillRect(x,y,3,5);}}
  function drawRoomActivity(g,r){if(model.camera.zoom<.22){const n=[...model.people.values()].filter(p=>Number(p.location_id)===Number(g.id)).length;if(n){ctx.fillStyle='#d2e1d5';ctx.beginPath();ctx.arc(g.x+g.width-12,g.y+20,Math.min(10,3+Math.sqrt(n)),0,Math.PI*2);ctx.fill();ctx.fillStyle='#101515';ctx.font='7px monospace';ctx.fillText(n,g.x+g.width-17,g.y+22);model.drawStats.clusters++;}}}
  function drawMachines(){if(!model.overlays.machines)return;for(const m of model.machines.values()){const g=model.geometry.get(Number(m.room_id));if(!g||!levelVisible(g.level))continue;const x=g.x+g.width-20,y=g.y+g.height-18;ctx.fillStyle=m.state==='NOMINAL'?'#83c990':m.state==='DEGRADED'?'#e6ba58':'#ed695c';ctx.fillRect(x,y,11,9);ctx.strokeStyle='#18211e';ctx.strokeRect(x,y,11,9);model.hits.push({type:'machine',id:Number(m.id),x:x-3,y:y-3,w:17,h:15});model.drawStats.machines++;}}
  function drawDependencies(){if(!model.overlays.resources&&!model.overlays.water)return;ctx.save();ctx.setLineDash([7,5]);ctx.lineWidth=1.5/model.camera.zoom;for(const l of model.snapshot?.dependency_links||[]){if(l.system==='water'&&!model.overlays.water&&!model.overlays.resources)continue;const g=model.geometry.get(Number(l.room_id));if(!g)continue;ctx.strokeStyle=l.system==='water'?'#4eb8e1':'#d0a968';ctx.beginPath();ctx.moveTo(g.x+g.width/2,g.y+g.height/2);ctx.lineTo((model.snapshot.geometry.bounds.width||0)-20,g.y+g.height/2);ctx.stroke();}ctx.restore();}
  function drawIncidents(){if(!model.overlays.incidents)return;for(const i of model.incidents){const rid=Number(i.room_id||i.location_id||i.root_room_id),g=model.geometry.get(rid);if(!g||!levelVisible(g.level))continue;const x=g.x+g.width/2,y=g.y+3;ctx.fillStyle='#ff6e5c';ctx.beginPath();ctx.moveTo(x,y-8);ctx.lineTo(x+7,y+5);ctx.lineTo(x-7,y+5);ctx.fill();model.hits.push({type:'incident',id:Number(i.id),x:x-9,y:y-10,w:18,h:18});}}
  function drawPeople(){if(!model.overlays.people||model.camera.zoom<.22)return;for(const p of model.people.values()){if(!p.is_alive)continue;const q=personPosition(p);if(!q||!levelVisible(q.room.level))continue;const radius=model.camera.zoom>.6?3.6:2.7;ctx.fillStyle=personColor(p);ctx.beginPath();ctx.arc(q.x,q.y,radius/model.camera.zoom**.25,0,Math.PI*2);ctx.fill();if(model.follow&&((model.follow.type==='person'&&Number(model.follow.id)===Number(p.id))||(model.follow.type==='household'&&Number(p.household_id)===Number(model.follow.id)))){ctx.strokeStyle='#fff';ctx.lineWidth=1/model.camera.zoom;ctx.beginPath();ctx.arc(q.x,q.y,7/model.camera.zoom**.25,0,Math.PI*2);ctx.stroke();}model.hits.push({type:'person',id:Number(p.id),x:q.x-5,y:q.y-5,w:10,h:10});model.drawStats.people++;}}

  function focusEntity(type,id,select=true){id=Number(id);let rid=0;if(type==='room')rid=id;else if(type==='person')rid=Number(model.people.get(id)?.location_id);else if(type==='household')rid=Number(model.households.get(id)?.home_room_id);else if(type==='machine')rid=Number(model.machines.get(id)?.room_id);const g=model.geometry.get(rid);if(g){model.isolatedLevel=null;model.hiddenLevels.delete(Number(g.level));const rect=canvas.getBoundingClientRect();model.camera.zoom=Math.max(model.camera.zoom,.75);model.camera.x=rect.width/(2*model.camera.zoom)-(g.x+g.width/2);model.camera.y=rect.height/(2*model.camera.zoom)-(g.y+g.height/2);buildLevels();}if(select)selectEntity(type,id);}
  async function selectEntity(type,id){model.selected={type,id:Number(id)};renderSelectedSummary();try{const d=await getJSON([`${API}/physical_entity?type=${encodeURIComponent(type)}&id=${id}`,`${API}/spatial_entity?type=${encodeURIComponent(type)}&id=${id}`]);if(model.selected?.type===type&&Number(model.selected.id)===Number(id)){model.detail=d;renderDetail(d);}}catch(e){showError(`Could not inspect ${type} ${id}: ${e.message}`);}}
  function renderSelectedSummary(){$('physical-details').innerHTML=`<div class="detail-kicker">LOADING AUTHORITATIVE RECORD</div><h3>${escapeHTML(entityName(model.selected.type,model.selected.id))}</h3>`;}
  function link(type,id,label){if(!id)return'<span>—</span>';return`<button class="detail-link" data-entity-type="${type}" data-entity-id="${escapeHTML(id)}">${escapeHTML(label||entityName(type,id))}</button>`;}
  function renderDetail(wrapper){const type=wrapper.type||model.selected.type,d=wrapper.details||wrapper,id=wrapper.id||model.selected.id;let rows=[];
    if(type==='person')rows=[['ID',d.id],['Age / stage',`${d.age_years??'—'} • ${title(d.life_stage)}`],['Activity',d.activity],['Current location',link('room',d.current_location_id,roomName(d.current_location_id))],['Destination',link('room',d.destination_id,roomName(d.destination_id))],['Home',link('room',d.home_room_id,roomName(d.home_room_id))],['Bed',d.bed_id||'Unassigned'],['Household',link('household',d.household_id)],['Workplace',link('room',d.workplace_room_id,roomName(d.workplace_room_id))],['School',link('room',d.school_room_id,roomName(d.school_room_id))],['Job',title(d.occupation_id)],['Department',title(d.department_id)],['Shift',title(d.shift)],['Health',`${Number(d.health_percent??d.health??0).toFixed(1)}%`],['Hydration',`${Number(d.hydration_percent??d.hydration??0).toFixed(1)}%`],['Parents',(d.parent_ids||[]).map(x=>link('person',x)).join(', ')||'—'],['Partner',link('person',d.partner_id)],['Children',(d.children_ids||[]).map(x=>link('person',x)).join(', ')||'—']];
    else if(type==='household')rows=[['ID',d.id],['Head',link('person',d.head_id,d.head_name)],['Home',link('room',d.home_room_id,roomName(d.home_room_id))],['Members',d.member_count],...((d.members||[]).map(m=>[title(m.life_stage),link('person',m.id,`${m.name} • ${title(m.occupation)}`)]))];
    else if(type==='room')rows=[['Room ID',d.id],['Type',title(d.room_type_name)],['Level',d.level],['Sector',d.sector_id],['Capacity',d.capacity_people],['Beds',`${Object.keys(d.occupied_beds||{}).length} / ${d.bed_count||0}`],['Present',d.occupant_count],['Inventory',d.inventory_id||'—'],...Object.entries(d.inventory_stocks||{}).map(([k,v])=>[title(k),v])];
    else if(type==='machine'){const m=model.machines.get(Number(id))||d;rows=[['Machine ID',id],['Type',title(m.type||m.machine_type)],['Location',link('room',m.room_id,roomName(m.room_id))],['State',`<span class="machine-state ${m.state}">${escapeHTML(m.state)}</span>`],['Operating hours',m.operating_hours],['Throughput',`${m.throughput_lpm||0} L/min`],['Active repair',m.active_repair||'—']];}
    else rows=Object.entries(d).filter(([,v])=>typeof v!=='object').slice(0,18).map(([k,v])=>[title(k),v]);
    const action=type==='person'?`<button data-follow="person" data-follow-id="${id}">FOLLOW PERSON</button>`:type==='household'?`<button data-follow="household" data-follow-id="${id}">FOLLOW HOUSEHOLD</button>`:'';
    const warning=Number(wrapper.room_id||0)<=0&&type!=='resource'?`<div class="detail-warning">Physical wiring issue: this record has no resolved room.</div>`:'';
    $('physical-details').innerHTML=`<div class="detail-kicker">${escapeHTML(type.toUpperCase())} • AUTHORITATIVE</div><h3>${escapeHTML(entityName(type,id))}</h3><div class="detail-actions">${action}<button data-stop-follow>STOP FOLLOW</button></div>${warning}<dl class="detail-grid">${rows.map(([k,v])=>`<dt>${escapeHTML(k)}</dt><dd>${v==null?'—':v}</dd>`).join('')}</dl>${type==='machine'?'<button class="detail-link" data-open-causal>Open full dependency explorer →</button>':''}<div class="detail-section"><h4>RAW SUPPLEMENT</h4><details><summary>Inspect JSON</summary><pre>${escapeHTML(JSON.stringify(d,null,2))}</pre></details></div>`;
  }
  function followCamera(){let ps=[];if(model.follow?.type==='person'){const p=model.people.get(Number(model.follow.id));if(p)ps=[p];}else if(model.follow?.type==='household')ps=[...model.people.values()].filter(p=>Number(p.household_id)===Number(model.follow.id));const points=ps.map(personPosition).filter(Boolean);if(!points.length)return;const minX=Math.min(...points.map(p=>p.x)),maxX=Math.max(...points.map(p=>p.x)),minY=Math.min(...points.map(p=>p.y)),maxY=Math.max(...points.map(p=>p.y)),r=canvas.getBoundingClientRect();model.camera.zoom=Math.min(1.4,Math.max(.35,Math.min((r.width-100)/Math.max(100,maxX-minX),(r.height-100)/Math.max(100,maxY-minY))));model.camera.x=r.width/(2*model.camera.zoom)-(minX+maxX)/2;model.camera.y=r.height/(2*model.camera.zoom)-(minY+maxY)/2;}
  function searchLocal(q){q=q.trim().toLowerCase();if(!q)return[];const out=[];for(const p of model.people.values())if(`${p.name} ${p.id}`.toLowerCase().includes(q))out.push({type:'person',id:p.id,label:p.name,sub:`${title(p.activity)} • ${roomName(p.location_id)}`});for(const h of model.households.values())if(`${h.name} ${h.id}`.toLowerCase().includes(q))out.push({type:'household',id:h.id,label:h.name,sub:roomName(h.home_room_id)});for(const r of model.rooms.values())if(`${r.room_type_name} ${r.id}`.toLowerCase().includes(q))out.push({type:'room',id:r.id,label:roomName(r.id),sub:`Level ${r.level}`});for(const m of model.machines.values())if(`${m.type} ${m.id}`.toLowerCase().includes(q))out.push({type:'machine',id:m.id,label:entityName('machine',m.id),sub:roomName(m.room_id)});for(const i of model.incidents)if(`${i.type||i.incident_type} ${i.id}`.toLowerCase().includes(q))out.push({type:'incident',id:i.id,label:title(i.type||i.incident_type),sub:roomName(i.room_id)});return out.slice(0,30);}
  function renderSearch(){const items=searchLocal($('physical-search').value),root=$('physical-search-results');root.innerHTML=items.map(x=>`<button data-search-type="${x.type}" data-search-id="${x.id}"><strong>${escapeHTML(x.label)}</strong><small>${escapeHTML(x.sub)}</small></button>`).join('');}

  let pointer=null,pinch=null;
  canvas.addEventListener('pointerdown',e=>{canvas.setPointerCapture(e.pointerId);pointer={id:e.pointerId,x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY};canvas.classList.add('dragging');});
  canvas.addEventListener('pointermove',e=>{if(!pointer||pointer.id!==e.pointerId)return;model.camera.x+=(e.clientX-pointer.x)/model.camera.zoom;model.camera.y+=(e.clientY-pointer.y)/model.camera.zoom;pointer.x=e.clientX;pointer.y=e.clientY;});
  canvas.addEventListener('pointerup',e=>{if(pointer&&Math.hypot(e.clientX-pointer.startX,e.clientY-pointer.startY)<5){const r=canvas.getBoundingClientRect(),w=screenToWorld(e.clientX-r.left,e.clientY-r.top),hit=[...model.hits].reverse().find(h=>w.x>=h.x&&w.x<=h.x+h.w&&w.y>=h.y&&w.y<=h.y+h.h);if(hit)selectEntity(hit.type,hit.id);}pointer=null;canvas.classList.remove('dragging');});
  canvas.addEventListener('wheel',e=>{e.preventDefault();const r=canvas.getBoundingClientRect(),before=screenToWorld(e.clientX-r.left,e.clientY-r.top),z=model.camera.zoom*Math.exp(-e.deltaY*.001);model.camera.zoom=Math.max(.12,Math.min(3,z));model.camera.x=(e.clientX-r.left)/model.camera.zoom-before.x;model.camera.y=(e.clientY-r.top)/model.camera.zoom-before.y;},{passive:false});
  canvas.addEventListener('touchstart',e=>{if(e.touches.length===2)pinch={distance:Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY),zoom:model.camera.zoom};},{passive:true});canvas.addEventListener('touchmove',e=>{if(pinch&&e.touches.length===2){const dist=Math.hypot(e.touches[0].clientX-e.touches[1].clientX,e.touches[0].clientY-e.touches[1].clientY);model.camera.zoom=Math.max(.12,Math.min(3,pinch.zoom*dist/pinch.distance));}},{passive:true});
  $('physical-search').addEventListener('input',renderSearch);$('physical-search-button').onclick=renderSearch;$('physical-search-results').onclick=e=>{const b=e.target.closest('[data-search-type]');if(b){focusEntity(b.dataset.searchType,b.dataset.searchId);$('physical-search-results').innerHTML='';}};
  $('physical-show-all').onclick=()=>{model.isolatedLevel=null;model.hiddenLevels.clear();buildLevels();fitWorld();};$('physical-fit').onclick=fitWorld;$('physical-reset-view').onclick=()=>{model.follow=null;model.isolatedLevel=null;model.hiddenLevels.clear();buildLevels();fitWorld();};
  document.querySelector('.physical-zoom').onclick=e=>{if(e.target.dataset.zoom)model.camera.zoom=Math.max(.12,Math.min(3,model.camera.zoom*(e.target.dataset.zoom==='in'?1.25:.8)));};
  $('physical-details').onclick=e=>{const b=e.target.closest('[data-entity-type]');if(b)focusEntity(b.dataset.entityType,b.dataset.entityId);const f=e.target.closest('[data-follow]');if(f){model.follow={type:f.dataset.follow,id:Number(f.dataset.followId)};followCamera();}if(e.target.closest('[data-stop-follow]'))model.follow=null;if(e.target.closest('[data-open-causal]'))window.location.hash='causal-chain';};
  window.addEventListener('resize',()=>{resize();});document.addEventListener('visibilitychange',()=>{if(!document.hidden)poll();});
  window.PhysicalViewer={model,camera:model.camera,select:selectEntity,focus:focusEntity,fit:fitWorld,search:searchLocal,drawStats:()=>({...model.drawStats}),applySnapshot,applyDelta,screenToWorld,roomPosition:id=>model.geometry.get(Number(id))||null};
  loadSnapshot();setInterval(poll,1000);requestAnimationFrame(draw);
})();
