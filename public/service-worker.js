self.addEventListener('install', () => {
  console.log('HGV Signing App installed')
})

self.addEventListener('activate', () => {
  console.log('HGV Signing App activated')
})

self.addEventListener('fetch', (event) => {
  event.respondWith(fetch(event.request))
})
