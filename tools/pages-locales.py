#!/usr/bin/env python3
"""Génère les pages locales (communes d'Abidjan et matières) pour le référencement Google.

Lancement depuis la racine du projet :  python3 tools/pages-locales.py
Les pages reprennent l'en-tête et le pied de page de enseignants.html.
Modifier les textes ici, puis relancer le script (les pages sont réécrites).
"""
import html
import json
import re
from urllib.parse import quote
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SITE = 'https://kone-educ.vercel.app'


def slug(s):
    s = s.lower()
    for a, b in (('é', 'e'), ('è', 'e'), ('ê', 'e'), ('ë', 'e'), ('à', 'a'), ('â', 'a'), ('î', 'i'), ('ï', 'i'), ('ô', 'o'), ('û', 'u'), ('ù', 'u'), ('ç', 'c'), ('’', '-'), ("'", '-')):
        s = s.replace(a, b)
    return re.sub(r'[^a-z0-9]+', '-', s).strip('-')


# Communes et quartiers : même liste que le formulaire de réservation (abidjan-locations.js)
src = (ROOT / 'abidjan-locations.js').read_text(encoding='utf-8')
COMMUNES = {}
for name, quartiers in re.findall(r"'([^']+)':\[([^\]]*)\]", src):
    COMMUNES[name] = [q for q in re.findall(r"'([^']+)'", quartiers) if q != 'Autre quartier']

# Communes voisines (pour les liens entre pages)
VOISINES = {
    'Abobo': ['Anyama', 'Adjamé', 'Cocody', 'Yopougon'],
    'Adjamé': ['Plateau', 'Abobo', 'Attécoubé', 'Cocody'],
    'Anyama': ['Abobo', 'Yopougon', 'Cocody'],
    'Attécoubé': ['Adjamé', 'Plateau', 'Yopougon'],
    'Bingerville': ['Cocody', 'Abobo'],
    'Cocody': ['Bingerville', 'Plateau', 'Adjamé', 'Abobo'],
    'Koumassi': ['Marcory', 'Port-Bouët', 'Treichville'],
    'Marcory': ['Koumassi', 'Treichville', 'Port-Bouët'],
    'Plateau': ['Cocody', 'Adjamé', 'Treichville', 'Attécoubé'],
    'Port-Bouët': ['Koumassi', 'Marcory', 'Treichville'],
    'Songon': ['Yopougon', 'Attécoubé'],
    'Treichville': ['Marcory', 'Plateau', 'Koumassi'],
    'Yopougon': ['Attécoubé', 'Songon', 'Abobo', 'Adjamé'],
}

