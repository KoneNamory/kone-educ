#!/usr/bin/env python3
"""Règlement intérieur KONE.EDUC (page du site + PDF) et fiche d'accord parent–enseignant (PDF à signer).
Usage : python3 tools/documents-officiels.py   (puis le rendu PDF se fait avec Playwright, voir la fin du fichier)
Pour modifier un taux, un numéro ou une date limite, changez les constantes ci-dessous."""
import html, os, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'communication' / '8-Documents-officiels' / ('interne' if int(os.environ.get('KONE_TAUX', '0') or 0) > 0 else '')
OUT.mkdir(parents=True, exist_ok=True)

# Taux des frais de service : jamais écrit ici (dépôt public). Documents internes : KONE_TAUX=… python3 tools/documents-officiels.py
TAUX = int(os.environ.get('KONE_TAUX', '0') or 0)
PART_ENS = 100 - TAUX
INTERNE = TAUX > 0              # avec le taux : documents internes, rangés dans un dossier non publié
NUMERO = '01 61 70 13 61'       # numéro officiel de dépôt des mensualités
JOUR_LIMITE = 10                # mensualité à payer au plus tard le … de chaque mois
JOUR_VERSEMENT = 15             # versement aux enseignants au plus tard le … du mois
VERSION = 'Version du 25 novembre 2026'

