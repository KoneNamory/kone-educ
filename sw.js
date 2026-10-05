// Service worker KONE.EDUC : installation de l'application et chargement rapide.
// Changer VERSION à chaque modification de ce fichier pour forcer la mise à jour.
const VERSION = 'kone-educ-v4';
const CORE = ['./', 'index.html', 'offline.html', 'site.css', 'site.js', 'app.css', 'app.js', 'favicon.svg', 'assets/hero-tutor.webp', 'assets/icons/icon-192.png'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSION).then((c) => c.addAll(CORE)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)))).then(() => self.clients.claim()));
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);
  // Seules les pages et fichiers du site sont mis en cache (jamais Supabase ni les services externes).
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;
  if (req.mode === 'navigate') {
    // Pages : réseau d'abord pour toujours afficher la dernière version, cache si hors connexion.
    e.respondWith(fetch(req).then((res) => {
      const copy = res.clone();
      caches.open(VERSION).then((c) => c.put(req, copy));
      return res;
    }).catch(() => caches.match(req).then((r) => r || caches.match('offline.html'))));
    return;
  }
  // Fichiers (CSS, JS, images) : réponse immédiate depuis le cache, mise à jour en arrière-plan.
  e.respondWith(caches.match(req).then((cached) => {
    const network = fetch(req).then((res) => {
      if (res.ok) { const copy = res.clone(); caches.open(VERSION).then((c) => c.put(req, copy)); }
      return res;
    }).catch(() => cached);
    return cached || network;
  }));
});
