import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/utils/validators.dart';

void main() {
  group('Validators Positive Test Suite', () {
    test('TC-P1: Valid full name with letters and spaces returns null', () {
      final result = Validators.validateName('Aarush Mishra');
      expect(result, isNull);
    });

    test('TC-P2: Valid standard RFC email address returns null', () {
      final result = Validators.validateEmail('student@university.edu');
      expect(result, isNull);
    });

    test('TC-P3: Valid 10-digit phone number starting with 6-9 returns null', () {
      final result = Validators.validatePhone('9876543210');
      expect(result, isNull);
    });

    test('TC-P4: Valid password with at least 8 chars, 1 uppercase, and 1 digit returns null', () {
      final result = Validators.validatePassword('Password123');
      expect(result, isNull);
    });

    test('TC-P5: Matching confirmation password returns null', () {
      final result = Validators.validateConfirmPassword('SecretPass1', 'SecretPass1');
      expect(result, isNull);
    });

    test('TC-P6: Valid 6-character alphanumeric classroom join code returns null', () {
      final result = Validators.validateClassCode('OS301A');
      expect(result, isNull);
    });

    test('TC-P7: Valid maximum marks between 1 and 1000 returns null', () {
      final result = Validators.validateMaxMarks('100');
      expect(result, isNull);
    });

    test('TC-P8: Valid marks obtained not exceeding maximum returns null', () {
      final result = Validators.validateMarksObtained('85.5', 100.0);
      expect(result, isNull);
    });

    test('TC-P9: Valid subject name between 2 and 50 characters returns null', () {
      final result = Validators.validateSubjectName('Operating Systems');
      expect(result, isNull);
    });

    test('TC-P10: Valid unit title returns null', () {
      final result = Validators.validateUnitTitle('Process Management & Threads');
      expect(result, isNull);
    });

    test('TC-P11: Valid ZIP file under 100MB with .zip extension returns null', () {
      final result = Validators.validateZipFile(fileName: 'materials.zip', sizeInBytes: 1024 * 1024);
      expect(result, isNull);
    });
  });

  group('Validators Negative Test Suite', () {
    test('TC-N1: Name containing numeric digits returns error message', () {
      final result = Validators.validateName('John123');
      expect(result, isNotNull);
      expect(result, contains('Name must contain letters and spaces only.'));
    });

    test('TC-N2: Malformed email missing domain extension returns error message', () {
      final result = Validators.validateEmail('not-an-email@domain');
      expect(result, isNotNull);
      expect(result, contains('valid email address'));
    });

    test('TC-N3: Phone number shorter than 10 digits returns error message', () {
      final result = Validators.validatePhone('98765');
      expect(result, isNotNull);
      expect(result, contains('Phone number must be exactly 10 digits.'));
    });

    test('TC-N4: Password lacking uppercase character returns error message', () {
      final result = Validators.validatePassword('weakpassword1');
      expect(result, isNotNull);
      expect(result, contains('at least one uppercase letter'));
    });

    test('TC-N5: Mismatched confirm password returns error message', () {
      final result = Validators.validateConfirmPassword('PassWord123', 'DifferentPassword456');
      expect(result, isNotNull);
      expect(result, contains('Passwords do not match.'));
    });

    test('TC-N6: Class code not exactly 6 alphanumeric characters returns error message', () {
      final result = Validators.validateClassCode('ABC12#');
      expect(result, isNotNull);
      expect(result, contains('must be exactly 6 letters/digits'));
    });

    test('TC-N7: Maximum marks exceeding 1000 returns error message', () {
      final result = Validators.validateMaxMarks('1500');
      expect(result, isNotNull);
      expect(result, contains('between 1 and 1000'));
    });

    test('TC-N8: Marks obtained exceeding maximum marks returns error message', () {
      final result = Validators.validateMarksObtained('105', 100.0);
      expect(result, isNotNull);
      expect(result, contains('cannot exceed maximum marks'));
    });

    test('TC-N9: Single character subject name returns error message', () {
      final result = Validators.validateSubjectName('A');
      expect(result, isNotNull);
      expect(result, contains('at least 2 characters'));
    });

    test('TC-N10: Subject name exceeding 50 characters returns error message', () {
      final result = Validators.validateSubjectName('A' * 51);
      expect(result, isNotNull);
      expect(result, contains('cannot exceed 50 characters'));
    });

    test('TC-N11: Empty unit title returns error message', () {
      final result = Validators.validateUnitTitle('   ');
      expect(result, isNotNull);
      expect(result, contains('Unit title is required.'));
    });

    test('TC-N12: File without .zip extension returns error message', () {
      final result = Validators.validateZipFile(fileName: 'document.pdf', sizeInBytes: 5000);
      expect(result, isNotNull);
      expect(result, contains('must have a .zip extension'));
    });

    test('TC-N13: Zero byte ZIP file returns error message', () {
      final result = Validators.validateZipFile(fileName: 'archive.zip', sizeInBytes: 0);
      expect(result, isNotNull);
      expect(result, contains('empty'));
    });

    test('TC-N14: ZIP file exceeding 100MB returns error message', () {
      final result = Validators.validateZipFile(
        fileName: 'huge.zip',
        sizeInBytes: 101 * 1024 * 1024,
      );
      expect(result, isNotNull);
      expect(result, contains('exceeds the maximum size limit of 100 MB'));
    });
  });
}

