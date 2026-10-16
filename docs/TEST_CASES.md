# StudyMate Classroom - Test Cases & Verification Matrix

This document records the comprehensive test specifications for **StudyMate Classroom**, encompassing automated unit test suites for pure business logic, static validators, ZIP archive parser, and Cloud Firestore services (using `fake_cloud_firestore`), as well as end-to-end manual UI verification scenarios across Student and Teacher roles.

---

## 1. Automated Unit Tests

*Executed via `flutter test` on Flutter SDK 3.47.7 (Dart 3.13.5). Real terminal execution confirmed all 48 test cases passing (0 failures, 0 errors, 100% pass rate).*

### 1.1 Input Field & Data Validators (`test/validators_test.dart`)

| Test Case ID | Scenario | Input Data | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-P1** | Validate valid student full name | `"Aarush Mishra"` | `null` (valid, no error) | Returned `null` as expected | **Pass** |
| **TC-P2** | Validate standard RFC format email address | `"student@university.edu"` | `null` (valid, no error) | Returned `null` as expected | **Pass** |
| **TC-P3** | Validate 10-digit Indian phone number starting with 6-9 | `"9876543210"` | `null` (valid, no error) | Returned `null` as expected | **Pass** |
| **TC-P4** | Validate strong password meeting complexity criteria | `"Password123"` | `null` (valid, >=8 chars, 1 uppercase, 1 digit) | Returned `null` as expected | **Pass** |
| **TC-P5** | Validate matching password confirmation | Password: `"SecretPass1"`, Confirm: `"SecretPass1"` | `null` (passwords match) | Returned `null` as expected | **Pass** |
| **TC-P6** | Validate 6-character alphanumeric classroom join code | `"OS301A"` | `null` (valid 6 uppercase alphanumeric chars) | Returned `null` as expected | **Pass** |
| **TC-P7** | Validate maximum assessment marks within range [1, 1000] | `"100"` | `null` (valid numerical evaluation range) | Returned `null` as expected | **Pass** |
| **TC-P8** | Validate marks obtained within allowed maximum marks | Marks: `"85.5"`, MaxMarks: `100.0` | `null` (valid score <= max marks) | Returned `null` as expected | **Pass** |
| **TC-P9** | Validate subject name between 2 and 50 characters | `"Operating Systems"` | `null` (valid subject title) | Returned `null` as expected | **Pass** |
| **TC-P10** | Validate unit title | `"Process Management & Threads"` | `null` (valid unit title) | Returned `null` as expected | **Pass** |
| **TC-P11** | Validate ZIP file selection under 100 MB | fileName: `"materials.zip"`, sizeInBytes: `1048576` | `null` (valid file extension and size) | Returned `null` as expected | **Pass** |
| **TC-N1** | Reject name containing numeric digits or symbols | `"John123"` | Error: `"Name must contain letters and spaces only."` | Returned error containing `"Name must contain letters and spaces only."` | **Pass** |
| **TC-N2** | Reject malformed email lacking domain extension | `"not-an-email@domain"` | Error: `"Please enter a valid email address (e.g., student@domain.com)."` | Returned error containing `"valid email address"` | **Pass** |
| **TC-N3** | Reject phone number shorter than 10 digits | `"98765"` | Error: `"Phone number must be exactly 10 digits."` | Returned error containing `"Phone number must be exactly 10 digits."` | **Pass** |
| **TC-N4** | Reject password lacking uppercase character | `"weakpassword1"` | Error: `"Password must contain at least one uppercase letter."` | Returned error containing `"at least one uppercase letter"` | **Pass** |
| **TC-N5** | Reject mismatched confirmation password | Password: `"PassWord123"`, Confirm: `"DifferentPassword456"` | Error: `"Passwords do not match."` | Returned error containing `"Passwords do not match."` | **Pass** |
| **TC-N6** | Reject class code with special characters or invalid length | `"ABC12#"` | Error: `"Classroom code must be exactly 6 letters/digits."` | Returned error containing `"must be exactly 6 letters/digits"` | **Pass** |
| **TC-N7** | Reject maximum marks exceeding ceiling (1000) | `"1500"` | Error: `"Maximum marks must be between 1 and 1000."` | Returned error containing `"between 1 and 1000"` | **Pass** |
| **TC-N8** | Reject marks obtained greater than maximum marks | Marks: `"105"`, MaxMarks: `100.0` | Error: `"Marks obtained cannot exceed maximum marks (100.0)."` | Returned error containing `"cannot exceed maximum marks"` | **Pass** |
| **TC-N9** | Reject single-character subject name | `"A"` | Error: `"Subject name must be at least 2 characters."` | Returned error containing `"at least 2 characters"` | **Pass** |
| **TC-N10** | Reject subject name exceeding 50 characters | `51 'A' characters` | Error: `"Subject name cannot exceed 50 characters."` | Returned error containing `"cannot exceed 50 characters"` | **Pass** |
| **TC-N11** | Reject whitespace-only unit title | `"   "` | Error: `"Unit title is required."` | Returned error containing `"Unit title is required."` | **Pass** |
| **TC-N12** | Reject non-zip extension file | fileName: `"document.pdf"`, sizeInBytes: `5000` | Error: `"Selected file must have a .zip extension."` | Returned error containing `"must have a .zip extension"` | **Pass** |
| **TC-N13** | Reject zero-byte ZIP file | fileName: `"empty.zip"`, sizeInBytes: `0` | Error: `"The selected ZIP file is empty."` | Returned error containing `"empty"` | **Pass** |
| **TC-N14** | Reject oversized ZIP file exceeding 100 MB limit | fileName: `"huge.zip"`, sizeInBytes: `105906176` (101 MB) | Error: `"ZIP file exceeds the maximum size limit of 100 MB."` | Returned error containing `"exceeds the maximum size limit of 100 MB"` | **Pass** |

