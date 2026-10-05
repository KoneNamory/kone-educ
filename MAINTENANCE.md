# Conservation du projet KONE.EDUC

## Emplacement du projet

Tous les fichiers du site sont enregistrés dans ce dossier :
`C:\Users\HP\Desktop\Stat_Pr_Assi\kone-educ-main`

Ils restent disponibles sans connexion Internet. Les pages HTML se consultent en double-cliquant sur leur fichier.

## Sauvegardes

- Le dossier `backups/` contient des copies ZIP datées du projet.
- Le suivi Git conserve l'historique des modifications locales : il permet de revenir à une version antérieure si nécessaire.

### Sauvegarde de la base de données
- **À la demande** : espace admin → « Sécurité et sauvegarde » → « Exporter toutes les données » (fichier JSON).
- **Automatique chaque dimanche** : workflow GitHub « Sauvegarde de la base » (`.github/workflows/sauvegarde-base.yml`).
  Fichier chiffré conservé 90 jours dans GitHub → Actions → exécution → « Artifacts ».
  - Secrets requis (GitHub → Settings → Secrets and variables → Actions) :
    - `SUPABASE_DB_URL` : Supabase → **Connect** → chaîne **Session pooler** (port 5432), avec le mot de passe de la base.
    - `BACKUP_PASSPHRASE` : mot de passe de chiffrement, à noter en lieu sûr (sans lui, la sauvegarde est illisible).
  - Déchiffrer : `gpg -d kone-educ-AAAA-MM-JJ.tar.gz.gpg > sauvegarde.tar.gz && tar -xzf sauvegarde.tar.gz`
  - Restaurer dans un projet Supabase vide : exécuter `site.sql`, puis `comptes.sql` et `reglages.sql`
    (avec `psql "$SUPABASE_DB_URL" -f fichier.sql`). Les fichiers déposés (photos, documents) restent dans Supabase Storage.
- **Journal des actions** : table `audit_log`, visible dans l'espace admin (créations, modifications, suppressions,
  y compris celles faites depuis le tableau de bord Supabase).

## Règle de travail

Avant chaque ajout important, créer une nouvelle sauvegarde et enregistrer une nouvelle version Git. Conserver également une copie du ZIP sur une clé USB, Google Drive ou OneDrive dès qu'une connexion est disponible.

## Pages actuelles

- `reservation.html` : demande de cours pour les parents.
- `candidature-enseignant.html` : candidature des enseignants.
- `messagerie.html?cours=ID` : échanges entre le parent et l'enseignant attribué à un cours.
- `contact.html` : formulaire de contact ; les messages s'affichent dans `espace-admin.html`.
- `mentions-legales.html` : mentions légales et politique de confidentialité.
- `paiements.html` : factures mensuelles du parent et paiement par Wave ou Orange Money.
- `payment-config.js` : numéros Wave, Orange Money et Moov Money affichés aux parents.
- `suivi.html?cours=ID` : comptes rendus de séance (enseignant), progression et avis (parent).
- `site.css` / `site.js` : en-tête, pied de page, menu mobile et bouton WhatsApp communs aux pages publiques.
- `sitemap.xml` / `robots.txt` : référencement ; remplacer `kone-educ.vercel.app` si le site a un autre nom de domaine.
- `mot-de-passe-oublie.html` / `nouveau-mot-de-passe.html` : réinitialisation du mot de passe par e-mail.
- `.github/workflows/supabase-keepalive.yml` : interroge Supabase tous les 3 jours pour éviter la mise en pause du projet gratuit.
- `app.css` / `app.js` : style et barre de navigation communs aux espaces connectés (liens selon le rôle, nom, déconnexion).
- `conseils.html` et `conseils-*.html` : blog de conseils (pages statiques pour le référencement). Ajouter chaque nouvel article à `conseils.html` et à `sitemap.xml`.
- `manifest.webmanifest`, `sw.js`, `offline.html`, `assets/icons/` : application installable sur téléphone et mode hors connexion. Après une modification de `sw.js`, changer sa constante `VERSION`.

## Test de bout en bout

`tests/e2e/parcours.mjs` rejoue le parcours complet (inscription, réservation, candidature, validation, attribution, facture, paiement, compte rendu, messagerie, avis, contact) sur les vraies pages, avec un faux Supabase qui refuse toute colonne absente de `supabase-schema.sql`. Nécessite Node.js et Playwright :

```
python3 -m http.server 8765 --bind 127.0.0.1 &
node tests/e2e/parcours.mjs
```
- `assets/og-image.jpg` : image affichée lors d'un partage sur WhatsApp, Facebook, etc. Chaque page publique déclare son adresse officielle (`canonical`) et cette image.
- Dossier enseignant : photo de profil dans l'espace de stockage public `avatars`, pièce d'identité, diplôme et CV dans l'espace privé `teacher-files` (accessible uniquement à l'enseignant et à l'administrateur, par liens temporaires).
- `enseignants.html` : profils publics des enseignants validés via la fonction `public_teachers()` (prénom + initiale, sans téléphone ni documents).
