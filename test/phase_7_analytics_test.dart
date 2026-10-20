import 'package:flutter_test/flutter_test.dart';
import 'package:studymate_classroom/models/classroom_model.dart';
import 'package:studymate_classroom/models/grade_model.dart';
import 'package:studymate_classroom/services/export_service.dart';

void main() {
  group('Phase 7 - Analytics & Reporting Tests', () {
    test('generateClassroomAnalyticsCsv formats class metrics, student scores and tier rankings accurately', () {
      final classroom = Classroom(
        id: 'cls_test_os',
        teacherId: 'teacher_1',
        teacherName: 'Prof. Tanenbaum',
        name: 'Operating Systems CE',
        subject: 'Computer Engineering',
        code: 'YM5PKF',
        description: 'Undergraduate core OS lecture and lab',
      );

      final students = [
        const StudentGradeSummary(
          studentId: 'stud_1',
          studentName: 'Alice Johnson',
          studentEmail: 'alice@uni.edu',
          studentPhone: '111',
          totalObtained: 92.5,
          totalMax: 100.0,
          assessmentsCount: 4,
        ),
        const StudentGradeSummary(
          studentId: 'stud_2',
          studentName: 'Bob Vance',
          studentEmail: 'bob@uni.edu',
          studentPhone: '222',
          totalObtained: 72.0,
          totalMax: 100.0,
          assessmentsCount: 4,
        ),
        const StudentGradeSummary(
          studentId: 'stud_3',
          studentName: 'Charlie Root',
          studentEmail: 'charlie@uni.edu',
          studentPhone: '333',
          totalObtained: 44.0,
          totalMax: 100.0,
          assessmentsCount: 3,
        ),
      ];

      final avg = (92.5 + 72.0 + 44.0) / 3.0;

      final csv = ExportService.instance.generateClassroomAnalyticsCsv(
        classroom: classroom,
        students: students,
        classAverage: avg,
      );

      expect(csv, contains('Classroom: "Operating Systems CE" ("Computer Engineering")'));
      expect(csv, contains('Code: YM5PKF, Total Students: 3'));
      expect(csv, contains('Student ID,Student Name,Student Email,Assessments Count,Total Obtained,Total Max,Percentage,Tier'));
      expect(csv, contains('stud_1,"Alice Johnson",alice@uni.edu,4,92.5,100.0,92.5%,Distinction'));
      expect(csv, contains('stud_2,"Bob Vance",bob@uni.edu,4,72.0,100.0,72.0%,First Class'));
      expect(csv, contains('stud_3,"Charlie Root",charlie@uni.edu,3,44.0,100.0,44.0%,Needs Support'));
    });
  });
}
