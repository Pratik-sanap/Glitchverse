/*! coi-serviceworker v0.1.7 - Guido Zuidhof and contributors, licensed under MIT */
/*! mini build for Godot HTML5 on GitHub Pages */
if (typeof window === 'undefined') {
  // Service Worker context
  self.addEventListener('install', () => self.skipWaiting());
  self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
  self.addEventListener('message', (ev) => {
    if (ev.data && ev.data.type === 'deregister') {
      self.registration
        .unregister()
        .then(() => self.clients.matchAll())
        .then((clients) => clients.forEach((client) => client.navigate(client.url)));
    }
  });
  self.addEventListener('fetch', function (e) {
    if (
      e.request.cache === 'only-if-cached' &&
      e.request.mode !== 'same-origin'
    ) {
      return;
    }
    e.respondWith(
      fetch(e.request).then((response) => {
        if (response.status === 0) {
          return response;
        }
        const newHeaders = new Headers(response.headers);
        newHeaders.set('Cross-Origin-Embedder-Policy', 'require-corp');
        newHeaders.set('Cross-Origin-Resource-Policy', 'cross-origin');
        newHeaders.set('Cross-Origin-Opener-Policy', 'same-origin');
        return new Response(response.body, {
          status: response.status,
          statusText: response.statusText,
          headers: newHeaders,
        });
      })
    );
  });
} else {
  // Window context — register ourselves as a service worker
  (async function () {
    if (window.crossOriginIsolated !== false) return;

    let registration = await navigator.serviceWorker
      .register(window.document.currentScript.src)
      .catch((e) =>
        console.error('COISW registration failed: ', e)
      );
    if (registration) {
      registration.addEventListener('updatefound', () => {
        console.log('Reloading page to make use of updated service worker.');
        window.location.reload();
      });
      // If the registration is active, but it's not controlling the page
      if (registration.active && !navigator.serviceWorker.controller) {
        console.log('Reloading page to make use of service worker.');
        window.location.reload();
      }
    }
  })();
}