MATIERES = {
    'Mathématiques': {
        'slug': 'cours-de-mathematiques-a-domicile-abidjan',
        'accroche': 'Reprendre les bases, gagner en méthode et aborder sereinement les examens.',
        'niveaux': [
            ('Primaire', 'Numération, opérations, calcul mental, fractions simples, mesures et résolution de problèmes ; préparation au CEPE.'),
            ('Collège', 'Calcul littéral, équations, fractions et puissances, théorèmes de Pythagore et de Thalès, statistiques ; préparation au BEPC.'),
            ('Lycée', 'Fonctions, dérivées, suites, probabilités, géométrie dans l’espace, nombres complexes ; préparation au BAC séries A, C et D.'),
        ],
        'methode': 'L’enseignant repart des notions mal comprises, fait beaucoup d’exercices progressifs et apprend à rédiger une solution complète, comme le demandent les correcteurs.',
    },
    'Français': {
        'slug': 'cours-de-francais-a-domicile-abidjan',
        'accroche': 'Lire, écrire et s’exprimer avec aisance, de l’orthographe à la dissertation.',
        'niveaux': [
            ('Primaire', 'Lecture et compréhension, orthographe, grammaire, conjugaison, vocabulaire et premières rédactions.'),
            ('Collège', 'Étude de texte, expression écrite, grammaire et conjugaison approfondies ; préparation à l’épreuve de français du BEPC.'),
            ('Lycée', 'Résumé, commentaire composé, dissertation, méthodologie de l’argumentation ; préparation au BAC.'),
        ],
        'methode': 'Des textes adaptés au niveau, des exercices courts et réguliers, et des rédactions corrigées en détail pour progresser à chaque séance.',
    },
    'Anglais': {
        'slug': 'cours-d-anglais-a-domicile-abidjan',
        'accroche': 'Comprendre, parler et écrire l’anglais avec confiance.',
        'niveaux': [
            ('Primaire', 'Vocabulaire du quotidien, premières phrases, comptines et jeux pour prendre goût à la langue.'),
            ('Collège', 'Grammaire et temps verbaux, compréhension de textes, expression écrite ; préparation à l’épreuve d’anglais du BEPC.'),
            ('Lycée', 'Compréhension de documents, essay, enrichissement du vocabulaire, aisance à l’oral ; préparation au BAC.'),
        ],
        'methode': 'L’élève pratique à l’oral à chaque séance et révise grammaire et vocabulaire avec des exercices ciblés sur ses points faibles.',
    },
    'Physique-Chimie': {
        'slug': 'cours-de-physique-chimie-a-domicile-abidjan',
        'accroche': 'Comprendre les phénomènes et réussir les exercices, de la 4e à la Terminale.',
        'niveaux': [
            ('Collège', 'Électricité, mécanique, optique, matière et transformations chimiques ; préparation au BEPC.'),
            ('Lycée', 'Mécanique, électricité, ondes, chimie organique, solutions et dosages ; préparation au BAC séries C et D.'),
        ],
        'methode': 'Le cours est relié à des exemples concrets, puis l’élève apprend une méthode de résolution claire : données, lois utilisées, calcul, unité et vérification.',
    },
    'SVT': {
        'slug': 'cours-de-svt-a-domicile-abidjan',
        'accroche': 'Maîtriser le cours, les schémas et la méthodologie des épreuves de SVT.',
        'niveaux': [
            ('Collège', 'Corps humain, reproduction, environnement et géologie ; préparation à l’épreuve de SVT du BEPC.'),
            ('Lycée', 'Génétique, immunologie, physiologie, géologie ; exploitation de documents et préparation au BAC série D.'),
        ],
        'methode': 'Fiches de synthèse, schémas annotés et entraînement à l’analyse de documents, l’exercice le plus fréquent aux examens.',
    },
}

base = (ROOT / 'enseignants.html').read_text(encoding='utf-8')
HEAD = base[:base.index('<style>')]
BODY_START = base[base.index('<body'):base.index('<main')].replace(' aria-current="page"', '')
FOOTER = base[base.index('<footer'):base.index('<script src="supabase-config.js">')]

