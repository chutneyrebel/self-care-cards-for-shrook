const CACHE = "self-care-cards-v5";
const FILES = ["./", "./index.html", "./manifest.webmanifest", "./cards.json", "./source-decks.json", "./jung-quotes.json", "./icon.svg"];
const APP_ROOT = new URL("./", self.location.href);
const DATA_FILES = new Set(["cards.json", "source-decks.json", "jung-quotes.json"]);

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES)));
  self.skipWaiting();
});

self.addEventListener("activate", event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(key => key.startsWith("self-care-cards-") && key !== CACHE).map(key => caches.delete(key))
  )));
  self.clients.claim();
});

self.addEventListener("fetch", event => {
  if (event.request.method !== "GET") return;
  const requestUrl = new URL(event.request.url);
  if (requestUrl.origin !== self.location.origin || !requestUrl.pathname.startsWith(APP_ROOT.pathname)) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const cached = await cache.match(event.request);
    if (cached) return cached;

    try {
      const response = await fetch(event.request);
      if (response.ok) await cache.put(event.request, response.clone());
      return response;
    } catch (error) {
      const fileName = requestUrl.pathname.split("/").pop();
      if (DATA_FILES.has(fileName)) {
        return new Response(JSON.stringify({ error: "offline_data_unavailable" }), {
          status: 503,
          headers: { "Content-Type": "application/json; charset=utf-8" }
        });
      }

      const fallback = await cache.match(new URL("./index.html", self.location.href).href);
      if (fallback) return fallback;
      throw error;
    }
  })());
});
