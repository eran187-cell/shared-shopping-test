const CACHE='ss-test-v156';
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(clients.claim()));
self.addEventListener('fetch',e=>{
  // Only handle GET requests — Cache API doesn't support POST/PUT/DELETE
  // (Firebase writes pass through directly without caching).
  if(e.request.method!=='GET')return;
  // network-first: always try network, fall back to cache
  e.respondWith(
    fetch(e.request).then(r=>{
      const clone=r.clone();
      caches.open(CACHE).then(c=>c.put(e.request,clone)).catch(()=>{});
      return r;
    }).catch(()=>caches.match(e.request))
  );
});
