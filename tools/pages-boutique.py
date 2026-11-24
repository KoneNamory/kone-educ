#!/usr/bin/env python3
"""Génère les pages publiques de la boutique (boutique.html, devenir-vendeur.html)
à partir de l'en-tête et du pied de page de services.html.
Usage : python3 tools/pages-boutique.py"""
import re, html, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = 'https://kone-educ.vercel.app'
base = (ROOT / 'services.html').read_text(encoding='utf-8')
HEAD = base[:base.index('<style>')]
BODY_START = base[base.index('<body'):base.index('<main')].replace(' aria-current="page"', '')
FOOTER = base[base.index('<footer'):base.index('<script src="site.js">')]


def page(fname, title, desc, css, main, scripts, extra_head=''):
    head = HEAD
    head = re.sub(r'<title>[^<]*</title>', '<title>' + html.escape(title) + '</title>', head)
    for k, v in (('name="description"', desc), ('property="og:title"', title), ('property="og:description"', desc)):
        head = re.sub(r'<meta ' + k + r' content="[^"]*">', '<meta ' + k + ' content="' + html.escape(v) + '">', head)
    head = re.sub(r'<link rel="canonical" href="[^"]*">', '<link rel="canonical" href="' + SITE + '/' + fname + '">', head)
    head = re.sub(r'<meta property="og:url" content="[^"]*">', '<meta property="og:url" content="' + SITE + '/' + fname + '">', head)
    body_start = BODY_START.replace('<a href="' + fname + '">', '<a href="' + fname + '" aria-current="page">', 1)
    out = (head + extra_head + '<style>' + css + '</style></head>' + body_start + main + FOOTER + scripts
           + '<script src="site.js"></script></body></html>\n')
    (ROOT / fname).write_text(out, encoding='utf-8')
    print('écrit', fname)


SUPA = '<script src="supabase-config.js"></script><script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>'

# ---------------------------------------------------------------- boutique.html
BQ_CSS = r"""
:root{--bq-b:#1559eb;--bq-o:#fa7518;--bq-n:#102149;--bq-m:#5b6884;--bq-l:#e3ebf8}
.bq,.bq-bar,dialog.bq-dlg,.bq button,.bq input,.bq select{font-family:"DM Sans",Arial,sans-serif}
.bq{max-width:1180px;margin:0 auto;padding:22px 20px 120px;color:var(--bq-n)}
.bq-hero{display:grid;gap:14px;padding:28px;border-radius:24px;color:#fff;background:linear-gradient(120deg,#0d3fb0,#1559eb 60%,#3d7bff)}
.bq-hero h1{margin:0;font:800 clamp(26px,4vw,40px)/1.1 Manrope,sans-serif;letter-spacing:-1px}
.bq-hero p{margin:0;color:#dce8ff;max-width:640px}
.bq-search{display:grid;grid-template-columns:1fr minmax(170px,240px);gap:10px}
.bq-search input,.bq-search select{width:100%;padding:14px 16px;border:0;border-radius:14px;font:600 16px "DM Sans",sans-serif;color:var(--bq-n);box-sizing:border-box}
.bq-trust{display:flex;flex-wrap:wrap;gap:8px 16px;font-size:14px;font-weight:700;color:#fff}
.bq-cats{display:flex;gap:8px;overflow-x:auto;padding:16px 0 6px;scrollbar-width:none}.bq-cats::-webkit-scrollbar{display:none}
.bq-chip{flex:none;padding:10px 14px;border:1px solid var(--bq-l);border-radius:99px;background:#fff;color:var(--bq-n);font:700 14px "DM Sans",sans-serif;cursor:pointer;white-space:nowrap}
.bq-chip.on{background:var(--bq-n);border-color:var(--bq-n);color:#fff}
.bq-filters{display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:6px 0 4px;font-size:14px;color:var(--bq-m)}
.bq-filters select{padding:9px 12px;border:1px solid var(--bq-l);border-radius:10px;font:600 14px "DM Sans",sans-serif;background:#fff}
.bq-filters label{display:flex;align-items:center;gap:6px;font-weight:700;color:var(--bq-n)}
.bq h2{margin:26px 0 12px;font:800 22px Manrope,sans-serif;color:var(--bq-n)}
.bq-shops{display:grid;grid-auto-flow:column;grid-auto-columns:minmax(250px,1fr);gap:12px;overflow-x:auto;padding-bottom:6px}
.bq-shop{display:flex;gap:12px;align-items:center;padding:14px;border:1px solid var(--bq-l);border-radius:18px;background:#fff;color:var(--bq-n);text-decoration:none;box-shadow:0 8px 22px rgba(21,61,140,.05)}
.bq-shop img,.bq-shop .ph{flex:none;width:54px;height:54px;border-radius:14px;object-fit:cover;background:#eef3ff;display:grid;place-items:center;font-size:26px}
.bq-shop b{display:block;font-size:15px}.bq-shop small{display:block;color:var(--bq-m);font-size:12.5px;line-height:1.4}
.bq-closed{color:#a11!important;font-weight:700}
.bq-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:14px}
.bq-card{display:flex;flex-direction:column;border:1px solid var(--bq-l);border-radius:18px;background:#fff;overflow:hidden;box-shadow:0 8px 22px rgba(21,61,140,.05)}
.bq-card .img{position:relative;aspect-ratio:1/1;background:#f3f6fc;display:grid;place-items:center;font-size:54px;cursor:pointer;border:0;padding:0;width:100%}
.bq-card .img img{width:100%;height:100%;object-fit:cover}
.bq-card .low{position:absolute;left:8px;top:8px;padding:3px 8px;border-radius:99px;background:#fff0dc;color:#9a5900;font-size:11.5px;font-weight:800}
.bq-card .in{display:flex;flex-direction:column;gap:4px;padding:12px;flex:1}
.bq-card h3{margin:0;font:700 15px/1.3 "DM Sans",sans-serif;color:var(--bq-n)}
.bq-card .meta{color:var(--bq-m);font-size:12.5px}
.bq-card .shopn{color:var(--bq-b);font-size:12.5px;font-weight:700;text-decoration:none}
.bq-card .row{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:8px;margin-top:auto;padding-top:8px}.bq-price{white-space:nowrap}
.bq-price{font:800 16px Manrope,sans-serif;color:var(--bq-n)}
.bq-add{padding:9px 14px;border:0;border-radius:11px;background:var(--bq-o);color:#fff;font:800 14px "DM Sans",sans-serif;cursor:pointer}
.bq-add:disabled{background:#c9d2e3;cursor:not-allowed}
.bq-step{display:inline-flex;align-items:center;border-radius:11px;background:#fff3e8;overflow:hidden}
.bq-step button{width:34px;height:36px;border:0;background:transparent;color:var(--bq-o);font:800 20px sans-serif;cursor:pointer}
.bq-step span{min-width:24px;text-align:center;font-weight:800;color:var(--bq-n)}
.bq-empty{padding:30px;border:1px dashed #cbd7ee;border-radius:18px;background:#fff;text-align:center;color:var(--bq-m)}
.bq-empty b{display:block;color:var(--bq-n);font-size:17px;margin-bottom:6px}
.bq-shophead{display:grid;grid-template-columns:auto 1fr;gap:16px;align-items:center;padding:20px;border:1px solid var(--bq-l);border-radius:22px;background:#fff}
.bq-shophead .ph,.bq-shophead img{width:76px;height:76px;border-radius:18px;object-fit:cover;background:#eef3ff;display:grid;place-items:center;font-size:36px}
.bq-shophead h1{margin:0;font:800 26px Manrope,sans-serif;color:var(--bq-n)}
.bq-shophead p{margin:4px 0;color:var(--bq-m);font-size:14px}
.bq-info{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px}
.bq-info span{padding:6px 10px;border-radius:99px;background:#f1f5fd;font-size:13px;font-weight:700;color:var(--bq-n)}
.bq-actions{display:flex;flex-wrap:wrap;gap:8px;margin-top:10px}
.bq-btn{display:inline-flex;align-items:center;justify-content:center;gap:6px;padding:11px 16px;border:0;border-radius:12px;background:var(--bq-b);color:#fff;font:800 15px "DM Sans",sans-serif;text-decoration:none;cursor:pointer}
.bq-btn.wa{background:#1fa855}.bq-btn.ghost{background:#fff;color:var(--bq-n);border:1px solid var(--bq-l)}.bq-btn.orange{background:var(--bq-o)}
.bq-btn:disabled{opacity:.55;cursor:not-allowed}
.bq-back{display:inline-block;margin:0 0 12px;color:var(--bq-b);font-weight:800;text-decoration:none}
.bq-reviews{display:grid;gap:8px;margin-top:10px}.bq-reviews div{padding:10px 12px;border-radius:12px;background:#f7f9fd;font-size:14px}
.bq-bar{position:fixed;left:16px;right:88px;bottom:16px;z-index:60;display:none;align-items:center;justify-content:space-between;gap:12px;max-width:640px;margin:0 auto;padding:12px 14px 12px 18px;border-radius:18px;background:var(--bq-n);color:#fff;box-shadow:0 18px 40px rgba(16,33,73,.35);cursor:pointer;border:0;text-align:left}
.bq-bar.show{display:flex}.bq-bar b{font-size:16px}.bq-bar small{display:block;color:#c7d3ee}
.bq-bar em{font-style:normal;padding:10px 14px;border-radius:12px;background:var(--bq-o);font-weight:800;white-space:nowrap}
dialog.bq-dlg{width:min(560px,calc(100% - 24px));max-height:calc(100dvh - 24px);padding:0;border:0;border-radius:22px;color:var(--bq-n);font-family:"DM Sans",sans-serif;box-shadow:0 30px 80px rgba(16,26,53,.35)}
dialog.bq-dlg::backdrop{background:rgba(10,20,45,.55)}
.bq-dlg .hd{position:sticky;top:0;z-index:2;display:flex;justify-content:space-between;align-items:center;padding:16px 20px;background:#fff;border-bottom:1px solid var(--bq-l)}
.bq-dlg .hd h2{margin:0;font:800 20px Manrope,sans-serif}
.bq-dlg .x{width:38px;height:38px;border:0;border-radius:50%;background:#f1f5fd;font-size:18px;cursor:pointer}
.bq-dlg .bd{padding:16px 20px 22px}
.bq-dlg label{display:block;margin-top:12px;font-weight:700;font-size:14px}
.bq-dlg input,.bq-dlg select,.bq-dlg textarea{display:block;width:100%;margin-top:6px;padding:12px;border:1px solid #d7e1f2;border-radius:11px;font:500 15px "DM Sans",sans-serif;box-sizing:border-box;color:var(--bq-n);background:#fff}
.bq-dlg .conditional{display:none}.bq-dlg .conditional.show{display:block}
.bq-opts{display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:8px}
.bq-opt{display:flex!important;gap:10px;align-items:flex-start;margin:0!important;padding:12px;border:2px solid #dbe5f5;border-radius:14px;cursor:pointer;font-weight:700}
.bq-opt input{width:auto!important;margin:3px 0 0!important}
.bq-opt small{display:block;color:var(--bq-m);font-weight:600;font-size:12.5px}
.bq-opt:has(input:checked){border-color:var(--bq-b);background:#f3f7ff}
.bq-opt.off{opacity:.45;pointer-events:none}
.bq-line{display:flex;align-items:center;gap:10px;padding:10px 0;border-bottom:1px solid #eef2f9}
.bq-line .t{flex:1;min-width:0}.bq-line .t b{display:block;font-size:14.5px}.bq-line .t small{color:var(--bq-m)}
.bq-line img,.bq-line .ph{width:46px;height:46px;border-radius:10px;object-fit:cover;background:#f3f6fc;display:grid;place-items:center;font-size:22px;flex:none}
.bq-sum{margin-top:12px;padding:12px 14px;border-radius:14px;background:#f7f9fd;font-size:15px}
.bq-sum div{display:flex;justify-content:space-between;padding:3px 0}.bq-sum .tot{font-weight:800;font-size:17px;border-top:1px solid #e3ebf8;margin-top:6px;padding-top:8px}
.bq-warn{margin-top:10px;padding:10px 12px;border-radius:12px;background:#fdecea;color:#a11;font-size:14px;font-weight:700}
.bq-ok{margin-top:10px;padding:10px 12px;border-radius:12px;background:#e5f7ec;color:#11743a;font-size:14px;font-weight:700}
.bq-shopblock{margin-bottom:18px;padding-bottom:12px;border-bottom:3px solid #f1f5fd}
.bq-shopblock h3{margin:4px 0 4px;font:800 17px Manrope,sans-serif}
.bq-success{text-align:center}.bq-success .big{font-size:56px}.bq-success h3{margin:6px 0;font:800 24px Manrope,sans-serif}
.bq-ref{display:inline-block;margin:8px 0;padding:8px 16px;border-radius:12px;background:#f1f5fd;font:800 22px Manrope,sans-serif;letter-spacing:2px}
.bq-momo{margin-top:12px;padding:14px;border-radius:14px;background:#fff7ec;border:1px solid #ffd7b0;text-align:left;font-size:14.5px}
.bq-badge{display:inline-block;padding:4px 10px;border-radius:99px;font-size:12px;font-weight:800}
.bq-sellcta{display:flex;flex-wrap:wrap;align-items:center;justify-content:space-between;gap:14px;margin-top:34px;padding:22px;border-radius:22px;background:#fff7ec;border:1px solid #ffd7b0}
.bq-sellcta b{font:800 19px Manrope,sans-serif;color:var(--bq-n)}.bq-sellcta p{margin:4px 0 0;color:var(--bq-m)}
@media(max-width:640px){.bq{padding:14px 14px 120px}.bq-hero{padding:20px;border-radius:20px}.bq-search{grid-template-columns:1fr}.bq-grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.bq-card .in{padding:10px}.bq-card h3{font-size:14px}.bq-card .row{flex-direction:column;align-items:stretch}.bq-add{width:100%;padding:10px}.bq-step{justify-content:space-between}.bq-opts{grid-template-columns:1fr}.bq-shophead{grid-template-columns:1fr}.bq-bar{left:12px;right:80px;bottom:12px}}
"""

