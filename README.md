# StudyMate Classroom 🎓
**Notes Organiser, Practice Questions and Classroom Grade Manager**

StudyMate Classroom is an offline-first Android application built with Flutter (Dart) and SQLite (`sqflite`). Designed with an educational dual-role architecture (**Student** and **Teacher**), it unites structured subject-wise study notes, interactive practice questions with revealable answers, 6-character code-based classroom enrollments, and an assessment grade manager with cumulative percentage computation.

---

## Key Features

### 🔐 Authentication & Security
- **Dual User Roles**: Register and login as either a **Student** or a **Teacher**.
- **Cryptographic Security**: Passwords are saved as salted SHA-256 hashes (`crypto` package); plain text passwords are never stored.
- **Account Validation**: Unique email constraint enforcement with user-friendly duplication error handling.
- **Session Management**: Dedicated logout action with confirmation dialog on both Student and Teacher home screens.

### 📚 Student Module
- **Notes Manager**: Create, edit, delete, search, and pin study notes. Pinned notes dynamically sort to the top.
- **Academic Topics**: Pre-categorized under *Operating Systems*, *Database Management*, *Computer Networks*, *Mathematics*, *Physics*, and *Other*.
- **Sample Questions per Note**: Quick shortcut on each note to inspect practice questions for that note's specific topic.
- **Interactive Practice Tab**: Select any academic topic and test comprehension with tap-to-reveal animated answer cards. Pre-seeded with 20 foundational questions upon first database creation.
- **Joined Classrooms & Grades**: Join classes using a 6-character code. View instructor names, individual assessment scores (marks/max marks and percentage), and cumulative overall percentage.

### 🧑‍🏫 Teacher Module
- **Classroom Creation**: Create courses by title and subject. Automatically generates a unique 6-character join code (e.g., `OS301A`).
- **One-Tap Code Sharing**: Quick copy button to copy the classroom code to the clipboard with visual SnackBar confirmation.
- **Student Roster & Grade Overview**: Inspect enrolled student rosters with each student's contact info and overall percentage badge.
- **Student Evaluation & Grading**: Tap any enrolled student to view their evaluation history and award new marks (assessment title, max marks, marks obtained, remarks).
- **Question Bank Authoring**: Author new practice questions and verified answers under any topic, instantly accessible to students in their Practice tab.

---

## 🛠️ Technology Stack & Dependencies
- **Framework**: Flutter 3.47+ (Channel stable)
- **Language**: Dart 3.13+
- **Database**: Local SQLite via `sqflite: ^2.3.3+1`
- **File System**: `path: ^1.9.0`
- **Security**: `crypto: ^3.0.3` (SHA-256 salted hashing)
- **Theme**: Material 3 Light Theme only, Indigo primary palette (`#3F51B5`), 12px corner radius, 16px standard spacing.

---

## 🚀 Setup & Execution Guide for VS Code

### 1. Prerequisites
1. Install [Visual Studio Code](https://code.visualstudio.com/).
2. Open VS Code Extensions view (`Ctrl+Shift+X` on Windows) and install:
   - **Flutter** (`Dart-Code.flutter`)
   - **Dart** (`Dart-Code.dart-code`)
3. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile) and ensure `flutter/bin` is added to your environment `PATH`.
4. Ensure [Android Studio](https://developer.android.com/studio) or Android Command-line Tools is installed for Android SDK and emulator support.

### 2. Verify Flutter Environment
Open a terminal in the project root and execute:
```bash
flutter doctor
```
Resolve any highlighted issues (e.g., Android toolchain or license acceptance via `flutter doctor --android-licenses`).

### 3. Scaffolding Android Platform (If Platform Folders are Missing)
If cloning into a clean repository where Android platform folders need reconstruction without overwriting `lib/`:
```bash
flutter create --platforms=android .
```

### 4. Fetch Dependencies
Install all required pub packages:
```bash
flutter pub get
```

### 5. Static Analysis & Unit Tests
Verify that there are zero analyzer errors/warnings and run the automated test suite:
```bash
# Static analysis (reports 0 errors and 0 warnings)
flutter analyze

# Automated unit tests (16 test cases covering Validators)
flutter test
```

### 6. Run on an Android Emulator
1. Check available emulators:
   ```bash
   flutter emulators
   ```
2. If no emulator exists, create one via the Flutter CLI or Android Studio Device Manager:
   ```bash
   flutter emulators --create --name Pixel_8_API_34
   ```
3. Launch the emulator:
   ```bash
   flutter emulators --launch Pixel_8_API_34
   ```
4. Verify connected devices:
   ```bash
   flutter devices
   ```
5. Run the application with hot reload:
   ```bash
   flutter run
   ```

### 7. Run on a Physical Android Smartphone
1. On your Android phone, enable **Developer Options**:
   - Go to **Settings** > **About Phone**.
   - Tap **Build Number** 7 times continuously until you see *"You are now a developer!"*.
2. Enable **USB Debugging**:
   - Go to **Settings** > **System / Additional Settings** > **Developer Options**.
   - Toggle **USB Debugging** to ON.
3. Connect your phone to your PC via a USB cable. Accept the *"Allow USB debugging?"* prompt on your phone screen.
4. Verify your phone is detected:
   ```bash
   flutter devices
   ```
5. Deploy and run the app directly on your phone:
   ```bash
   flutter run -d <your-device-id>
   ```

### 8. Build Release APK
To compile the standalone production release APK for Android:
```bash
flutter build apk --release
```
**APK Output Path**:
```
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧪 Testing Matrix & Documentation
- `test/validators_test.dart`: Contains 16 unit tests (`TC-P1`..`TC-P8` positive cases, `TC-N1`..`TC-N8` negative cases).
- `docs/TEST_CASES.md`: Comprehensive test matrix including unit test execution logs and manual UI test scenarios.
- `docs/REPORT.md`: Full academic project report (Chapters 1 to 8) with Mermaid diagrams (Architecture, Flowchart, Use Cases, ER Diagram).

---

## 📁 Project Directory Structure
```
studymate_classroom/
├── android/                   # Android native platform files
├── docs/
│   ├── REPORT.md              # 8-chapter academic project report with Mermaid diagrams
│   └── TEST_CASES.md          # Positive & negative test case matrix
├── lib/
│   ├── models/                # Data entities (User, Note, Classroom, Grade, Question)
│   ├── screens/
│   │   ├── auth/              # LoginScreen, RegisterScreen
│   │   ├── student/           # StudentHomeScreen, NotesTab, PracticeTab, ClassroomsTab, GradesScreen
│   │   └── teacher/           # TeacherHomeScreen, ClassroomsTab, DetailScreen, GradeHistoryScreen, QuestionBankTab
│   ├── services/
│   │   └── database_service.dart # Central SQLite repository with salted SHA-256
│   ├── utils/
│   │   ├── app_exception.dart # Domain AppException class
│   │   ├── app_theme.dart     # Material 3 light theme (Indigo, 12px radius, 16px spacing)
│   │   ├── constants.dart     # Academic topics and 20 seeded practice questions
│   │   └── validators.dart    # Pure static form validators
│   ├── widgets/               # Reusable UI widgets (CustomTextField, PrimaryButton, CustomDialog, EmptyState)
│   └── main.dart              # Application entry point
├── test/
│   └── validators_test.dart   # Unit tests with flutter_test
├── pubspec.yaml               # Project dependencies (sqflite, path, crypto)
└── README.md                  # Setup and execution instructions
```
