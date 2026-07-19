// File generated from google-services.json (eeg-mobil).
// Auth is NOT used. Only Core, Firestore, and Storage.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB6FPK2cZrzf_OmWWZoD15DNMUEOlwJ-2E',
    appId: '1:189070431099:web:0000000000000000000000',
    messagingSenderId: '189070431099',
    projectId: 'eeg-mobil',
    authDomain: 'eeg-mobil.firebaseapp.com',
    storageBucket: 'eeg-mobil.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB6FPK2cZrzf_OmWWZoD15DNMUEOlwJ-2E',
    appId: '1:189070431099:android:54ae1976ce9ac2a0a5e3de',
    messagingSenderId: '189070431099',
    projectId: 'eeg-mobil',
    storageBucket: 'eeg-mobil.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB6FPK2cZrzf_OmWWZoD15DNMUEOlwJ-2E',
    appId: '1:189070431099:ios:0000000000000000000000',
    messagingSenderId: '189070431099',
    projectId: 'eeg-mobil',
    storageBucket: 'eeg-mobil.firebasestorage.app',
    iosBundleId: 'com.example.eegMobil',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB6FPK2cZrzf_OmWWZoD15DNMUEOlwJ-2E',
    appId: '1:189070431099:ios:0000000000000000000000',
    messagingSenderId: '189070431099',
    projectId: 'eeg-mobil',
    storageBucket: 'eeg-mobil.firebasestorage.app',
    iosBundleId: 'com.example.eegMobil',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB6FPK2cZrzf_OmWWZoD15DNMUEOlwJ-2E',
    appId: '1:189070431099:web:0000000000000000000000',
    messagingSenderId: '189070431099',
    projectId: 'eeg-mobil',
    storageBucket: 'eeg-mobil.firebasestorage.app',
  );
}
