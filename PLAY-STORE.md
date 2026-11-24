# Publier KONE.EDUC sur le Google Play Store

L’application Android est le site lui-même, emballé grâce à une « Trusted Web Activity » (TWA).
Chaque amélioration du site apparaît donc aussitôt dans l’application, sans nouvelle publication.

## 1. Créer le compte développeur Google Play

1. Rendez-vous sur https://play.google.com/console et connectez-vous avec le compte Google de KONE.EDUC.
2. Choisissez le type de compte : **Organisation** si l’entreprise est immatriculée (numéro D-U-N-S demandé), sinon **Personnel**.
3. Payez les frais d’inscription uniques (25 $ US, environ 15 000 FCFA) et vérifiez votre identité.
4. Compte **Personnel** : Google impose un **test fermé** avec au moins 12 testeurs pendant 14 jours avant la publication publique (voir l’étape 4).

## 2. Générer l’application avec PWABuilder

1. Sur un ordinateur, ouvrez https://www.pwabuilder.com et saisissez `https://kone-educ.vercel.app`.
2. Cliquez sur **Package for stores**, puis sur **Android** et **Generate Package**.
3. Réglages conseillés :
   - Package ID : `com.koneeduc.app`. Il est définitif : ne plus jamais le changer.
   - App name : `KONE.EDUC` · Launcher name : `KONE.EDUC`
   - Theme color : `#1559EB` · Background color : `#FFFFFF` · Status bar color : `#1559EB`
   - Signing key : **Create new**, puis renseignez le nom et le pays (CI).
4. Téléchargez le fichier ZIP. Il contient :
   - le fichier `.aab` à envoyer sur le Play Store ;
   - `signing.keystore` et `signing-key-info.txt`. **Gardez-les précieusement** (clé USB, Google Drive privé) : sans eux, impossible de mettre à jour l’application.
   - `assetlinks.json`

## 3. Relier l’application au site (supprime la barre d’adresse)

Envoyez le contenu du fichier `assetlinks.json` à l’équipe technique (ou à Claude).
Il sera publié à l’adresse `https://kone-educ.vercel.app/.well-known/assetlinks.json`.

Après le premier envoi sur la Play Console, Google ajoute sa propre clé de signature :
allez dans **Configuration → Intégrité de l’application → Signature de l’application**,
copiez l’**empreinte du certificat SHA-256** de la « clé de signature d’application » et transmettez-la aussi.
Les deux empreintes doivent figurer dans `assetlinks.json`.

## 4. Créer la fiche sur la Play Console

**Créer une application** → Langue par défaut : Français · Application · Gratuite.

Images (dossier `assets/store/` et fichiers fournis) :
- Icône : `assets/icons/icon-512.png` (512 × 512)
- Image de présentation : `banniere-1024x500.png`
- Captures d’écran du téléphone : `1-accueil.png`, `2-fiche-enseignant.png`, `4-bilan.png`, `5-planning.png` (1080 × 1920)

Liens à renseigner :
- Politique de confidentialité : `https://kone-educ.vercel.app/mentions-legales.html#confidentialite`
- Suppression du compte : `https://kone-educ.vercel.app/suppression-compte.html`
- Site web : `https://kone-educ.vercel.app`

Questionnaires :
- **Accès à l’application** : l’application demande une connexion. Donnez un compte Parent de test (e-mail + mot de passe) pour l’examen de Google.
- **Publicités** : non.
- **Classification du contenu** : catégorie « Éducation » ; aucun contenu sensible.
- **Public cible** : adultes, 18 ans et plus (ce sont les parents et les enseignants qui utilisent l’application).
- **Sécurité des données** : données collectées : nom, adresse e-mail, téléphone, photos et documents des enseignants, messages. Elles sont chiffrées en transit, ne sont ni vendues ni partagées à des fins publicitaires, et l’utilisateur peut demander leur suppression.

Ensuite : **Tests → Test fermé** (compte Personnel : 12 testeurs, 14 jours), puis **Production → Créer une release** et envoi du fichier `.aab`.

## Textes de la fiche

**Nom de l’application** (30 caractères max.)
KONE.EDUC – Cours à domicile

**Description courte** (80 caractères max.)
Cours particuliers à domicile à Abidjan, avec suivi après chaque séance.

**Description complète**

KONE.EDUC met en relation les familles et des enseignants vérifiés pour des cours particuliers à domicile et en ligne, à Abidjan et dans toute la Côte d’Ivoire.

👪 POUR LES PARENTS
• Réservez un cours en deux minutes, ou demandez directement l’enseignant de votre choix
• Consultez la fiche de chaque enseignant : diplôme, expérience et avis vérifiés d’autres parents
• Suivez le planning des séances et recevez un rappel avant chaque cours
• Lisez le compte rendu de l’enseignant après chaque séance : notions travaillées, devoirs, compréhension
• Recevez chaque mois un bilan de progression clair, imprimable en PDF
• Échangez avec l’enseignant par messagerie
• Réglez vos factures par Wave, Orange Money, MTN MoMo ou Moov Money

👩‍🏫 POUR LES ENSEIGNANTS
• Déposez votre dossier (diplôme, CV, pièce d’identité) et faites-vous valider
• Postulez aux offres de cours proches de chez vous
• Planifiez vos séances et envoyez vos comptes rendus en quelques clics
• Disposez d’une fiche publique avec les avis des familles

✅ NOS GARANTIES
• Enseignants sélectionnés : identité, diplôme et entretien pédagogique vérifiés
• Suivi après chaque séance et bilan mensuel
• Remplacement de l’enseignant si besoin
• Vos données restent confidentielles

Une question ? Écrivez-nous sur WhatsApp au 01 61 70 13 61.
