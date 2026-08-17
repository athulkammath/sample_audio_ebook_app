import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class FileService {
  /// Gets the application documents directory path.
  static Future<String> getAppDocumentsPath() async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Copies an asset from the Flutter bundle to the local filesystem.
  /// Returns the absolute path of the local file.
  static Future<String> copyAssetToFile(String assetPath) async {
    final fileName = assetPath.split('/').last;
    final path = await getAppDocumentsPath();
    final localFile = File('$path/$fileName');

    if (!await localFile.exists()) {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await localFile.writeAsBytes(bytes, flush: true);
    }

    return localFile.path;
  }

  /// Saves bytes to a file in the local storage.
  static Future<File> saveFile(String fileName, List<int> bytes) async {
    final path = await getAppDocumentsPath();
    final file = File('$path/$fileName');
    return await file.writeAsBytes(bytes);
  }

  /// Checks if a file exists.
  static Future<bool> fileExists(String filePath) async {
    return await File(filePath).exists();
  }
}