# ------------------------------------------------------------------ Règlement intérieur (texte)
# Chaque section : (titre, [paragraphes]) ; un paragraphe commençant par « - » devient une puce.
REGLEMENT = [
  ('Article 1 – Objet et champ d’application', [
    'Le présent règlement intérieur fixe les règles que doivent respecter toutes les personnes qui utilisent les services de KONE.EDUC : les enseignants, les parents et familles, les élèves, les vendeurs de la boutique en ligne et les écoles partenaires.',
    'Toute inscription sur le site kone-educ.com, toute demande de cours, toute candidature et toute ouverture de boutique vaut acceptation du présent règlement.',
  ]),
  ('Article 2 – Définitions', [
    '- <b>KONE.EDUC</b> : la structure qui met en relation les familles et les enseignants, assure le suivi pédagogique, encaisse les mensualités et rémunère les enseignants.',
    '- <b>Parent</b> : le parent ou le tuteur légal qui demande des cours pour un élève, ou l’élève majeur qui les demande pour lui-même.',
    '- <b>Enseignant</b> : toute personne validée par KONE.EDUC pour donner des cours à domicile ou en ligne.',
    '- <b>Mensualité</b> : la somme mensuelle convenue pour les cours d’un élève, indiquée sur la fiche d’accord.',
    '- <b>Fiche d’accord</b> : le document signé par le parent, l’enseignant et KONE.EDUC, qui précise les cours, la mensualité et le numéro de paiement.',
  ]),
  ('Titre I – Règles applicables aux enseignants', []),
  ('Article 3 – Recrutement et vérification', [
    'L’enseignant fournit des informations exactes et des documents authentiques : pièce d’identité, dernier diplôme, CV et photo. Toute fausse information ou tout faux document entraîne la radiation immédiate.',
    'L’enseignant ne commence aucun cours avant d’avoir été validé par KONE.EDUC et d’avoir signé la fiche d’accord de la famille concernée.',
  ]),
  ('Article 4 – Ponctualité et assiduité', [
    '- L’enseignant respecte les jours, horaires et durées prévus sur la fiche d’accord.',
    '- Tout retard de plus de 15 minutes est signalé à la famille avant l’heure du cours.',
    '- Toute absence est signalée à la famille et à KONE.EDUC au moins 24 heures à l’avance, sauf cas de force majeure dûment justifié.',
    '- Chaque séance manquée par l’enseignant est rattrapée dans le mois, à une date convenue avec la famille. À défaut, elle est déduite de sa rémunération.',
    '- Trois absences non justifiées dans un même mois entraînent le remplacement de l’enseignant auprès de la famille.',
  ]),
  ('Article 5 – Comportement, tenue et sécurité de l’élève', [
    '- L’enseignant adopte une tenue correcte et un langage respectueux envers l’élève, la famille et l’équipe KONE.EDUC.',
    '- Il est strictement interdit de frapper, d’humilier, de menacer ou de punir physiquement un élève.',
    '- Tout comportement déplacé, propos ou geste à caractère sexuel, harcèlement ou demande d’argent à l’élève entraîne la radiation immédiate, sans préjudice des poursuites prévues par la loi.',
    '- L’enseignant ne consomme ni alcool, ni tabac, ni aucune drogue pendant les cours, et ne se présente jamais sous leur effet.',
    '- Les cours ont lieu au domicile de la famille ou en ligne, aux horaires prévus. Aucun déplacement de l’élève vers un autre lieu n’est permis sans l’accord écrit du parent.',
  ]),
  ('Article 6 – Qualité et suivi pédagogique', [
    '- L’enseignant prépare ses cours et adapte sa méthode au niveau et aux difficultés de l’élève.',
    '- Après chaque séance, il remplit le compte rendu sur la plateforme KONE.EDUC : notions travaillées, devoirs donnés, niveau de compréhension.',
    '- Il contribue au bilan mensuel de progression envoyé aux parents.',
    '- Il signale à KONE.EDUC toute difficulté importante : absences répétées de l’élève, manque de matériel, problème de comportement.',
  ]),
  ('Article 7 – Rémunération et frais de service', ([
    f'KONE.EDUC encaisse la mensualité payée par la famille. Elle retient <b>{TAUX} % de frais de service</b> (recherche des familles, vérification, suivi pédagogique, facturation, assistance) et verse <b>{PART_ENS} % de la mensualité à l’enseignant</b>.',
    f'Exemple : pour une mensualité de 40 000 FCFA, KONE.EDUC retient {40000 * TAUX // 100:,} FCFA et verse {40000 * PART_ENS // 100:,} FCFA à l’enseignant.'.replace(',', ' '),
  ] if INTERNE else [
    'KONE.EDUC encaisse la mensualité payée par la famille. Elle retient des frais de service (recherche des familles, vérification, suivi pédagogique, facturation, assistance) et verse le reste de la mensualité à l’enseignant. Le montant versé à l’enseignant est indiqué sur sa fiche d’accord.',
  ]) + [
    f'Le versement est effectué par mobile money au plus tard le {JOUR_VERSEMENT} du mois, pour le mois écoulé, dès réception de la mensualité de la famille. Le montant et la date de chaque versement sont visibles par l’enseignant dans son espace « Mes gains ».',
    '- Le premier mois est rémunéré au prorata des séances réellement effectuées.',
    '- Les séances non faites et non rattrapées ne sont pas rémunérées.',
    '- En cas de retard de paiement de la famille, KONE.EDUC fait les relances. L’enseignant ne réclame jamais lui-même d’argent à la famille.',
  ]),
  ('Article 8 – Interdiction de contourner KONE.EDUC', [
    '- Il est interdit à l’enseignant de recevoir un paiement directement de la famille, en espèces ou par mobile money.',
    '- Il est interdit de proposer à une famille présentée par KONE.EDUC de poursuivre les cours sans passer par KONE.EDUC, pendant la mission et dans les 12 mois qui suivent sa fin.',
    '- Tout manquement entraîne la radiation de l’enseignant et le paiement à KONE.EDUC d’une indemnité égale aux frais de service qu’elle aurait perçus sur la période concernée.',
  ]),
  ('Article 9 – Confidentialité', [
    'L’enseignant garde confidentielles les informations sur l’élève et sa famille : notes, difficultés, adresse, vie privée. Il ne publie aucune photo ni vidéo de l’élève ou du domicile sans l’accord écrit du parent.',
  ]),
  ('Article 10 – Fin de mission', [
    '- L’enseignant qui souhaite arrêter une mission prévient KONE.EDUC au moins 15 jours à l’avance, pour permettre son remplacement.',
    '- KONE.EDUC peut mettre fin à une mission si la famille est insatisfaite, si le règlement n’est pas respecté ou si l’élève ne progresse pas malgré les échanges.',
  ]),
  ('Titre II – Règles applicables aux parents et familles', []),
  ('Article 11 – Paiement des mensualités', [
    f'La mensualité est payée <b>au plus tard le {JOUR_LIMITE} de chaque mois</b>, uniquement sur le numéro officiel de KONE.EDUC : <b>{NUMERO}</b>. Le nom de l’élève et le mois concerné sont indiqués dans le message du paiement.',
    '- Aucun paiement ne doit être remis directement à l’enseignant. KONE.EDUC ne reconnaît que les paiements reçus sur son numéro officiel.',
    '- Le parent conserve le reçu du paiement (SMS de confirmation) et peut le déclarer depuis son espace « Paiements ».',
    '- Après deux relances restées sans réponse, les cours peuvent être suspendus jusqu’au paiement.',
    '- Toute modification de la mensualité fait l’objet d’une nouvelle fiche d’accord.',
  ]),
  ('Article 12 – Déroulement des cours', [
    '- Pour un élève mineur, un adulte responsable est présent au domicile pendant toute la durée du cours.',
    '- La famille fournit un endroit calme et éclairé, avec une table, et veille à ce que l’élève dispose de ses cahiers et manuels.',
    '- Toute séance annulée par la famille moins de 24 heures à l’avance est due, sauf cas de force majeure.',
    '- La famille traite l’enseignant avec respect et ne lui demande pas de tâches sans rapport avec les cours.',
  ]),
  ('Article 13 – Suivi, réclamations et changement d’enseignant', [
    '- Le parent consulte les comptes rendus et les bilans mensuels dans son espace KONE.EDUC.',
    '- Toute réclamation est adressée à KONE.EDUC sur WhatsApp ou depuis le site. KONE.EDUC répond sous 48 heures.',
    '- Si le premier cours ne convient pas, ou à tout moment en cas d’insatisfaction justifiée, KONE.EDUC propose un autre enseignant sans frais supplémentaires.',
  ]),
  ('Article 14 – Arrêt des cours', [
    'La famille qui souhaite arrêter les cours prévient KONE.EDUC au moins 15 jours avant la fin du mois. Le mois commencé reste dû.',
  ]),
  ('Titre III – Règles applicables aux vendeurs de la boutique', []),
  ('Article 15 – Obligations des vendeurs', [
    '- Le vendeur ne vend que des articles réels, conformes à leur description et à leur photo, au prix affiché.',
    '- Il répond à chaque commande dans les meilleurs délais. Toute commande sans réponse au bout de 24 heures peut être annulée automatiquement.',
    '- Tout refus ou toute annulation est motivé auprès du client.',
    '- Il livre dans le délai annoncé et remet au client le bon de commande.',
    '- La vente de contrefaçons et de copies d’ouvrages ou de sujets protégés sans l’autorisation de leurs auteurs est interdite.',
    '- Les coordonnées des clients ne servent qu’à la livraison de leur commande.',
    '- Pendant la période de lancement, KONE.EDUC ne prélève aucune commission sur les ventes de la boutique. Toute commission future sera annoncée au vendeur au moins 30 jours à l’avance.',
  ]),
  ('Titre IV – Dispositions communes', []),
  ('Article 16 – Traçabilité', [
    'Toutes les opérations réalisées sur la plateforme (demandes de cours, comptes rendus, paiements, versements, commandes, mouvements de stock, mises en relation) sont enregistrées et horodatées. Ces enregistrements font foi en cas de désaccord.',
  ]),
  ('Article 17 – Sanctions', [
    'Selon la gravité des faits, KONE.EDUC peut prononcer, après avoir entendu la personne concernée sauf urgence :',
    '- un avertissement écrit ;',
    '- une suspension temporaire du compte ;',
    '- le retrait d’une mission ou la fermeture d’une boutique ;',
    '- la radiation définitive.',
    'Les faits graves (atteinte à la sécurité d’un élève, fraude, faux documents, détournement de paiements) entraînent la radiation immédiate et peuvent être signalés aux autorités compétentes.',
  ]),
  ('Article 18 – Données personnelles', [
    'KONE.EDUC utilise les données personnelles uniquement pour le fonctionnement de ses services. Elles ne sont ni vendues ni cédées. Chacun peut demander leur consultation, leur correction ou leur suppression, selon la politique de confidentialité publiée sur le site.',
  ]),
  ('Article 19 – Règlement des différends', [
    'En cas de désaccord, les parties recherchent d’abord une solution amiable avec la médiation de KONE.EDUC. À défaut, le différend est porté devant les juridictions compétentes d’Abidjan.',
  ]),
  ('Article 20 – Modification du règlement', [
    'KONE.EDUC peut modifier le présent règlement. La nouvelle version est publiée sur le site et communiquée aux utilisateurs au moins 15 jours avant son entrée en vigueur.',
  ]),
]


