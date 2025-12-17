import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class FileDownloadService {
  static final Dio _dio = Dio();

  static Future<String?> downloadFile({
    required String url,
    required String fileName,
    Function(int, int)? onProgress,
  }) async {
    try {
      // Get app's documents directory (no permission needed)
      final directory = await getApplicationDocumentsDirectory();
      final savePath = '${directory.path}/$fileName';
      
      // Download file
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        deleteOnError: true,
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      
      return savePath;
    } catch (e) {
      print('Download error: $e');
      return null;
    }
  }
}