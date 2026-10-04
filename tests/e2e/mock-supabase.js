// Faux Supabase en mémoire (persisté dans localStorage) pour tester les parcours de bout en bout.
(function () {
  var COLS = window.__KE_COLUMNS || {};
  var load = function () { try { return JSON.parse(localStorage.getItem('__ke_db') || '{}'); } catch (e) { return {}; } };
  var save = function (db) { localStorage.setItem('__ke_db', JSON.stringify(db)); };
  var log = function (op) { var l = JSON.parse(localStorage.getItem('__ke_log') || '[]'); l.push(op); localStorage.setItem('__ke_log', JSON.stringify(l)); };
  var nextId = function (db, t) { db.__seq = db.__seq || {}; db.__seq[t] = (db.__seq[t] || 0) + 1; return db.__seq[t]; };
  var checkCols = function (t, obj) {
    if (!COLS[t]) return { message: 'relation "public.' + t + '" does not exist' };
    for (var k in obj) if (COLS[t].indexOf(k) < 0) return { message: 'Could not find the \'' + k + '\' column of \'' + t + '\' in the schema cache' };
    return null;
  };
  function query(table) {
    var filters = [], orders = [], op = 'select', payload = null, cols = '*', opts = {}, single = 0;
    var q = {
      select: function (c) { if (op === 'select') cols = c || '*'; return q; },
      eq: function (k, v) { filters.push([k, v]); return q; },
      order: function (k, o) { orders.push([k, !o || o.ascending !== false]); return q; },
      limit: function () { return q; },
      insert: function (v) { op = 'insert'; payload = v; return q; },
      update: function (v) { op = 'update'; payload = v; return q; },
      upsert: function (v, o) { op = 'upsert'; payload = v; opts = o || {}; return q; },
      delete: function () { op = 'delete'; return q; },
      single: function () { single = 1; return q; },
      maybeSingle: function () { single = 2; return q; },
      then: function (res, rej) { return Promise.resolve(run()).then(res, rej); }
    };
    function match(r) { return filters.every(function (f) { return String(r[f[0]]) === String(f[1]); }); }
    function run() {
      var db = load(); db[table] = db[table] || [];
      var rows = db[table], err;
      if (!COLS[table]) return { data: null, error: { message: 'relation "public.' + table + '" does not exist' } };
      if (op === 'insert' || op === 'upsert') {
        var list = Array.isArray(payload) ? payload : [payload];
        for (var i = 0; i < list.length; i++) {
          if ((err = checkCols(table, list[i]))) return { data: null, error: err };
          var keys = (opts.onConflict || '').split(',').filter(Boolean);
          var existing = op === 'upsert' && keys.length ? rows.find(function (r) { return keys.every(function (k) { return String(r[k]) === String(list[i][k]); }); }) : null;
          if (existing) Object.assign(existing, list[i]);
          else { var row = Object.assign({ created_at: new Date().toISOString() }, list[i]); if (COLS[table].indexOf('id') >= 0 && row.id == null) row.id = nextId(db, table); if (table === 'course_requests' && !row.status) row.status = 'pending'; if (table === 'invoices' && !row.status) row.status = 'unpaid'; rows.push(row); }
        }
        log([op, table, payload]); save(db); return { data: null, error: null };
      }
      if (op === 'update') {
        if ((err = checkCols(table, payload))) return { data: null, error: err };
        rows.filter(match).forEach(function (r) { Object.assign(r, payload); });
        log(['update', table, payload, filters]); save(db); return { data: null, error: null };
      }
      if (op === 'delete') { db[table] = rows.filter(function (r) { return !match(r); }); save(db); return { data: null, error: null }; }
      var out = rows.filter(match).map(function (r) {
        var o = Object.assign({}, r), m = /(\w+)\(([^)]*)\)/.exec(cols);
        if (m) { var ref = (load()[m[1]] || []).find(function (x) { return x.id === r[m[1] === 'course_requests' ? 'course_request_id' : m[1] + '_id']; }); o[m[1]] = ref || null; }
        return o;
      });
      orders.slice().reverse().forEach(function (o) { out.sort(function (a, b) { return (a[o[0]] > b[o[0]] ? 1 : a[o[0]] < b[o[0]] ? -1 : 0) * (o[1] ? 1 : -1); }); });
      if (single === 1) return out.length ? { data: out[0], error: null } : { data: null, error: { message: 'JSON object requested, multiple (or no) rows returned' } };
      if (single === 2) return { data: out[0] || null, error: null };
      return { data: out, error: null };
    }
    return q;
  }
  var auth = {
    getUser: async function () { var u = JSON.parse(localStorage.getItem('__ke_user') || 'null'); return { data: { user: u }, error: null }; },
    getSession: async function () { var u = JSON.parse(localStorage.getItem('__ke_user') || 'null'); return { data: { session: u ? { user: u } : null } }; },
    signUp: async function (c) { var db = load(); db.__users = db.__users || []; var u = { id: 'u' + (db.__users.length + 1) + '-' + c.email.split('@')[0], email: c.email }; db.__users.push(Object.assign({ password: c.password }, u)); save(db); localStorage.setItem('__ke_user', JSON.stringify(u)); return { data: { user: u, session: { user: u } }, error: null }; },
    signInWithPassword: async function (c) { var u = (load().__users || []).find(function (x) { return x.email === c.email && x.password === c.password; }); if (!u) return { data: {}, error: { message: 'Invalid login credentials' } }; u = { id: u.id, email: u.email }; localStorage.setItem('__ke_user', JSON.stringify(u)); return { data: { user: u }, error: null }; },
    signOut: async function () { localStorage.removeItem('__ke_user'); return { error: null }; },
    resetPasswordForEmail: async function () { return { error: null }; },
    updateUser: async function () { return { error: null }; }
  };
  var storage = {
    from: function (bucket) {
      return {
        upload: async function (path, file) {
          if (['avatars', 'teacher-files', 'documents'].indexOf(bucket) < 0) return { data: null, error: { message: 'Bucket not found' } };
          var db = load(); db.__storage = db.__storage || []; db.__storage.push({ bucket: bucket, path: path, type: file && file.type, size: file && file.size }); save(db);
          log(['upload', bucket, path]); return { data: { path: path }, error: null };
        },
        getPublicUrl: function (path) { return { data: { publicUrl: 'https://storage.test/' + bucket + '/' + path } }; },
        createSignedUrl: async function (path) { log(['signedUrl', bucket, path]); return { data: { signedUrl: 'about:blank#' + bucket + '/' + path }, error: null }; },
        download: async function () { return { data: new Blob(['x']), error: null }; }
      };
    }
  };
  var rpc = async function (name) {
    if (name !== 'public_teachers') return { data: null, error: { message: 'function not found' } };
    var db = load();
    var out = (db.teacher_profiles || []).filter(function (t) { return t.approved; }).map(function (t) {
      var p = (db.profiles || []).find(function (x) { return x.id === t.id; }) || {};
      var parts = String(p.full_name || '').trim().split(/\s+/);
      var rv = (db.reviews || []).filter(function (r) { return r.teacher_id === t.id; });
      return { id: t.id, display_name: parts[0] + (parts[1] ? ' ' + parts[1].charAt(0).toUpperCase() + '.' : ''), subject: t.subject, degree: t.degree, experience: t.experience, levels: t.levels, location: t.location, bio: t.bio, photo_url: t.photo_url,
        rating: rv.length ? Math.round(rv.reduce(function (a, r) { return a + r.rating; }, 0) / rv.length * 10) / 10 : null, reviews_count: rv.length };
    });
    return { data: out, error: null };
  };
  window.supabase = { createClient: function () { return { auth: auth, from: query, storage: storage, rpc: rpc }; } };
})();