def corps_reglement(h='h2', h3='h3'):
    out = []
    for titre, paras in REGLEMENT:
        if not paras:
            out.append('<' + h + ' class="titre">' + titre + '</' + h + '>')
            continue
        out.append('<section class="art"><' + h3 + '>' + titre + '</' + h3 + '>')
        ul = []
        for p in paras:
            if p.startswith('- '):
                ul.append('<li>' + p[2:] + '</li>')
            else:
                if ul: out.append('<ul>' + ''.join(ul) + '</ul>'); ul = []
                out.append('<p>' + p + '</p>')
        if ul: out.append('<ul>' + ''.join(ul) + '</ul>')
        out.append('</section>')
    return '\n'.join(out)


FONTS = '''@font-face{font-family:I;src:url(file:///usr/share/fonts/opentype/inter/Inter-Regular.otf);font-weight:400}
@font-face{font-family:I;src:url(file:///usr/share/fonts/opentype/inter/Inter-SemiBold.otf);font-weight:600}
@font-face{font-family:I;src:url(file:///usr/share/fonts/opentype/inter/Inter-Bold.otf);font-weight:700}
@font-face{font-family:I;src:url(file:///usr/share/fonts/opentype/inter/Inter-ExtraBold.otf);font-weight:800}'''
LOGO = 'file://' + str(ROOT / 'assets' / 'logo' / 'kone-educ-logo.jpg')
EMBL = 'file://' + str(ROOT / 'assets' / 'logo' / 'kone-educ-embleme.jpg')