CSS = """
:root{--blue:#1559eb;--orange:#fa7518;--ink:#101a35;--muted:#596580;--line:#dbe5f5;--pale:#f5f9ff;--ok:#11743a}
*{box-sizing:border-box}body{margin:0;color:var(--ink);font-family:"DM Sans",sans-serif;background:#fff}a{color:inherit;text-decoration:none}
.shell{width:min(1120px,calc(100% - 48px));margin:auto}
.l-hero{padding:64px 0 54px;background:linear-gradient(120deg,#eef4ff,#fff 60%,#fff3e8)}
.l-crumb{margin:0 0 16px;font-size:13.5px;color:var(--muted)}.l-crumb a{color:var(--blue);font-weight:700}
.l-kicker{display:inline-block;margin:0 0 14px;padding:6px 12px;border-radius:99px;background:#eaf1ff;color:var(--blue);font-size:13px;font-weight:800}
.l-hero h1{max-width:820px;margin:0;font:800 clamp(32px,4.6vw,54px)/1.08 Manrope,sans-serif;letter-spacing:-2px}
.l-hero h1 em{font-style:normal;color:var(--orange)}
.l-lead{max-width:680px;margin:18px 0 0;color:var(--muted);font-size:18px;line-height:1.65}
.l-cta{display:flex;flex-wrap:wrap;gap:10px;margin-top:26px}
.l-btn{display:inline-flex;align-items:center;gap:8px;padding:14px 20px;border-radius:12px;background:var(--orange);color:#fff;font-weight:800;box-shadow:0 10px 22px rgba(250,117,24,.25)}
.l-btn.ghost{background:#fff;color:var(--ink);border:1px solid var(--line);box-shadow:none}
.l-trust{display:flex;flex-wrap:wrap;gap:8px 18px;margin:22px 0 0;padding:0;list-style:none;color:#2c3a5c;font-size:14.5px;font-weight:700}
.l-sec{padding:58px 0;border-top:1px solid #eef2f8}.l-sec.pale{background:var(--pale)}
.l-sec h2{margin:0 0 10px;font:800 clamp(24px,3vw,34px)/1.2 Manrope,sans-serif;letter-spacing:-1px}
.l-sec>.shell>p{max-width:760px;color:var(--muted);line-height:1.7}
.chips{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}.chips span,.chips a{padding:8px 13px;border:1px solid var(--line);border-radius:99px;background:#fff;font-size:14px;font-weight:700;color:#2c3a5c}.chips a:hover{border-color:var(--blue);color:var(--blue)}
.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:20px}
.card{padding:22px;border:1px solid var(--line);border-radius:16px;background:#fff}
.card h3{margin:0 0 8px;font:800 18px Manrope,sans-serif}.card p{margin:0;color:var(--muted);line-height:1.6;font-size:15px}
.card .n{display:grid;place-items:center;width:34px;height:34px;margin-bottom:12px;border-radius:50%;background:var(--blue);color:#fff;font-weight:800}
.teachers{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:18px}
.t{display:flex;gap:12px;align-items:center;padding:14px;border:1px solid var(--line);border-radius:14px;background:#fff}
.t .av{flex:none;display:grid;place-items:center;width:52px;height:52px;border-radius:14px;overflow:hidden;background:var(--blue);color:#fff;font:800 20px Manrope,sans-serif}.t .av img{width:100%;height:100%;object-fit:cover}
.t b{display:block}.t small{display:block;color:var(--muted);font-size:13px}
.t-empty{margin-top:14px;padding:18px;border:1px dashed var(--line);border-radius:14px;color:var(--muted)}
.faq details{margin-top:10px;padding:16px 18px;border:1px solid var(--line);border-radius:14px;background:#fff}
.faq summary{cursor:pointer;font-weight:800}.faq p{margin:10px 0 0;color:var(--muted);line-height:1.65}
.l-final{padding:60px 0;text-align:center;color:#fff;background:var(--blue)}
.l-final h2{margin:0;font:800 clamp(26px,3.4vw,40px)/1.15 Manrope,sans-serif;letter-spacing:-1.4px}.l-final p{margin:12px auto 22px;max-width:560px;color:#dce8ff}
.l-final .l-btn{background:#fff;color:var(--blue);box-shadow:none}
@media(max-width:900px){.cards,.teachers{grid-template-columns:1fr 1fr}}
@media(max-width:600px){.shell{width:calc(100% - 32px)}.l-hero{padding:44px 0 40px}.cards,.teachers{grid-template-columns:1fr}.l-sec{padding:44px 0}}
"""

STEPS = ('<div class="cards">'
         '<div class="card"><span class="n">1</span><h3>Vous décrivez le besoin</h3><p>Niveau, matière, jours disponibles et quartier : la demande prend deux minutes, depuis votre téléphone.</p></div>'
         '<div class="card"><span class="n">2</span><h3>Nous choisissons l’enseignant</h3><p>Un enseignant vérifié (identité, diplôme, entretien) et disponible près de chez vous. Vous pouvez aussi demander un enseignant précis.</p></div>'
         '<div class="card"><span class="n">3</span><h3>Les cours commencent</h3><p>Planning des séances, compte rendu après chaque cours et bilan de progression chaque mois dans votre espace parent.</p></div>'
         '</div>')


