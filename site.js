// Menu mobile et bouton WhatsApp des pages publiques KONE.EDUC
(function () {
  // Numéro WhatsApp au format international sans « + » ni espaces, ex. '2250700000000'. Vide = bouton masqué.
  var WHATSAPP = '2250161701361';
  var header = document.querySelector('.ke-header');
  var burger = document.querySelector('.ke-burger');
  if (header && burger) {
    burger.addEventListener('click', function () {
      var open = header.classList.toggle('open');
      burger.setAttribute('aria-expanded', open);
      burger.textContent = open ? '✕' : '☰';
    });
  }
  if (WHATSAPP) {
    var a = document.createElement('a');
    a.className = 'ke-whatsapp';
    a.href = 'https://wa.me/' + WHATSAPP + '?text=' + encodeURIComponent('Bonjour KONE.EDUC, je souhaite un renseignement sur les cours à domicile.');
    a.target = '_blank';
    a.rel = 'noopener';
    a.setAttribute('aria-label', 'Nous écrire sur WhatsApp');
    a.innerHTML = '<svg width="22" height="22" viewBox="0 0 24 24" fill="#fff" aria-hidden="true"><path d="M12 2a10 10 0 0 0-8.6 15.1L2 22l5-1.3A10 10 0 1 0 12 2zm5.3 14.1c-.2.6-1.3 1.2-1.8 1.2s-1 .2-3.4-.7a11.8 11.8 0 0 1-4.6-4.1c-.4-.6-1-1.6-1-3.1s.8-2.2 1.1-2.5.6-.3.8-.3h.6c.2 0 .4 0 .6.5l.9 2.1c.1.2.1.4 0 .6l-.4.6-.4.5c-.1.2-.3.3-.1.6a8.6 8.6 0 0 0 1.6 2 7.8 7.8 0 0 0 2.3 1.4c.3.1.5.1.6-.1l.9-1c.2-.3.4-.2.7-.1l2 1c.3.1.5.2.5.3s.1.7-.1 1.3z"/></svg><span>WhatsApp</span>';
    document.body.appendChild(a);
  }
})();
