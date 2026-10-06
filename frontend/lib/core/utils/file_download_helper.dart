import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cross-platform utility to open or download files and reports across Web, Mobile, and Desktop.
class FileDownloadHelper {
  /// Opens a download URL directly in the browser or launches an external application handler.
  /// When the target endpoint serves Content-Disposition: attachment,
  /// desktop and web browsers automatically initiate a file download.
  static Future<bool> openOrDownloadUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      return await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (e) {
      debugPrint('FileDownloadHelper error opening URL ($url): $e');
      return false;
    }
  }
}
