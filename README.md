# StudyMate Classroom 🎓
**Cloud-Synchronized Notes Organiser, Subject Material ZIP Importer, Practice Engine & Classroom Grade Manager**

StudyMate Classroom is an Android application built with Flutter (Dart) and powered by **Google Firebase** (**Firebase Authentication** & **Cloud Firestore**). Designed with an educational dual-role architecture (**Student** and **Teacher**), it unites structured subject-wise study notes, interactive practice questions with revealable answers, curriculum material ZIP importing (Subject > Unit > Notes & Practicals), 6-character code-based classroom enrollments, and an assessment grade manager with cumulative percentage metrics.

---

## 🌟 Key Features

### 🔐 Authentication & Role Management (Firebase Auth)
- **Dual User Roles**: Register and login as either a **Student** or a **Teacher**.
- **Secure Cloud Authentication**: Powered by Firebase Authentication (Email/Password).
- **User Document Profile**: Registration stores user details (`fullName`, `email`, `phone`, `role`, `createdAt`) in `users/{uid}` in Cloud Firestore.
- **Graceful Error Mapping**: Friendly error messages for `email-already-in-use`, `wrong-password`, `invalid-credential`, `too-many-requests`, etc.
- **Dedicated Logout**: Logout button with confirmation dialog on both Student and Teacher dashboards.

### 📚 Student Module (4 Bottom Navigation Tabs)
1. **Notes Tab**:
   - Create, edit, delete, search, and pin study notes in `users/{uid}/notes`.
   - Pinned notes dynamically sort to the top.
   - Categorized by academic topics: *Operating Systems*, *Database Management*, *Computer Networks*, *Mathematics*, *Physics*, *Other*.
   - Shortcut on each note card to view topic sample questions.
   - Offline sync indicator showing when snapshots are served from local cache.
2. **Practice Tab**:
   - Filter by academic topic and test comprehension with tap-to-reveal animated answer cards.
   - Real-time updates from the global `questions` collection.
   - Pre-seeded with 20 foundational questions upon first setup.
3. **Library Tab (ZIP Import of Subject Material)**:
   - Pick a `.zip` archive from phone storage.
   - Background isolate extraction parses the multi-tier hierarchy: `Subject > Unit > (Notes / Practicals / questions.json)`.
   - Security protection: Zip-slip prevention (`../` path blocking) and executable skipping (`.exe`, `.bat`, `.apk`, `.sh`).
   - Pre-commit interactive preview tree allows reviewing and renaming subjects before importing.
   - Built-in monospace code/text file viewer with clipboard copy and fallback external app launcher (`open_filex`).
   - Unit completion checkboxes with dynamic progress bars.
   - Full subject and unit management (rename, delete with cascading document cleanup).
   - In-app "How to prepare your ZIP" help dialog explaining the supported directory layout.
4. **Classrooms Tab**:
   - Join classrooms using a unique 6-character join code.
   - Enforce duplicate join prevention and invalid code detection via transactions.
   - View enrolled courses and tap to inspect detailed evaluation grades (marks obtained, maximum marks, percentage, instructor remarks) and overall classroom percentage.

### 🧑‍🏫 Teacher Module (2 Bottom Navigation Tabs)
1. **Classrooms Tab**:
   - Create classrooms (name, subject). The system generates a unique 6-character join code (e.g. `OS301A`) guarded by a Firestore transaction reservation in `codes/{code}`.
   - One-tap copy button with clipboard integration and SnackBar confirmation.
   - Inspect enrolled student rosters showing individual overall percentages.
   - Tap any student to view their evaluation history and award new grades (assessment title, max marks, marks obtained, remarks).
2. **Question Bank Tab**:
   - Author new practice questions and verified answers under any topic.
   - Questions immediately sync to all students' Practice tabs.
   - Filter questions by topic or browse the entire catalog.

---

## 📁 Expected ZIP File Layout

When preparing a study material ZIP archive for import into the Student Library:
```text
<Subject Name>/
  Unit 1 - <Unit Title>/
    notes/
      lecture_notes.pdf
      summary.txt
    practicals/
      lab_experiment1.c
      query.sql
    questions.json        <-- Optional: array of {"question": "...", "answer": "..."}
  Unit 2 - <Unit Title>/
    notes/
      ...
    practicals/
      ...
```

