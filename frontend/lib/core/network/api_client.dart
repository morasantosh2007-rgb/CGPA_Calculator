import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 10),
      headers: {
        'Accept': 'application/json',
      },
    ),
  )..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          // Device & Client Isolation Header
          final studentId = prefs.getString('student_id');
          if (studentId != null && studentId.isNotEmpty) {
            options.headers['X-Student-Id'] = studentId;
          }

          final regNo = prefs.getString('registration_number');
          if (regNo != null && regNo.isNotEmpty) {
            options.headers['X-Registration-Number'] = regNo;
          }

          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('access_token');
          }
          return handler.next(error);
        },
      ),
    );

  static Future<bool> hasCompletedSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString('student_id');
    if (studentId != null && studentId.isNotEmpty) {
      return true;
    }

    // Auto-sync existing active profile from backend so new browser runs don't re-prompt
    try {
      final res = await dio.get(ApiConstants.profile);
      if (res.data is Map && res.data['id'] != null) {
        final id = res.data['id'].toString();
        final reg = res.data['registration_number']?.toString() ?? '';
        final name = res.data['full_name']?.toString() ?? '';

        if (id.isNotEmpty) {
          await saveStudentSession(
            studentId: id,
            regNo: reg,
            fullName: name,
          );
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  static Future<void> saveStudentSession({
    required String studentId,
    required String regNo,
    required String fullName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('student_id', studentId);
    await prefs.setString('registration_number', regNo);
    await prefs.setString('student_name', fullName);
  }

  static Future<void> clearStudentSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('student_id');
    await prefs.remove('registration_number');
    await prefs.remove('student_name');
  }

  static Future<String?> getActiveStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('student_id');
  }
}