BQ_MAIN = r"""<main class="bq" id="bq">
<section class="bq-hero" id="hero">
  <h1>Fournitures scolaires livrées chez vous</h1>
  <p>Livres, manuels, cahiers, annales et fournitures du programme, chez des boutiques vérifiées d’Abidjan. Commandez en 2 minutes, payez à la livraison ou par mobile money.</p>
  <div class="bq-search"><input id="q" type="search" placeholder="Rechercher : cahier, annales BEPC, manuel CM2…" aria-label="Rechercher un article"><select id="commune" aria-label="Commune de livraison"><option value="">📍 Ma commune de livraison</option></select></div>
  <div class="bq-trust"><span>✅ Boutiques vérifiées</span><span>💵 Paiement à la livraison</span><span>📱 Wave · Orange Money · MTN · Moov</span><span>⭐ Avis des familles</span></div>
</section>
<div id="view"></div>
<section class="bq-sellcta"><div><b>🏪 Vous êtes libraire ou papetier ?</b><p>Ouvrez votre boutique gratuitement et recevez des commandes de parents et d’enseignants près de chez vous.</p></div><a class="bq-btn orange" href="devenir-vendeur.html">Vendre sur KONE.EDUC →</a></section>
</main>
<button type="button" class="bq-bar" id="bar" aria-label="Voir le panier"><span><b id="barN">0 article</b><small id="barT">0 FCFA</small></span><em>Voir le panier →</em></button>
<dialog class="bq-dlg" id="dlg" aria-labelledby="dlgTitle"><div class="hd"><h2 id="dlgTitle">Panier</h2><button type="button" class="x" aria-label="Fermer" onclick="dlg.close()">✕</button></div><div class="bd" id="dlgBody"></div></dialog>
"""

