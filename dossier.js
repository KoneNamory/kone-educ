// Éléments obligatoires du dossier enseignant.
// Liste commune à la candidature, à l'espace enseignant et à l'espace administrateur.
window.KE_DOSSIER = {
  fields: [
    ['degree', 'Diplôme'],
    ['subject', 'Matière principale'],
    ['experience', 'Années d’expérience'],
    ['location', 'Ville / quartier'],
    ['levels', 'Niveaux enseignés'],
    ['availability', 'Jours disponibles'],
    ['format', 'Format de cours'],
    ['bio', 'Présentation de votre expérience']
  ],
  docs: [
    ['photo_url', 'Photo de profil'],
    ['id_doc_path', 'Pièce d’identité'],
    ['diploma_path', 'Dernier diplôme'],
    ['cv_path', 'CV']
  ],
  all: function () { return this.fields.concat(this.docs); },
  // Éléments manquants : [[colonne, libellé], …]
  missing: function (t) {
    return this.all().filter(function (d) { return !t || !String(t[d[0]] == null ? '' : t[d[0]]).trim(); });
  },
  percent: function (t) {
    var total = this.all().length;
    return Math.round((total - this.missing(t).length) / total * 100);
  }
};
