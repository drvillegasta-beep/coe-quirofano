/* COE Farmacia · funciona sin red: guarda la app y sus librerías en esta computadora.
   Solo atiende farmacia.html y sus librerías; las demás páginas del sitio pasan directo. */
const CACHE = 'coe-farmacia-v1';
const PRE = ['./farmacia.html', 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => Promise.all(PRE.map(u => c.add(new Request(u, { cache: 'reload' })).catch(() => {})))).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(ks => Promise.all(ks.filter(k => k.startsWith('coe-farmacia-') && k !== CACHE).map(k => caches.delete(k)))).then(() => self.clients.claim()));
});

const esPagina = u => u.origin === self.location.origin && /\/farmacia\.html$/.test(u.pathname);
const esLib = u => u.hostname === 'cdn.jsdelivr.net' || u.hostname === 'fonts.googleapis.com' || u.hostname === 'fonts.gstatic.com';

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const u = new URL(req.url);
  if (esPagina(u)) {
    // primero la red (para recibir versiones nuevas); sin red, la copia guardada
    e.respondWith(fetch(req).then(r => {
      if (r.ok && !u.search) { const cp = r.clone(); caches.open(CACHE).then(c => c.put('./farmacia.html', cp)); }
      return r;
    }).catch(() => caches.match('./farmacia.html')));
    return;
  }
  if (esLib(u)) {
    e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(r => {
      if (r.ok || r.type === 'opaque') { const cp = r.clone(); caches.open(CACHE).then(c => c.put(req, cp)); }
      return r;
    })));
  }
});
