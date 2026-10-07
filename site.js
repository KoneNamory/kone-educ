// Menu mobile et bouton WhatsApp des pages publiques KONE.EDUC
(function () {
  // Numéro WhatsApp au format international sans « + » ni espaces, ex. '2250700000000'. Vide = bouton masqué.
  var WHATSAPP = '2250161701361';
  var header = document.querySelector('.ke-header');
  var burger = document.querySelector('.ke-burger');
  if (header && burger) {
    burger.addEventListener('click', function () {
      var open = header.classList.toggle('open');
      burger.setAttribute('aria-expanded', open);
      burger.textContent = open ? '✕' : '☰';
    });
  }
  if (WHATSAPP) {
    var a = document.createElement('a');
    a.className = 'ke-whatsapp';
    a.href = 'https://wa.me/' + WHATSAPP + '?text=' + encodeURIComponent('Bonjour KONE.EDUC, je souhaite un renseignement sur les cours à domicile.');
    a.target = '_blank';
    a.rel = 'noopener';
    a.setAttribute('aria-label', 'Nous écrire sur WhatsApp');
    a.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24" fill="#fff" aria-hidden="true"><path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm5.3 14.1c-.2.6-1.3 1.2-1.8 1.2s-1 .2-3.4-.7a11.8 11.8 0 0 1-4.6-4.1c-.4-.6-1-1.6-1-3.1s.8-2.2 1.1-2.5.6-.3.8-.3h.6c.2 0 .4 0 .6.5l.9 2.1c.1.2.1.4 0 .6l-.4.6-.4.5c-.1.2-.3.3-.1.6a8.6 8.6 0 0 0 1.6 2 7.8 7.8 0 0 0 2.3 1.4c.3.1.5.1.6-.1l.9-1c.2-.3.4-.2.7-.1l2 1c.3.1.5.2.5.3s.1.7-.1 1.3z"/></svg><span>WhatsApp</span>';
    document.body.appendChild(a);
  }
  // Compte : « Se connecter » demande d'abord s'il s'agit d'un compte Parent ou Enseignant.
  // Une fois connecté, le bouton devient « Mon espace ».
  var actions = document.querySelector('.ke-actions');
  var loginLink = actions && actions.querySelector('a[href="connexion.html"]');
  var signedIn = false;
  try { for (var i = 0; i < localStorage.length; i++) { if (/^sb-.+-auth-token$/.test(localStorage.key(i))) signedIn = true; } } catch (err) {}
  if (loginLink && signedIn) {
    loginLink.textContent = 'Mon espace';
  } else if (loginLink) {
    var dlg = document.createElement('dialog');
    dlg.className = 'ke-account';
    dlg.setAttribute('aria-labelledby', 'ke-account-title');
    dlg.innerHTML = '<button type="button" class="ke-account-x" aria-label="Fermer">✕</button>'
      + '<h2 id="ke-account-title">Bienvenue sur KONE.EDUC</h2><p>Vous êtes :</p>'
      + '<div class="ke-account-grid">'
      + '<div class="ke-account-card"><span class="ke-account-ic">👪</span><b>Parent</b><small>Je cherche des cours pour mon enfant</small><a class="ke-btn fill" href="connexion.html?role=parent">Se connecter</a><a class="ke-btn" href="inscription.html?role=parent">Créer un compte</a></div>'
      + '<div class="ke-account-card"><span class="ke-account-ic">👩‍🏫</span><b>Enseignant</b><small>Je donne des cours</small><a class="ke-btn fill" href="connexion.html?role=teacher">Se connecter</a><a class="ke-btn" href="inscription.html?role=teacher">Créer un compte</a></div>'
      + '</div>';
    document.body.appendChild(dlg);
    dlg.querySelector('.ke-account-x').onclick = function () { dlg.close(); };
    dlg.addEventListener('click', function (e) { if (e.target === dlg) dlg.close(); });
    loginLink.textContent = 'Se connecter / S’inscrire';
    loginLink.addEventListener('click', function (e) {
      if (typeof dlg.showModal !== 'function') return; // ancien navigateur : la page de connexion pose la question
      e.preventDefault();
      if (header) { header.classList.remove('open'); if (burger) { burger.setAttribute('aria-expanded', false); burger.textContent = '☰'; } }
      dlg.showModal();
    });
  }
  // Bouton « Installer l'application » quand le navigateur le permet (Android, ordinateur).
  var footerBottom = document.querySelector('.ke-footer-bottom');
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault();
    if (!footerBottom || document.querySelector('.ke-install')) return;
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'ke-install';
    btn.textContent = '📲 Installer l’application';
    btn.onclick = function () { e.prompt(); e.userChoice.then(function () { btn.remove(); }); };
    footerBottom.insertBefore(btn, footerBottom.firstChild);
  });
})();

// Application installable : enregistrement du service worker.
if ('serviceWorker' in navigator && (location.protocol === 'https:' || location.hostname === 'localhost')) navigator.serviceWorker.register('sw.js').catch(function () {});
