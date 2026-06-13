import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// Prompts for a workspace directory. Desktop-only — returns null on web
/// (no filesystem) and on cancel/error.
Future<String?> pickWorkspaceDirectory() async {
  if (kIsWeb) return null;
  try {
    return await FilePicker.platform.getDirectoryPath(dialogTitle: 'Choose workspace folder');
  } catch (e) {
    debugPrint('Workspace picker failed: $e');
    return null;
  }
}