# ------------------------------------------------------------------ PDF : règlement intérieur
PDF_CSS = FONTS + '''
@page{size:A4;margin:18mm 17mm 18mm}
*{box-sizing:border-box}body{margin:0;font-family:I,Arial,sans-serif;font-size:10.4pt;line-height:1.5;color:#0f1b37}
.head{display:flex;align-items:center;justify-content:space-between;border-bottom:3px solid #1559eb;padding-bottom:10px;margin-bottom:14px}
.head img{height:60px}.head div{text-align:right;font-size:9pt;color:#5b6884}
h1{margin:6px 0 2px;font-size:22pt;font-weight:800;letter-spacing:-.5px;color:#10294f}
.sub{margin:0 0 12px;color:#5b6884}
.titre{margin:18px 0 6px;padding:7px 12px;border-radius:8px;background:#10294f;color:#fff;font-size:12.5pt;font-weight:800;break-after:avoid}
.art{break-inside:avoid-page}.art h3{margin:12px 0 4px;font-size:11pt;font-weight:800;color:#1559eb;break-after:avoid}
p{margin:4px 0}ul{margin:4px 0 4px 18px;padding:0}li{margin:2px 0}
.cle{margin:10px 0;padding:10px 14px;border:2px solid #f0b030;border-radius:10px;background:#fff8e9}
.sign{margin-top:22px;display:grid;grid-template-columns:1fr 1fr;gap:18px;break-inside:avoid}
.sign div{border:1px solid #cfdcf3;border-radius:10px;padding:10px 12px;height:120px}
.sign b{display:block;margin-bottom:4px}.sign small{color:#5b6884}
.foot{margin-top:16px;font-size:8.5pt;color:#5b6884;text-align:center}
'''
reg_pdf = ('<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Règlement intérieur KONE.EDUC</title><style>' + PDF_CSS + '</style></head><body>'
  + '<div class="head"><img src="' + LOGO + '" alt="KONE.EDUC"><div>KONE.EDUC – Cours à domicile<br>Abidjan, Côte d’Ivoire<br>WhatsApp : ' + NUMERO + '<br>kone-educ.com</div></div>'
  + '<h1>Règlement intérieur</h1><p class="sub">Enseignants · Parents et familles · Vendeurs · ' + VERSION + '</p>'
  + '<div class="cle"><b>L’essentiel :</b> mensualité payée au plus tard le ' + str(JOUR_LIMITE) + ' du mois, uniquement au ' + NUMERO + ' (KONE.EDUC) · ' + (str(TAUX) + ' % de frais de service, ' + str(PART_ENS) + ' % versés à l’enseignant · ' if INTERNE else '') + 'aucun paiement direct à l’enseignant · absence prévenue 24 h à l’avance · compte rendu après chaque séance.</div>'
  + corps_reglement()
  + '<div class="sign"><div><b>Nom, prénom et qualité</b><small>(enseignant, parent, vendeur)</small></div><div><b>Date et signature</b><small>précédées de la mention « Lu et approuvé »</small></div></div>'
  + '<p class="foot">KONE.EDUC – L’excellence à domicile · ' + VERSION + '</p></body></html>')