def faq_block(items):
    return '<div class="faq">' + ''.join('<details><summary>' + html.escape(q) + '</summary><p>' + a + '</p></details>' for q, a in items) + '</div>'


def faq_jsonld(items):
    return {'@type': 'FAQPage', 'mainEntity': [{'@type': 'Question', 'name': q, 'acceptedAnswer': {'@type': 'Answer', 'text': re.sub('<[^>]+>', '', a)}} for q, a in items]}


TEACHERS_JS = """<script src="supabase-config.js"></script><script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script><script>
// Enseignants validés correspondant à la page (fonction publique, sans données sensibles)
(async function () {
  var box = document.getElementById('teachers'); if (!box) return;
  var esc = function (v) { return String(v == null ? '' : v).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); };
  var norm = function (v) { return String(v || '').normalize('NFD').replace(/[\\u0300-\\u036f]/g, '').toLowerCase(); };
  try {
    var r = await supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey).rpc('public_teachers');
    var f = box.dataset.filter, v = norm(box.dataset.value);
    var list = (r.data || []).filter(function (t) { return norm(f === 'subject' ? t.subject : t.location).indexOf(v) >= 0; }).slice(0, 6);
    if (!list.length) return;
    box.innerHTML = '<div class="teachers">' + list.map(function (t) {
      return '<a class="t" href="enseignant.html?id=' + encodeURIComponent(t.id) + '"><span class="av">' + (t.photo_url ? '<img src="' + esc(t.photo_url) + '" alt="" loading="lazy">' : esc((t.display_name || '?').charAt(0))) + '</span><span><b>' + esc(t.display_name) + '</b><small>' + esc(t.subject) + (t.location ? ' · ' + esc(t.location) : '') + '</small>' + (t.reviews_count > 0 ? '<small>⭐ ' + Number(t.rating).toLocaleString('fr-FR') + '/5 · ' + t.reviews_count + ' avis</small>' : '') + '</span></a>';
    }).join('') + '</div>';
  } catch (e) {}
})();
</script>"""


def page(fname, title, desc, h1, crumbs, body, jsonld):
    head = HEAD
    head = re.sub(r'<title>[^<]*</title>', '<title>' + html.escape(title) + '</title>', head)
    head = re.sub(r'<meta name="description" content="[^"]*">', '<meta name="description" content="' + html.escape(desc) + '">', head)
    head = re.sub(r'<link rel="canonical" href="[^"]*">', '<link rel="canonical" href="' + SITE + '/' + fname + '">', head)
    head = re.sub(r'<meta property="og:url" content="[^"]*">', '<meta property="og:url" content="' + SITE + '/' + fname + '">', head)
    head = re.sub(r'<meta property="og:title" content="[^"]*">', '<meta property="og:title" content="' + html.escape(title) + '">', head)
    head = re.sub(r'<meta property="og:description" content="[^"]*">', '<meta property="og:description" content="' + html.escape(desc) + '">', head)
    head = head.replace('DM+Sans:wght@400;500;600;700', 'DM+Sans:wght@400;500;600;700;800')
    bc = {'@type': 'BreadcrumbList', 'itemListElement': [{'@type': 'ListItem', 'position': i + 1, 'name': n, 'item': SITE + '/' + u} for i, (n, u) in enumerate(crumbs)]}
    ld = {'@context': 'https://schema.org', '@graph': [bc] + jsonld}
    crumb_html = '<p class="l-crumb">' + ' › '.join('<a href="' + u + '">' + html.escape(n) + '</a>' for n, u in crumbs[:-1]) + ' › ' + html.escape(crumbs[-1][0]) + '</p>'
    out = (head + '<style>' + CSS + '</style><script type="application/ld+json">' + json.dumps(ld, ensure_ascii=False) + '</script></head>'
           + BODY_START + '<main>' + body.replace('{CRUMB}', crumb_html) + '</main>' + FOOTER + TEACHERS_JS + '<script src="site.js"></script></body></html>\n')
    (ROOT / fname).write_text(out, encoding='utf-8')
    return fname


