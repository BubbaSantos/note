// Cache the app shell so Note opens offline; API calls always go to the network.
const CACHE = 'note-v19';
const SHELL = ['./', 'index.html', 'icon.svg', 'icon.png', 'icon-192.png', 'icon-512.png', 'manifest.webmanifest'];
self.addEventListener('install', e => e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).then(() => self.skipWaiting())));
self.addEventListener('activate', e => e.waitUntil(
  caches.keys().then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim())));
self.addEventListener('fetch', e => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  e.respondWith(fetch(e.request).then(r => {
    caches.open(CACHE).then(c => c.put(e.request, r.clone()));
    return r;
  }).catch(() => caches.match(e.request)));
});
