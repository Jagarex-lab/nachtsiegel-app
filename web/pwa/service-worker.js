'use strict';
// Generated for one exact source commit. Deliberately no offline-game claim:
// Navigation and build-info bypass HTTP caches so a replaced Pages export
// cannot boot an old HTML entry whose commit-addressed WASM/PCK was removed.
// Core/illustration fetches are not intercepted or put in Cache Storage.
// Existing profiles/localStorage and already running games are never touched.
const CACHE = 'orafold-brand-__COMMIT__';
const BRAND = ['./app-icon-192.png','./app-icon-512.png','./apple-touch-icon.png'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(BRAND)).then(()=>self.skipWaiting())));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('orafold-brand-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 if (event.request.method!=='GET') return;
 const requestURL=new URL(event.request.url);
 const scope=new URL(self.registration.scope);
 if (requestURL.origin!==scope.origin||!requestURL.pathname.startsWith(scope.pathname)) return;
 const metadata=new URL('build-info.json',scope);
 if (event.request.mode==='navigate'||requestURL.pathname===metadata.pathname) {
  // No cache fallback to an old engine entry. A failed request never commands
  // an existing client to reload, so an in-memory duel remains undisturbed.
  event.respondWith(fetch(event.request,{cache:'no-store'}));
  return;
 }
 const urls=BRAND.map(path=>new URL(path,self.registration.scope).href);
 if (urls.includes(requestURL.href)) event.respondWith(caches.open(CACHE).then(cache=>cache.match(event.request)).then(cached=>cached||fetch(event.request)));
});
