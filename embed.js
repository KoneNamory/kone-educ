// KONE.EDUC – Mode « aperçu » : une page ouverte dans la fenêtre Explorer d'un espace (?embed=1)
// s'affiche sans en-tête, pied de page ni menu, et les liens internes restent dans la fenêtre.
(function () {
  if (!/[?&]embed=1\b/.test(location.search)) return;
  document.documentElement.classList.add('ke-embed');
  window.KE_EMBED = true;
  var add = function (href) { try { var u = new URL(href, location.href); if (u.origin !== location.origin || /\.(pdf|jpg|png)$/i.test(u.pathname)) return null; u.searchParams.set('embed', '1'); return u.pathname.split('/').pop() + u.search + u.hash; } catch (e) { return null; } };
  document.addEventListener('click', function (e) {
    var a = e.target.closest && e.target.closest('a[href]'); if (!a || a.target === '_blank' || /^(mailto|tel|https?:\/\/wa\.me|javascript)/.test(a.getAttribute('href'))) return;
    var h = add(a.getAttribute('href')); if (!h) return;
    // Pages de connexion ou d'espace : on sort de l'aperçu pour ouvrir la page en grand
    if (/^(connexion|inscription|espace-)/.test(h)) { e.preventDefault(); window.top.location.href = h.replace(/[?&]embed=1/, ''); return; }
    e.preventDefault(); location.href = h;
  }, true);
})();
