import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import 'models/app.dart';

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
  final AppModel app;
  final String baseUrl;

  FileUploader(this.app, String baseUrl)
    : baseUrl = baseUrl.replaceFirst('ws', 'http');

  String _sanitizeFileName(String filename) {
    var name = filename.replaceAll(RegExp(r'[?#%\/\\]'), '').trim();
    if (name.isEmpty) name = "video";
    return name;
  }

  Future<void> uploadFile(
    File file, {
    required bool isTemp,
    required Function(String message, bool isError) onMessage,
  }) async {
    try {
      final title = _sanitizeFileName(file.path.split('/').last);
      final name = Uri.encodeComponent(title);
      final fileSize = await file.length();

      // send last chunk separately to allow server file streaming while uploading
      final lastChunk = await _uploadLastChunk(file, fileSize, name);
      if (lastChunk.errorId != null) {
        onMessage(lastChunk.info ?? 'Upload failed', true);
        return;
      }
      final url = lastChunk.url!;

      final duration = await _getFileDuration(file);
      if (duration == 0 || duration.isNaN || duration.isInfinite) {
        onMessage('Failed to add video.', true);
        return;
      }

      await _uploadFullFile(
        file: file,
        fileSize: fileSize,
        name: name,
        url: url,
        title: title,
        duration: duration,
        isTemp: isTemp,
        onMessage: onMessage,
      );
    } catch (e) {
      onMessage('Upload error: $e', true);
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

  Future<double> _getFileDuration(File file) async {
    final controller = VideoPlayerController.file(file);
    Duration? duration;
    try {
      await controller.initialize();
      duration = controller.value.duration;
    } catch (e) {
      print(e);
    } finally {
      await controller.dispose();
    }
    if (duration == null) return 0;
    return duration.inMilliseconds / 1000;
  }

  Future<void> _uploadFullFile({
    required File file,
    required int fileSize,
    required String name,
    required String url,
    required String title,
    required double duration,
    required bool isTemp,
    required Function(String message, bool isError) onMessage,
  }) async {
    final client = HttpClient();
    var canceled = false;

    var added = false;
    void ensureAdded() {
      if (added) return;
      added = true;
      app.addUploadedVideo(url, title, duration, true, isTemp);
      app.registerUpload(url, () {
        canceled = true;
        client.close(force: true);
      });
    }

    try {
      final request = await client.postUrl(Uri.parse('$baseUrl/upload'));
      request.headers.set('content-name', name);
      request.headers.set('content-type', 'application/octet-stream');
      request.contentLength = fileSize;

      var uploadedBytes = 0;
      var lastSentRatio = 0.0;
      final stream = file.openRead();

      await request.addStream(
        stream.transform(
          StreamTransformer.fromHandlers(
            handleData: (data, sink) {
              ensureAdded();
              uploadedBytes += data.length;
              final ratio = (uploadedBytes / fileSize).clamp(0.0, 1.0);
              if (ratio - lastSentRatio >= 0.01 || ratio >= 1) {
                lastSentRatio = ratio;
                app.sendProgress('Uploading', ratio, url);
              }
              sink.add(data);
            },
          ),
        ),
      );

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();
      app.unregisterUpload(url);

      UploadResponse data;
      try {
        data = UploadResponse.fromJson(json.decode(responseBody));
      } catch (e) {
        print(e);
        app.sendProgress('Canceled', 0, url);
        return;
      }
      if (data.errorId != null) {
        onMessage(data.info ?? 'Upload failed', true);
        app.sendProgress('Canceled', 0, url);
        return;
      }
      ensureAdded();
      app.sendProgress('Completed', 1, url);
    } catch (e) {
      app.unregisterUpload(url);
      if (!canceled) app.sendProgress('Canceled', 0, url);
    } finally {
      client.close();
    }
  }
}
