// KONE.EDUC – Étiquettes flottantes animées dans les bandeaux (comme sur la boutique), adaptées à chaque page.
// Ajoutées seulement sur grand écran et seulement s'il reste de la place à côté du texte.
(function () {
  if (window.KE_EMBED || !window.matchMedia || !matchMedia('(min-width: 900px)').matches) return;
  var page = (location.pathname.split('/').pop() || 'index.html').replace('.html', '');
  var hero = document.querySelector('main>section.hero, .l-hero, .c-hero, .dv-hero');
  if (!hero || hero.querySelector('.ke-fl')) return;
  var C = {
    'services': [['🏠', 'À domicile'], ['💻', 'En ligne'], ['📈', 'Suivi des progrès']],
    'tarifs': [['💳', 'Wave · Orange · MTN · Moov'], ['🧾', 'Reçu numéroté'], ['📅', 'Sans engagement']],
    'a-propos': [['🎓', 'Excellence'], ['🤝', 'Confiance'], ['🇨🇮', 'Partout en Côte d’Ivoire']],
    'enseignants': [['✅', 'Profils vérifiés'], ['⭐', 'Avis des parents'], ['🏆', 'Classement']],
    'preparation-concours': [['📘', 'BEPC · BAC'], ['📊', 'ENSEA'], ['🏗️', 'INPHB']],
    'offres-enseignants': [['📢', 'Nouvelles offres'], ['🏫', 'Écoles'], ['👪', 'Familles']],
    'ecoles': [['🏫', 'Votre école'], ['👩‍🏫', 'Enseignants vérifiés'], ['🤝', 'Mise en relation']],
    'devenir-vendeur': [['🛒', 'Commandes'], ['💵', 'Payé directement'], ['📊', 'Statistiques']],
    'conseils': [['📚', 'Méthodes'], ['🧠', 'Mémoriser'], ['🎯', 'Réussir ses examens']],
    'cours-particuliers-abidjan': [['📍', '18 communes'], ['🏠', 'À domicile'], ['📝', 'Compte rendu']]
  };
  var MAT = { 'mathematiques': ['📐', 'Mathématiques'], 'francais': ['📖', 'Français'], 'anglais': ['🇬🇧', 'Anglais'], 'physique-chimie': ['⚗️', 'Physique-Chimie'], 'svt': ['🌿', 'SVT'] };
  var chips = C[page], card = null;
  var m = page.match(/^cours-particuliers-a-domicile-(.+)$/), s = page.match(/^cours-de-(.+)-a-domicile-abidjan$/);
  if (m) {
    var com = (document.querySelector('.l-hero h1 em') || {}).textContent || 'votre commune';
    chips = [['📍', com], ['🏠', 'À domicile'], ['✅', 'Enseignant vérifié']];
  } else if (s) {
    var mt = MAT[s[1]] || ['📚', 'Cours'];
    chips = [mt, ['🎯', 'BEPC · BAC'], ['📝', 'Exercices corrigés']];
  }
  if (!chips) return;
  if (m || s || page === 'cours-particuliers-abidjan') card = { t: 'Compte rendu de séance', st: 'Envoyé aux parents · aujourd’hui', rows: [['ok', '✓', 'Notions travaillées', 'Fractions, équations'], ['ok', '✓', 'Compréhension', '4 / 5 · en progrès'], ['go', '📈', 'Bilan du mois', 'Disponible dans l’espace parent']] };
  // Zone libre à droite du texte du bandeau
  var hr = hero.getBoundingClientRect(), right = hr.left;
  hero.querySelectorAll('h1, p, .l-cta, .l-trust, .tags, a, form').forEach(function (el) { if (el.closest('.service-art, .dv-phone, .portrait, .hero-grid > :last-child:not(:first-child)')) return; var rg = document.createRange(); rg.selectNodeContents(el); var r = rg.getBoundingClientRect(); if (r.width && r.right > right) right = r.right; });
  var visual = hero.querySelector('.service-art, .dv-phone, .hero-grid > :last-child:not(:first-child)');
  var host, free = hr.right - right;
  if (getComputedStyle(hero).position === 'static') hero.style.position = 'relative';
  if (visual && visual.getBoundingClientRect().left > hr.left + hr.width * .35) {
    // Calque posé exactement sur l'illustration existante (sans être coupé par ses bords)
    var vr = visual.getBoundingClientRect(); host = document.createElement('div'); host.className = 'ke-hv over';
    host.style.cssText = 'left:' + (vr.left - hr.left) + 'px;top:' + (vr.top - hr.top) + 'px;width:' + vr.width + 'px;height:' + vr.height + 'px';
    hero.appendChild(host);
  }
  else if (free >= 380) { host = document.createElement('div'); host.className = 'ke-hv'; host.style.width = Math.min(free - 60, 420) + 'px'; hero.appendChild(host); }
  else if (free >= 200 || hr.width - (right - hr.left) >= 200) { host = document.createElement('div'); host.className = 'ke-hv slim'; hero.appendChild(host); }
  else return;
  if (host.className.indexOf('over') < 0 && hr.height < 360) { chips = chips.slice(0, 2); if (host.className === 'ke-hv') { host.style.height = Math.max(150, hr.height - 70) + 'px'; card = null; } }
  var e = function (v) { return String(v).replace(/[&<>"]/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]; }); };
  var html = '';
  if (card && host.className === 'ke-hv') html += '<div class="ke-hcard"><b>' + e(card.t) + '</b><small>' + e(card.st) + '</small>' + card.rows.map(function (r) { return '<div class="ke-hrow"><i class="' + r[0] + '">' + r[1] + '</i><span><b>' + e(r[2]) + '</b><small>' + e(r[3]) + '</small></span></div>'; }).join('') + '</div>';
  if (card) host.classList.add('withcard');
  html += chips.map(function (c, i) { return '<div class="ke-fl ke-fl' + (i + 1) + '" aria-hidden="true">' + c[0] + ' <b>' + e(c[1]) + '</b></div>'; }).join('');
  host.insertAdjacentHTML('beforeend', html);
})();
