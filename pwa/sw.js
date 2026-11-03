// Service worker della webapp: tiene in cache tutta l'app per usarla offline in palestra.
// Strategia: rete con timeout breve, se non c'è rete si usa la copia in cache.
const VERSION = '__VERSION__';
const CACHE = 'scout-volley-' + VERSION;
const PRECACHE = __PRECACHE__;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // un file che manca non deve bloccare l'installazione
    await Promise.all(PRECACHE.map((url) => cache.add(url).catch(() => null)));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter((k) => k.startsWith('scout-volley-') && k !== CACHE).map((k) => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    // stesso sito: chiedi sempre al server se c'è una versione nuova (salta la cache HTTP del browser)
    const sameOrigin = new URL(req.url).origin === self.location.origin;
    const fresh = !sameOrigin
      ? fetch(req)
      : req.mode === 'navigate'
        ? fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' })
        : fetch(req, { cache: 'no-cache' });
    const network = fresh.then((res) => {
      if (res && (res.ok || res.type === 'opaque')) cache.put(req, res.clone());
      return res;
    });
    try {
      return await Promise.race([
        network,
        new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), 3500)),
      ]);
    } catch (e) {
      const hit = (await cache.match(req)) || (await cache.match(req, { ignoreSearch: true }));
      if (hit) return hit;
      if (req.mode === 'navigate') {
        const home = await cache.match('./');
        if (home) return home;
      }
      return network;
    }
  })());
});