BQ_JS = r"""<script src="abidjan-locations.js"></script><script src="boutique-commun.js"></script><script>
const db = supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
const B = KE_BOUTIQUE, esc = B.esc;
let shops = [], products = [], user = null, profile = null, loaded = false;
const st = { q: '', cat: '', niveau: '', commune: '', livrable: true };
try { st.commune = localStorage.getItem('koneEducCommune') || ''; } catch (e) {}
const params = () => new URLSearchParams(location.search);
const shopById = id => shops.find(s => String(s.id) === String(id));
const COMMUNES = Object.keys(window.KONE_EDUC_ABIDJAN || {}).concat(Object.keys(window.KONE_EDUC_ENVIRONS || {}));
commune.innerHTML += COMMUNES.map(c => '<option>' + esc(c) + '</option>').join('');
commune.value = st.commune;
commune.onchange = () => { st.commune = commune.value; try { localStorage.setItem('koneEducCommune', st.commune); } catch (e) {} render(); };
q.oninput = () => { st.q = q.value; render(); };

function img(p, cls) { return p.photo_url ? '<img src="' + esc(p.photo_url) + '" alt="" loading="lazy">' : '<span aria-hidden="true">' + B.catIcon(p.category) + '</span>'; }
function shopLogo(s) { return s.logo_url ? '<img src="' + esc(s.logo_url) + '" alt="">' : '<span class="ph" aria-hidden="true">🏪</span>'; }
function livraisonTexte(s) {
  if (st.commune) { const f = B.fraisLivraison(s, st.commune); if (f != null) return '🛵 Livraison ' + (f ? B.fcfa(f) : 'gratuite') + ' à ' + st.commune; return s.pickup ? '🏪 Retrait en boutique (ne livre pas à ' + st.commune + ')' : '❌ Ne livre pas à ' + st.commune; }
  return '🛵 ' + B.zonesTexte(s);
}
function noteTexte(s) { return s.ratings_count ? '⭐ ' + Number(s.rating).toFixed(1) + ' (' + s.ratings_count + ' avis)' : '🆕 Nouvelle boutique'; }
function livrable(s) { return !st.commune || B.fraisLivraison(s, st.commune) != null || s.pickup; }
function norm(v) { return String(v || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }

function filtres(list) {
  const words = norm(st.q).split(/\s+/).filter(Boolean);
  return list.filter(p => {
    const s = shopById(p.shop_id); if (!s) return false;
    if (st.cat && p.category !== st.cat) return false;
    if (st.niveau && p.level && p.level !== st.niveau && p.level !== 'Tous niveaux') return false;
    if (st.livrable && st.commune && !livrable(s)) return false;
    const hay = norm([p.name, p.description, p.subject, p.level, B.catLabel(p.category), s.name].join(' '));
    return words.every(w => hay.includes(w));
  });
}
function carte(p) {
  const s = shopById(p.shop_id), n = B.qte(p), out = p.stock === 0;
  const ctl = out ? '<button class="bq-add" disabled>Épuisé</button>' : n ? '<span class="bq-step"><button type="button" aria-label="Retirer un" onclick="plus(' + p.id + ',-1)">−</button><span>' + n + '</span><button type="button" aria-label="Ajouter un" onclick="plus(' + p.id + ',1)">+</button></span>' : '<button class="bq-add" type="button" onclick="plus(' + p.id + ',1)">+ Ajouter</button>';
  return '<article class="bq-card"><button type="button" class="img" onclick="fiche(' + p.id + ')" aria-label="Voir ' + esc(p.name) + '">' + img(p) + (p.stock != null && p.stock > 0 && p.stock <= 3 ? '<span class="low">Plus que ' + p.stock + '</span>' : '') + '</button><div class="in"><h3>' + esc(p.name) + '</h3><span class="meta">' + esc([B.catLabel(p.category), p.level, p.subject].filter(Boolean).join(' · ')) + '</span>'
    + (params().get('shop') ? '' : '<a class="shopn" href="boutique.html?shop=' + s.id + '">🏪 ' + esc(s.name) + '</a>')
    + '<div class="row"><span class="bq-price">' + B.fcfa(p.price) + '</span>' + ctl + '</div></div></article>';
}
function grille(list, vide) { return list.length ? '<div class="bq-grid">' + list.map(carte).join('') + '</div>' : '<div class="bq-empty">' + vide + '</div>'; }
function chips() {
  return '<div class="bq-cats" role="toolbar" aria-label="Catégories"><button type="button" class="bq-chip' + (st.cat ? '' : ' on') + '" onclick="st.cat=\'\';render()">Tout</button>'
    + B.CATEGORIES.map(c => '<button type="button" class="bq-chip' + (st.cat === c[0] ? ' on' : '') + '" onclick="st.cat=\'' + c[0] + '\';render()">' + c[2] + ' ' + c[1] + '</button>').join('') + '</div>'
    + '<div class="bq-filters"><select aria-label="Niveau scolaire" onchange="st.niveau=this.value;render()"><option value="">🎓 Tous les niveaux</option>' + B.NIVEAUX.slice(1).map(n => '<option' + (st.niveau === n ? ' selected' : '') + '>' + n + '</option>').join('') + '</select>'
    + (st.commune ? '<label><input type="checkbox"' + (st.livrable ? ' checked' : '') + ' onchange="st.livrable=this.checked;render()"> Seulement les boutiques qui livrent à ' + esc(st.commune) + ' (ou retrait)</label>' : '<span>Choisissez votre commune pour voir les frais de livraison.</span>') + '</div>';
}

function render() {
  const view = document.getElementById('view');
  if (!loaded) { view.innerHTML = '<div class="bq-empty" style="margin-top:18px">Chargement de la boutique…</div>'; return; }
  const sid = params().get('shop');
  hero.hidden = !!sid;
  if (sid) {
    const s = shopById(sid);
    if (!s) { view.innerHTML = '<a class="bq-back" href="boutique.html">← Toutes les boutiques</a><div class="bq-empty"><b>Boutique introuvable</b>Elle n’est peut-être pas encore validée par KONE.EDUC.</div>'; return; }
    document.title = s.name + ' | Boutique KONE.EDUC';
    const list = filtres(products.filter(p => p.shop_id === s.id));
    view.innerHTML = '<a class="bq-back" href="boutique.html">← Toutes les boutiques</a><section class="bq-shophead">' + shopLogo(s) + '<div><h1>' + esc(s.name) + '</h1><p>📍 ' + esc([s.quartier, s.commune].filter(Boolean).join(', ')) + (s.is_open ? '' : ' · <span class="bq-closed">Fermée pour le moment</span>') + '</p>' + (s.description ? '<p>' + esc(s.description) + '</p>' : '')
      + '<div class="bq-info"><span>' + noteTexte(s) + '</span><span>' + esc(livraisonTexte(s)) + '</span>' + (s.delivery_delay ? '<span>⏱ ' + esc(s.delivery_delay) + '</span>' : '') + (s.pickup ? '<span>🏪 Retrait possible</span>' : '') + '<span>💳 ' + [s.pay_cod ? 'Paiement à la livraison' : '', s.pay_momo ? 'Mobile money' : ''].filter(Boolean).join(' · ') + '</span>' + (s.min_order ? '<span>Minimum ' + B.fcfa(s.min_order) + '</span>' : '') + (s.delivered_count ? '<span>✅ ' + s.delivered_count + ' commande(s) livrée(s)</span>' : '') + '</div>'
      + '<div class="bq-actions"><a class="bq-btn wa" target="_blank" rel="noopener" href="' + B.waLink(s.whatsapp || s.phone, 'Bonjour, je vous contacte depuis la boutique KONE.EDUC.') + '">WhatsApp</a><a class="bq-btn ghost" href="' + B.telLink(s.phone) + '">📞 Appeler</a><button type="button" class="bq-btn ghost" onclick="partager(' + s.id + ')">🔗 Partager</button></div><div class="bq-reviews" id="reviews"></div></div></section>'
      + chips() + '<h2>Articles (' + list.length + ')</h2>' + grille(list, '<b>Aucun article ne correspond</b>Essayez une autre catégorie ou un autre mot.');
    db.rpc('shop_reviews', { p_shop: s.id }).then(r => { const el = document.getElementById('reviews'); if (el && r.data && r.data.length) el.innerHTML = r.data.slice(0, 3).map(x => '<div><b>' + B.stars(x.rating) + '</b> ' + esc(x.buyer) + (x.review ? ' : « ' + esc(x.review) + ' »' : '') + '</div>').join(''); });
    return;
  }
  document.title = 'Boutique scolaire : livres, cahiers, fournitures livrés à Abidjan | KONE.EDUC';
  const vis = shops.filter(s => !st.livrable || livrable(s));
  const list = filtres(products);
  view.innerHTML = chips()
    + (vis.length ? '<h2>Boutiques' + (st.commune ? ' pour ' + esc(st.commune) : '') + '</h2><div class="bq-shops">' + vis.map(s => '<a class="bq-shop" href="boutique.html?shop=' + s.id + '">' + shopLogo(s) + '<span><b>' + esc(s.name) + '</b><small>' + noteTexte(s) + ' · ' + esc(s.commune) + '</small><small>' + esc(livraisonTexte(s)) + '</small>' + (s.is_open ? '' : '<small class="bq-closed">Fermée pour le moment</small>') + '</span></a>').join('') + '</div>' : '')
    + '<h2>' + (st.q || st.cat || st.niveau ? 'Résultats (' + list.length + ')' : 'Tous les articles') + '</h2>'
    + grille(list, shops.length ? '<b>Aucun article ne correspond</b>Essayez un autre mot, une autre catégorie ou décochez le filtre de livraison.' : '<b>La boutique ouvre bientôt 🎉</b>Les premières librairies et papeteries partenaires arrivent. Vous êtes vendeur ? <a href="devenir-vendeur.html">Ouvrez votre boutique</a>.');
}

function plus(id, d) {
  const p = products.find(x => x.id === id); if (!p) return;
  const s = shopById(p.shop_id);
  if (d > 0 && s && !s.is_open) { alert(s.name + ' est fermée pour le moment. Revenez plus tard ou choisissez une autre boutique.'); return; }
  const before = B.qte(p), after = B.ajouter(p, d);
  if (d > 0 && after === before && p.stock != null) alert('Stock maximum atteint pour cet article.');
  render(); barre();
  if (dlg.open && dlg.dataset.mode === 'panier') ouvrirPanier();
}
function barre() { const t = B.totalPanier(); bar.classList.toggle('show', t.articles > 0); barN.textContent = t.articles + ' article' + (t.articles > 1 ? 's' : ''); barT.textContent = B.fcfa(t.montant) + (t.boutiques > 1 ? ' · ' + t.boutiques + ' boutiques' : ''); }
bar.onclick = () => ouvrirPanier();
document.addEventListener('panier', barre);

function fiche(id) {
  const p = products.find(x => x.id === id), s = shopById(p.shop_id);
  dlg.dataset.mode = 'fiche'; dlgTitle.textContent = p.name;
  dlgBody.innerHTML = '<div style="display:grid;place-items:center;aspect-ratio:4/3;border-radius:16px;background:#f3f6fc;overflow:hidden;font-size:80px">' + (p.photo_url ? '<img src="' + esc(p.photo_url) + '" alt="" style="width:100%;height:100%;object-fit:contain">' : B.catIcon(p.category)) + '</div>'
    + '<p class="bq-price" style="font-size:24px;margin:14px 0 4px">' + B.fcfa(p.price) + '</p><p style="margin:0;color:#5b6884">' + esc([B.catLabel(p.category), p.level, p.subject].filter(Boolean).join(' · ')) + '</p>'
    + (p.description ? '<p style="white-space:pre-line">' + esc(p.description) + '</p>' : '')
    + '<p>🏪 <a href="boutique.html?shop=' + s.id + '">' + esc(s.name) + '</a> · ' + noteTexte(s) + '<br><small>' + esc(livraisonTexte(s)) + '</small></p>'
    + (p.stock === 0 ? '<button class="bq-btn" disabled>Épuisé</button>' : '<button class="bq-btn orange" style="width:100%" onclick="plus(' + p.id + ',1);dlg.close()">Ajouter au panier</button>');
  if (!dlg.open) dlg.showModal();
}

function ouvrirPanier() {
  const c = B.panier(), ids = Object.keys(c);
  dlg.dataset.mode = 'panier'; dlgTitle.textContent = '🛒 Mon panier';
  if (!ids.length) { dlgBody.innerHTML = '<div class="bq-empty"><b>Votre panier est vide</b>Ajoutez des articles pour commander.</div>'; if (!dlg.open) dlg.showModal(); return; }
  dlgBody.innerHTML = (ids.length > 1 ? '<p style="margin-top:0;color:#5b6884">Vous avez des articles de ' + ids.length + ' boutiques : chaque boutique reçoit sa propre commande et livre séparément.</p>' : '')
    + ids.map(sid => {
      const s = shopById(sid), items = Object.values(c[sid]); const sub = items.reduce((a, i) => a + i.qty * i.price, 0);
      if (!s) return '<div class="bq-shopblock"><p class="bq-warn">Une boutique de votre panier n’est plus disponible.</p><button class="bq-btn ghost" onclick="KE_BOUTIQUE.viderBoutique(\'' + esc(sid) + '\');ouvrirPanier()">Retirer ces articles</button></div>';
      return '<div class="bq-shopblock"><h3>🏪 ' + esc(s.name) + '</h3>' + items.map(i => '<div class="bq-line">' + (i.photo ? '<img src="' + esc(i.photo) + '" alt="">' : '<span class="ph">📦</span>') + '<div class="t"><b>' + esc(i.name) + '</b><small>' + B.fcfa(i.price) + '</small></div><span class="bq-step"><button type="button" aria-label="Retirer un" onclick="plus(' + i.id + ',-1)">−</button><span>' + i.qty + '</span><button type="button" aria-label="Ajouter un" onclick="plus(' + i.id + ',1)">+</button></span></div>').join('')
        + '<div class="bq-sum"><div><span>Sous-total</span><b>' + B.fcfa(sub) + '</b></div></div>'
        + (s.min_order && sub < s.min_order ? '<p class="bq-warn">Minimum de commande : ' + B.fcfa(s.min_order) + '. Ajoutez ' + B.fcfa(s.min_order - sub) + '.</p>' : '')
        + (!s.is_open ? '<p class="bq-warn">Boutique fermée pour le moment.</p>' : '')
        + '<button type="button" class="bq-btn orange" style="width:100%;margin-top:12px"' + ((s.min_order && sub < s.min_order) || !s.is_open ? ' disabled' : '') + ' onclick="commander(' + s.id + ')">Commander chez ' + esc(s.name) + ' →</button></div>';
    }).join('');
  if (!dlg.open) dlg.showModal();
}

async function commander(sid) {
  const s = shopById(sid), items = Object.values(B.panier()[String(sid)] || {});
  const sub = items.reduce((a, i) => a + i.qty * i.price, 0);
  dlg.dataset.mode = 'commande'; dlgTitle.textContent = 'Finaliser ma commande';
  if (!user) {
    dlgBody.innerHTML = '<div class="bq-success"><div class="big">🔐</div><h3>Connectez-vous pour commander</h3><p>Votre panier est gardé. Un compte permet de suivre votre commande en direct et de contacter le vendeur.</p><a class="bq-btn" style="width:100%" href="connexion.html?redirect=boutique.html">Se connecter</a><p>Pas encore de compte ? <a href="inscription.html?role=parent&redirect=boutique.html">Créer un compte gratuit</a></p></div>';
    return;
  }
  const livre = Object.keys(s.delivery_fees || {}).length || s.default_delivery_fee != null;
  dlgBody.innerHTML = '<form id="ck"><p style="margin:0 0 6px"><b>🏪 ' + esc(s.name) + '</b> · ' + items.reduce((a, i) => a + i.qty, 0) + ' article(s)</p>'
    + '<label>Votre nom <input id="ckName" required maxlength="120" autocomplete="name"></label><label>Téléphone (le vendeur vous appellera) <input id="ckPhone" type="tel" required maxlength="30" autocomplete="tel"></label>'
    + '<p style="margin:14px 0 0;font-weight:800">Réception</p><div class="bq-opts"><label class="bq-opt' + (livre ? '' : ' off') + '"><input type="radio" name="mode" value="delivery"' + (livre ? ' checked' : ' disabled') + '><span>🛵 Livraison<small>' + (livre ? esc(s.delivery_delay || 'Le vendeur vous livre') : 'Non proposée') + '</small></span></label><label class="bq-opt' + (s.pickup ? '' : ' off') + '"><input type="radio" name="mode" value="pickup"' + (!livre && s.pickup ? ' checked' : '') + (s.pickup ? '' : ' disabled') + '><span>🏪 Retrait en boutique<small>' + esc([s.quartier, s.commune].filter(Boolean).join(', ')) + ' · gratuit</small></span></label></div>'
    + '<div id="ckDel"><label>Commune <select id="ckCommune"></select></label><label>Quartier <select id="ckQuartier"></select></label><label>Adresse ou repère <input id="ckAddr" maxlength="200" placeholder="Ex. Rue des jardins, près de la pharmacie, portail bleu"></label></div>'
    + '<p style="margin:14px 0 0;font-weight:800">Paiement</p><div class="bq-opts"><label class="bq-opt' + (s.pay_cod ? '' : ' off') + '"><input type="radio" name="pay" value="cod"' + (s.pay_cod ? ' checked' : ' disabled') + '><span>💵 À la livraison<small>Espèces ou mobile money à la réception</small></span></label><label class="bq-opt' + (s.pay_momo ? '' : ' off') + '"><input type="radio" name="pay" value="momo"' + (!s.pay_cod && s.pay_momo ? ' checked' : '') + (s.pay_momo ? '' : ' disabled') + '><span>📱 Mobile money avant<small>Wave, Orange Money, MTN, Moov</small></span></label></div>'
    + '<label>Message au vendeur (facultatif) <textarea id="ckNote" rows="2" maxlength="500" placeholder="Ex. Appelez-moi avant de venir"></textarea></label>'
    + '<div class="bq-sum" id="ckSum"></div><p id="ckMsg" role="status"></p><button class="bq-btn orange" style="width:100%;margin-top:6px" id="ckBtn">Valider ma commande</button><button type="button" class="bq-btn ghost" style="width:100%;margin-top:8px" onclick="ouvrirPanier()">← Retour au panier</button></form>';
  ckName.value = (profile && profile.full_name) || ''; ckPhone.value = (profile && profile.phone) || '';
  setupAbidjanLocation('ckCommune', 'ckQuartier');
  if (st.commune) { ckCommune.value = st.commune; ckCommune.dispatchEvent(new Event('change')); }
  const mode = () => (ck.querySelector('input[name=mode]:checked') || {}).value;
  const maj = () => {
    const m = mode(), del = m === 'delivery'; ckDel.hidden = !del;
    ckCommune.required = del; ckQuartier.required = del && ckQuartier.closest('label').style.display !== 'none';
    const loc = del ? getAbidjanLocation('ckCommune', 'ckQuartier') : null;
    const fee = del ? (loc.commune ? B.fraisLivraison(s, loc.commune) : 0) : 0;
    let warn = '';
    if (del && loc.commune && fee == null) warn = '<p class="bq-warn">❌ ' + esc(s.name) + ' ne livre pas à ' + esc(loc.commune) + '.' + (s.pickup ? ' Choisissez le retrait en boutique.' : '') + '</p>';
    ckSum.innerHTML = '<div><span>Articles</span><b>' + B.fcfa(sub) + '</b></div><div><span>Livraison</span><b>' + (del ? (fee == null ? '—' : fee ? B.fcfa(fee) : 'Gratuite') : 'Retrait gratuit') + '</b></div><div class="tot"><span>Total à payer</span><span>' + B.fcfa(sub + (fee || 0)) + '</span></div>' + warn;
    ckBtn.disabled = !m || (del && loc.commune && fee == null);
  };
  ck.addEventListener('change', maj); ck.addEventListener('input', maj); maj();
  ck.onsubmit = async e => {
    e.preventDefault(); ckBtn.disabled = true; ckBtn.textContent = 'Envoi…'; ckMsg.textContent = '';
    const m = mode(), loc = m === 'delivery' ? getAbidjanLocation('ckCommune', 'ckQuartier') : { commune: null, quartier: null };
    const r = await db.rpc('place_order', { p_shop: s.id, p_items: items.map(i => ({ product_id: i.id, qty: i.qty })), p_mode: m, p_commune: loc.commune, p_quartier: loc.quartier,
      p_address: m === 'delivery' ? ckAddr.value : null, p_payment: (ck.querySelector('input[name=pay]:checked') || {}).value, p_name: ckName.value, p_phone: ckPhone.value, p_note: ckNote.value });
    if (r.error) { ckMsg.className = 'bq-warn'; ckMsg.textContent = r.error.message; ckBtn.disabled = false; ckBtn.textContent = 'Valider ma commande'; await charger(); return; }
    const o = Array.isArray(r.data) ? r.data[0] : r.data, pay = (ck.querySelector('input[name=pay]:checked') || {}).value;
    B.viderBoutique(s.id); render();
    dlgTitle.textContent = 'Commande envoyée ✅';
    dlgBody.innerHTML = '<div class="bq-success"><div class="big">🎉</div><h3>Merci ! Votre commande est envoyée</h3><p>' + esc(s.name) + ' vient d’être prévenu(e). Vous recevrez une notification dès qu’elle est acceptée.</p><div class="bq-ref">' + esc(o.order_ref) + '</div><p>Total : <b>' + B.fcfa(o.order_total) + '</b></p><div id="momoBox"></div>'
      + '<a class="bq-btn" style="width:100%" href="mes-commandes.html">Suivre ma commande</a><a class="bq-btn wa" style="width:100%;margin-top:8px" target="_blank" rel="noopener" href="' + B.waLink(s.whatsapp || s.phone, 'Bonjour ' + s.name + ', je viens de passer la commande ' + o.order_ref + ' (' + B.fcfa(o.order_total) + ') sur KONE.EDUC.') + '">Prévenir le vendeur sur WhatsApp</a><button type="button" class="bq-btn ghost" style="width:100%;margin-top:8px" onclick="dlg.close()">Continuer mes achats</button></div>';
    if (pay === 'momo') {
      const n = await db.rpc('order_momo_numbers', { p_order: o.order_id }); const x = (n.data || [])[0] || {};
      const lignes = [['Wave', x.wave], ['Orange Money', x.orange], ['MTN MoMo', x.mtn], ['Moov Money', x.moov]].filter(l => l[1]);
      momoBox.innerHTML = '<div class="bq-momo"><b>📱 Paiement par mobile money</b><br>Envoyez <b>' + B.fcfa(o.order_total) + '</b> à :<br>' + (lignes.length ? lignes.map(l => l[0] + ' : <b>' + esc(l[1]) + '</b>').join('<br>') : 'le numéro que le vendeur vous donnera') + '<br><small>Puis signalez votre paiement dans « Mes commandes » avec la référence de la transaction.</small></div>';
    }
  };
}

function partager(id) {
  const s = shopById(id), url = location.origin + location.pathname + '?shop=' + id;
  const txt = 'Commandez chez ' + s.name + ' sur KONE.EDUC : livres, cahiers et fournitures livrés à domicile. ' + url;
  if (navigator.share) navigator.share({ title: s.name, text: txt, url }).catch(() => {}); else location.href = 'https://wa.me/?text=' + encodeURIComponent(txt);
}

async function charger() {
  const [s, p] = await Promise.all([db.rpc('public_shops'), db.from('products').select('id,shop_id,name,description,category,level,subject,price,stock,photo_url,active').eq('active', true).order('created_at', { ascending: false }).limit(2000)]);
  shops = s.data || []; products = (p.data || []).filter(x => x.active && shops.some(y => y.id === x.shop_id));
  if (!s.error && !p.error) B.synchroniser(products); // jamais en cas d'erreur réseau : le panier serait vidé
  loaded = true; render(); barre();
}
db.auth.getUser().then(async r => { user = r.data && r.data.user; if (user) { const p = await db.from('profiles').select('full_name, phone, role').eq('id', user.id).maybeSingle(); profile = p.data; } });
render(); charger();
window.addEventListener('popstate', render);
</script>"""

