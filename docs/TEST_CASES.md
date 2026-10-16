# StudyMate Classroom - Test Cases & Verification Matrix

This document records the comprehensive test specifications for **StudyMate Classroom**, encompassing automated unit test suites for pure business logic and static validators, as well as end-to-end manual UI verification scenarios across Student and Teacher roles.

---

## 1. Automated Unit Tests (`test/validators_test.dart`)

*Executed via `flutter test` on Flutter 3.47.7 (Dart 3.13.5). Real terminal execution confirmed all 16 test cases passing (0 failures, 0 errors).*

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
| **TC-N1** | Reject name containing numeric digits or symbols | `"John123"` | Error: `"Name must contain letters and spaces only."` | Returned error containing `"Name must contain letters and spaces only."` | **Pass** |
| **TC-N2** | Reject malformed email lacking domain extension | `"not-an-email@domain"` | Error: `"Please enter a valid email address (e.g., student@domain.com)."` | Returned error containing `"valid email address"` | **Pass** |
| **TC-N3** | Reject phone number shorter than 10 digits | `"98765"` | Error: `"Phone number must be exactly 10 digits."` | Returned error containing `"Phone number must be exactly 10 digits."` | **Pass** |
| **TC-N4** | Reject password lacking uppercase character | `"weakpassword1"` | Error: `"Password must contain at least one uppercase letter."` | Returned error containing `"at least one uppercase letter"` | **Pass** |
| **TC-N5** | Reject mismatched confirmation password | Password: `"PassWord123"`, Confirm: `"DifferentPassword456"` | Error: `"Passwords do not match."` | Returned error containing `"Passwords do not match."` | **Pass** |
| **TC-N6** | Reject class code with special characters or invalid length | `"ABC12#"` | Error: `"Classroom code must be exactly 6 letters/digits."` | Returned error containing `"must be exactly 6 letters/digits"` | **Pass** |
| **TC-N7** | Reject maximum marks exceeding ceiling (1000) | `"1500"` | Error: `"Maximum marks must be between 1 and 1000."` | Returned error containing `"between 1 and 1000"` | **Pass** |
| **TC-N8** | Reject marks obtained greater than maximum marks | Marks: `"105"`, MaxMarks: `100.0` | Error: `"Marks obtained cannot exceed maximum marks (100.0)."` | Returned error containing `"cannot exceed maximum marks"` | **Pass** |

---

## 2. Manual UI Test Cases (Physical Device / Emulator Matrix)

*Note: In strict compliance with engineering verification rules, actual execution on a live physical phone or running emulator must be performed by the user/tester on their target hardware. The fields below reflect pre-execution test specifications.*

### 2.1 Positive Manual UI Test Cases

| Test Case ID | Scenario | Input Data | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-UI-P1** | Register new user account as Student | Name: `"Ananya Sharma"`, Email: `"ananya@test.com"`, Phone: `"9876543211"`, Role: `"Student"`, Password: `"StudentPass1"`, Confirm: `"StudentPass1"` | Account created in SQLite `users` table with salted SHA-256 hash; success SnackBar shown; navigated to `StudentHomeScreen`. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P2** | Student Login with valid credentials | Email: `"ananya@test.com"`, Password: `"StudentPass1"` | Salted hash matches stored hash; welcome SnackBar shown; routes to `StudentHomeScreen` with 3 bottom tabs. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P3** | Create and pin a new study note | Title: `"Paging vs Segmentation"`, Topic: `"Operating Systems"`, Content: `"Paging avoids external fragmentation..."`, Pin: Toggled ON | Note saved to SQLite; appears at top of notes list with "PINNED" badge; shows shortcut to sample questions. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P4** | Teacher creates classroom and copies join code | Name: `"CS301 OS Lab"`, Subject: `"Operating Systems"` | Unique 6-character code generated (e.g. `"CS301A"`); displayed on classroom card; tapping "Copy" copies to clipboard with SnackBar. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P5** | Student joins classroom via 6-character code | Code: `"CS301A"` | Enrolled in `enrollments` table; classroom appears in Student's Classrooms tab showing Instructor name. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P6** | Teacher grades student assessment | Title: `"Midterm Exam"`, Max: `"100"`, Marks: `"88"`, Remarks: `"Well structured answers"` | Grade inserted in `grades` table; student overall percentage recalculated; visible in teacher history and student grades screen. | To be filled after device testing | To be filled after device testing |
| **TC-UI-P7** | Interactive Practice question answer reveal | Topic: `"Database Management"`, tap "Tap to reveal answer" | Card animates open to show verified explanation; tapping "Hide" collapses the answer container. | To be filled after device testing | To be filled after device testing |

---

### 2.2 Negative Manual UI Test Cases

| Test Case ID | Scenario | Input Data | Expected Result | Actual Result | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-UI-N1** | Login with incorrect password | Email: `"ananya@test.com"`, Password: `"WrongPass999"` | Login rejected; error SnackBar displayed: `"Incorrect password. Please verify your credentials."`; user remains on login screen. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N2** | Registration with already registered email | Email: `"ananya@test.com"` (already in DB) | Registration rejected; error SnackBar displayed: `"An account with this email address already exists. Please log in or use a different email."` | To be filled after device testing | To be filled after device testing |
| **TC-UI-N3** | Registration form submission with empty fields | All fields left blank, tap "Create Account" | Form validation triggered; descriptive error messages shown under each field; no database call initiated. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N4** | Student attempts to join with invalid class code | Code: `"NONEXIST"` (7 chars) or non-existent `"XYZ999"` | Validation error under field if invalid format, or error SnackBar: `"No classroom found with code \"XYZ999\"."` | To be filled after device testing | To be filled after device testing |
| **TC-UI-N5** | Student attempts duplicate enrollment in same classroom | Student re-enters code of classroom already joined | SQLite UNIQUE enrollment constraint triggered; error SnackBar: `"You are already enrolled in this classroom."` | To be filled after device testing | To be filled after device testing |
| **TC-UI-N6** | Teacher enters marks obtained higher than maximum marks | Max Marks: `"50"`, Marks Obtained: `"65"` | Inline field validation error: `"Marks obtained cannot exceed maximum marks (50.0)."` Dialog save button prevented from submitting. | To be filled after device testing | To be filled after device testing |
| **TC-UI-N7** | Registration with phone number under 10 digits | Phone: `"987654"` | Form field error: `"Phone number must be exactly 10 digits."`; submission blocked. | To be filled after device testing | To be filled after device testing |