def service(name, area):
    return {'@type': 'Service', 'name': name, 'serviceType': 'Cours particuliers à domicile',
            'provider': {'@type': 'EducationalOrganization', 'name': 'KONE.EDUC', 'url': SITE + '/'},
            'areaServed': area}


generated = []
commune_slug = {c: 'cours-particuliers-a-domicile-' + slug(c) + '.html' for c in COMMUNES}
matiere_file = {m: d['slug'] + '.html' for m, d in MATIERES.items()}
HUB = 'cours-particuliers-abidjan.html'

# ---------- Pages par commune ----------
for c, quartiers in COMMUNES.items():
    q_txt = ', '.join(quartiers[:-1]) + ' et ' + quartiers[-1] if len(quartiers) > 1 else quartiers[0]
    voisines = [v for v in VOISINES.get(c, []) if v in COMMUNES]
    faq = [
        ('Dans quels quartiers de ' + c + ' intervenez-vous ?', 'Nos enseignants se déplacent dans toute la commune de ' + c + ', notamment à ' + html.escape(q_txt) + '. Si votre quartier n’est pas cité, indiquez-le dans votre demande.'),
        ('Quelles matières et quels niveaux ?', 'Mathématiques, français, anglais, physique-chimie, SVT et d’autres matières sur demande, du primaire à l’université, avec une préparation spécifique au CEPE, au BEPC et au BAC.'),
        ('Comment l’enseignant est-il choisi ?', 'Chaque enseignant est vérifié par notre équipe : pièce d’identité, diplôme et entretien pédagogique. Nous choisissons celui qui correspond au niveau, à la matière et aux disponibilités de votre enfant, près de chez vous.'),
        ('Combien coûtent les cours ?', 'Le tarif dépend du niveau, de la matière et du nombre d’heures par semaine. Nous vous l’indiquons lors de notre prise de contact, avant tout engagement.'),
        ('Comment suivre les progrès de mon enfant ?', 'Après chaque séance, l’enseignant envoie un compte rendu dans votre espace parent : notions travaillées, devoirs, compréhension. Vous recevez aussi un bilan de progression chaque mois.'),
        ('Les cours peuvent-ils avoir lieu en ligne ?', 'Oui. Selon vos préférences, les cours se déroulent à domicile à ' + c + ' ou en ligne, avec le même suivi.'),
    ]
    body = ('<section class="l-hero"><div class="shell">{CRUMB}<span class="l-kicker">📍 ' + html.escape(c) + ', Abidjan</span>'
            '<h1>Cours particuliers à domicile à <em>' + html.escape(c) + '</em></h1>'
            '<p class="l-lead">Des enseignants vérifiés se déplacent chez vous à ' + html.escape(c) + ' (' + html.escape(', '.join(quartiers[:4])) + '…) pour accompagner votre enfant, du primaire au BAC. Après chaque séance, vous recevez un compte rendu.</p>'
            '<div class="l-cta"><a class="l-btn" href="reservation.html?commune=' + quote(c) + '">Réserver un enseignant à ' + html.escape(c) + '</a><a class="l-btn ghost" href="https://wa.me/2250161701361?text=' + quote('Bonjour KONE.EDUC, je cherche un enseignant à domicile à ' + c + '.') + '">💬 WhatsApp</a></div>'
            '<ul class="l-trust"><li>✓ Enseignants vérifiés</li><li>📝 Compte rendu après chaque séance</li><li>📊 Bilan mensuel</li><li>📱 Wave, Orange, MTN, Moov</li></ul></div></section>'
            '<section class="l-sec"><div class="shell"><h2>Les quartiers de ' + html.escape(c) + ' où nous intervenons</h2><p>Nos enseignants viennent à domicile dans l’ensemble de la commune. Indiquez simplement votre quartier lors de la réservation.</p>'
            '<div class="chips">' + ''.join('<span>' + html.escape(q) + '</span>' for q in quartiers) + '</div></div></section>'
            '<section class="l-sec pale"><div class="shell"><h2>Toutes les matières, du primaire au BAC</h2><p>Soutien scolaire régulier, remise à niveau ou préparation aux examens (CEPE, BEPC, BAC) : l’accompagnement s’adapte au besoin de chaque élève de ' + html.escape(c) + '.</p>'
            '<div class="chips">' + ''.join('<a href="' + matiere_file[m] + '">' + html.escape(m) + '</a>' for m in MATIERES) + '<a href="conseils-reussir-le-bepc.html">Préparer le BEPC</a><a href="conseils-preparer-le-bac.html">Préparer le BAC</a><a href="conseils-preparer-le-cepe.html">Préparer le CEPE</a></div></div></section>'
            '<section class="l-sec"><div class="shell"><h2>Nos enseignants à ' + html.escape(c) + '</h2><p>Quelques enseignants validés qui interviennent dans la commune. Cliquez sur un profil pour voir son parcours et les avis des parents.</p>'
            '<div id="teachers" data-filter="location" data-value="' + html.escape(c) + '"><div class="t-empty">Notre réseau d’enseignants couvre ' + html.escape(c) + ' : décrivez votre besoin et nous vous proposons l’enseignant le plus adapté.</div></div></div></section>'
            '<section class="l-sec pale"><div class="shell"><h2>Comment ça marche ?</h2>' + STEPS + '</div></section>'
            '<section class="l-sec"><div class="shell"><h2>Questions fréquentes</h2>' + faq_block(faq) + '</div></section>'
            + ('<section class="l-sec pale"><div class="shell"><h2>Communes voisines</h2><div class="chips">' + ''.join('<a href="' + commune_slug[v] + '">Cours à domicile à ' + html.escape(v) + '</a>' for v in voisines) + '<a href="' + HUB + '">Toutes les communes</a></div></div></section>' if voisines else '')
            + '<section class="l-final"><div class="shell"><h2>Trouvez un enseignant à ' + html.escape(c) + '</h2><p>Deux minutes pour décrire le besoin de votre enfant. Notre équipe vous recontacte rapidement.</p><a class="l-btn" href="reservation.html?commune=' + quote(c) + '">Réserver un cours</a></div></section>')
    generated.append(page(commune_slug[c],
                          'Cours particuliers à domicile à ' + c + ' | KONE.EDUC',
                          'Cours particuliers et soutien scolaire à domicile à ' + c + ' (Abidjan) : enseignants vérifiés, du primaire au BAC, compte rendu après chaque séance.',
                          '', [('Accueil', 'index.html'), ('Cours à Abidjan', HUB), (c, commune_slug[c])], body,
                          [service('Cours particuliers à domicile à ' + c, {'@type': 'AdministrativeArea', 'name': c + ', Abidjan'}), faq_jsonld(faq)]))

