// KONE.EDUC – Préparations aux examens et concours (liste commune à tout le site)
window.KONE_EDUC_PREPARATIONS = [
  ['Examens nationaux', ['CEPE', 'BEPC', 'BAC']],
  ['Concours ENSEA', ['ENSEA – AS', 'ENSEA – ISE Maths', 'ENSEA – ISE Économie']],
  ['Concours INPHB', ['INPHB – A2GP', 'INPHB – Classes préparatoires', 'INPHB – ITA']]
];
// Remplit un <select> : « Aucune » puis les préparations groupées
window.fillPreparations = function (select, emptyLabel) {
  select.innerHTML = '<option value="">' + (emptyLabel || 'Aucune (suivi scolaire)') + '</option>'
    + KONE_EDUC_PREPARATIONS.map(function (g) { return '<optgroup label="' + g[0] + '">' + g[1].map(function (p) { return '<option>' + p + '</option>'; }).join('') + '</optgroup>'; }).join('');
};
// Cases à cocher (plusieurs préparations) dans un conteneur
window.fillPreparationChecks = function (box, name, checked) {
  var on = String(checked || '').split(/\s*,\s*/);
  box.innerHTML = KONE_EDUC_PREPARATIONS.map(function (g) {
    return '<div class="prep-group"><b>' + g[0] + '</b>' + g[1].map(function (p) {
      return '<label class="prep-check"><input type="checkbox" name="' + name + '" value="' + p + '"' + (on.indexOf(p) >= 0 ? ' checked' : '') + '> ' + p + '</label>';
    }).join('') + '</div>';
  }).join('');
};
