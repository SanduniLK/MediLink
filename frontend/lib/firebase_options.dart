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
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA_kJTskeEgR1H3X64_D9jbUE4U4c23bqc',
    appId: '1:617494714296:web:051b81b9330546f22b614d',
    messagingSenderId: '617494714296',
    projectId: 'medilink-c7499',
    authDomain: 'medilink-c7499.firebaseapp.com',
    storageBucket: 'medilink-c7499.firebasestorage.app',
    measurementId: 'G-B51QLRC6FV',
    databaseURL: 'https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBkbnOnw9z-uYjg2W1JXUwTBJz3tYPxn_4',
    appId: '1:617494714296:android:58d09e37e087f4042b614d',
    messagingSenderId: '617494714296',
    projectId: 'medilink-c7499',
    storageBucket: 'medilink-c7499.firebasestorage.app',
    databaseURL: 'https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB4jmnG7NTyX7Un6soqRJvOBRqRLcF0t9E',
    appId: '1:617494714296:ios:52926c6585a3bdaf2b614d',
    messagingSenderId: '617494714296',
    projectId: 'medilink-c7499',
    storageBucket: 'medilink-c7499.firebasestorage.app',
    iosBundleId: 'com.example.frontend',
    databaseURL: 'https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app/', // ADD THIS
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB4jmnG7NTyX7Un6soqRJvOBRqRLcF0t9E',
    appId: '1:617494714296:ios:52926c6585a3bdaf2b614d',
    messagingSenderId: '617494714296',
    projectId: 'medilink-c7499',
    storageBucket: 'medilink-c7499.firebasestorage.app',
    iosBundleId: 'com.example.frontend',
    databaseURL: 'https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app/', // ADD THIS
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA_kJTskeEgR1H3X64_D9jbUE4U4c23bqc',
    appId: '1:617494714296:web:625afc8a4858b77f2b614d',
    messagingSenderId: '617494714296',
    projectId: 'medilink-c7499',
    authDomain: 'medilink-c7499.firebaseapp.com',
    storageBucket: 'medilink-c7499.firebasestorage.app',
    measurementId: 'G-593KFEKXYX',
    databaseURL: 'https://medilink-c7499-default-rtdb.asia-southeast1.firebasedatabase.app/', // ADD THIS
  );
}