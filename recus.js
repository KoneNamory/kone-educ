// KONE.EDUC – Liste des reçus de l'utilisateur connecté (chacun ne voit que les siens ; l'admin voit tout)
(function () {
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var fcfa = function (n) { return Math.round(Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' FCFA'; };
  var KIND = { mensualite: ['🧾', 'Mensualité'], commande: ['🛒', 'Commande'], versement: ['💸', 'Versement'] };
  var METH = { wave: 'Wave', orange_money: 'Orange Money', mtn_money: 'MTN MoMo', moov_money: 'Moov Money', livraison: 'Paiement à la livraison', mobile_money: 'Mobile money' };
  window.KE_RECUS = { METH: METH, KIND: KIND, esc: esc, fcfa: fcfa };
  // el : conteneur ; opts.kinds : types à afficher ; opts.titre ; opts.admin (recherche + export)
  window.afficherRecus = async function (el, opts) {
    opts = opts || {};
    if (!el) return;
    var client = window.db || supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
    el.innerHTML = '<p style="color:#5b6884">Chargement des reçus…</p>';
    var q = client.from('receipts').select('*').order('issued_at', { ascending: false }).limit(opts.admin ? 2000 : 300);
    if (opts.kinds && opts.kinds.length === 1) q = q.eq('kind', opts.kinds[0]);
    var r = await q;
    if (r.error) { el.innerHTML = '<p style="color:#5b6884">Les reçus seront disponibles après la mise à jour de la base.</p>'; return; }
    var all = (r.data || []).filter(function (x) { return !opts.kinds || opts.kinds.indexOf(x.kind) >= 0; });
    var filtre = '', type = '';
    function rendu() {
      var L = all.filter(function (x) { return (!type || x.kind === type) && (!filtre || [x.number, x.label, x.payer_name, x.payee_name, x.reference].join(' ').toLowerCase().indexOf(filtre) >= 0); });
      var tot = L.reduce(function (a, x) { return a + x.amount; }, 0);
      el.querySelector('.rc-list').innerHTML = L.length ? L.map(function (x) {
        return '<a class="rc-item" href="recu.html?n=' + encodeURIComponent(x.number) + '" style="display:flex;align-items:center;gap:12px;padding:12px 4px;border-bottom:1px solid #eef2f9;color:inherit;text-decoration:none"><span style="font-size:24px">' + (KIND[x.kind] || ['🧾'])[0] + '</span><span style="flex:1;min-width:0"><b style="display:block">' + esc(x.label) + '</b><small style="color:#5b6884">N° ' + esc(x.number) + ' · ' + new Date(x.issued_at).toLocaleDateString('fr-FR') + ' · ' + esc(METH[x.method] || x.method || '') + (opts.admin ? ' · ' + esc(x.payer_name || '') + ' → ' + esc(x.payee_name || '') : '') + '</small></span><b style="white-space:nowrap">' + fcfa(x.amount) + '</b></a>';
      }).join('') : '<p style="color:#5b6884;padding:8px 0">' + (all.length ? 'Aucun reçu ne correspond.' : 'Aucun reçu pour le moment. Un reçu est créé automatiquement à chaque paiement confirmé.') + '</p>';
      var t = el.querySelector('.rc-total'); if (t) t.textContent = L.length + ' reçu(s) · ' + fcfa(tot);
    }
    el.innerHTML = (opts.titre ? '<h2 style="margin:0 0 6px">' + esc(opts.titre) + '</h2>' : '')
      + (opts.admin ? '<div style="display:flex;flex-wrap:wrap;gap:8px;margin:8px 0"><input class="rc-q" type="search" placeholder="Rechercher : n° de reçu, nom, référence…" style="flex:1 1 240px;padding:10px;border:1px solid #d7e1f2;border-radius:10px"><select class="rc-t" style="padding:10px;border:1px solid #d7e1f2;border-radius:10px"><option value="">Tous les types</option><option value="mensualite">Mensualités</option><option value="commande">Commandes boutique</option><option value="versement">Versements enseignants</option></select><button type="button" class="rc-x btn ghost">⬇ Export Excel (CSV)</button></div>' : '')
      + '<small class="rc-total" style="color:#5b6884"></small><div class="rc-list"></div>';
    if (opts.admin) {
      el.querySelector('.rc-q').oninput = function () { filtre = this.value.trim().toLowerCase(); rendu(); };
      el.querySelector('.rc-t').onchange = function () { type = this.value; rendu(); };
      el.querySelector('.rc-x').onclick = function () {
        var qv = function (v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; };
        var rows = [['Numéro', 'Date', 'Type', 'Libellé', 'Payé par', 'Reçu par', 'Montant (FCFA)', 'Moyen', 'Référence']].concat(all.map(function (x) { return [x.number, x.issued_at, (KIND[x.kind] || [, x.kind])[1], x.label, x.payer_name, x.payee_name, x.amount, METH[x.method] || x.method, x.reference]; }));
        var a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['﻿' + rows.map(function (r) { return r.map(qv).join(';'); }).join('\n')], { type: 'text/csv;charset=utf-8' }));
        a.download = 'kone-educ-recus-' + new Date().toISOString().slice(0, 10) + '.csv'; a.click();
      };
    }
    rendu();
  };
})();
