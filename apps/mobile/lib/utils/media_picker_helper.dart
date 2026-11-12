import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import '../services/api_service.dart';

class MediaPickerHelper {
  /// Opens the native Web / Smartphone Gallery or File selector and returns the chosen HTML File.
  static Future<html.File?> _pickRawHtmlFile({
    String accept = 'image/*,video/*',
    bool captureCamera = false,
  }) async {
    if (!kIsWeb) return null;

    final completer = Completer<html.File?>();
    final input = html.FileUploadInputElement()..accept = accept;
    if (captureCamera) {
      input.setAttribute('capture', 'environment');
    }
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
      if (files != null && files.isNotEmpty) {
        finish(files.first);
      } else {
        finish(null);
      }
    });

    // Android/iOS safe focus timeout: Give 4 seconds before concluding cancel
    // so mobile OS file pickers have ample time to deliver the file payload.
    focusSub = html.window.onFocus.listen((_) {
      Future.delayed(const Duration(seconds: 4), () {
        if (!completer.isCompleted) {
          final files = input.files;
          if (files != null && files.isNotEmpty) {
            finish(files.first);
          } else {
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
    void Function(double progress)? onProgress,
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

      // Check if running on Vercel: Vercel serverless has a 4.5MB limit on request payloads.
      // Direct stream to the Cloudflare Tunnel endpoint supports up to 250MB HD videos/photos.
      String uploadUrl = '/api/v1/storage/upload-file';
      if (kIsWeb) {
        final host = html.window.location.host;
        if (host.contains('vercel.app')) {
          uploadUrl = 'https://matthew-ozone-competitions-pets.trycloudflare.com/api/v1/storage/upload-file';
        }
      }

      final xhr = html.HttpRequest();
      xhr.open('POST', uploadUrl);

      // Real upload percentage progress
      xhr.upload.onProgress.listen((e) {
        if (e.lengthComputable && e.total != null && e.total! > 0) {
          final fraction = e.loaded! / e.total!;
          onProgress?.call(fraction.clamp(0.0, 0.98));
        }
      });

      xhr.onLoadEnd.listen((_) {
        try {
          if (xhr.status != null && xhr.status! >= 200 && xhr.status! < 300) {
            onProgress?.call(1.0);
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
    bool captureCamera = false,
    void Function(double progress)? onProgress,
  }) async {
    final file = await _pickRawHtmlFile(accept: accept, captureCamera: captureCamera);
    if (file == null) return null;

    onProgress?.call(0.05);

    // 1. Prefer raw binary FormData streaming (fast, handles large HD videos & photos cleanly)
    final multipartUrl = await _uploadBinaryMultipart(
      file,
      prefix: filename ?? 'media',
      onProgress: onProgress,
    );
    if (multipartUrl != null && multipartUrl.isNotEmpty) {
      return multipartUrl;
    }

    // 2. Fallback to Data URI upload if multipart failed
    onProgress?.call(0.5);
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
    onProgress?.call(1.0);
    return liveUrl ?? base64Data;
  }
}
