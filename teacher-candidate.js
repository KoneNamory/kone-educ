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

// Où se trouve chaque élément du dossier dans le formulaire (pour le préremplir et le signaler s'il manque)
const SPOT = {
  degree: '#degree', subject: '#subject', experience: 'select[name="experience"]', location: 'input[name="location"]',
  levels: 'input[name="levels"]', availability: 'input[name="days"]', format: 'select[name="format"]', bio: 'textarea[name="bio"]',
  photo_url: 'input[name="photo"]', id_doc_path: 'input[name="idDoc"]', diploma_path: 'input[name="diploma"]', cv_path: 'input[name="cv"]'
};
const spotBox = key => { const el = teacherForm.querySelector(SPOT[key]); return el && (el.closest('.full') || el.closest('label')); };
const statusBox = document.createElement('div');
statusBox.id = 'dossier-status';
statusBox.className = 'dossier-status';

// Sélectionne une option connue, sinon « Autre » avec la précision
function pick(select, value, otherInput) {
  if (!value) return;
  const known = Array.from(select.options).some(o => o.value === value || o.text === value);
  select.value = known ? value : 'other';
  select.dispatchEvent(new Event('change'));
  if (!known && otherInput) otherInput.value = value;
}

function showStatus(t) {
  const missing = KE_DOSSIER.missing(t);
  teacherForm.querySelectorAll('.is-missing').forEach(el => el.classList.remove('is-missing'));
  missing.forEach(d => { const box = spotBox(d[0]); if (box) box.classList.add('is-missing'); });
  const pct = KE_DOSSIER.percent(t);
  statusBox.innerHTML = missing.length
    ? '<div class="ds-head"><b>Votre dossier est complet à ' + pct + ' %</b><span>' + missing.length + ' élément(s) à compléter</span></div><div class="ds-bar"><i style="width:' + pct + '%"></i></div>'
      + '<p>Vos réponses déjà enregistrées sont préremplies. Complétez seulement ce qui manque (encadré en orange), puis envoyez :</p>'
      + '<div class="ds-list">' + missing.map(d => '<button type="button" data-key="' + d[0] + '">' + d[1] + '</button>').join('') + '</div>'
    : '<div class="ds-head"><b>✓ Votre dossier est complet</b><span>100 %</span></div><div class="ds-bar"><i style="width:100%"></i></div><p>Vous pouvez mettre à jour vos informations ou remplacer un document à tout moment.</p>';
  teacherForm.querySelector('button[type="submit"]').textContent = missing.length ? 'Compléter mon dossier →' : 'Mettre à jour mon dossier →';
}

statusBox.addEventListener('click', e => {
  const key = e.target.dataset && e.target.dataset.key;
  const el = key && teacherForm.querySelector(SPOT[key]);
  if (!el) return;
  (el.closest('.full') || el.closest('label') || el).scrollIntoView({ behavior: 'smooth', block: 'center' });
  setTimeout(() => el.focus({ preventScroll: true }), 300);
});

