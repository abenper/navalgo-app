// Firebase Cloud Messaging service worker for NavalGO Web.
// Runs in background and handles push notifications when the app
// tab is closed or not focused.

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBbcgQPb2xVH5qEucH_yetrZqnhA2xAWrM',
  authDomain: 'naval-go.firebaseapp.com',
  projectId: 'naval-go',
  storageBucket: 'naval-go.firebasestorage.app',
  messagingSenderId: '201883315763',
  appId: '1:201883315763:web:a87e3264bca378024dbd46',
  measurementId: 'G-V45H99BJT7',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title || payload.data?.title || 'NavalGO';
  const body = payload.notification?.body || payload.data?.body || '';
  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {},
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ('focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    }),
  );
});
