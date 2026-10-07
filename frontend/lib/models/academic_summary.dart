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

  static double _toDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  static int _toInt(dynamic val, [int defaultVal = 0]) {
    if (val == null) return defaultVal;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val) ?? defaultVal;
    return defaultVal;
  }

  factory AcademicSummary.fromJson(Map<String, dynamic> json) {
    return AcademicSummary(
      studentName: json['student_name']?.toString() ?? '',
      registrationNumber: json['registration_number']?.toString() ?? '',
      universityName: json['university_name']?.toString() ?? '',
      cgpa: _toDouble(json['cgpa']),
      totalCreditsCompleted: _toDouble(json['total_credits_completed']),
      totalBacklogsCount: _toInt(json['total_backlogs_count']),
      clearedBacklogsCount: _toInt(json['cleared_backlogs_count']),
      activeBacklogsCount: _toInt(json['active_backlogs_count']),
      highestSgpa: _toDouble(json['highest_sgpa']),
      lowestSgpa: _toDouble(json['lowest_sgpa']),
    );
  }
}
