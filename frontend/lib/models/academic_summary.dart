class AcademicSummary {
  final String studentName;
  final String registrationNumber;
  final String universityName;
  final double cgpa;
  final double totalCreditsCompleted;
  final int totalBacklogsCount;
  final int clearedBacklogsCount;
  final int activeBacklogsCount;
  final double highestSgpa;
  final double lowestSgpa;

  AcademicSummary({
    required this.studentName,
    required this.registrationNumber,
    required this.universityName,
    required this.cgpa,
    required this.totalCreditsCompleted,
    required this.totalBacklogsCount,
    required this.clearedBacklogsCount,
    required this.activeBacklogsCount,
    required this.highestSgpa,
    required this.lowestSgpa,
  });

  factory AcademicSummary.fromJson(Map<String, dynamic> json) {
    return AcademicSummary(
      studentName: json['student_name'] ?? '',
      registrationNumber: json['registration_number'] ?? '',
      universityName: json['university_name'] ?? '',
      cgpa: (json['cgpa'] as num?)?.toDouble() ?? 0.0,
      totalCreditsCompleted: (json['total_credits_completed'] as num?)?.toDouble() ?? 0.0,
      totalBacklogsCount: json['total_backlogs_count'] ?? 0,
      clearedBacklogsCount: json['cleared_backlogs_count'] ?? 0,
      activeBacklogsCount: json['active_backlogs_count'] ?? 0,
      highestSgpa: (json['highest_sgpa'] as num?)?.toDouble() ?? 0.0,
      lowestSgpa: (json['lowest_sgpa'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