(OUT / 'reglement-interieur.html').write_text(reg_pdf, encoding='utf-8')

# ------------------------------------------------------------------ PDF : fiche d'accord à signer
def ligne(lbl, w='100%'):
    return '<div class="f" style="width:' + w + '"><span>' + lbl + '</span><i></i></div>'

FA_CSS = FONTS + '''
@page{size:A4;margin:9mm 12mm}
*{box-sizing:border-box}body{margin:0;font-family:I,Arial,sans-serif;font-size:9pt;line-height:1.32;color:#0f1b37}
.head{display:flex;align-items:center;gap:14px;border-bottom:3px solid #1559eb;padding-bottom:8px}
.head img{height:46px}.head h1{flex:1;margin:0;font-size:17pt;font-weight:800;color:#10294f;letter-spacing:-.3px}.head h1 small{display:block;font-size:9pt;font-weight:600;color:#5b6884;letter-spacing:0}
.ref{text-align:right;font-size:8.8pt;color:#5b6884}.ref b{color:#0f1b37}
h2{margin:7px 0 2px;padding:3px 10px;border-radius:6px;background:#eaf1ff;color:#10294f;font-size:10.5pt;font-weight:800}
.row{display:flex;flex-wrap:wrap;gap:4px 14px}
.f{display:flex;align-items:flex-end;gap:6px;margin:4px 0}.f span{white-space:nowrap;font-weight:600}.f i{flex:1;border-bottom:1px dotted #8a99b8;height:13px}
.chk{display:inline-flex;align-items:center;gap:5px;margin-right:12px;font-weight:600}.chk:before{content:"";width:11px;height:11px;border:1.5px solid #10294f;border-radius:2px}
.pay{margin:6px 0;padding:7px 12px;border:2.5px solid #f0b030;border-radius:12px;background:#fff8e9}
.pay .num{display:flex;align-items:center;justify-content:space-between;gap:10px}
.pay .num b{font-size:22pt;font-weight:800;color:#10294f;letter-spacing:.5px}.pay .num small{font-size:9pt;font-weight:700}
.pay p{margin:3px 0}
.split{display:grid;grid-template-columns:1fr 1fr 1fr;gap:8px;margin-top:6px}.split div{padding:6px 8px;border-radius:8px;background:#fff;border:1px solid #f3d38c}.split b{display:block;font-size:8.5pt;color:#5b6884}
ul{margin:2px 0 2px 16px;padding:0}li{margin:1px 0}
.eng{display:grid;grid-template-columns:1fr 1fr;gap:10px}.eng div{padding:6px 10px;border:1px solid #dbe5f5;border-radius:10px}.eng b{color:#1559eb}
.sign{display:grid;grid-template-columns:1fr 1fr 1fr;gap:10px;margin-top:8px}.sign div{height:105px;padding:6px 8px;border:1px solid #cfdcf3;border-radius:10px;font-size:8.8pt}.sign b{display:block}
.note{margin-top:6px;font-size:8.2pt;color:#5b6884;text-align:center}
'''
fiche = ('<!doctype html><html lang="fr"><head><meta charset="utf-8"><title>Fiche d’accord KONE.EDUC</title><style>' + FA_CSS + '</style></head><body>'
  + '<div class="head"><img src="' + EMBL + '" alt=""><h1>Fiche d’accord de cours à domicile<small>Accord entre la famille, l’enseignant et KONE.EDUC</small></h1><div class="ref">Dossier n° <b>KE-______</b><br>Date : ___ / ___ / 20___</div></div>'
  + '<h2>1. La famille</h2><div class="row">' + ligne('Nom et prénom du parent / tuteur :', '62%') + ligne('Téléphone :', '34%') + ligne('Commune :', '32%') + ligne('Quartier et repère :', '64%') + '</div>'
  + '<h2>2. L’élève</h2><div class="row">' + ligne('Nom et prénom :', '50%') + ligne('Classe :', '22%') + ligne('Âge :', '22%') + ligne('Établissement fréquenté :', '100%') + '</div>'
  + '<h2>3. L’enseignant</h2><div class="row">' + ligne('Nom et prénom :', '62%') + ligne('Téléphone :', '34%') + ligne('Matière(s) enseignée(s) :', '100%') + '</div>'
  + '<h2>4. Les cours</h2><div class="row">' + ligne('Préparation visée (CEPE, BEPC, BAC, ENSEA, INPHB…) :', '100%') + ligne('Jours :', '48%') + ligne('Horaires :', '48%') + ligne('Séances par semaine :', '31%') + ligne('Durée d’une séance :', '31%') + ligne('Début le :', '32%') + '</div>'
  + '<div style="margin:4px 0"><span class="chk">À domicile</span><span class="chk">En ligne</span></div>'
  + '<h2>5. Mensualité et paiement</h2>'
  + '<div class="pay">' + ligne('Mensualité convenue :', '100%').replace('<i></i>', '<i></i><span>FCFA par mois</span>')
  + '<div class="num"><div><small>NUMÉRO OFFICIEL DE DÉPÔT DES MENSUALITÉS (KONE.EDUC)</small><br><b>' + NUMERO + '</b></div><div style="text-align:right"><span class="chk">Wave</span><span class="chk">Orange Money</span><br><span class="chk">MTN MoMo</span><span class="chk">Moov Money</span></div></div>'
  + '<p>• Paiement <b>au plus tard le ' + str(JOUR_LIMITE) + ' de chaque mois</b>, uniquement sur ce numéro. Indiquer dans le message : <b>nom de l’élève + mois</b>.</p>'
  + '<p>• <b>Aucun paiement ne doit être remis à l’enseignant.</b> Seuls les paiements reçus sur le numéro officiel de KONE.EDUC sont reconnus.</p>'
  + ('<div class="split"><div><b>Mensualité payée par la famille</b>__________ FCFA (100 %)</div><div><b>Frais de service KONE.EDUC</b>__________ FCFA (' + str(TAUX) + ' %)</div><div><b>Versé à l’enseignant par KONE.EDUC</b>__________ FCFA (' + str(PART_ENS) + ' %)</div></div>' if INTERNE else '') + '</div>'
  + '<h2>6. Engagements</h2><div class="eng"><div><b>La famille s’engage à :</b><ul><li>payer la mensualité avant le ' + str(JOUR_LIMITE) + ' du mois sur le numéro officiel ;</li><li>assurer la présence d’un adulte pendant les cours d’un mineur ;</li><li>prévenir 24 h à l’avance en cas d’annulation (sinon la séance est due) ;</li><li>prévenir 15 jours avant la fin du mois pour arrêter les cours.</li></ul></div>'
  + '<div><b>L’enseignant s’engage à :</b><ul><li>être ponctuel et prévenir 24 h à l’avance de toute absence ;</li><li>rattraper chaque séance manquée dans le mois ;</li><li>remplir le compte rendu après chaque séance ;</li><li>ne recevoir aucun paiement direct de la famille et ne pas la démarcher hors KONE.EDUC.</li></ul></div></div>'
  + '<p style="margin:6px 0 0"><b>KONE.EDUC s’engage à</b> suivre les cours, remplacer l’enseignant en cas de besoin, envoyer un bilan mensuel et verser à l’enseignant sa rémunération au plus tard le ' + str(JOUR_VERSEMENT) + ' du mois suivant.</p>'
  + '<p style="margin:4px 0 0">Les signataires déclarent avoir lu et accepté le <b>règlement intérieur de KONE.EDUC</b> (kone-educ.com/reglement-interieur.html), dont la présente fiche fait partie.</p>'
  + '<div class="sign"><div><b>Le parent / tuteur</b>« Lu et approuvé », date et signature</div><div><b>L’enseignant</b>« Lu et approuvé », date et signature</div><div><b>Pour KONE.EDUC</b>Nom, date, signature et cachet</div></div>'
  + '<p class="note">Fiche établie en trois exemplaires : un pour la famille, un pour l’enseignant, un pour KONE.EDUC · ' + VERSION + '</p></body></html>')
