import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/api_service.dart';

class MediaPickerHelper {
  /// Opens the native Web / Smartphone Gallery or File selector and returns the chosen HTML File.
  static Future<html.File?> _pickRawHtmlFile({String accept = 'image/*,video/*'}) async {
    if (!kIsWeb) return null;

    final completer = Completer<html.File?>();
    final input = html.FileUploadInputElement()..accept = accept;
    input.style.display = 'none';
    html.document.body?.append(input);

    StreamSubscription<html.Event>? changeSub;
    StreamSubscription<html.Event>? focusSub;

    void finish(html.File? file) {
      changeSub?.cancel();
      focusSub?.cancel();
      try {
        input.remove();
      } catch (_) {}
      if (!completer.isCompleted) {
        completer.complete(file);
      }
    }

    changeSub = input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.isEmpty) {
        finish(null);
      } else {
        finish(files.first);
      }
    });

    // If user closes iOS/Android/Desktop picker without choosing a file, window regains focus.
    focusSub = html.window.onFocus.listen((_) {
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!completer.isCompleted) {
          final files = input.files;
          if (files == null || files.isEmpty) {
            finish(null);
          }
        }
      });
    });

    input.click();
    return completer.future;
  }

  /// Opens the native device gallery and returns a base64 Data URI (legacy/compatibility helper).
  static Future<String?> pickMediaFile({String accept = 'image/*,video/*'}) async {
    final file = await _pickRawHtmlFile(accept: accept);
    if (file == null) return null;
    final reader = html.FileReader();
    final completer = Completer<String?>();
    reader.onLoadEnd.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(reader.result?.toString());
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    reader.readAsDataUrl(file);
    return completer.future;
  }

  /// Uploads a binary File directly via FormData (avoids browser base64 RAM bloat on videos/photos)
  /// and automatically stores to Cloudflare R2 (when configured) or local /uploads.
  static Future<String?> _uploadBinaryMultipart(
    html.File file, {
    String? prefix,
  }) async {
    final completer = Completer<String?>();
    try {
      final formData = html.FormData();
      formData.appendBlob('file', file, file.name);
      if (prefix != null && prefix.isNotEmpty) {
        formData.append('prefix', prefix);
      }
      if (file.type.isNotEmpty) {
        formData.append('mimeType', file.type);
      }

      final xhr = html.HttpRequest();
      xhr.open('POST', '/api/v1/storage/upload-file');
      xhr.onLoadEnd.listen((_) {
        try {
          if (xhr.status != null && xhr.status! >= 200 && xhr.status! < 300) {
            final parsed = jsonDecode(xhr.responseText ?? '{}');
            final url = (parsed['data']?['url'] ?? parsed['url']) as String?;
            if (!completer.isCompleted) completer.complete(url);
            return;
          }
        } catch (_) {}
        if (!completer.isCompleted) completer.complete(null);
      });
      xhr.onError.listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });
      xhr.send(formData);
    } catch (_) {
      if (!completer.isCompleted) completer.complete(null);
    }
    return completer.future;
  }

  /// Picks media directly from device gallery and uploads to Cloudflare R2 / backend storage.
  static Future<String?> pickAndUploadMedia({
    String accept = 'image/*',
    String? filename,
  }) async {
    final file = await _pickRawHtmlFile(accept: accept);
    if (file == null) return null;

    // 1. Prefer raw binary FormData streaming (fast, handles large HD videos & photos cleanly)
    final multipartUrl = await _uploadBinaryMultipart(file, prefix: filename ?? 'media');
    if (multipartUrl != null && multipartUrl.isNotEmpty) {
      return multipartUrl;
    }

    // 2. Fallback to Data URI upload if multipart failed (e.g., very small offline edge)
    final reader = html.FileReader();
    final readCompleter = Completer<String?>();
    reader.onLoadEnd.listen((_) {
      if (!readCompleter.isCompleted) {
        readCompleter.complete(reader.result?.toString());
      }
    });
    reader.onError.listen((_) {
      if (!readCompleter.isCompleted) readCompleter.complete(null);
    });
    reader.readAsDataUrl(file);
    final base64Data = await readCompleter.future;
    if (base64Data == null || base64Data.isEmpty) return null;

    final liveUrl = await ApiService().uploadMedia(base64Data, filename: filename ?? file.name);
    return liveUrl ?? base64Data;
  }
}