page('boutique.html', 'Boutique scolaire : livres, cahiers, fournitures livrés à Abidjan | KONE.EDUC',
     'Commandez livres, manuels, cahiers, annales et fournitures scolaires chez des boutiques vérifiées d’Abidjan. Livraison à domicile, paiement à la livraison ou par mobile money.',
     BQ_CSS, BQ_MAIN, SUPA + BQ_JS)

# ---------------------------------------------------------------- devenir-vendeur.html
DV_CSS = r"""
.dv{max-width:1100px;margin:0 auto;padding:22px 20px 60px;color:#102149;font-family:"DM Sans",Arial,sans-serif}
.dv-hero{display:grid;grid-template-columns:1.2fr .8fr;gap:24px;align-items:center;padding:34px;border-radius:26px;color:#fff;background:linear-gradient(120deg,#0d3fb0,#1559eb 60%,#3d7bff)}
.dv-hero h1{margin:0 0 12px;font:800 clamp(28px,4.4vw,44px)/1.08 Manrope,sans-serif;letter-spacing:-1.2px}
.dv-hero p{margin:0 0 18px;color:#dce8ff;font-size:17px;line-height:1.55}
.dv-hero .tags{display:flex;flex-wrap:wrap;gap:8px;margin-bottom:20px}.dv-hero .tags span{padding:7px 12px;border-radius:99px;background:rgba(255,255,255,.16);font-weight:800;font-size:14px}
.dv-phone{padding:18px;border-radius:24px;background:#fff;color:#102149;box-shadow:0 24px 60px rgba(0,0,0,.25)}
.dv-phone .n{display:flex;gap:10px;align-items:center;padding:12px;border-radius:14px;background:#fff7ec;border:1px solid #ffd7b0;margin-bottom:10px}
.dv-phone .n b{display:block}.dv-phone .n small{color:#5b6884}
.dv-phone .acts{display:grid;grid-template-columns:1fr 1fr;gap:8px}.dv-phone .acts span{padding:10px;border-radius:12px;text-align:center;font-weight:800;color:#fff;background:#11743a}.dv-phone .acts span+span{background:#b42318}
.dv-btn{display:inline-flex;align-items:center;justify-content:center;gap:8px;padding:14px 20px;border-radius:14px;background:#fa7518;color:#fff;font:800 16px "DM Sans",sans-serif;text-decoration:none}
.dv-btn.light{background:#fff;color:#1559eb}.dv-btn.wa{background:#1fa855}
.dv h2{margin:44px 0 16px;font:800 clamp(24px,3vw,32px) Manrope,sans-serif;letter-spacing:-.6px;text-align:center}
.dv-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
.dv-card{padding:20px;border:1px solid #e3ebf8;border-radius:20px;background:#fff;box-shadow:0 10px 30px rgba(21,61,140,.06)}
.dv-card .ic{font-size:30px}.dv-card b{display:block;margin:8px 0 4px;font-size:17px}.dv-card p{margin:0;color:#5b6884;line-height:1.5}
.dv-steps{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;counter-reset:s}
.dv-step{position:relative;padding:20px;border-radius:20px;background:#f4f7fc}
.dv-step:before{counter-increment:s;content:counter(s);display:grid;place-items:center;width:38px;height:38px;margin-bottom:10px;border-radius:50%;background:#1559eb;color:#fff;font-weight:800}
.dv-step b{display:block;margin-bottom:4px}.dv-step p{margin:0;color:#5b6884;font-size:15px;line-height:1.5}
.dv-faq details{margin:0 auto 10px;max-width:780px;padding:16px 18px;border:1px solid #e3ebf8;border-radius:16px;background:#fff}
.dv-faq summary{cursor:pointer;font-weight:800}.dv-faq p{margin:10px 0 0;color:#5b6884;line-height:1.6}
.dv-final{margin-top:40px;padding:30px;border-radius:24px;background:#fff7ec;border:1px solid #ffd7b0;text-align:center}
.dv-final p{color:#5b6884}.dv-final .row{display:flex;flex-wrap:wrap;gap:10px;justify-content:center}
@media(max-width:860px){.dv-hero{grid-template-columns:1fr;padding:24px}.dv-grid{grid-template-columns:1fr 1fr}.dv-steps{grid-template-columns:1fr 1fr}}
@media(max-width:560px){.dv{padding:14px 14px 50px}.dv-grid,.dv-steps{grid-template-columns:1fr}}
"""