(OUT / 'fiche-accord.html').write_text(fiche, encoding='utf-8')

# ------------------------------------------------------------------ Page du site : reglement-interieur.html (version publique uniquement)
if INTERNE:
    print('Documents internes (avec le taux) écrits dans', OUT, '– ne pas publier.'); sys.exit(0)
base = (ROOT / 'services.html').read_text(encoding='utf-8')
head = base[:base.index('<style>')]
head = re.sub(r'<title>[^<]*</title>', '<title>Règlement intérieur | KONE.EDUC</title>', head)
desc = 'Règlement intérieur KONE.EDUC : règles des enseignants, des parents et des vendeurs, paiement des mensualités, frais de service, traçabilité et sanctions.'
for k in ('name="description"', 'property="og:description"'):
    head = re.sub(r'<meta ' + k + r' content="[^"]*">', '<meta ' + k + ' content="' + desc + '">', head)
head = re.sub(r'<meta property="og:title" content="[^"]*">', '<meta property="og:title" content="Règlement intérieur | KONE.EDUC">', head)
head = re.sub(r'<link rel="canonical" href="[^"]*">', '<link rel="canonical" href="https://www.kone-educ.com/reglement-interieur.html">', head)
head = re.sub(r'<meta property="og:url" content="[^"]*">', '<meta property="og:url" content="https://www.kone-educ.com/reglement-interieur.html">', head)
body_start = base[base.index('<body'):base.index('<main')].replace(' aria-current="page"', '')
footer = base[base.index('<footer'):base.index('<script src="site.js">')]
SITE_CSS = '''.ri{max-width:860px;margin:0 auto;padding:26px 20px 70px;font-family:"DM Sans",Arial,sans-serif;color:#0f1b37;line-height:1.65}
.ri h1{margin:4px 0 4px;font:800 clamp(28px,4vw,40px) Manrope,sans-serif;letter-spacing:-1px}.ri .sub{color:#5b6884;margin:0 0 16px}
.ri .cle{margin:16px 0;padding:16px 18px;border:2px solid #f0b030;border-radius:16px;background:#fff8e9}
.ri .titre{margin:30px 0 8px;padding:10px 16px;border-radius:12px;background:#10294f;color:#fff;font:800 19px Manrope,sans-serif}
.ri .art h3{margin:20px 0 6px;font:800 17px Manrope,sans-serif;color:#1559eb}.ri p{margin:6px 0}.ri ul{margin:6px 0 6px 20px;padding:0}
.ri .dl{display:flex;flex-wrap:wrap;gap:10px;margin:14px 0}.ri .dl a{padding:11px 16px;border-radius:12px;background:#1559eb;color:#fff;font-weight:800;text-decoration:none}.ri .dl a.alt{background:#fff;color:#1559eb;border:1px solid #cfdcf3}
.ri nav.toc{margin:12px 0;padding:14px 18px;border:1px solid #e3ebf8;border-radius:16px;background:#fff;font-size:15px}.ri nav.toc a{color:#1559eb;text-decoration:none}'''
toc = ' · '.join('<a href="#t' + str(i) + '">' + t.split('–')[1].strip() + '</a>' for i, (t, p) in enumerate(REGLEMENT) if not p)
corps = corps_reglement()
i = [0]
def ancre(m):
    i[0] += 1
    return '<h2 class="titre" id="t' + str([k for k, (t, p) in enumerate(REGLEMENT) if not p][i[0] - 1]) + '">'