### Flexible Layout Rules:
- **Unit Naming**: Supports `Unit 1 - Basics`, `Unit 2. Concurrency`, `Unit_3`, `Module 1`, etc.
- **Practical Folders**: Supports folder names like `practicals`, `practical`, `lab`, `labs`, `code`, `experiments`.
- **Top-Level Units**: If the archive has no top-level Subject folder and starts directly with `Unit 1`, `Unit 2`, the app detects this and prompts the student to provide or confirm the subject name.
- **Embedded Questions**: If a unit folder contains `questions.json`, its questions are parsed and added directly to the app's practice question bank.
- **Sample ZIP Generator**: Generate a test archive anytime by running:
  ```bash
  dart run tool/make_sample_zip.dart
  ```
  This creates `sample_study_material.zip` in the project root.

---

## 🛠️ Technology Stack & Dependencies

- **Framework**: Flutter 3.47+ (Channel stable)
- **Language**: Dart 3.13+
- **Authentication**: `firebase_auth: ^6.7.0`
- **Database & Sync**: `cloud_firestore: ^6.10.0`
- **Core Firebase**: `firebase_core: ^4.15.0`
- **Archive Extraction**: `archive: ^3.6.1`
- **File Picker**: `file_picker: ^13.1.0`
- **Device Paths**: `path_provider: ^2.1.6`
- **File Opener**: `open_filex: ^5.0.0`
- **Testing & Mocking**: `fake_cloud_firestore: ^4.3.0`, `flutter_test`
- **UI & Design**: Material 3 Light Theme, Indigo primary palette (`#3F51B5`), 12px border radius, 16px standard spacing.

---

## 🚀 Setup & Execution Guide for VS Code

### 1. Prerequisites
1. Install [Visual Studio Code](https://code.visualstudio.com/).
2. Open VS Code Extensions view (`Ctrl+Shift+X` on Windows) and install:
   - **Flutter** (`Dart-Code.flutter`)
   - **Dart** (`Dart-Code.dart-code`)
3. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile) and ensure `flutter/bin` is in your environment `PATH`.
4. Install [Android Studio](https://developer.android.com/studio) or Android Command-line Tools for Android SDK and emulator support.

### 2. Configure Firebase (Mandatory for Live Device / Emulator Execution)
For security and privacy, `firebase_options.dart` and `google-services.json` must be generated for your own Firebase project. Follow the detailed steps in [SETUP_FIREBASE.md](file:///c:/Users/Aarush/Desktop/Notes_manager/Notes-manager/SETUP_FIREBASE.md):

```bash
# 1. Install CLI tools
npm install -g firebase-tools
dart pub global activate flutterfire_cli

# 2. Login to Firebase
firebase login

# 3. Configure FlutterFire (creates lib/firebase_options.dart and android/app/google-services.json)
flutterfire configure

# 4. Deploy security rules
firebase deploy --only firestore:rules
```

> **Note**: If you run the app before configuring Firebase, StudyMate Classroom will display a helpful in-app setup guidance screen (`FirebaseNotConfiguredScreen`) with one-tap clipboard copy buttons instead of crashing.

### 3. Fetch Dependencies
```bash
flutter pub get
```

### 4. Static Analysis & Unit Tests
Verify zero analyzer issues and run the comprehensive automated test suite (48 test cases):
```bash
# Static analysis (reports zero issues)
flutter analyze

# Automated unit tests (48 tests covering Validators, ZIP Parser, and Firestore)
flutter test
```

### 5. Run on Device / Emulator
Select your connected Android device or emulator in the VS Code status bar and run:
```bash
flutter run
```

---

## 🔒 Security Rules & Indexes

- **Security Rules (`firestore.rules`)**: Strict role-based rules protecting `users/{uid}`, `notes`, `subjects`, `units`, `resources`, `classrooms`, `codes`, `grades`, and `questions`. See [firestore.rules](file:///c:/Users/Aarush/Desktop/Notes_manager/Notes-manager/firestore.rules) and [SETUP_FIREBASE.md](file:///c:/Users/Aarush/Desktop/Notes_manager/Notes-manager/SETUP_FIREBASE.md) for full explanations.
- **Composite Indexes (`firestore.indexes.json`)**: Configured for compound queries (e.g. notes ordered by `pinned` desc, `createdAt` desc).

---

## ⚠️ Limitations & Notes

- **SQLite Data Migration**: Legacy local data stored in `sqflite` databases from earlier versions of this project is not automatically migrated to Cloud Firestore.
- **Real Device Execution**: Running the app on a live emulator or phone requires running `flutterfire configure` to generate project-specific Firebase credentials.
