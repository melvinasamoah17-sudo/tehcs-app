# TEHCS Flutter App
## Twitch Empire Home Care Service

---

## Project Structure

```
tehcs_app/
├── lib/
│   ├── main.dart                     → App entry point
│   ├── firebase_options.dart         → Firebase config
│   ├── models/
│   │   ├── booking.dart              → Booking data model
│   │   └── chat_message.dart         → Chat message model
│   ├── screens/
│   │   ├── splash_screen.dart        → Loading / splash
│   │   ├── main_screen.dart          → Bottom nav shell
│   │   ├── home_screen.dart          → Home with services & bookings
│   │   ├── services_screen.dart      → All services by category
│   │   ├── booking_screen.dart       → Book a service form
│   │   ├── bookings_screen.dart      → View all bookings
│   │   ├── chat_screen.dart          → Real-time chat
│   │   ├── profile_screen.dart       → User profile & settings
│   │   └── auth/
│   │       ├── login_screen.dart     → Sign in
│   │       └── register_screen.dart  → Create account
│   ├── widgets/
│   │   ├── service_chip.dart         → Service card chip
│   │   ├── booking_card.dart         → Booking summary card
│   │   └── bottom_nav.dart           → Bottom navigation bar
│   └── theme/
│       └── app_theme.dart            → TEHCS brand colors & theme
├── pubspec.yaml                      → Dependencies
└── README.md                         → This file
```

---

## STEP 1 — Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

---

## STEP 2 — Connect to Firebase

Run this in your project folder:

```bash
flutterfire configure
```

- Select project: **tehcs-675c6**
- Select platforms: **Android** and **iOS**
- This generates the correct `firebase_options.dart` automatically

---

## STEP 3 — Install dependencies

```bash
flutter pub get
```

---

## STEP 4 — Create assets folder

```bash
mkdir -p assets/images
```

Copy your TEHCS logo into `assets/images/tehcs.jpg`

---

## STEP 5 — Android setup

In `android/app/build.gradle` make sure:

```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

In `android/app/src/main/AndroidManifest.xml` add internet permission:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.CALL_PHONE"/>
```

---

## STEP 6 — iOS setup

In `ios/Runner/Info.plist` add:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>TEHCS needs access to select photos.</string>
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tel</string>
    <string>whatsapp</string>
    <string>https</string>
</array>
```

---

## STEP 7 — Run the app

```bash
# Android
flutter run

# iOS (Mac only)
flutter run -d ios

# Check for issues
flutter doctor
```

---

## STEP 8 — Build release APK (Android)

```bash
flutter build apk --release
```

APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## STEP 9 — Build for iOS App Store (Mac only)

```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode to archive and submit.

---

## Firebase Firestore Rules

Paste these in Firebase Console → Firestore → Rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /enquiries/{docId} {
      allow create: if true;
      allow read, update, delete: if request.auth != null;
    }

    match /bookings/{docId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null
        && resource.data.uid == request.auth.uid;
    }

    match /clients/{docId} {
      allow create: if request.auth != null;
      allow read, update: if request.auth != null;
    }

    match /chats/{docId} {
      allow read, write: if request.auth != null;
    }

    match /services/{docId} {
      allow read: if true;
      allow create, update, delete: if request.auth != null;
    }

    match /staff/{docId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Brand Colors

| Color  | Hex       | Usage                    |
|--------|-----------|--------------------------|
| Navy   | #1B2B5E   | Primary, buttons, text   |
| Gold   | #F5A623   | Accents, CTA buttons     |
| Red    | #E63329   | Errors, highlights       |
| White  | #FFFFFF   | Backgrounds, cards       |

---

## App Features

| Screen        | Features                                              |
|---------------|-------------------------------------------------------|
| Splash        | Animated logo, auto-redirect based on auth state      |
| Login         | Email/password, forgot password reset                 |
| Register      | Full name, email, phone, password                     |
| Home          | Greeting, stats, service chips, recent bookings       |
| Services      | All 21 services, category tabs, search                |
| Book          | Date/time picker, address, phone, notes, EmailJS      |
| Bookings      | All bookings, filter tabs, progress bar               |
| Chat          | Real-time Firestore chat, quick replies               |
| Profile       | User info, contact links, sign out                    |

---

## Support

- UK:    +44 7448 468070
- Ghana: +233 240 699 329
- Email: twitchempireinfo@gmail.com
- Web:   https://tehcs.com
