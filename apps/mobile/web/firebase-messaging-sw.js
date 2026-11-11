// Firebase Cloud Messaging (FCM) Web Service Worker
// Replace the firebaseConfig values below with your Firebase Console -> Project Settings -> Web App config.
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

const firebaseConfig = {
  apiKey: "YOUR_FIREBASE_API_KEY",
  authDomain: "project-513606.firebaseapp.com",
  projectId: "project-513606",
  storageBucket: "project-513606.appspot.com",
  messagingSenderId: "914782829465",
  appId: "YOUR_FIREBASE_WEB_APP_ID"
};

if (firebaseConfig.apiKey !== "YOUR_FIREBASE_API_KEY") {
  firebase.initializeApp(firebaseConfig);
  const messaging = firebase.messaging();

  messaging.onBackgroundMessage((payload) => {
    console.log('[firebase-messaging-sw.js] Received background message ', payload);
    const notificationTitle = payload.notification?.title || 'Spaces Cambodia Message';
    const notificationOptions = {
      body: payload.notification?.body || 'You have a new notification',
      icon: '/icons/Icon-192.png'
    };
    self.registration.showNotification(notificationTitle, notificationOptions);
  });
}

