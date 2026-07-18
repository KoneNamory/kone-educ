# Connexion KONE.EDUC à Supabase

1. Dans Supabase, ouvrez **SQL Editor** puis **New query**.
2. Copiez tout le contenu de `supabase-schema.sql` dans l'éditeur.
3. Cliquez sur **Run**.
4. Confirmez ensuite que les tables `profiles`, `course_requests` et `teacher_profiles` apparaissent dans **Table Editor**.

La clé publique est enregistrée dans `supabase-config.js`. Elle peut être utilisée dans le site ; la clé `service_role` ne doit jamais être ajoutée au projet.
