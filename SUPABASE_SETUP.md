# Connexion KONE.EDUC à Supabase

1. Dans Supabase, ouvrez **SQL Editor** puis **New query**.
2. Copiez tout le contenu de `supabase-schema.sql` dans l'éditeur.
3. Cliquez sur **Run**.
4. Confirmez ensuite que les tables `profiles`, `course_requests` et `teacher_profiles` apparaissent dans **Table Editor**.

La clé publique est enregistrée dans `supabase-config.js`. Elle peut être utilisée dans le site ; la clé `service_role` ne doit jamais être ajoutée au projet.

## Mise à jour du schéma

Copier le code depuis la version texte brut sur GitHub (un aperçu de fichier peut ne copier que les lignes visibles) :
https://raw.githubusercontent.com/KoneNamory/kone-educ/main/supabase-schema.sql

Avant de cliquer sur **Run**, vérifier que la dernière ligne collée est `notify pgrst, 'reload schema';`. La tâche GitHub « Supabase keep-alive » (onglet Actions) indique ensuite si une table manque.

Après chaque modification de `supabase-schema.sql`, relancez **tout** le fichier dans **SQL Editor**. Il peut être relancé sans risque : il ne supprime aucune donnée.

## Sécurité des rôles

- À l'inscription, un utilisateur ne peut choisir que le rôle `parent` ou `teacher`.
- Pour créer un administrateur, modifiez la colonne `role` du profil directement dans **Table Editor** (table `profiles`). Depuis le site, seul un administrateur peut changer un rôle.
- Seul un administrateur peut valider une candidature enseignant (`approved`).