FAQ = [
    ('Combien ça coûte ?', 'L’ouverture de la boutique est gratuite et, pendant le lancement, KONE.EDUC ne prend aucune commission sur vos ventes. Vous gardez 100 % de vos ventes. Si une commission est introduite plus tard, vous serez prévenu à l’avance et vous resterez libre de continuer ou non.'),
    ('Comment suis-je payé ?', 'Directement par le client, sans intermédiaire : en espèces ou par mobile money à la livraison, ou par mobile money (Wave, Orange Money, MTN, Moov) avant la livraison, sur vos propres numéros. Vous choisissez les moyens de paiement que vous acceptez.'),
    ('Qui livre les commandes ?', 'Vous, ou votre livreur. Vous choisissez les communes où vous livrez et vos frais de livraison pour chacune. Vous pouvez aussi proposer le retrait dans votre boutique.'),
    ('Comment je reçois les commandes ?', 'Dans votre espace vendeur, en temps réel, avec une alerte sonore, et par notification et e-mail. Vous voyez le nom, le téléphone et l’adresse du client, et vous pouvez l’appeler ou lui écrire sur WhatsApp en un clic.'),
    ('Et si un client ne répond pas ou ne paie pas ?', 'Vous pouvez refuser ou annuler une commande en indiquant la raison au client : vos articles reviennent automatiquement en stock. Le client doit avoir un compte avec son numéro de téléphone, et le nombre de commandes par personne est limité pour éviter les abus.'),
    ('Pourquoi ma boutique doit-elle être validée ?', 'Pour la confiance des familles : l’équipe KONE.EDUC vérifie chaque boutique (identité, numéro, adresse) avant sa mise en ligne. Le badge « Boutique vérifiée » rassure vos clients. Vous pouvez ajouter vos produits pendant la vérification.'),
    ('Que puis-je vendre ?', 'Tout ce qui sert à l’école et au programme : livres, manuels, cahiers, annales et sujets d’examens, fiches et documents pédagogiques, fournitures, cartables… Les contenus protégés doivent être vendus avec l’accord de leurs auteurs ou éditeurs.'),
    ('Je ne suis pas à l’aise avec Internet, c’est compliqué ?', 'Non : tout se fait depuis votre téléphone. Ajouter un article prend 30 secondes (photo, nom, prix). Si vous le souhaitez, l’équipe KONE.EDUC vous aide à installer votre boutique sur WhatsApp au 01 61 70 13 61.'),
]
DV_MAIN = """<main class="dv">
<section class="dv-hero"><div><h1>Vendez vos fournitures scolaires à des milliers de familles</h1><p>Libraires, papetiers, imprimeurs, auteurs de fiches : ouvrez votre boutique sur KONE.EDUC et recevez des commandes de parents et d’enseignants près de chez vous.</p>
<div class="tags"><span>0 FCFA pour s’inscrire</span><span>0 % de commission au lancement</span><span>Payé directement</span></div>
<a class="dv-btn" href="inscription.html?role=seller">Ouvrir ma boutique gratuitement →</a></div>
<div class="dv-phone" aria-hidden="true"><div class="n"><span style="font-size:28px">🛒</span><div><b>Nouvelle commande · 9 000 FCFA</b><small>3 cahiers, 2 annales BEPC · Yopougon</small></div></div><div class="n"><span style="font-size:28px">📍</span><div><b>Mariam K. · 07 •• •• •• 02</b><small>Livraison · paiement à la livraison</small></div></div><div class="acts"><span>✓ Accepter</span><span>✕ Refuser</span></div></div></section>

<h2>Pourquoi vendre sur KONE.EDUC ?</h2>
<div class="dv-grid">
<div class="dv-card"><div class="ic">👪</div><b>Des clients qui cherchent déjà</b><p>Les parents et les enseignants de KONE.EDUC achètent livres, cahiers et annales toute l’année, surtout à la rentrée et avant les examens.</p></div>
<div class="dv-card"><div class="ic">💵</div><b>Vous êtes payé directement</b><p>Espèces ou mobile money, sur vos propres numéros. Aucun intermédiaire ne garde votre argent.</p></div>
<div class="dv-card"><div class="ic">🔔</div><b>Commandes en temps réel</b><p>Alerte sonore, notification et e-mail à chaque commande. Accepter, préparer, livrer : un clic à chaque étape.</p></div>
<div class="dv-card"><div class="ic">🛵</div><b>Vous gardez le contrôle</b><p>Vos prix, vos stocks, vos communes et vos frais de livraison. Retrait en boutique possible.</p></div>
<div class="dv-card"><div class="ic">📞</div><b>Contact client en un clic</b><p>Appel ou WhatsApp avec le message déjà écrit, adresse et repère du client, bon de livraison imprimable.</p></div>
<div class="dv-card"><div class="ic">⭐</div><b>Une boutique de confiance</b><p>Badge « Boutique vérifiée », avis des clients, et un lien de votre boutique à partager sur WhatsApp et Facebook.</p></div>
</div>

<h2>Comment ça marche ?</h2>
<div class="dv-steps">
<div class="dv-step"><b>Créez votre compte</b><p>Choisissez « Vendeur » : nom, téléphone, e-mail. 1 minute.</p></div>
<div class="dv-step"><b>Ouvrez votre boutique</b><p>Adresse, communes livrées et frais, moyens de paiement. 2 minutes.</p></div>
<div class="dv-step"><b>Ajoutez vos articles</b><p>Photo, nom, prix, stock. KONE.EDUC valide votre boutique sous 24 h.</p></div>
<div class="dv-step"><b>Recevez des commandes</b><p>Acceptez, livrez, encaissez. Suivez vos ventes et vos avis.</p></div>
</div>

<h2>Questions fréquentes</h2>
<div class="dv-faq">""" + ''.join('<details><summary>' + html.escape(q) + '</summary><p>' + html.escape(a) + '</p></details>' for q, a in FAQ) + """</div>

<section class="dv-final"><h2 style="margin-top:0">Prêt à vendre ?</h2><p>Inscription gratuite. Vous pouvez arrêter à tout moment.</p><div class="row"><a class="dv-btn" href="inscription.html?role=seller">Ouvrir ma boutique</a><a class="dv-btn wa" href="https://wa.me/2250161701361?text=""" + html.escape('Bonjour KONE.EDUC, je suis vendeur et je souhaite ouvrir ma boutique.') + """" target="_blank" rel="noopener">Être aidé sur WhatsApp</a></div><p style="margin-top:14px">Déjà vendeur ? <a href="connexion.html?role=seller">Accéder à mon espace vendeur</a></p></section>
</main>"""
faq_ld = '<script type="application/ld+json">' + __import__('json').dumps({'@context': 'https://schema.org', '@type': 'FAQPage', 'mainEntity': [{'@type': 'Question', 'name': q, 'acceptedAnswer': {'@type': 'Answer', 'text': a}} for q, a in FAQ]}, ensure_ascii=False) + '</script>'
page('devenir-vendeur.html', 'Vendre des fournitures scolaires à Abidjan : ouvrez votre boutique | KONE.EDUC',
     'Libraires et papetiers : ouvrez gratuitement votre boutique sur KONE.EDUC, recevez des commandes de parents et d’enseignants, soyez payé directement. 0 % de commission au lancement.',
     DV_CSS, DV_MAIN, '', faq_ld)

