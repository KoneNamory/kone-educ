// Barre de navigation des espaces connectés : liens selon le rôle, nom de l'utilisateur, déconnexion.
(function () {
  var client = typeof db !== 'undefined' ? db : supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
  var LINKS = {
    parent: [['espace-parent.html', 'Mon espace'], ['planning.html', 'Planning'], ['paiements.html', 'Paiements'], ['ressources.html', 'Ressources'], ['reservation.html', 'Nouvelle demande']],
    teacher: [['espace-enseignant.html', 'Mon espace'], ['planning.html', 'Planning'], ['offres.html', 'Offres de cours'], ['ressources.html', 'Ressources']],
    admin: [['espace-admin.html', 'Administration'], ['planning.html', 'Planning'], ['gestion-documents.html', 'Documents'], ['ressources.html', 'Ressources']]
  };
  var page = location.pathname.split('/').pop() || 'index.html';
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var bar = document.createElement('header');
  bar.className = 'ke-app';
  bar.innerHTML = '<div class="ke-app-in"><a class="ke-app-brand" href="index.html"><img src="assets/logo/kone-educ-embleme.jpg" alt="" width="38" height="38"><span>KONE.<b>EDUC</b></span></a><nav class="ke-app-nav" aria-label="Navigation de l’espace"></nav><div class="ke-app-user"></div></div>';
  document.body.insertBefore(bar, document.body.firstChild);
  var nav = bar.querySelector('.ke-app-nav'), user = bar.querySelector('.ke-app-user');
  client.auth.getUser().then(function (r) {
    var u = r.data && r.data.user;
    if (!u) { user.innerHTML = '<a class="ke-app-out" href="connexion.html" style="text-decoration:none">Se connecter</a>'; return; }
    return client.from('profiles').select('full_name, role').eq('id', u.id).single().then(function (p) {
      var prof = p.data || {}, links = LINKS[prof.role] || [];
      nav.innerHTML = links.map(function (l) { return '<a href="' + l[0] + '"' + (l[0] === page ? ' aria-current="page"' : '') + '>' + l[1] + '</a>'; }).join('');
      var name = prof.full_name || u.email || '';
      user.innerHTML = '<span class="ke-app-avatar" aria-hidden="true">' + esc(name.trim().charAt(0).toUpperCase() || '?') + '</span><span class="ke-app-name">' + esc(name) + '</span><button type="button" class="ke-app-out">Se déconnecter</button>';
      user.querySelector('button').onclick = function () { client.auth.signOut().then(function () { location.href = 'connexion.html'; }); };
      // Cloche et messages : non-lus visibles partout, panneau au clic, chaque notification mène à sa page
      var homes = { parent: 'espace-parent.html', teacher: 'espace-enseignant.html', admin: 'espace-admin.html' };
      if (!homes[prof.role]) return;
      var wrap = document.createElement('div');
      wrap.className = 'ke-notif';
      wrap.innerHTML = '<button type="button" class="ke-app-bell ke-msg" aria-label="Messages" hidden>💬<span></span></button>'
        + '<button type="button" class="ke-app-bell ke-bell" aria-label="Notifications" aria-expanded="false">🔔<span hidden></span></button>'
        + '<div class="ke-panel" hidden><div class="ke-panel-head"><b>Notifications</b><div class="ke-tabs"><button type="button" data-tab="all" class="on">Tout</button><button type="button" data-tab="msg">Messages</button></div><button type="button" class="ke-readall">Tout marquer comme lu</button></div><div class="ke-panel-list"></div></div>';
      user.insertBefore(wrap, user.firstChild);
      var bellBtn = wrap.querySelector('.ke-bell'), msgBtn = wrap.querySelector('.ke-msg'), panel = wrap.querySelector('.ke-panel'), listEl = wrap.querySelector('.ke-panel-list');
      var items = [], tab = 'all';
      var ago = function (d) { var m = Math.round((Date.now() - new Date(d)) / 60000); return m < 1 ? 'à l’instant' : m < 60 ? 'il y a ' + m + ' min' : m < 1440 ? 'il y a ' + Math.round(m / 60) + ' h' : new Date(d).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short' }); };
      var isMsg = function (n) { return n.title === 'Nouveau message'; };
      function badge(btn, count) { var sp = btn.querySelector('span'); sp.hidden = !count; sp.textContent = count > 9 ? '9+' : count; }
      function render() {
        var unread = items.filter(function (n) { return !n.is_read; });
        badge(bellBtn, unread.length);
        var um = unread.filter(isMsg).length; msgBtn.hidden = !um; badge(msgBtn, um);
        bellBtn.setAttribute('aria-label', unread.length + ' notification(s) non lue(s)');
        var list = items.filter(function (n) { return tab === 'all' || isMsg(n); });
        listEl.innerHTML = list.map(function (n) {
          return '<a class="ke-n' + (n.is_read ? '' : ' unread') + '" href="' + esc(n.link || homes[prof.role]) + '" data-id="' + n.id + '"><span class="ke-n-ic">' + (isMsg(n) ? '💬' : '🔔') + '</span><span><b>' + esc(n.title) + '</b><small>' + esc(n.body) + '</small><em>' + ago(n.created_at) + '</em></span></a>';
        }).join('') || '<p class="ke-empty">' + (tab === 'msg' ? 'Aucun message pour le moment.' : 'Aucune notification pour le moment.') + '</p>';
      }
      function refresh() {
        client.from('notifications').select('*').eq('recipient_id', u.id).order('created_at', { ascending: false }).limit(30).then(function (r) { if (!r.error) { items = r.data || []; render(); } });
      }
      function open(t) { tab = t || 'all'; wrap.querySelectorAll('.ke-tabs button').forEach(function (b) { b.classList.toggle('on', b.dataset.tab === tab); }); panel.hidden = false; bellBtn.setAttribute('aria-expanded', 'true'); render(); }
      bellBtn.onclick = function (e) { e.stopPropagation(); if (panel.hidden) open('all'); else { panel.hidden = true; bellBtn.setAttribute('aria-expanded', 'false'); } };
      msgBtn.onclick = function (e) { e.stopPropagation(); open('msg'); };
      wrap.querySelectorAll('.ke-tabs button').forEach(function (b) { b.onclick = function (e) { e.stopPropagation(); open(b.dataset.tab); }; });
      panel.onclick = function (e) { e.stopPropagation(); };
      document.addEventListener('click', function () { panel.hidden = true; bellBtn.setAttribute('aria-expanded', 'false'); });
      // Ouvrir une notification : marquée comme lue, puis ouverture de la page concernée
      listEl.addEventListener('click', function (e) {
        var a = e.target.closest('a.ke-n'); if (!a) return;
        e.preventDefault();
        var id = Number(a.dataset.id), n = items.find(function (x) { return x.id === id; });
        var go = function () { location.href = a.getAttribute('href'); };
        if (n && !n.is_read) { n.is_read = true; client.from('notifications').update({ is_read: true }).eq('id', id).then(go, go); } else go();
      });
      wrap.querySelector('.ke-readall').onclick = function () {
        items.forEach(function (n) { n.is_read = true; }); render();
        client.from('notifications').update({ is_read: true }).eq('recipient_id', u.id).eq('is_read', false).then(function () {});
      };
      document.addEventListener('ke-notifications-read', function () { items.forEach(function (n) { n.is_read = true; }); render(); });
      refresh();
      setInterval(function () { if (!document.hidden) refresh(); }, 60000);
    });
  });
})();

// Application installable : enregistrement du service worker.
if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) navigator.serviceWorker.register('sw.js').catch(function () {});
