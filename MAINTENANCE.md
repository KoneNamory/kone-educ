# Conservation du projet KONE.EDUC

## Emplacement du projet

Tous les fichiers du site sont enregistrés dans ce dossier :
`C:\Users\HP\Desktop\Stat_Pr_Assi\kone-educ-main`

Ils restent disponibles sans connexion Internet. Les pages HTML se consultent en double-cliquant sur leur fichier.

## Sauvegardes

- Le dossier `backups/` contient des copies ZIP datées du projet.
- Le suivi Git conserve l'historique des modifications locales : il permet de revenir à une version antérieure si nécessaire.

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