# ---------------------------------------------------------------- ecoles.html (écoles qui recrutent)
EC_CSS = DV_CSS + r"""
.ec-form{margin:0 auto;max-width:820px;padding:26px;border:1px solid #e3ebf8;border-radius:24px;background:#fff;box-shadow:0 18px 50px rgba(21,61,140,.08)}
.ec-form fieldset{margin:0 0 14px;padding:16px;border:1px solid #e3ebf8;border-radius:16px}.ec-form legend{padding:0 6px;font:800 17px Manrope,sans-serif}
.ec-form .g{display:grid;grid-template-columns:1fr 1fr;gap:0 14px}
.ec-form label{display:block;margin-top:10px;font-weight:700;font-size:14.5px}
.ec-form input,.ec-form select,.ec-form textarea{display:block;width:100%;margin-top:6px;padding:12px;border:1px solid #d7e1f2;border-radius:11px;font:500 15px "DM Sans",sans-serif;box-sizing:border-box;background:#fff;color:#102149}
.ec-form .full{grid-column:1/-1}.ec-form .conditional{display:none}.ec-form .conditional.show{display:block}
.ec-chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:8px}.ec-chips label{display:flex;align-items:center;gap:6px;margin:0;padding:8px 12px;border:1px solid #d7e1f2;border-radius:99px;font-weight:700;cursor:pointer}
.ec-chips input{width:auto;margin:0}.ec-chips label:has(input:checked){background:#eaf1ff;border-color:#1559eb;color:#1559eb}
.ec-msg{min-height:22px;font-weight:700}.ec-msg.err{color:#b42318}
.ec-ok{display:none;text-align:center;padding:30px}.ec-ok.show{display:block}.ec-ok .big{font-size:56px}
@media(max-width:640px){.ec-form{padding:16px}.ec-form .g{grid-template-columns:1fr}}
"""
SUBJ = ['Mathématiques', 'Physique-Chimie', 'SVT', 'Français', 'Anglais', 'Philosophie', 'Histoire-Géographie', 'Espagnol', 'Allemand', 'Économie', 'Comptabilité', 'Informatique', 'EPS', 'Instituteur (primaire)']
EC_MAIN = """<main class="dv">
<section class="dv-hero"><div><h1>Votre école cherche un enseignant qualifié ?</h1><p>Écoles primaires, collèges, lycées, universités, centres de formation et de préparation aux concours : décrivez le poste, KONE.EDUC vous met en relation avec un enseignant vérifié.</p>
<div class="tags"><span>Gratuit pour les écoles</span><span>Enseignants vérifiés</span><span>Réponse sous 48 h</span></div><a class="dv-btn" href="#demande">Déposer ma demande →</a></div>
<div class="dv-phone" aria-hidden="true"><div class="n"><span style="font-size:28px">🏫</span><div><b>Lycée · Bingerville</b><small>Mathématiques · Terminale · BAC</small></div></div><div class="n"><span style="font-size:28px">✅</span><div><b>3 enseignants intéressés</b><small>Diplôme, identité et entretien vérifiés</small></div></div><div class="acts"><span>Mise en relation</span><span style="background:#1559eb">Sous 48 h</span></div></div></section>
<h2>Comment ça marche ?</h2>
<div class="dv-steps">
<div class="dv-step"><b>Décrivez le poste</b><p>Matières, niveaux, volume horaire, type de contrat, rémunération. 2 minutes, sans créer de compte.</p></div>
<div class="dv-step"><b>Nous sélectionnons</b><p>Les enseignants validés de la matière sont prévenus ; notre équipe étudie leurs profils.</p></div>
<div class="dv-step"><b>Mise en relation</b><p>Nous vous présentons le ou les meilleurs profils et transmettons vos coordonnées à l’enseignant choisi.</p></div>
<div class="dv-step"><b>Vous recrutez</b><p>Vous rencontrez l’enseignant et convenez ensemble des conditions.</p></div>
</div>
<h2 id="demande">Déposer une demande</h2>
<form class="ec-form" id="ecForm"><div id="ecFields">
<fieldset><legend>Votre établissement</legend><div class="g">
<label>Nom de l’établissement *<input id="eSchool" required maxlength="120" placeholder="Ex. Lycée Les Pionniers"></label>
<label>Type *<select id="eType" required><option value="">Choisir</option><option>École primaire</option><option>Collège / Lycée</option><option>Université / Grande école</option><option>Centre de formation</option><option>Centre de préparation aux concours</option></select></label>
<label>Commune *<select id="eCommune" required></select></label><label>Quartier *<select id="eQuartier"></select></label>
<label>Nom du responsable *<input id="eContact" required maxlength="120" autocomplete="name"></label><label>Téléphone / WhatsApp *<input id="ePhone" type="tel" required maxlength="30" autocomplete="tel"></label>
<label class="full">E-mail<input id="eEmail" type="email" maxlength="160" autocomplete="email"></label></div></fieldset>
<fieldset><legend>Le poste</legend>
<label>Matières *</label><div class="ec-chips" id="eSubjects">""" + ''.join('<label><input type="checkbox" value="' + html.escape(x) + '"> ' + html.escape(x) + '</label>' for x in SUBJ) + """</div>
<div class="g"><label>Autre matière<input id="eOther" maxlength="80" placeholder="Si absente de la liste"></label><label>Niveaux / classes<input id="eLevels" maxlength="200" placeholder="Ex. 3e, Terminale D"></label>
<label>Préparation à un examen ou concours<select id="ePrep"></select></label>
<label>Type de contrat *<select id="eContract" required><option value="">Choisir</option><option>Vacation</option><option>Temps partiel</option><option>Temps plein</option><option>Remplacement</option><option>Cours de soutien</option></select></label>
<label>Volume horaire<input id="eHours" maxlength="60" placeholder="Ex. 6 h par semaine"></label><label>Rémunération proposée<input id="eSalary" maxlength="80" placeholder="Ex. 5 000 F / heure"></label>
<label>Date de début<input id="eStart" type="date"></label>
<label class="full">Profil demandé<textarea id="eReq" rows="2" maxlength="600" placeholder="Ex. Licence minimum, expérience en classe d’examen"></textarea></label>
<label class="full">Informations complémentaires<textarea id="eDetails" rows="3" maxlength="1000"></textarea></label></div></fieldset>
<p class="ec-msg" id="eMsg" role="status"></p><button class="dv-btn" style="width:100%;border:0;cursor:pointer" id="eBtn">Envoyer ma demande</button>
<p style="text-align:center;color:#5b6884;font-size:14px">Vos coordonnées ne sont jamais publiées : seul l’enseignant retenu les reçoit, de la part de KONE.EDUC.</p></div>
<div class="ec-ok" id="ecOk"><div class="big">🎉</div><h3 style="font:800 24px Manrope,sans-serif">Demande envoyée !</h3><p>Notre équipe vous contacte sous 48 h avec un ou plusieurs profils d’enseignants.</p><a class="dv-btn wa" href="https://wa.me/2250161701361" target="_blank" rel="noopener">Nous écrire sur WhatsApp</a></div></form>
<section class="dv-final"><h2 style="margin-top:0">Vous êtes enseignant ?</h2><p>Les écoles partenaires recrutent aussi des vacataires et des remplaçants. Inscrivez-vous et faites valider votre dossier pour recevoir leurs offres.</p><div class="row"><a class="dv-btn" href="candidature-enseignant.html">Devenir enseignant KONE.EDUC</a><a class="dv-btn light" style="border:1px solid #e3ebf8" href="offres-enseignants.html">Voir les offres</a></div></section>
</main>"""
EC_JS = r"""<script src="abidjan-locations.js"></script><script src="preparations.js"></script><script>
const db = supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
setupAbidjanLocation('eCommune', 'eQuartier'); fillPreparations(ePrep, 'Aucune');
ecForm.onsubmit = async e => {
  e.preventDefault(); eMsg.className = 'ec-msg'; eMsg.textContent = '';
  const subj = Array.from(eSubjects.querySelectorAll('input:checked')).map(x => x.value).concat(eOther.value.trim() ? [eOther.value.trim()] : []);
  if (!subj.length) { eMsg.className = 'ec-msg err'; eMsg.textContent = 'Choisissez au moins une matière.'; return; }
  const loc = getAbidjanLocation('eCommune', 'eQuartier');
  eBtn.disabled = true; eBtn.textContent = 'Envoi…';
  const r = await db.rpc('submit_school_request', { p_school: eSchool.value, p_type: eType.value, p_contact: eContact.value, p_phone: ePhone.value, p_email: eEmail.value,
    p_commune: loc.commune, p_quartier: loc.quartier, p_subjects: subj.join(', '), p_levels: eLevels.value, p_preparation: ePrep.value, p_contract: eContract.value,
    p_hours: eHours.value, p_salary: eSalary.value, p_start: eStart.value || null, p_requirements: eReq.value, p_details: eDetails.value });
  if (r.error) { eMsg.className = 'ec-msg err'; eMsg.textContent = r.error.message; eBtn.disabled = false; eBtn.textContent = 'Envoyer ma demande'; return; }
  ecFields.hidden = true; ecOk.classList.add('show'); ecForm.scrollIntoView({ behavior: 'smooth' });
};
</script>"""
page('ecoles.html', 'Écoles : recrutez un enseignant qualifié à Abidjan | KONE.EDUC',
     'Écoles, lycées, universités et centres de formation : décrivez le poste, KONE.EDUC vous met en relation avec un enseignant vérifié. Gratuit pour les écoles.',
     EC_CSS, EC_MAIN, SUPA + EC_JS)

