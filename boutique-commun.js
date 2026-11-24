// KONE.EDUC – Boutique : outils communs (panier, prix, statuts des commandes)
(function () {
  var KEY = 'koneEducPanier';
  var B = window.KE_BOUTIQUE = {};

  B.CATEGORIES = [
    ['livres', 'Livres', '📚'], ['manuels', 'Manuels scolaires', '📘'], ['cahiers', 'Cahiers', '📓'],
    ['fournitures', 'Fournitures', '✏️'], ['documents', 'Documents & fiches', '📄'], ['annales', 'Annales & sujets', '📝'],
    ['autres', 'Autres', '🎒']
  ];
  B.catLabel = function (c) { var x = B.CATEGORIES.find(function (k) { return k[0] === c; }); return x ? x[1] : c; };
  B.catIcon = function (c) { var x = B.CATEGORIES.find(function (k) { return k[0] === c; }); return x ? x[2] : '🎒'; };
  B.NIVEAUX = ['Tous niveaux', 'Maternelle', 'CP1', 'CP2', 'CE1', 'CE2', 'CM1', 'CM2', '6e', '5e', '4e', '3e', '2nde', '1ère', 'Terminale', 'Université'];
  B.DELAIS = ['Moins de 2 heures', 'Le jour même', 'Sous 24 heures', 'Sous 48 heures', 'Sous 72 heures'];

  B.STATUTS = {
    'new': ['Nouvelle', 'Envoyée au vendeur', '#9a5900', '#fff0dc'],
    'accepted': ['Acceptée', 'Acceptée par le vendeur', '#1559eb', '#e8f0ff'],
    'ready': ['Prête', 'Prête', '#6b3fd4', '#f0e9ff'],
    'delivering': ['En livraison', 'En route vers vous', '#0b7a75', '#e0f6f4'],
    'delivered': ['Livrée', 'Livrée', '#11743a', '#e5f7ec'],
    'cancelled': ['Annulée', 'Annulée', '#a11', '#fde2e2'],
    'refused': ['Refusée', 'Refusée par le vendeur', '#a11', '#fde2e2']
  };
  B.badge = function (st, buyer) {
    var s = B.STATUTS[st] || [st, st, '#333', '#eee'];
    return '<span class="bq-badge" style="color:' + s[2] + ';background:' + s[3] + '">' + B.esc(buyer ? s[1] : s[0]) + '</span>';
  };
  B.PAIEMENT = { cod: 'À la livraison', momo: 'Mobile money' };
  B.PAY_STATUS = { unpaid: 'Non payé', declared: 'Paiement signalé, à vérifier', paid: 'Payé ✓' };

  B.esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  B.fcfa = function (n) { return (Math.round(Number(n) || 0)).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' FCFA'; };
  B.depuis = function (d) {
    var s = Math.max(0, (Date.now() - new Date(d).getTime()) / 1000);
    if (s < 60) return 'à l’instant'; if (s < 3600) return 'il y a ' + Math.floor(s / 60) + ' min';
    if (s < 86400) return 'il y a ' + Math.floor(s / 3600) + ' h';
    return new Date(d).toLocaleDateString('fr-FR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
  };
  // Numéro ivoirien → format international pour WhatsApp (10 chiffres → 225…)
  B.waNum = function (p) { var d = String(p || '').replace(/\D/g, ''); if (d.length === 10) d = '225' + d; if (d.length === 8) d = '225' + d; return d; };
  B.waLink = function (p, text) { return 'https://wa.me/' + B.waNum(p) + (text ? '?text=' + encodeURIComponent(text) : ''); };
  B.telLink = function (p) { return 'tel:' + String(p || '').replace(/[^\d+]/g, ''); };
  B.stars = function (r) { r = Math.round(Number(r) || 0); return '★★★★★'.slice(0, r) + '☆☆☆☆☆'.slice(0, 5 - r); };

  // Frais de livraison d'une boutique pour une commune (null = ne livre pas)
  B.fraisLivraison = function (shop, commune) {
    var f = shop && shop.delivery_fees || {};
    if (commune && Object.prototype.hasOwnProperty.call(f, commune)) return Number(f[commune]);
    if (shop && shop.default_delivery_fee != null) return Number(shop.default_delivery_fee);
    return null;
  };
  B.zonesTexte = function (shop) {
    var f = shop.delivery_fees || {}, k = Object.keys(f);
    var t = k.length ? k.slice(0, 4).join(', ') + (k.length > 4 ? ' +' + (k.length - 4) : '') : '';
    if (shop.default_delivery_fee != null) t = t ? t + ' et ailleurs' : 'Partout';
    return t || 'Retrait en boutique uniquement';
  };

  // ---------- Panier (enregistré sur l'appareil, un panier par boutique)
  B.panier = function () { try { var c = JSON.parse(localStorage.getItem(KEY) || '{}'); return c && typeof c === 'object' ? c : {}; } catch (e) { return {}; } };
  B.enregistrer = function (c) { try { localStorage.setItem(KEY, JSON.stringify(c)); } catch (e) {} document.dispatchEvent(new CustomEvent('panier')); };
  B.ajouter = function (p, q) {
    var c = B.panier(), s = String(p.shop_id); c[s] = c[s] || {};
    var cur = c[s][p.id] ? c[s][p.id].qty : 0, n = Math.max(0, Math.min(100, cur + (q || 1)));
    if (p.stock != null) n = Math.min(n, p.stock);
    if (n <= 0) delete c[s][p.id]; else c[s][p.id] = { id: p.id, name: p.name, price: p.price, qty: n, photo: p.photo_url || '', stock: p.stock };
    if (!Object.keys(c[s]).length) delete c[s];
    B.enregistrer(c); return n;
  };
  B.qte = function (p) { var c = B.panier()[String(p.shop_id)]; return c && c[p.id] ? c[p.id].qty : 0; };
  B.viderBoutique = function (shopId) { var c = B.panier(); delete c[String(shopId)]; B.enregistrer(c); };
  // Met le panier à jour avec les prix et stocks actuels ; retire les articles qui ne sont plus vendus
  B.synchroniser = function (products) {
    var c = B.panier(), change = false;
    Object.keys(c).forEach(function (s) {
      Object.keys(c[s]).forEach(function (k) {
        var p = products.find(function (x) { return String(x.id) === String(k); }), it = c[s][k];
        if (!p) { delete c[s][k]; change = true; return; }
        var q = p.stock != null ? Math.min(it.qty, p.stock) : it.qty;
        if (q <= 0) { delete c[s][k]; change = true; return; }
        if (it.price !== p.price || it.name !== p.name || it.qty !== q || it.photo !== (p.photo_url || '')) { c[s][k] = { id: p.id, name: p.name, price: p.price, qty: q, photo: p.photo_url || '', stock: p.stock }; change = true; }
      });
      if (!Object.keys(c[s]).length) { delete c[s]; change = true; }
    });
    if (change) B.enregistrer(c);
  };
  B.totalPanier = function () {
    var c = B.panier(), n = 0, t = 0;
    Object.keys(c).forEach(function (s) { Object.keys(c[s]).forEach(function (k) { n += c[s][k].qty; t += c[s][k].qty * c[s][k].price; }); });
    return { articles: n, montant: t, boutiques: Object.keys(c).length };
  };
})();
