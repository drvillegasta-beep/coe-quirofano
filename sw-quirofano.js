/* COE Quirófano: permite abrir la app aunque no haya internet.
   Solo atiende quirofano-v2.html y sus librerías; cualquier otra página pasa directo a la red. */
const CACHE = 'qx-app-v1';
const PAGINA = /\/quirofano-v2\.html$/;
const LIBS = /^https:\/\/(cdn\.jsdelivr\.net|unpkg\.com|cdnjs\.cloudflare\.com)\/.*\d+\.\d+/;

self.addEventListener('install', e => { self.skipWaiting(); });
self.addEventListener('activate', e => { e.waitUntil(self.clients.claim()); });

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin === location.origin && PAGINA.test(url.pathname)) {
    // Red primero; si no hay red, la última copia guardada
    e.respondWith((async () => {
      const c = await caches.open(CACHE);
      try {
        const r = await fetch(req);
        if (r.ok && !url.search.includes('nv=')) c.put(url.origin + url.pathname, r.clone());
        return r;
      } catch (err) {
        const hit = await c.match(url.origin + url.pathname);
        if (hit) return hit;
        throw err;
      }
    })());
    return;
  }
  if (LIBS.test(req.url)) {
    // Librerías con versión fija: copia guardada primero
    e.respondWith((async () => {
      const c = await caches.open(CACHE);
      const hit = await c.match(req);
      if (hit) return hit;
      const r = await fetch(req);
      if (r.ok) c.put(req, r.clone());
      return r;
    })());
  }
});
