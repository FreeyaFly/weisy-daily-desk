/* Weisy data layer: window.weisyStore.use('db') gives the page collections it can subscribe to and write,
   backed by the local server.py (/api/data, /api/doc/<collection>/<id>). */
(() => {
  'use strict';
  const state = { data: null, listeners: new Map() };
  const clone = o => JSON.parse(JSON.stringify(o));
  const deepFreeze = o => { if (o && typeof o === 'object') { Object.values(o).forEach(deepFreeze); Object.freeze(o); } return o; };
  const rid = () => Array.from(crypto.getRandomValues(new Uint8Array(15)), b => 'abcdefghijklmnopqrstuvwxyz0123456789'[b % 36]).join('');
  function merge(target, patch) {
    for (const [k, v] of Object.entries(patch)) {
      if (v && typeof v === 'object' && !Array.isArray(v) && target[k] && typeof target[k] === 'object' && !Array.isArray(target[k])) merge(target[k], v);
      else target[k] = clone(v);
    }
  }
  function emit(col) {
    const docs = Object.entries(state.data[col] || {}).map(([id, d]) => { const frozen = deepFreeze(clone(d)); return { id, data: () => frozen }; });
    (state.listeners.get(col) || []).forEach(cb => cb({ docs }));
  }
  async function reload() {
    const r = await fetch('/api/data', { cache: 'no-store' });
    if (!r.ok) throw new Error('load failed');
    state.data = (await r.json()).collections || {};
    state.listeners.forEach((_, col) => emit(col));
  }
  /* Several windows: after a save the others reload; a window coming back to the front reloads too.
     While this window still has unsaved writes it waits, so its own changes never flicker back. */
  const chan = 'BroadcastChannel' in window ? new BroadcastChannel('weisy') : null;
  let inflight = 0, reloadWanted = false;
  function refresh() {
    if (!state.data) return;
    if (inflight) { reloadWanted = true; return; }
    reload().catch(() => { /* server gone; keep showing what we have */ });
  }
  if (chan) chan.onmessage = refresh;
  document.addEventListener('visibilitychange', () => { if (!document.hidden) refresh(); });
  /* Presence: this window tells the server it is open (every 20 s, and when it comes back to the front) and
     when it closes, so the server can stop itself after the last window. If the server stops answering,
     the page is told ('weisy-offline'); when it answers again, 'weisy-online'. */
  const wid = rid();
  let missed = 0, offline = false;
  function markOffline() { if (!offline) { offline = true; window.dispatchEvent(new Event('weisy-offline')); } }
  async function hello() {
    try {
      const r = await fetch(`/api/hello?id=${wid}`, { method: 'POST', cache: 'no-store' });
      if (!r.ok) throw new Error('hello failed');
      missed = 0;
      if (offline) { offline = false; window.dispatchEvent(new Event('weisy-online')); refresh(); }
    } catch { if (++missed >= 2) markOffline(); }
  }
  setInterval(hello, 20000);
  window.addEventListener('pageshow', hello);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) hello(); });
  window.addEventListener('pagehide', () => { try { navigator.sendBeacon(`/api/bye?id=${wid}`); } catch { /* closing anyway */ } });
  /* Optimistic: the page sees the change at once; if saving fails, reload the saved data and report it. */
  async function write(method, col, id, body) {
    inflight++;
    try { return await send(method, col, id, body); } finally {
      if (!--inflight && reloadWanted) { reloadWanted = false; refresh(); }
    }
  }
  async function send(method, col, id, body) {
    const docs = state.data[col] || (state.data[col] = {});
    if (method === 'PATCH' && !docs[id]) throw { code: 'invalid_argument', message: 'document does not exist' };
    if (method === 'PUT') docs[id] = clone(body);
    else if (method === 'PATCH') merge(docs[id], body);
    else delete docs[id];
    emit(col);
    let r;
    try {
      r = await fetch(`/api/doc/${encodeURIComponent(col)}/${encodeURIComponent(id)}`, {
        method, headers: { 'Content-Type': 'application/json' }, body: body === undefined ? undefined : JSON.stringify(body),
      });
    } catch (e) { r = null; }
    if (!r) markOffline();
    if (!r || !r.ok) {
      try { await reload(); } catch { /* server gone; keep showing what we have */ }
      throw { code: r && r.status === 404 ? 'invalid_argument' : 'unavailable', message: r ? `HTTP ${r.status}` : 'the local server is not responding' };
    }
    if (window.__writes) window.__writes[`${col}/${id}`] = method === 'DELETE' ? null : clone(docs[id]);
    if (chan) chan.postMessage({ col, id });
  }
  const docRef = (col, id) => ({
    id,
    set: d => write('PUT', col, id, d),
    update: p => write('PATCH', col, id, p),
    delete: () => write('DELETE', col, id),
  });
  const db = {
    collection: col => ({
      onSnapshot(cb) {
        if (!state.listeners.has(col)) state.listeners.set(col, []);
        state.listeners.get(col).push(cb);
        setTimeout(() => emit(col), 0);
        return () => { const l = state.listeners.get(col); const i = l.indexOf(cb); if (i >= 0) l.splice(i, 1); };
      },
      doc: id => docRef(col, id || rid()),
    }),
    doc: path => { const [col, id] = path.split('/'); return docRef(col, id); },
  };
  /* Export backup: a plain file download. */
  const downloads = {
    async save({ filename, data }) {
      const a = document.createElement('a');
      a.href = URL.createObjectURL(new Blob([data], { type: 'application/json' }));
      a.download = filename;
      document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(a.href), 5000);
      return { status: 'saved' };
    },
  };
  window.weisyStore = {
    use: async name => {
      if (name === 'db') {
        try { if (!state.data) await reload(); } catch { return null; }
        if (window.__TEST__) {
          window.__writes = {};
          window.__DATA__ = Object.fromEntries(Object.entries(state.data).map(([c, o]) => [c, Object.entries(o).map(([id, d]) => ({ id, ...d }))]));
        }
        return db;
      }
      if (name === 'downloads') return downloads;
      return null;
    },
  };
})();