# ---------------------------------------------------------------- offres-enseignants.html (offres publiques)
OF_CSS = DV_CSS + r"""
.of-bar{display:flex;flex-wrap:wrap;gap:8px;margin:0 0 14px}.of-bar button,.of-bar select{padding:10px 14px;border:1px solid #e3ebf8;border-radius:99px;background:#fff;font:700 14px "DM Sans",sans-serif;color:#102149;cursor:pointer}
.of-bar button.on{background:#102149;color:#fff;border-color:#102149}
.of-list{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:14px}
.of-card{display:flex;flex-direction:column;gap:8px;padding:18px;border:1px solid #e3ebf8;border-radius:20px;background:#fff;box-shadow:0 10px 30px rgba(21,61,140,.06)}
.of-card h3{margin:0;font:800 17px/1.3 Manrope,sans-serif}.of-kind{align-self:flex-start;padding:4px 10px;border-radius:99px;font-size:12px;font-weight:800;background:#eaf1ff;color:#1559eb}.of-kind.ecole{background:#fff0dc;color:#9a5900}
.of-meta{display:flex;flex-wrap:wrap;gap:6px}.of-meta span{padding:5px 9px;border-radius:99px;background:#f4f7fc;font-size:13px;font-weight:700}
.of-acts{display:flex;flex-wrap:wrap;gap:8px;margin-top:auto;padding-top:6px}.of-acts a{flex:1;text-align:center;padding:10px;border-radius:12px;font-weight:800;text-decoration:none;font-size:14px}
.of-acts .go{background:#1559eb;color:#fff}.of-acts .wa{background:#1fa855;color:#fff}.of-acts .fb{background:#f4f7fc;color:#102149}
.of-empty{padding:30px;border:1px dashed #cbd7ee;border-radius:18px;text-align:center;color:#5b6884;background:#fff}
"""
OF_MAIN = """<main class="dv">
<section class="dv-hero"><div><h1>Offres pour enseignants à Abidjan</h1><p>Cours à domicile demandés par des familles et postes proposés par des écoles : préparation au CEPE, BEPC, BAC et aux concours ENSEA et INPHB. Mis à jour en temps réel.</p>
<div class="tags"><span>Familles vérifiées</span><span>Écoles partenaires</span><span>Partagez une offre en 1 clic</span></div><a class="dv-btn" href="candidature-enseignant.html">Postuler comme enseignant →</a></div>
<div class="dv-phone" aria-hidden="true"><div class="n"><span style="font-size:28px">📚</span><div><b>Mathématiques · Terminale</b><small>Préparation ENSEA – ISE Maths · Cocody</small></div></div><div class="n"><span style="font-size:28px">🏫</span><div><b>Collège / Lycée · Bingerville</b><small>Physique-Chimie · Vacation</small></div></div></div></section>
<h2>Offres en cours</h2>
<div class="of-bar" id="bar"></div><div id="list"><div class="of-empty">Chargement des offres…</div></div>
<section class="dv-final"><h2 style="margin-top:0">Une école ? Une famille ?</h2><p>Déposez votre demande, nous trouvons l’enseignant qualifié.</p><div class="row"><a class="dv-btn" href="reservation.html">Famille : réserver un enseignant</a><a class="dv-btn light" style="border:1px solid #e3ebf8" href="ecoles.html">École : recruter un enseignant</a></div></section>
</main>"""
OF_JS = r"""<script>
const db = supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
const esc = v => String(v == null ? '' : v).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
let offres = [], f = { kind: '', prep: '', commune: '' };
const lien = o => location.origin + location.pathname + '#' + o.kind + '-' + o.id;
function partage(o) { return o.title + (o.preparation ? ' · Préparation ' + o.preparation : '') + ' · ' + o.commune + '. Offre KONE.EDUC : ' + lien(o); }
function render() {
  const uniq = k => [...new Set(offres.map(o => o[k]).filter(Boolean))].sort((a, b) => a.localeCompare(b, 'fr'));
  bar.innerHTML = [['', 'Toutes (' + offres.length + ')'], ['cours', '🏠 Cours à domicile'], ['ecole', '🏫 Écoles']].map(x => '<button type="button" class="' + (f.kind === x[0] ? 'on' : '') + '" onclick="f.kind=\'' + x[0] + '\';render()">' + x[1] + '</button>').join('')
    + '<select aria-label="Préparation" onchange="f.prep=this.value;render()"><option value="">🎯 Toutes les préparations</option>' + uniq('preparation').map(p => '<option' + (f.prep === p ? ' selected' : '') + '>' + esc(p) + '</option>').join('') + '</select>'
    + '<select aria-label="Commune" onchange="f.commune=this.value;render()"><option value="">📍 Toutes les communes</option>' + uniq('commune').map(p => '<option' + (f.commune === p ? ' selected' : '') + '>' + esc(p) + '</option>').join('') + '</select>';
  const l = offres.filter(o => (!f.kind || o.kind === f.kind) && (!f.prep || o.preparation === f.prep) && (!f.commune || o.commune === f.commune));
  list.innerHTML = l.length ? '<div class="of-list">' + l.map(o => '<article class="of-card" id="' + o.kind + '-' + o.id + '"><span class="of-kind ' + o.kind + '">' + (o.kind === 'ecole' ? '🏫 École' : '🏠 Cours à domicile') + '</span><h3>' + esc(o.title) + '</h3><div class="of-meta"><span>📍 ' + esc(o.commune) + '</span>' + (o.preparation ? '<span>🎯 ' + esc(o.preparation) + '</span>' : '') + (o.levels && o.kind === 'ecole' ? '<span>🎓 ' + esc(o.levels) + '</span>' : '') + (o.format ? '<span>' + esc(o.format) + '</span>' : '') + (o.contract ? '<span>📄 ' + esc(o.contract) + '</span>' : '') + (o.salary ? '<span>💰 ' + esc(o.salary) + '</span>' : '') + '</div><small style="color:#5b6884">Publiée le ' + new Date(o.created_at).toLocaleDateString('fr-FR') + '</small>'
    + '<div class="of-acts"><a class="go" href="' + (o.kind === 'ecole' ? 'offres.html#ecoles' : 'offres.html') + '">Postuler</a><a class="wa" target="_blank" rel="noopener" href="https://wa.me/?text=' + encodeURIComponent(partage(o)) + '">Partager</a><a class="fb" target="_blank" rel="noopener" href="https://www.facebook.com/sharer/sharer.php?u=' + encodeURIComponent(lien(o)) + '">Facebook</a></div></article>').join('') + '</div>'
    : '<div class="of-empty"><b style="display:block;color:#102149;font-size:17px">Aucune offre ouverte pour ces critères</b>Inscrivez-vous comme enseignant : vous serez prévenu(e) dès qu’une nouvelle offre arrive.</div>';
}
// Offres d'emploi lisibles par Google (Google pour l'emploi)
function jsonld() {
  const s = document.createElement('script'); s.type = 'application/ld+json';
  s.textContent = JSON.stringify({ '@context': 'https://schema.org', '@graph': offres.map(o => ({ '@type': 'JobPosting', title: o.title, description: o.title + (o.preparation ? '. Préparation ' + o.preparation : '') + (o.levels ? '. Niveaux : ' + o.levels : '') + '. Offre transmise par KONE.EDUC.',
    datePosted: String(o.created_at).slice(0, 10), validThrough: new Date(new Date(o.created_at).getTime() + 60 * 864e5).toISOString().slice(0, 10), employmentType: o.kind === 'ecole' ? (o.contract === 'Temps plein' ? 'FULL_TIME' : 'PART_TIME') : 'CONTRACTOR',
    hiringOrganization: { '@type': 'Organization', name: 'KONE.EDUC', sameAs: location.origin, logo: location.origin + '/assets/icons/icon-512.png' },
    jobLocation: { '@type': 'Place', address: { '@type': 'PostalAddress', addressLocality: o.commune || 'Abidjan', addressRegion: 'Abidjan', addressCountry: 'CI' } },
    url: lien(o), identifier: { '@type': 'PropertyValue', name: 'KONE.EDUC', value: o.kind + '-' + o.id } })) });
  document.head.appendChild(s);
}
db.rpc('public_offers').then(r => { offres = r.data || []; render(); if (offres.length) jsonld(); const h = location.hash && document.querySelector(location.hash); if (h) h.scrollIntoView(); });
</script>"""
page('offres-enseignants.html', 'Offres pour enseignants : cours à domicile et écoles à Abidjan | KONE.EDUC',
     'Offres de cours à domicile et postes en écoles à Abidjan : préparation CEPE, BEPC, BAC, concours ENSEA (AS, ISE) et INPHB (A2GP, classes préparatoires, ITA). Postulez avec KONE.EDUC.',
     OF_CSS, OF_MAIN, SUPA + OF_JS)
