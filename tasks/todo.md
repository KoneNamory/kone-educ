# Feuille de route - KONE.EDUC

## État de départ (13 juillet 2026)

- [x] Identifier les maquettes et prototypes fournis.
- [x] Relever les fonctionnalités déjà imaginées : espaces Parent, Enseignant et Administration.
- [x] Choisir la page d'accueil visuelle de référence : la maquette KONE.EDUC bleue et orange.

## Étape 1 - Cadrage du produit

- [ ] Définir les utilisateurs, leurs besoins et les parcours principaux.
- [ ] Définir le périmètre de la première version (MVP).
- [ ] Rédiger l'arborescence des pages et les données à gérer.

## Étape 2 - Design et site vitrine

- [x] Construire une page d'accueil responsive à partir de la maquette validée.
- [x] Créer la page Services.
- [x] Créer la page Enseignants.
- [x] Créer la page Tarifs.
- [x] Créer la page À propos.
- [x] Créer la page Contact.
- [x] Créer le premier formulaire de réservation (prototype HTML autonome).
- [x] Ajouter le formulaire de candidature enseignant (prototype HTML autonome).

## Étape 3 - Plateforme

- [x] Créer le premier espace Parent en mode démo.
- [x] Créer le premier espace Enseignant en mode démo.
- [x] Créer le premier espace Administrateur en mode démo.
- [x] Mettre en place l'authentification et les rôles Parent, Enseignant, Administrateur.
- [x] Construire les tableaux de bord et le suivi des demandes.
- [x] Ajouter les notifications dans les espaces Parent et Enseignant.
- [x] Ajouter la bibliothèque de documents.
- [x] Ajouter la messagerie entre le parent et l'enseignant attribué (`messagerie.html`).
- [x] Facturation mensuelle : l'administrateur crée les factures, le parent paie par Wave ou Orange Money et indique la référence, l'administrateur confirme (`paiements.html`).
- [ ] Renseigner le lien Wave Business et le numéro marchand Orange Money dans `payment-config.js`.
- [ ] Confirmation automatique des paiements via les API Wave Checkout et Orange Money Web Payment (nécessite les contrats marchands et une fonction serveur).

## Étape 4 - Qualité et mise en ligne

- [ ] Tester l'expérience mobile, les formulaires et les parcours principaux.
- [x] Sécuriser les rôles (pas d'auto-promotion administrateur ni d'auto-validation enseignant).
- [x] Enregistrer les messages du formulaire de contact et les afficher dans l'espace Administration.
- [x] Rédiger les mentions légales et la politique de confidentialité (`mentions-legales.html`).
- [ ] Compléter les informations marquées « à compléter » dans `mentions-legales.html` (RCCM, adresse, responsable, durées de conservation).
- [x] En-tête et pied de page communs, menu mobile, référencement (descriptions, données structurées, sitemap).
- [x] Suivi pédagogique : compte rendu après chaque séance et courbe de progression (`suivi.html`).
- [x] Avis des parents sur les enseignants, note moyenne dans l'espace Administration.
- [ ] Renseigner le numéro WhatsApp dans `site.js` et vérifier l'adresse du site dans `sitemap.xml` et `robots.txt`.
- [ ] Préparer les données de démonstration.
- [ ] Déployer le site.

## Conservation du projet

- [x] Ajouter une documentation de maintenance locale.
- [x] Créer une sauvegarde ZIP après chaque étape importante.
- [x] Enregistrer chaque étape importante dans l'historique Git local.

## Notes d'analyse

La maquette illustrée sert de référence visuelle pour l'accueil. Le fichier `kone-educ_2.html` sert de référence fonctionnelle, mais il devra être réorganisé en un projet maintenable avant d'ajouter une base de données ou des paiements réels.
