import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../models/customer.dart';

class ImageOptimizer {
  /// Compresses and resizes a single image file if it exceeds [maxBytesThreshold] (default 200 KB).
  /// Resizes to max [maxDimension]px (default 1024px) and compresses to [quality]% JPEG (default 70).
  static Future<String?> optimizeImageFile(String? filePath, {int maxBytesThreshold = 200 * 1024, int maxDimension = 1024, int quality = 70}) async {
    if (filePath == null || filePath.trim().isEmpty) return null;
    final file = File(filePath);
    if (!file.existsSync()) return filePath;

    try {
      final fileLength = await file.length();
      // If already below threshold, no compression needed
      if (fileLength <= maxBytesThreshold) {
        return filePath;
      }

      // Run image processing in compute isolate to avoid UI thread lag
      final optimizedBytes = await compute(_compressImageTask, {
        'path': filePath,
        'maxDimension': maxDimension,
        'quality': quality,
      });

      if (optimizedBytes != null && optimizedBytes.isNotEmpty) {
        await file.writeAsBytes(optimizedBytes, flush: true);
        debugPrint('[ImageOptimizer] Compressed $filePath from ${(fileLength / 1024).toStringAsFixed(1)} KB to ${(optimizedBytes.length / 1024).toStringAsFixed(1)} KB');
      }
    } catch (e) {
      debugPrint('[ImageOptimizer] Error optimizing $filePath: $e');
    }
    return filePath;
  }

  /// Scans all customer profile photos and transaction receipt images and compresses any that exceed 200 KB.
  static Future<int> optimizeAllCustomerImages(List<Customer> customers) async {
    int optimizedCount = 0;
    for (final customer in customers) {
      if (customer.photoPath != null) {
        final f = File(customer.photoPath!);
        if (f.existsSync() && (await f.length()) > 200 * 1024) {
          await optimizeImageFile(customer.photoPath);
          optimizedCount++;
        }
      }
      for (final txn in customer.transactions) {
        if (txn.imagePath != null) {
          final f = File(txn.imagePath!);
          if (f.existsSync() && (await f.length()) > 200 * 1024) {
            await optimizeImageFile(txn.imagePath);
            optimizedCount++;
          }
        }
      }
    }
    return optimizedCount;
  }
}

List<int>? _compressImageTask(Map<String, dynamic> params) {
  final path = params['path'] as String;
  final maxDim = params['maxDimension'] as int;
  final quality = params['quality'] as int;

  final file = File(path);
  if (!file.existsSync()) return null;

  final rawBytes = file.readAsBytesSync();
  final image = img.decodeImage(rawBytes);
  if (image == null) return null;

  img.Image resized = image;
  if (image.width > maxDim || image.height > maxDim) {
    if (image.width >= image.height) {
      resized = img.copyResize(image, width: maxDim, interpolation: img.Interpolation.linear);
    } else {
      resized = img.copyResize(image, height: maxDim, interpolation: img.Interpolation.linear);
    }
  }

  return img.encodeJpg(resized, quality: quality);
}