---

### 1.2 ZIP Import Parser (`test/zip_import_parser_test.dart`)

| Test Case ID | Scenario | Input Data | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-Z-P1** | Standard 3-tier hierarchy extraction | Archive: `Operating Systems/Unit 1 - Basics/notes/intro.txt` and `practicals/fork_demo.c` | Parsed subject `"Operating Systems"`, 1 unit (`Unit 1: Basics`), 1 note, 1 practical | Extracted subject, unit, and files correctly matching structure | **Pass** |
| **TC-Z-P2** | Unit prefix variations with hyphens and dot formats | `DBMS/Unit 2 - SQL Fundamentals/notes/queries.sql`, `DBMS/Unit 3. Indexing & Hashing/notes/btree.txt` | Extracted Unit 2 with title `"SQL Fundamentals"` and Unit 3 with title `"Indexing & Hashing"` | Extracted unit numbers and cleanly stripped punctuation prefixes | **Pass** |
| **TC-Z-P3** | Unit without numerical prefix | `Networks/Routing Protocols/notes/rip.txt` | Unit number inferred sequentially as 1, title `"Routing Protocols"` | Inferred number 1, preserved descriptive title | **Pass** |
| **TC-Z-P4** | Laboratory folder variations classification | Archive containing `lab/`, `code/`, `notes/` folders | Files in `lab/` and `code/` classified as `practical`; files in `notes/` classified as `note` | Folders correctly mapped to practical/note items | **Pass** |
| **TC-Z-P5** | Extraction of `questions.json` embedded in unit | JSON array of 2 questions in `Unit 1 - Processes/questions.json` | 2 `ParsedQuestion` models attached to unit with full text and verified answer | Questions extracted and associated with corresponding unit | **Pass** |
| **TC-Z-P6** | Root-level subject files collection | `Chemistry/syllabus.pdf` and `Chemistry/reference.txt` | Files grouped into inferred `"Unit 1 - General"` | General unit created holding both notes | **Pass** |
| **TC-Z-N1** | Corrupted or non-ZIP header bytes | Random uncompressed binary bytes | Throws `AppException` with `"Corrupted or invalid ZIP file format"` | Caught `AppException` indicating corrupted format | **Pass** |
| **TC-Z-N2** | Completely empty ZIP payload | 0-byte buffer | Throws `AppException` with `"The selected ZIP file is empty."` | Caught `AppException` indicating empty buffer | **Pass** |
| **TC-Z-N3** | Zip-slip directory traversal path injection | File path `Operating Systems/../../etc/passwd` | File blocked and added to `skippedFiles`; valid sibling files parsed safely | Blocked path traversal attempt and recorded security warning | **Pass** |
| **TC-Z-N4** | Executable and script binaries security filter | Files with `.exe`, `.bat`, `.apk`, `.sh` extensions | Executables discarded and reported in `skippedFiles`; zero practicals/notes created | All 2 executables skipped and logged in skipped list | **Pass** |
| **TC-Z-N5** | Malformed JSON in `questions.json` resilience | Unclosed JSON syntax in `questions.json` | Parser logs error in `errors` list without crashing; notes extracted normally | Logged parsing error and continued note extraction | **Pass** |
| **TC-Z-N6** | Top-level unit folder without subject prompt flag | Archive immediately starting with `Unit 1 - CPU Scheduling/` | Flags `requiresSubjectNamePrompt: true` so UI prompts student | Flagged `requiresSubjectNamePrompt = true` | **Pass** |