corps = re.sub(r'<h2 class="titre">', ancre, corps)
main = ('<main class="ri"><h1>Règlement intérieur</h1><p class="sub">Enseignants · Parents et familles · Vendeurs · ' + VERSION + '</p>'
  + '<div class="cle"><b>L’essentiel :</b> mensualité payée au plus tard le ' + str(JOUR_LIMITE) + ' du mois, uniquement au <b>' + NUMERO + '</b> (KONE.EDUC) · ' + (str(TAUX) + ' % de frais de service, ' + str(PART_ENS) + ' % versés à l’enseignant · ' if INTERNE else '') + 'aucun paiement direct à l’enseignant · absence prévenue 24 h à l’avance · compte rendu après chaque séance.</div>'
  + '<div class="dl"><a href="https://github.com/KoneNamory/kone-educ/raw/main/communication/8-Documents-officiels/KONE-EDUC-reglement-interieur.pdf">⬇ Télécharger en PDF</a><a class="alt" href="https://github.com/KoneNamory/kone-educ/raw/main/communication/8-Documents-officiels/KONE-EDUC-fiche-accord.pdf">⬇ Fiche d’accord à signer</a></div>'
  + '<nav class="toc" aria-label="Sommaire">' + toc + '</nav>' + corps + '<p style="margin-top:30px;color:#5b6884">Une question sur ce règlement ? Écrivez-nous sur WhatsApp au ' + NUMERO + '.</p></main>')
(ROOT / 'reglement-interieur.html').write_text(head + '<style>' + SITE_CSS + '</style></head>' + body_start + main + footer + '<script src="site.js"></script></body></html>\n', encoding='utf-8')
print('écrit : reglement-interieur.html,', OUT / 'reglement-interieur.html', ',', OUT / 'fiche-accord.html')
