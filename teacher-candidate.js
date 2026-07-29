const teacherDb = supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
document.getElementById('teacher-form').addEventListener('submit', async function (event) {
  event.preventDefault();
  const { data: { user } } = await teacherDb.auth.getUser();
  if (!user) return;
  const form = new FormData(this);
  const subject = form.get('subject') === 'other' ? form.get('otherSubject') : form.get('subject');
  const degree = form.get('degree') === 'other' ? form.get('otherDegree') : form.get('degree');
  const days = Array.from(document.querySelectorAll('input[name="days"]:checked')).map(x => x.value);
  if (!days.length) return;
  const profileUpdate = await teacherDb.from('profiles').update({ full_name: form.get('name'), phone: form.get('phone') }).eq('id', user.id);
  if (profileUpdate.error) { const message = document.getElementById('confirmation'); message.textContent = 'Erreur : ' + profileUpdate.error.message; message.classList.add('show'); return; }
  const { error } = await teacherDb.from('teacher_profiles').upsert(
    { id: user.id, degree, subject, experience: form.get('experience'), availability: days.join(', '), format: form.get('format'), bio: form.get('bio') },
    { onConflict: 'id' }
  );
  const message = document.getElementById('confirmation');
  if (error) { message.textContent = 'Erreur : ' + error.message; message.classList.add('show'); return; }
  message.textContent = 'Candidature enregistrée et mise à jour avec succès !'; message.classList.add('show');
});
