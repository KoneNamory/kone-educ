const teacherDb = supabase.createClient(KONE_EDUC_SUPABASE.url, KONE_EDUC_SUPABASE.publishableKey);
document.getElementById('teacher-form').addEventListener('submit', async function () {
  const { data: { user } } = await teacherDb.auth.getUser();
  if (!user) return;
  const form = new FormData(this);
  const subject = form.get('subject') === 'other' ? form.get('otherSubject') : form.get('subject');
  const degree = form.get('degree') === 'other' ? form.get('otherDegree') : form.get('degree');
  const { error } = await teacherDb.from('teacher_profiles').insert({ id: user.id, degree, subject, experience: form.get('experience'), availability: form.get('availability'), course_format: form.get('format'), bio: form.get('bio') });
  const message = document.getElementById('confirmation');
  if (error) { message.textContent = 'Erreur : ' + error.message; message.classList.add('show'); return; }
  message.textContent = 'Candidature enregistrée avec succès !'; message.classList.add('show');
});
