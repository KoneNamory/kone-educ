const teacherDb = supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
const MAX_SIZE = 5 * 1024 * 1024;
const PHOTO_TYPES = ['image/jpeg', 'image/png', 'image/webp'];
const DOC_TYPES = PHOTO_TYPES.concat('application/pdf');
// Champ du formulaire → colonne de teacher_profiles et libellé
const FILES = {
  photo: { column: 'photo_url', label: 'la photo de profil', types: PHOTO_TYPES },
  idDoc: { column: 'id_doc_path', label: 'la pièce d’identité', types: DOC_TYPES },
  diploma: { column: 'diploma_path', label: 'le diplôme', types: DOC_TYPES },
  cv: { column: 'cv_path', label: 'le CV', types: DOC_TYPES }
};
const teacherForm = document.getElementById('teacher-form');
const notice = document.getElementById('confirmation');
const say = (text, isError) => { notice.textContent = text; notice.classList.add('show'); notice.style.color = isError ? '#b42318' : ''; };

// Documents déjà fournis : ils deviennent facultatifs (à renvoyer seulement pour les remplacer)
(async function markExistingFiles() {
  const { data: { user } } = await teacherDb.auth.getUser();
  if (!user) {
    // Prévenir avant la saisie : sans compte, la candidature (et ses fichiers) ne peut pas être enregistrée
    const box = document.createElement('div');
    box.className = 'login-first';
    box.innerHTML = '<b>Créez d’abord votre compte enseignant</b><p>Votre candidature et vos documents sont rattachés à votre compte. Connectez-vous ou créez un compte, puis revenez sur cette page.</p><a class="lf-btn" href="inscription.html?role=teacher">Créer un compte enseignant</a> <a class="lf-link" href="connexion.html?redirect=candidature-enseignant.html">J’ai déjà un compte</a>';
    teacherForm.parentNode.insertBefore(box, teacherForm);
    return;
  }
  const { data } = await teacherDb.from('teacher_profiles').select('*').eq('id', user.id).maybeSingle();
  if (!data) return;
  Object.keys(FILES).forEach((name) => {
    if (!data[FILES[name].column]) return;
    teacherForm.querySelector('input[name="' + name + '"]').required = false;
    teacherForm.querySelector('.have[data-for="' + name + '"]').textContent = '✓ Déjà fourni — choisissez un fichier seulement pour le remplacer.';
  });
})();

teacherForm.addEventListener('submit', async function (event) {
  event.preventDefault();
  const { data: { user } } = await teacherDb.auth.getUser();
  if (!user) { location.href = 'connexion.html?redirect=candidature-enseignant.html'; return; }
  const form = new FormData(this);
  const subject = form.get('subject') === 'other' ? form.get('otherSubject') : form.get('subject');
  const degree = form.get('degree') === 'other' ? form.get('otherDegree') : form.get('degree');
  const days = Array.from(document.querySelectorAll('input[name="days"]:checked')).map(x => x.value);
  const levels = Array.from(document.querySelectorAll('input[name="levels"]:checked')).map(x => x.value);
  if (!days.length) { say('Choisissez au moins un jour de disponibilité.', true); return; }

  // Vérification des fichiers avant tout envoi
  for (const name of Object.keys(FILES)) {
    const file = form.get(name);
    if (!file || !file.size) continue;
    if (!FILES[name].types.includes(file.type)) { say('Format non accepté pour ' + FILES[name].label + ' : utilisez JPG, PNG, WEBP' + (name === 'photo' ? '.' : ' ou PDF.'), true); return; }
    if (file.size > MAX_SIZE) { say('Le fichier pour ' + FILES[name].label + ' dépasse 5 Mo.', true); return; }
  }

  const button = this.querySelector('button[type="submit"]');
  button.disabled = true;
  try {
    const profileUpdate = await teacherDb.from('profiles').update({ full_name: form.get('name'), phone: form.get('phone') }).eq('id', user.id);
    if (profileUpdate.error) throw profileUpdate.error;

    const row = { id: user.id, degree, subject, experience: form.get('experience'), availability: days.join(', '), location: form.get('location'), levels: levels.join(', '), format: form.get('format'), bio: form.get('bio') };
    // Envoi des documents : la photo dans « avatars » (public), le reste dans « teacher-files » (privé)
    for (const name of Object.keys(FILES)) {
      const file = form.get(name);
      if (!file || !file.size) continue;
      say('Envoi de ' + FILES[name].label + '…');
      const ext = (file.name.split('.').pop() || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '');
      const path = user.id + '/' + name + '-' + Date.now() + '.' + ext;
      const bucket = name === 'photo' ? 'avatars' : 'teacher-files';
      const upload = await teacherDb.storage.from(bucket).upload(path, file, { contentType: file.type, upsert: true });
      if (upload.error) throw upload.error;
      row[FILES[name].column] = name === 'photo' ? teacherDb.storage.from('avatars').getPublicUrl(path).data.publicUrl : path;
    }

    const { error } = await teacherDb.from('teacher_profiles').upsert(row, { onConflict: 'id' });
    if (error) throw error;
    say('Candidature et documents enregistrés avec succès ! Nous étudions votre dossier.');
  } catch (error) {
    say('Erreur : ' + (error.message || error), true);
  } finally {
    button.disabled = false;
  }
});
