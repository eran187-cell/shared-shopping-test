const CACHE='ss-test-v35';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(clients.claim()));
self.addEventListener('fetch',e=>{
  // network-first: always try network, fall back to cache
  e.respondWith(
    fetch(e.request).then(r=>{
      const clone=r.clone();
      caches.open(CACHE).then(c=>c.put(e.request,clone));
      return r;
    }).catch(()=>caches.match(e.request))
  );
});
