// Barre de navigation des espaces connectés : liens selon le rôle, nom de l'utilisateur, déconnexion.
(function () {
  var client = typeof db !== 'undefined' ? db : supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
  // Icônes du menu (traits simples, couleur du texte)
  var IC = {
    home: '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
    grid: '<rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="3" width="7" height="7" rx="2"/><rect x="3" y="14" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/>',
    cal: '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/>',
    card: '<rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20M6 15h4"/>',
    book: '<path d="M4 4h6a3 3 0 0 1 3 3v13a2 2 0 0 0-2-2H4zM20 4h-6a3 3 0 0 0-3 3v13a2 2 0 0 1 2-2h7z"/>',
    bag: '<path d="M5 8h14l-1 12H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/>',
    plus: '<circle cx="12" cy="12" r="9"/><path d="M12 8v8M8 12h8"/>',
    mega: '<path d="M3 11v2a1 1 0 0 0 1 1h3l6 4V6L7 10H4a1 1 0 0 0-1 1z"/><path d="M17 9a4 4 0 0 1 0 6"/>',
    brief: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M9 7V5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2v2M3 13h18"/>',
    coins: '<ellipse cx="12" cy="6" rx="7" ry="3"/><path d="M5 6v6c0 1.7 3.1 3 7 3s7-1.3 7-3V6M5 12v6c0 1.7 3.1 3 7 3s7-1.3 7-3v-6"/>',
    store: '<path d="M4 9l1.5-5h13L20 9M4 9h16v11H4zM9 20v-6h6v6"/>',
    eye: '<path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>',
    chart: '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
    file: '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6M8 13h8M8 17h5"/>',
    shield: '<path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z"/><path d="M9 12l2 2 4-4"/>',
    user: '<circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/>',
    help: '<circle cx="12" cy="12" r="9"/><path d="M9.5 9a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.7M12 17h.01"/>',
    out: '<path d="M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 17l5-5-5-5M15 12H3"/>',
    menu: '<path d="M4 6h16M4 12h16M4 18h16"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>'
  };
  var icon = function (n) { return '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + (IC[n] || '') + '</svg>'; };
  // Menu de chaque type de compte, par rubriques : [titre, [[page, libellé, icône], …]]
  var MENU = {
    parent: [['Mon suivi', [['espace-parent.html', 'Tableau de bord', 'grid'], ['planning.html', 'Planning des cours', 'cal'], ['ressources.html', 'Ressources', 'book']]],
      ['Paiements', [['paiements.html', 'Mensualités et reçus', 'card']]],
      ['Boutique', [['mes-commandes.html', 'Mes commandes', 'bag'], ['boutique.html', 'Boutique scolaire', 'store']]],
      ['Nouveau', [['reservation.html', 'Nouvelle demande de cours', 'plus']]]],
    teacher: [['Mon activité', [['espace-enseignant.html', 'Tableau de bord', 'grid'], ['planning.html', 'Planning des cours', 'cal'], ['ressources.html', 'Ressources', 'book']]],
      ['Opportunités', [['offres-enseignants.html', 'Offres KONE.EDUC', 'mega'], ['offres.html', 'Offres de cours', 'brief']]],
      ['Mes revenus', [['versements.html', 'Mes gains et reçus', 'coins']]],
      ['Boutique', [['mes-commandes.html', 'Mes commandes', 'bag']]]],
    seller: [['Ma boutique', [['espace-vendeur.html', 'Tableau de bord', 'grid'], ['boutique.html', 'Voir la boutique en ligne', 'eye']]],
      ['Mes achats', [['mes-commandes.html', 'Mes achats', 'bag']]]],
    admin: [['Pilotage', [['espace-admin.html', 'Administration', 'shield'], ['tableau-de-bord.html', 'Tableau de bord', 'chart'], ['planning.html', 'Planning', 'cal']]],
      ['Finances', [['versements.html', 'Versements', 'coins']]],
      ['Contenus', [['gestion-documents.html', 'Documents', 'file'], ['ressources.html', 'Ressources', 'book'], ['espace-admin.html#joboffers', 'Offres KONE.EDUC', 'mega'], ['espace-admin.html#shops', 'Boutiques', 'store'], ['espace-admin.html#examresults', 'Résultats aux examens', 'chart']]]]
  };
  var ROLE = { parent: 'Parent', teacher: 'Enseignant', seller: 'Vendeur', admin: 'Administration' };
  var page = location.pathname.split('/').pop() || 'index.html';
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var avatarHtml = function (url, name, cls) { return url ? '<img class="' + cls + '" src="' + esc(url) + '" alt="">' : '<span class="' + cls + '" aria-hidden="true">' + esc((name || '?').trim().charAt(0).toUpperCase() || '?') + '</span>'; };
  var bar = document.createElement('header');
  bar.className = 'ke-app';
  bar.innerHTML = '<div class="ke-app-in"><button type="button" class="ke-app-burger" aria-label="Ouvrir le menu" aria-expanded="false" hidden>' + icon('menu') + '</button><a class="ke-app-brand" href="index.html"><img src="assets/logo/kone-educ-embleme.jpg" alt="" width="38" height="38"><span>KONE.<b>EDUC</b></span></a><span class="ke-app-sp"></span><div class="ke-app-user"></div></div>';
  document.body.insertBefore(bar, document.body.firstChild);
  var user = bar.querySelector('.ke-app-user'), burger = bar.querySelector('.ke-app-burger');
  client.auth.getUser().then(function (r) {
    var u = r.data && r.data.user;
    if (!u) { user.innerHTML = '<a class="ke-app-out" href="connexion.html" style="text-decoration:none">Se connecter</a>'; return; }
    return client.from('profiles').select('*').eq('id', u.id).single().then(function (p) {
      var prof = p.data || {}, groups = MENU[prof.role] || [];
      var name = prof.full_name || u.email || '';
      var num = 'KE-' + String(u.id).replace(/-/g, '').slice(0, 8).toUpperCase();
      // Menu latéral : photo, nom, numéro de compte, rubriques
      var side = document.createElement('aside');
      side.className = 'ke-side'; side.id = 'keSide'; side.setAttribute('aria-label', 'Menu de mon espace');
      var link = function (l) { var cur = l[0] === page || (l[0].indexOf('#') > 0 && l[0] === page + location.hash); return '<a href="' + l[0] + '"' + (cur ? ' aria-current="page"' : '') + '>' + icon(l[2]) + '<span>' + l[1] + '</span></a>'; };
      side.innerHTML = '<div class="ke-side-head"><a href="mon-profil.html" class="ke-side-me" title="Modifier ma photo et mon profil">' + avatarHtml(prof.avatar_url, name, 'ke-side-av') + '<span class="ke-side-cam" aria-hidden="true">📷</span></a><div class="ke-side-id"><b>' + esc(name) + '</b><small>' + esc(ROLE[prof.role] || '') + ' · ' + num + '</small></div><button type="button" class="ke-side-x" aria-label="Fermer le menu">' + icon('close') + '</button></div>'
        + '<nav class="ke-app-nav">' + groups.map(function (g) { return '<p class="ke-side-t">' + g[0] + '</p>' + g[1].map(link).join(''); }).join('')
        + '<p class="ke-side-t">Mon compte</p>' + link(['mon-profil.html', 'Mon profil et ma photo', 'user']) + '<a href="https://wa.me/2250161701361" target="_blank" rel="noopener">' + icon('help') + '<span>Aide (WhatsApp)</span></a></nav>'
        + '<button type="button" class="ke-side-out">' + icon('out') + '<span>Se déconnecter</span></button>';
      var veil = document.createElement('div'); veil.className = 'ke-side-veil';
      document.body.insertBefore(side, bar.nextSibling); document.body.insertBefore(veil, side.nextSibling);
      document.body.classList.add('ke-has-side');
      burger.hidden = false;
      var setOpen = function (o) { document.body.classList.toggle('ke-side-open', o); burger.setAttribute('aria-expanded', String(o)); };
      burger.onclick = function () { setOpen(!document.body.classList.contains('ke-side-open')); };
      veil.onclick = side.querySelector('.ke-side-x').onclick = function () { setOpen(false); };
      document.addEventListener('keydown', function (e) { if (e.key === 'Escape') setOpen(false); });
      side.querySelector('.ke-side-out').onclick = function () { client.auth.signOut().then(function () { location.href = 'connexion.html'; }); };
      user.innerHTML = '<a class="ke-app-me" href="mon-profil.html" aria-label="Mon profil">' + avatarHtml(prof.avatar_url, name, 'ke-app-avatar') + '</a>';
      window.KE_ME = { id: u.id, name: name, role: prof.role, avatar: prof.avatar_url, num: num };
      document.dispatchEvent(new CustomEvent('ke-me', { detail: window.KE_ME }));
      // Cloche et messages : non-lus visibles partout, panneau au clic, chaque notification mène à sa page
      var homes = { parent: 'espace-parent.html', teacher: 'espace-enseignant.html', admin: 'espace-admin.html', seller: 'espace-vendeur.html' };
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
