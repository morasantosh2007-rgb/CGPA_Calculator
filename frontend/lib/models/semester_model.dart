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

  factory AcademicAttemptModel.fromJson(Map<String, dynamic> json) {
    return AcademicAttemptModel(
      id: json['id'] ?? '',
      attemptNumber: json['attempt_number'] ?? 1,
      examType: json['exam_type'] ?? 'REGULAR',
      academicSession: json['academic_session'] ?? '',
      isVerified: json['is_verified'] ?? false,
      subjectAttemptsCount: json['subject_attempts_count'] ?? 0,
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

  SemesterModel({
    required this.id,
    required this.semesterNumber,
    required this.academicYear,
    required this.status,
    this.sgpa,
    required this.totalCredits,
    required this.effectiveSubjectsCount,
    required this.attempts,
  });

  factory SemesterModel.fromJson(Map<String, dynamic> json) {
    var rawAttempts = json['attempts'] as List? ?? [];
    List<AcademicAttemptModel> parsedAttempts =
        rawAttempts.map((a) => AcademicAttemptModel.fromJson(a)).toList();

    return SemesterModel(
      id: json['id'] ?? '',
      semesterNumber: json['semester_number'] ?? 1,
      academicYear: json['academic_year'] ?? '',
      status: json['status'] ?? 'COMPLETED',
      sgpa: (json['sgpa'] as num?)?.toDouble(),
      totalCredits: (json['total_credits'] as num?)?.toDouble() ?? 0.0,
      effectiveSubjectsCount: json['effective_subjects_count'] ?? 0,
      attempts: parsedAttempts,
    );
  }
}
