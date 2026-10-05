// Numéros de paiement affichés aux parents dans « Mes paiements ».
window.KONE_EDUC_PAYMENT = {
  name: 'KONE.EDUC',
  methods: [
    { id: 'wave', label: 'Wave', number: '07 98 06 73 36', how: 'Ouvrez l’application Wave et envoyez le montant exact au' },
    { id: 'orange_money', label: 'Orange Money', number: '07 98 06 73 36', how: 'Composez #144# (ou ouvrez l’application Orange Money) et envoyez le montant exact au' },
    // Un moyen sans numéro n'est pas proposé aux parents
    { id: 'mtn_money', label: 'MTN MoMo', number: '05 94 51 61 53', how: 'Composez *133# (ou ouvrez l’application MoMo) et envoyez le montant exact au' },
    { id: 'moov_money', label: 'Moov Money', number: '01 61 70 13 61', how: 'Composez *155# (ou ouvrez l’application Moov Money) et envoyez le montant exact au' }
  ]
};
// Seuls les moyens avec un numéro renseigné sont affichés
window.KONE_EDUC_PAYMENT.methods = window.KONE_EDUC_PAYMENT.methods.filter(function (m) { return m.number; });
