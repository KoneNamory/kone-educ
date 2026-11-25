// KONE.EDUC – Fichiers envoyés : 600 Ko maximum chacun pour ne pas saturer le stockage.
// Les photos sont réduites et compressées automatiquement sur le téléphone avant l'envoi ;
// les PDF trop lourds sont refusés avec un conseil pour les alléger.
(function () {
  var MAX = 600 * 1024;
  window.KE_FILE_MAX = MAX;
  var taille = function (n) { return n < 1024 * 1024 ? Math.round(n / 1024) + ' Ko' : (n / 1048576).toFixed(1).replace('.', ',') + ' Mo'; };
  window.KE_fileSize = taille;
  // Image → JPEG de 600 Ko maximum (côté le plus long ≤ maxSide, qualité réduite si besoin)
  window.KE_compressImage = function (file, maxSide) {
    maxSide = maxSide || 1600;
    return new Promise(function (ok, ko) {
      var img = new Image(), url = URL.createObjectURL(file);
      img.onload = function () {
        URL.revokeObjectURL(url);
        var side = maxSide, q = 0.85, c = document.createElement('canvas');
        (function essai() {
          var k = Math.min(1, side / Math.max(img.width, img.height));
          c.width = Math.round(img.width * k); c.height = Math.round(img.height * k);
          var x = c.getContext('2d'); x.fillStyle = '#fff'; x.fillRect(0, 0, c.width, c.height); x.drawImage(img, 0, 0, c.width, c.height);
          c.toBlob(function (b) {
            if (!b) { ko(new Error('Image illisible.')); return; }
            if (b.size <= MAX || side < 500) { ok(b); return; }
            if (q > 0.55) q -= 0.12; else side = Math.round(side * 0.8);
            essai();
          }, 'image/jpeg', q);
        })();
      };
      img.onerror = function () { URL.revokeObjectURL(url); ko(new Error('Ce fichier n’est pas une image lisible.')); };
      img.src = url;
    });
  };
  // Prépare un fichier avant l'envoi : { blob, type, ext } ou erreur explicite
  window.KE_prepareUpload = async function (file, opts) {
    opts = opts || {};
    if (!file) throw new Error('Aucun fichier choisi.');
    if (/^image\//.test(file.type)) {
      var b = await KE_compressImage(file, opts.maxSide);
      return { blob: b, type: 'image/jpeg', ext: 'jpg' };
    }
    if (file.size > MAX) throw new Error('« ' + file.name + ' » pèse ' + taille(file.size) + ' : la limite est de 600 Ko par fichier. Prenez plutôt une photo du document (elle sera compressée automatiquement) ou réduisez le PDF (par exemple sur ilovepdf.com, « Compresser PDF »).');
    var ext = (file.name.split('.').pop() || 'bin').toLowerCase().replace(/[^a-z0-9]/g, '');
    return { blob: file, type: file.type || 'application/octet-stream', ext: ext };
  };
})();
