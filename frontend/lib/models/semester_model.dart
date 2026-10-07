class AcademicAttemptModel {
  final String id;
  final int attemptNumber;
  final String examType;
  final String academicSession;
  final bool isVerified;
  final int subjectAttemptsCount;

  AcademicAttemptModel({
    required this.id,
    required this.attemptNumber,
    required this.examType,
    required this.academicSession,
    required this.isVerified,
    required this.subjectAttemptsCount,
  });

  static int _toInt(dynamic val, [int defaultVal = 0]) {
    if (val == null) return defaultVal;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  factory AcademicAttemptModel.fromJson(Map<String, dynamic> json) {
    return AcademicAttemptModel(
      id: json['id']?.toString() ?? '',
      attemptNumber: _toInt(json['attempt_number'], 1),
      examType: json['exam_type']?.toString() ?? 'REGULAR',
      academicSession: json['academic_session']?.toString() ?? '',
      isVerified: json['is_verified'] == true || json['is_verified']?.toString().toLowerCase() == 'true',
      subjectAttemptsCount: _toInt(json['subject_attempts_count'], 0),
    );
  }
}

class EffectiveSubjectModel {
  final String id;
  final String subjectCode;
  final String subjectName;
  final String grade;
  final double gradePoint;
  final double credits;
  final bool isPass;

  EffectiveSubjectModel({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.grade,
    required this.gradePoint,
    required this.credits,
    required this.isPass,
  });

  factory EffectiveSubjectModel.fromJson(Map<String, dynamic> json) {
    return EffectiveSubjectModel(
      id: json['id']?.toString() ?? '',
      subjectCode: json['subject_code']?.toString() ?? '',
      subjectName: json['subject_name']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
      gradePoint: SemesterModel._toDouble(json['grade_point']),
      credits: SemesterModel._toDouble(json['credits']),
      isPass: json['is_pass'] == true || json['is_pass']?.toString().toLowerCase() == 'true',
    );
  }
}

class SemesterModel {
  final String id;
  final int semesterNumber;
  final String academicYear;
  final String status;
  final double? sgpa;
  final double totalCredits;
  final int effectiveSubjectsCount;
  final List<AcademicAttemptModel> attempts;
  final List<EffectiveSubjectModel> effectiveSubjects;

  SemesterModel({
    required this.id,
    required this.semesterNumber,
    required this.academicYear,
    required this.status,
    this.sgpa,
    required this.totalCredits,
    required this.effectiveSubjectsCount,
    required this.attempts,
    this.effectiveSubjects = const [],
  });

  static double? _toDoubleOrNull(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  static int _toInt(dynamic val, [int defaultVal = 1]) {
    if (val == null) return defaultVal;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  factory SemesterModel.fromJson(Map<String, dynamic> json) {
    var rawAttempts = json['attempts'] as List? ?? [];
    List<AcademicAttemptModel> parsedAttempts =
        rawAttempts.map((a) => AcademicAttemptModel.fromJson(a as Map<String, dynamic>)).toList();

    var rawSubjects = json['effective_subjects'] as List? ?? [];
    List<EffectiveSubjectModel> parsedSubjects =
        rawSubjects.map((s) => EffectiveSubjectModel.fromJson(s as Map<String, dynamic>)).toList();

    return SemesterModel(
      id: json['id']?.toString() ?? '',
      semesterNumber: _toInt(json['semester_number'], 1),
      academicYear: json['academic_year']?.toString() ?? '',
      status: json['status']?.toString() ?? 'COMPLETED',
      sgpa: _toDoubleOrNull(json['sgpa']),
      totalCredits: _toDouble(json['total_credits']),
      effectiveSubjectsCount: _toInt(json['effective_subjects_count'], 0),
      attempts: parsedAttempts,
      effectiveSubjects: parsedSubjects,
    );
  }
}
