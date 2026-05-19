# Firebase Google OAuth Setup Guide

This document provides a comprehensive guide on setting up Firebase Authentication (Google Sign-In) for Flutter, specific to `google_sign_in` package v7+ and `firebase_auth`.

## Table of Contents
1. [Firebase Console Setup](#firebase-console-setup)
2. [Android Configuration](#android-configuration)
3. [iOS Configuration](#ios-configuration)
4. [Code Explanation (Google Sign-In v7+)](#code-explanation)

---

## Firebase Console Setup

1. **Create a Firebase Project:**
   - Go to the [Firebase Console](https://console.firebase.google.com/).
   - Click **Add project** and follow the prompts.

2. **Enable Google Authentication:**
   - Navigate to **Authentication** -> **Sign-in method**.
   - Click on **Add new provider** and select **Google**.
   - Enable it, provide a support email, and save.

3. **Add App to Firebase:**
   - On the Project Overview page, click the Flutter, Android, or iOS icon to register your app.
   - For a cross-platform Flutter project, you can use the FlutterFire CLI:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```
     *This command automatically registers your apps and downloads necessary config files (`google-services.json`, `GoogleService-Info.plist`, and `firebase_options.dart`).*

4. **Add SHA-1 Key (Crucial for Android Google Sign-In):**
   - Google Sign-In on Android *requires* your app's SHA-1 fingerprint.
   - To get your debug SHA-1 key, run:
     ```bash
     cd android && ./gradlew signingReport
     ```
   - Copy the SHA-1 from the `debug` variant.
   - In Firebase Console, go to **Project settings** -> **General**, scroll to your Android app, and click **Add fingerprint**. Paste the SHA-1 key and save.

---

## Android Configuration

If you used `flutterfire configure`, most of this is handled automatically. Otherwise, manually ensure:

1. **`google-services.json`:**
   - Must be placed inside `android/app/`.

2. **Gradle Configuration:**
   - In `android/build.gradle` (Project level), ensure you have the Google services classpath.
   - In `android/app/build.gradle` (App level), apply the plugin:
     ```gradle
     plugins {
         id "com.google.gms.google-services"
     }
     ```

3. **Min SDK Version:**
   - Firebase and Google Sign-In typically require a higher minimum SDK. In `android/app/build.gradle`, set `minSdkVersion` to at least `21` or `23`.

---

## iOS Configuration

If you used `flutterfire configure`, the plist is linked. However, you still need to configure the URL scheme manually for Google Sign-In.

1. **`GoogleService-Info.plist`:**
   - Download this from Firebase Console.
   - Open your iOS project in **Xcode** (`ios/Runner.xcworkspace`).
   - Drag and drop `GoogleService-Info.plist` into the `Runner` folder inside Xcode. Ensure "Copy items if needed" is checked.

2. **Add Custom URL Scheme:**
   - Open `ios/Runner/Info.plist` in Xcode or a text editor.
   - Find the `REVERSED_CLIENT_ID` inside your `GoogleService-Info.plist` (e.g., `com.googleusercontent.apps.1234567890-abcdefg`).
   - Add the following to your `Info.plist`:
     ```xml
     <key>CFBundleURLTypes</key>
     <array>
       <dict>
         <key>CFBundleTypeRole</key>
         <string>Editor</string>
         <key>CFBundleURLSchemes</key>
         <array>
           <string>YOUR_REVERSED_CLIENT_ID_HERE</string>
         </array>
       </dict>
     </array>
     ```

---

## Code Explanation

The code in `lib/main.dart` uses the latest v7 architecture of `google_sign_in`, which has significant differences from older versions.

### 1. Initialization
With v7+, you must explicitly initialize the Google Sign-In singleton before running your app:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // REQUIRED FOR v7+: Initialize the singleton
  await GoogleSignIn.instance.initialize();
  
  runApp(const MyApp());
}
```

### 2. The OAuth Flow (Authentication vs. Authorization)
Version 7 introduces a strict separation between **Identity** (who the user is) and **Permissions** (what scopes they authorize). Firebase requires both an ID token (Identity) and an Access token (Permissions).

```dart
Future<void> signInWithGoogle() async {
  final googleSignIn = GoogleSignIn.instance;

  // STEP 1: Authentication (Identity)
  // This triggers the native UI for account selection.
  final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
  if (googleUser == null) return; // User canceled

  // STEP 2: Extract ID Token
  final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

  // STEP 3: Authorization (Permissions)
  // We explicitly request scopes to generate an Access Token.
  final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);

  // STEP 4: Combine Tokens into a Firebase Credential
  final AuthCredential credential = GoogleAuthProvider.credential(
    idToken: googleAuth.idToken,       // From authentication phase
    accessToken: clientAuth.accessToken, // From authorization phase
  );

  // STEP 5: Sign into Firebase
  await FirebaseAuth.instance.signInWithCredential(credential);
}
```

### 3. State Management
The `AuthGate` widget listens to the `FirebaseAuth.instance.authStateChanges()` stream. 
- If the stream emits a `User`, it means the user is successfully authenticated and is routed to the `HomeScreen`.
- If it emits `null`, the user is logged out and routed to the `LoginScreen`.

### 4. Sign Out
To fully sign out a user, you must sign out from both Google Sign-In and Firebase Authentication to prevent automatic re-authentication loops.
```dart
await GoogleSignIn.instance.signOut();
await FirebaseAuth.instance.signOut();
```