# ---------- Pages par matière ----------
for m, d in MATIERES.items():
    faq = [
        ('À partir de quel niveau ?', 'Nous accompagnons les élèves en ' + m.lower() + ' ' + ('du primaire au lycée' if any(n == 'Primaire' for n, _ in d['niveaux']) else 'du collège au lycée') + ', avec une préparation ciblée aux examens.'),
        ('Les cours ont-ils lieu à domicile ?', 'Oui, partout à Abidjan (Cocody, Yopougon, Abobo, Marcory…) et en ligne si vous préférez.'),
        ('Comment est choisi l’enseignant de ' + m.lower() + ' ?', 'Nous sélectionnons un enseignant vérifié, spécialiste de la matière, selon le niveau de l’élève et vos disponibilités. Vous pouvez aussi choisir un enseignant précis sur sa fiche.'),
        ('Combien coûtent les cours ?', 'Le tarif dépend du niveau et du nombre d’heures par semaine. Nous vous l’indiquons lors de notre prise de contact, avant tout engagement.'),
        ('Comment voir les progrès ?', 'Un compte rendu après chaque séance (notions, devoirs, compréhension) et un bilan de progression chaque mois, dans votre espace parent.'),
    ]
    body = ('<section class="l-hero"><div class="shell">{CRUMB}<span class="l-kicker">📘 ' + html.escape(m) + '</span>'
            '<h1>Cours de ' + html.escape(m.lower() if m != 'SVT' else 'SVT') + ' à domicile à <em>Abidjan</em></h1>'
            '<p class="l-lead">' + html.escape(d['accroche']) + ' Des enseignants vérifiés se déplacent chez vous ou donnent cours en ligne, avec un compte rendu après chaque séance.</p>'
            '<div class="l-cta"><a class="l-btn" href="reservation.html?matiere=' + quote(m) + '">Réserver un cours de ' + html.escape(m.lower() if m != 'SVT' else 'SVT') + '</a><a class="l-btn ghost" href="enseignants.html?matiere=' + quote(m) + '">Voir nos enseignants</a></div>'
            '<ul class="l-trust"><li>✓ Enseignants spécialistes vérifiés</li><li>📝 Compte rendu après chaque séance</li><li>🎯 Préparation aux examens</li></ul></div></section>'
            '<section class="l-sec"><div class="shell"><h2>Ce que nous travaillons, niveau par niveau</h2><div class="cards">'
            + ''.join('<div class="card"><h3>' + html.escape(n) + '</h3><p>' + html.escape(t) + '</p></div>' for n, t in d['niveaux']) + '</div></div></section>'
            '<section class="l-sec pale"><div class="shell"><h2>Notre méthode</h2><p>' + html.escape(d['methode']) + ' L’enseignant note après chaque séance les notions travaillées et le niveau de compréhension : vous voyez la progression mois après mois.</p></div></section>'
            '<section class="l-sec"><div class="shell"><h2>Nos enseignants de ' + html.escape(m.lower() if m != 'SVT' else 'SVT') + '</h2><p>Quelques enseignants validés dans cette matière. Cliquez sur un profil pour voir son parcours et les avis des parents.</p>'
            '<div id="teachers" data-filter="subject" data-value="' + html.escape(m) + '"><div class="t-empty">Décrivez le besoin de votre enfant : nous vous proposons l’enseignant de ' + html.escape(m.lower() if m != 'SVT' else 'SVT') + ' le plus adapté, près de chez vous.</div></div></div></section>'
            '<section class="l-sec pale"><div class="shell"><h2>Partout à Abidjan</h2><div class="chips">' + ''.join('<a href="' + commune_slug[c] + '">' + html.escape(c) + '</a>' for c in COMMUNES) + '</div></div></section>'
            '<section class="l-sec"><div class="shell"><h2>Comment ça marche ?</h2>' + STEPS + '</div></section>'
            '<section class="l-sec pale"><div class="shell"><h2>Questions fréquentes</h2>' + faq_block(faq) + '<div class="chips" style="margin-top:22px">' + ''.join('<a href="' + matiere_file[o] + '">Cours de ' + html.escape(o.lower() if o != 'SVT' else 'SVT') + '</a>' for o in MATIERES if o != m) + '</div></div></section>'
            '<section class="l-final"><div class="shell"><h2>Un enseignant de ' + html.escape(m.lower() if m != 'SVT' else 'SVT') + ' pour votre enfant</h2><p>Deux minutes pour décrire le besoin. Notre équipe vous recontacte rapidement.</p><a class="l-btn" href="reservation.html?matiere=' + quote(m) + '">Réserver un cours</a></div></section>')
    generated.append(page(matiere_file[m],
                          'Cours de ' + (m.lower() if m != 'SVT' else 'SVT') + ' à domicile à Abidjan | KONE.EDUC',
                          'Cours particuliers de ' + (m.lower() if m != 'SVT' else 'SVT') + ' à domicile à Abidjan : enseignants vérifiés, du ' + ('primaire' if any(n == 'Primaire' for n, _ in d['niveaux']) else 'collège') + ' au BAC, compte rendu après chaque séance.',
                          '', [('Accueil', 'index.html'), ('Cours à Abidjan', HUB), (m, matiere_file[m])], body,
                          [service('Cours de ' + m + ' à domicile', {'@type': 'City', 'name': 'Abidjan'}), faq_jsonld(faq)]))

