class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  // Auth
  static const String login = '$baseUrl/auth/login/';
  static const String register = '$baseUrl/auth/register/';
  static const String me = '$baseUrl/auth/me/';
  static const String refresh = '$baseUrl/auth/refresh/';

  // Students & Profile
  static const String profile = '$baseUrl/students/profile/';
  static const String studentSetup = '$baseUrl/students/setup/';
  static const String universities = '$baseUrl/students/universities/';

  // Grading & Policies
  static const String gradingSystems = '$baseUrl/grading/systems/';
  static const String calculationPolicies = '$baseUrl/grading/policies/';

  // Semesters & Attempts
  static const String semesters = '$baseUrl/semesters/';
  static const String attempts = '$baseUrl/semesters/attempts/';

  // Grade Sheets
  static const String gradeSheets = '$baseUrl/grade-sheets/';
  static const String uploadGradeSheet = '$baseUrl/grade-sheets/upload/';
  static String verifyGradeSheet(String id) => '$baseUrl/grade-sheets/$id/verify/';

  // Calculations & Analytics
  static const String summary = '$baseUrl/calculations/summary/';
  static const String recalculate = '$baseUrl/calculations/recalculate/';
  static const String progression = '$baseUrl/analytics/progression/';
  static const String distribution = '$baseUrl/analytics/distribution/';
  static const String whatIf = '$baseUrl/analytics/what-if/';
  static const String target = '$baseUrl/analytics/target/';

  // Reports
  static const String exportPdf = '$baseUrl/reports/transcript-pdf/';
  static const String exportJson = '$baseUrl/reports/audit-json/';
}
