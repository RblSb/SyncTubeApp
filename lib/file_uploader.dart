import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class UploadResponse {
  final String? url;
  final String? errorId;
  final String? info;

  UploadResponse({this.url, this.errorId, this.info});

  factory UploadResponse.fromJson(Map<String, dynamic> json) {
    return UploadResponse(
      url: json['url'],
      errorId: json['errorId'],
      info: json['info'],
    );
  }
}

class FileUploader {
  final String baseUrl;
  final ValueNotifier<double> uploadProgress = ValueNotifier<double>(0.0);

  FileUploader(String baseUrl) : baseUrl = baseUrl.replaceFirst('ws', 'http');

  String _sanitizeFileName(String filename) {
    var name = filename.replaceAll(RegExp(r'[?#%\/\\]'), '').trim();
    if (name.isEmpty) name = "video";
    return Uri.encodeComponent(name);
  }

  Future<UploadResponse?> uploadFile(
    File file, {
    required Function(String url) onLastChunkUploaded,
    required Function(String message, bool isError) onMessage,
  }) async {
    try {
      final filename = _sanitizeFileName(file.path.split('/').last);
      final fileSize = await file.length();

      // Upload last chunk first (read only the last chunk)
      final lastChunkResponse = await _uploadLastChunk(
        file,
        fileSize,
        filename,
      );

      if (lastChunkResponse.errorId != null) {
        onMessage(lastChunkResponse.info ?? 'Upload failed', true);
        return lastChunkResponse;
      } else {
        onLastChunkUploaded(lastChunkResponse.url!);
      }

      // Upload full file with streaming
      await _uploadFullFile(file, fileSize, filename, onMessage);

      return lastChunkResponse;
    } catch (e) {
      onMessage('Upload error: $e', true);
      return null;
    }
  }

  Future<UploadResponse> _uploadLastChunk(
    File file,
    int fileSize,
    String filename,
  ) async {
    const chunkSize = 5 * 1024 * 1024; // 5 MB
    final bufferOffset = (fileSize - chunkSize).clamp(0, fileSize);

    // Read only the last chunk from file
    final lastChunkBytes = await _readFileChunk(file, bufferOffset, fileSize);

    final response = await http.post(
      Uri.parse('$baseUrl/upload-last-chunk'),
      headers: {
        'content-name': filename,
        'content-type': 'application/octet-stream',
      },
      body: lastChunkBytes,
    );

    if (response.statusCode == 200) {
      return UploadResponse.fromJson(json.decode(response.body));
    } else {
      return UploadResponse(
        errorId: 'HTTP_ERROR',
        info: 'Upload failed with status: ${response.statusCode}',
      );
    }
  }

  Future<Uint8List> _readFileChunk(File file, int start, int end) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      await raf.setPosition(start);
      final length = end - start;
      final bytes = await raf.read(length);
      return bytes;
    } finally {
      await raf.close();
    }
  }

  Future<void> _uploadFullFile(
    File file,
    int fileSize,
    String filename,
    Function(String message, bool isError)? onMessage,
  ) async {
    try {
      final client = HttpClient();
      final request = await client.postUrl(Uri.parse('$baseUrl/upload'));

      request.headers.set('content-name', filename);
      request.headers.set('content-type', 'application/octet-stream');
      request.contentLength = fileSize;

      // Stream file with progress tracking
      var uploadedBytes = 0;
      final stream = file.openRead();

      await request.addStream(
        stream.transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              uploadedBytes += data.length;
              final progress = uploadedBytes / fileSize;
              uploadProgress.value = progress.clamp(0.0, 1.0);
              sink.add(data);
            },
          ),
        ),
      );

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        try {
          final data = UploadResponse.fromJson(json.decode(responseBody));
          if (data.errorId != null) {
            onMessage?.call(data.info ?? 'Upload completed with error', true);
          }
        } catch (e) {
          // Response might not be JSON, that's okay
        }
      } else {
        onMessage?.call('Upload failed: ${response.statusCode}', true);
      }

      client.close();
    } catch (e) {
      onMessage?.call('Upload error: $e', true);
    }

    // Reset progress after a delay
    Future.delayed(const Duration(milliseconds: 500), () {
      uploadProgress.value = 0.0;
    });
  }

  void dispose() {
    uploadProgress.dispose();
  }
}