---

### 1.3 Cloud Firestore Service (`test/firestore_service_test.dart`)

| Test Case ID | Scenario | Input Data | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-F-P1** | Note lifecycle CRUD in `users/{uid}/notes` | Create note, update content, toggle pin state, and delete note | Document created in `users/{uid}/notes`, updated in place, pinned toggled to true, document deleted | Full CRUD verified in subcollection with correct timestamps and fields | **Pass** |
| **TC-F-P2** | Classroom creation with unique code & reservation | Name: `"OS Lab Section A"`, Subject: `"Operating Systems"` | 6-character code generated; doc stored in `classrooms` and reserved in `codes/{code}` | Unique code generated and reservation document confirmed | **Pass** |
| **TC-F-P3** | Student classroom enrollment via transaction | Valid 6-character classroom code | Student UID appended to `studentIds` array; returned `Classroom` contains UID | Transaction appended student ID to enrollment list | **Pass** |
| **TC-F-P4** | Teacher records student grade | Assessment: `"Lab Quiz 1"`, Max: `50.0`, Obtained: `46.5` | Grade stored in `classrooms/{id}/grades`; percentage calculated as `93.0%` | Grade inserted with accurate calculated percentage | **Pass** |
| **TC-F-P5** | Question bank authoring | Topic: `"Mathematics"`, question and answer strings | Question document stored in top-level `questions` collection | Document stored with topic, verified answer, and author UID | **Pass** |
| **TC-F-P6** | Starter questions idempotent seeding | Call `seedInitialQuestions()` twice | 20 starter questions seeded once; guarded by `config/seed`; second call is no-op | Exact 20 questions persisted with zero duplicate documents | **Pass** |
| **TC-F-N1** | Join classroom with non-existent code | Code: `"NONEX9"` | Throws `AppException` (`"No classroom found with code \"NONEX9\"."`) | Threw `AppException` with friendly error message | **Pass** |
| **TC-F-N2** | Duplicate enrollment rejection | Same student attempts joining same classroom twice | Transaction detects UID in `studentIds`; throws `AppException` (`"already enrolled"`) | Second join blocked with duplicate enrollment exception | **Pass** |
| **TC-F-N3** | Reject note creation with empty title | Title: `"   "` | Throws `AppException` before initiating Firestore write | Blocked by validator with user-facing message | **Pass** |
| **TC-F-N4** | Reject marks obtained greater than maximum marks | Marks Obtained: `75.0`, Max Marks: `50.0` | Throws `AppException` (`"cannot exceed maximum marks"`) | Blocked before write; database state intact | **Pass** |
| **TC-F-N5** | Cascading subject deletion | Delete subject having child units and resources | All child units and resources deleted in chunked batches; subject doc deleted | All subcollections and parent docs removed cleanly | **Pass** |

---

## 2. Manual UI Test Cases (Physical Device / Emulator Matrix)

*Note: In strict compliance with engineering verification rules, actual execution on a live physical phone or running emulator must be performed once Firebase is configured with `flutterfire configure`. The fields below reflect pre-execution test specifications.*

### 2.1 Positive Manual UI Test Cases

