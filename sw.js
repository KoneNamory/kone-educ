// Service worker KONE.EDUC : installation de l'application et chargement rapide, même avec un réseau faible.
// Changer VERSION à chaque modification de ce fichier pour forcer la mise à jour.
const VERSION = 'kone-educ-v17';
const EXT = 'kone-educ-externe-v1'; // bibliothèque Supabase et polices : gardées d'une version à l'autre
const CORE = ['./', 'index.html', 'offline.html', 'site.css', 'ke-theme.css', 'site.js', 'app.css', 'dash.css', 'app.js', 'embed.js', 'fichiers.js',
  'abidjan-locations.js', 'preparations.js', 'supabase-config.js', 'assets/logo/kone-educ-embleme.jpg', 'assets/icons/favicon-48.png', 'assets/hero-tutor.webp', 'assets/icons/icon-192.png'];
// Hôtes externes dont les fichiers ne changent pas (jamais l'API Supabase, toujours en direct)
const EXT_HOSTS = ['cdn.jsdelivr.net', 'fonts.googleapis.com', 'fonts.gstatic.com'];
const TIMEOUT = 4000; // au-delà, on affiche la dernière version enregistrée de la page

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION && k !== EXT).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

// Réponse immédiate depuis le cache, mise à jour en arrière-plan
function rapide(req, cacheName) {
  return caches.open(cacheName).then((c) => c.match(req).then((cached) => {
    const network = fetch(req).then((res) => { if (res.ok || res.type === 'opaque') c.put(req, res.clone()); return res; }).catch(() => cached);
    return cached || network;
  }));
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) {
    if (EXT_HOSTS.includes(url.hostname)) e.respondWith(rapide(req, EXT));
    return;
  }
  if (req.mode === 'navigate') {
    // Pages : réseau d'abord (dernière version) ; si le réseau tarde plus de 4 s ou est coupé, version enregistrée.
    const network = fetch(req, { cache: 'no-store' }).then((res) => {
      if (res.ok) { const copy = res.clone(); caches.open(VERSION).then((c) => c.put(req, copy)); }
      return res;
    });
    e.respondWith(new Promise((resolve) => {
      let done = false;
      const fallback = () => caches.match(req, { ignoreSearch: true }).then((r) => r || caches.match('offline.html'));
      const timer = setTimeout(() => { caches.match(req, { ignoreSearch: true }).then((r) => { if (r && !done) { done = true; resolve(r); } }); }, TIMEOUT);
      network.then((res) => { clearTimeout(timer); if (!done) { done = true; resolve(res); } })
        .catch(() => { clearTimeout(timer); if (!done) { done = true; resolve(fallback()); } });
    }));
    return;
  }
  e.respondWith(rapide(req, VERSION));
});