// Un enseignant qui revient retrouve ses réponses et voit ce qui manque
async function loadDossier() {
  const { data: { user } } = await teacherDb.auth.getUser();
  if (!user) {
    // Prévenir avant la saisie : sans compte, la candidature (et ses fichiers) ne peut pas être enregistrée
    const box = document.createElement('div');
    box.className = 'login-first';
    box.innerHTML = '<b>Créez d’abord votre compte enseignant</b><p>Votre candidature et vos documents sont rattachés à votre compte. Connectez-vous ou créez un compte, puis revenez sur cette page.</p><a class="lf-btn" href="inscription.html?role=teacher">Créer un compte enseignant</a> <a class="lf-link" href="connexion.html?redirect=candidature-enseignant.html">J’ai déjà un compte</a>';
    teacherForm.parentNode.insertBefore(box, teacherForm);
    return;
  }
  const { data: prof } = await teacherDb.from('profiles').select('role, full_name, phone').eq('id', user.id).maybeSingle();
  if (prof && prof.role !== 'teacher') {
    const box = document.createElement('div');
    box.className = 'login-first';
    box.innerHTML = '<b>Vous êtes connecté avec un compte ' + (prof.role === 'parent' ? 'Parent' : 'Administrateur') + '.</b><p>Une candidature doit être déposée avec un compte Enseignant. Déconnectez-vous, puis créez un compte Enseignant.</p><a class="lf-btn" href="inscription.html?role=teacher">Créer un compte enseignant</a>';
    teacherForm.parentNode.insertBefore(box, teacherForm);
    teacherForm.querySelectorAll('input, select, textarea, button').forEach(el => { el.disabled = true; });
    return;
  }
  const f = teacherForm.elements;
  if (prof) { if (!f.name.value) f.name.value = prof.full_name || ''; if (!f.phone.value) f.phone.value = prof.phone || ''; }
  if (!f.email.value) f.email.value = user.email || '';
  const { data } = await teacherDb.from('teacher_profiles').select('*').eq('id', user.id).maybeSingle();
  if (!statusBox.isConnected) teacherForm.parentNode.insertBefore(statusBox, teacherForm);
  if (data) {
    pick(f.degree, data.degree, f.otherDegree);
    pick(f.subject, data.subject, f.otherSubject);
    if (data.experience) f.experience.value = data.experience;
    if (data.format) f.format.value = data.format;
    if (data.location) f.location.value = data.location;
    if (data.bio) f.bio.value = data.bio;
    const split = v => String(v || '').split(',').map(x => x.trim()).filter(Boolean);
    split(data.levels).forEach(v => { const c = teacherForm.querySelector('input[name="levels"][value="' + v + '"]'); if (c) c.checked = true; });
    split(data.availability).forEach(v => { const c = teacherForm.querySelector('input[name="days"][value="' + v + '"]'); if (c) c.checked = true; });
    // Documents déjà fournis : facultatifs (à renvoyer seulement pour les remplacer)
    Object.keys(FILES).forEach((name) => {
      const input = teacherForm.querySelector('input[name="' + name + '"]'), note = teacherForm.querySelector('.have[data-for="' + name + '"]');
      const given = !!data[FILES[name].column];
      input.required = !given;
      note.textContent = given ? '✓ Déjà fourni — choisissez un fichier seulement pour le remplacer.' : '';
    });
  }
  showStatus(data);
  return data;
}
loadDossier();

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
    // Profil du compte : mis à jour, ou recréé en Enseignant s'il a disparu
    const { data: existing } = await teacherDb.from('profiles').select('role').eq('id', user.id).maybeSingle();
    const profileSave = existing
      ? await teacherDb.from('profiles').update({ full_name: form.get('name'), phone: form.get('phone') }).eq('id', user.id)
      : await teacherDb.from('profiles').insert({ id: user.id, full_name: form.get('name'), phone: form.get('phone'), role: 'teacher' });
    if (profileSave.error) throw new Error('enregistrement de votre profil refusé (' + profileSave.error.message + ')');
    if (existing && existing.role !== 'teacher') throw new Error('ce compte est enregistré comme ' + (existing.role === 'parent' ? 'Parent' : existing.role) + ' : utilisez un compte Enseignant');

    const row = { id: user.id, degree, subject, experience: form.get('experience'), availability: days.join(', '), location: form.get('location'), levels: levels.join(', '), format: form.get('format'), bio: form.get('bio') };
    // Envoi des documents : la photo dans « avatars » (public), le reste dans « teacher-files » (privé)
    for (const name of Object.keys(FILES)) {
      const file = form.get(name);
      if (!file || !file.size) continue;
      say('Envoi de ' + FILES[name].label + '…');
      const ext = (file.name.split('.').pop() || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '');
      const path = user.id + '/' + name + '-' + Date.now() + '.' + ext;
      const bucket = name === 'photo' ? 'avatars' : 'teacher-files';
      // Nom de fichier unique : pas de remplacement (qui exigerait des droits de lecture en plus)
      const upload = await teacherDb.storage.from(bucket).upload(path, file, { contentType: file.type, upsert: false });
      if (upload.error) throw new Error('envoi de ' + FILES[name].label + ' refusé (' + upload.error.message + ')');
      row[FILES[name].column] = name === 'photo' ? teacherDb.storage.from('avatars').getPublicUrl(path).data.publicUrl : path;
    }

    const { error } = await teacherDb.from('teacher_profiles').upsert(row, { onConflict: 'id' });
    if (error) throw new Error('enregistrement de la candidature refusé (' + error.message + ')');
    teacherForm.querySelectorAll('input[type="file"]').forEach(i => { i.value = ''; });
    const left = KE_DOSSIER.missing(await loadDossier()).length;
    say(left ? 'Dossier enregistré. Il reste ' + left + ' élément(s) à compléter (voir en haut du formulaire).' : 'Candidature enregistrée ! Votre dossier est complet : nous l’étudions et vous contactons très vite.');
  } catch (error) {
    say('Erreur : ' + (error.message || error), true);
  } finally {
    button.disabled = false;
  }
});
