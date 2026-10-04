// Barre de navigation des espaces connectés : liens selon le rôle, nom de l'utilisateur, déconnexion.
(function () {
  var client = typeof db !== 'undefined' ? db : supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
  var LINKS = {
    parent: [['espace-parent.html', 'Mon espace'], ['paiements.html', 'Paiements'], ['ressources.html', 'Ressources'], ['reservation.html', 'Nouvelle demande']],
    teacher: [['espace-enseignant.html', 'Mon espace'], ['ressources.html', 'Ressources']],
    admin: [['espace-admin.html', 'Administration'], ['gestion-documents.html', 'Documents'], ['ressources.html', 'Ressources']]
  };
  var page = location.pathname.split('/').pop() || 'index.html';
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var bar = document.createElement('header');
  bar.className = 'ke-app';
  bar.innerHTML = '<div class="ke-app-in"><a class="ke-app-brand" href="index.html"><img src="favicon.svg" alt="" width="30" height="30"><span>KONE.<b>EDUC</b></span></a><nav class="ke-app-nav" aria-label="Navigation de l’espace"></nav><div class="ke-app-user"></div></div>';
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
      // Cloche : nombre de notifications non lues (parents et enseignants)
      var home = { parent: 'espace-parent.html', teacher: 'espace-enseignant.html' }[prof.role];
      if (home) {
        client.from('notifications').select('id').eq('recipient_id', u.id).eq('is_read', false).then(function (n) {
          var count = (n.data || []).length;
          if (!count) return;
          var bell = document.createElement('a');
          bell.className = 'ke-app-bell';
          bell.href = home;
          bell.setAttribute('aria-label', count + ' nouvelle(s) notification(s)');
          bell.innerHTML = '🔔<span>' + (count > 9 ? '9+' : count) + '</span>';
          user.insertBefore(bell, user.firstChild);
          document.addEventListener('ke-notifications-read', function () { bell.remove(); });
        });
      }
    });
  });
})();

// Application installable : enregistrement du service worker.
if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) navigator.serviceWorker.register('sw.js').catch(function () {});