# ---------- Page d'ensemble ----------
body = ('<section class="l-hero"><div class="shell">{CRUMB}<span class="l-kicker">📍 Abidjan et toute la Côte d’Ivoire</span>'
        '<h1>Cours particuliers à domicile à <em>Abidjan</em></h1>'
        '<p class="l-lead">Choisissez votre commune ou la matière recherchée. Partout à Abidjan, des enseignants vérifiés accompagnent votre enfant à domicile ou en ligne, avec un compte rendu après chaque séance et un bilan chaque mois.</p>'
        '<div class="l-cta"><a class="l-btn" href="reservation.html">Réserver un cours</a><a class="l-btn ghost" href="enseignants.html">Voir nos enseignants</a></div></div></section>'
        '<section class="l-sec"><div class="shell"><h2>Par commune</h2><div class="chips">' + ''.join('<a href="' + commune_slug[c] + '">Cours à domicile à ' + html.escape(c) + '</a>' for c in COMMUNES) + '</div></div></section>'
        '<section class="l-sec pale"><div class="shell"><h2>Par matière</h2><div class="chips">' + ''.join('<a href="' + matiere_file[m] + '">Cours de ' + html.escape(m.lower() if m != 'SVT' else 'SVT') + '</a>' for m in MATIERES) + '</div></div></section>'
        '<section class="l-sec"><div class="shell"><h2>Préparer un examen</h2><div class="chips"><a href="conseils-preparer-le-cepe.html">CEPE</a><a href="conseils-reussir-le-bepc.html">BEPC</a><a href="conseils-preparer-le-bac.html">BAC</a></div></div></section>'
        '<section class="l-sec pale"><div class="shell"><h2>Comment ça marche ?</h2>' + STEPS + '</div></section>'
        '<section class="l-final"><div class="shell"><h2>Trouvez l’enseignant idéal pour votre enfant</h2><p>Deux minutes pour décrire le besoin. Notre équipe vous recontacte rapidement.</p><a class="l-btn" href="reservation.html">Réserver un cours</a></div></section>')
generated.append(page(HUB, 'Cours particuliers à domicile à Abidjan, par commune et par matière | KONE.EDUC',
                      'Cours particuliers à domicile dans toutes les communes d’Abidjan (Cocody, Yopougon, Abobo, Marcory…) et dans toutes les matières, du primaire au BAC.',
                      '', [('Accueil', 'index.html'), ('Cours à Abidjan', HUB)], body,
                      [service('Cours particuliers à domicile à Abidjan', {'@type': 'City', 'name': 'Abidjan'})]))

# ---------- Plan du site ----------
sm = (ROOT / 'sitemap.xml').read_text(encoding='utf-8')
added = 0
for f in generated:
    loc = SITE + '/' + f
    if loc not in sm:
        sm = sm.replace('</urlset>', '  <url><loc>' + loc + '</loc></url>\n</urlset>')
        added += 1
(ROOT / 'sitemap.xml').write_text(sm, encoding='utf-8')
print(len(generated), 'pages générées,', added, 'ajoutées au plan du site')