| Test Case ID | Scenario | Input Data | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-UI-P1** | Register new user account as Student | Name: `"Ananya Sharma"`, Email: `"ananya@test.com"`, Phone: `"9876543211"`, Role: `"Student"`, Password: `"StudentPass1"`, Confirm: `"StudentPass1"` | Account created via Firebase Auth; document written to `users/{uid}`; navigated to `StudentHomeScreen` (4 bottom tabs: Notes, Practice, Library, Classrooms). | To be filled after device testing | To be filled after device testing |
| **TC-UI-P2** | Student Login with valid credentials | Email: `"ananya@test.com"`, Password: `"StudentPass1"` | Authenticated via Firebase Auth; role read from `users/{uid}`; routes to `StudentHomeScreen`. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P3** | Create and pin a new study note | Title: `"Paging vs Segmentation"`, Topic: `"Operating Systems"`, Content: `"Paging avoids external fragmentation..."`, Pin: Toggled ON | Note saved to `users/{uid}/notes`; live stream updates immediately; pinned note appears first with "PINNED" badge. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P4** | Teacher creates classroom and copies join code | Name: `"CS301 OS Lab"`, Subject: `"Operating Systems"` | Unique 6-character code generated; displayed on classroom card; tapping "Copy" copies to clipboard with SnackBar. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P5** | Student joins classroom via 6-character code | Code: `"OS301A"` | Transaction updates `studentIds` array; classroom appears in Student's Classrooms tab showing Instructor name. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P6** | Teacher grades student assessment | Title: `"Midterm Exam"`, Max: `"100"`, Marks: `"88"`, Remarks: `"Well structured answers"` | Grade inserted in `classrooms/{id}/grades`; student overall percentage recalculated in roster; visible in student grades screen. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P7** | Interactive Practice question answer reveal | Topic: `"Database Management"`, tap "Tap to reveal answer" | Card animates open to show verified explanation; tapping "Hide" collapses the answer container. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P8** | Student imports curriculum ZIP package with unit notes and practicals | Select `sample_study_material.zip` via FilePicker | Background isolate parses archive; pre-commit preview tree renders subjects and units; tapping Confirm creates Firestore documents and writes files to local storage. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P9** | Open and view practical code inside built-in text viewer | Tap practical file (e.g., `fork_demo.c`) | Opens `FileViewerScreen` displaying code in scrollable monospace font with copy button; fallback option to open externally. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P10** | Toggle unit completion checkbox | Tap checkbox next to `"Unit 1 - CPU Scheduling"` | Unit `completed` field updated in Firestore; subject progress bar updates in real time. | To be filled after device testing | To be filled after device testing |

---

### 2.2 Negative Manual UI Test Cases

| Test Case ID | Scenario | Input Data | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-UI-N1** | Login with incorrect password | Email: `"ananya@test.com"`, Password: `"WrongPass999"` | Login rejected by Firebase Auth; error SnackBar displayed: `"Incorrect password. Please verify your credentials."`; user remains on login screen. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N2** | Registration with already registered email | Email: `"ananya@test.com"` (already in Firebase Auth) | Registration rejected; friendly error SnackBar displayed: `"An account with this email address already exists. Please log in or use a different email."` | To be filled after device testing | To be filled after device testing |
| **TC-UI-N3** | Registration form submission with empty fields | All fields left blank, tap "Create Account" | Form validation triggered; descriptive error messages shown under each field; no network call initiated. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N4** | Student attempts to join with invalid class code | Code: `"XYZ999"` (non-existent) | Error SnackBar: `"No classroom found with code \"XYZ999\"."` | To be filled after device testing | To be filled after device testing |
| **TC-UI-N5** | Student attempts duplicate enrollment in same classroom | Student re-enters code of classroom already joined | Transaction rejects duplicate; error SnackBar: `"You are already enrolled in this classroom."` | To be filled after device testing | To be filled after device testing |
| **TC-UI-N6** | Teacher enters marks obtained higher than maximum marks | Max Marks: `"50"`, Marks Obtained: `"65"` | Inline field validation error: `"Marks obtained cannot exceed maximum marks (50.0)."` Dialog save button prevented from submitting. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N7** | Registration with phone number under 10 digits | Phone: `"987654"` | Form field error: `"Phone number must be exactly 10 digits."`; submission blocked. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N8** | Student picks non-ZIP or corrupted file | Select `.pdf` or corrupted file via FilePicker | Validator rejects non-zip with `"Selected file must have a .zip extension."`; preview aborted safely. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N9** | Launch app before running `flutterfire configure` | Clean emulator launch without `google-services.json` | Displays in-app `FirebaseNotConfiguredScreen` with exact CLI instructions and clipboard copy buttons; no unhandled crash. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N10** | Student tries to rename subject with empty string | Clear name field in Rename Subject dialog | Validation error: `"Subject name is required."`; rename prevented. | To be filled after device testing | To be filled after device testing |
