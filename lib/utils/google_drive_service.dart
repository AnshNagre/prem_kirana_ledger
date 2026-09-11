import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import 'image_optimizer.dart';

class GoogleDriveService extends ChangeNotifier {
  static final GoogleDriveService instance = GoogleDriveService._internal();
  GoogleDriveService._internal();

  static const String _prefScriptUrl = 'pk_gdrive_script_url';
  static const String _prefLastSync = 'pk_gdrive_last_sync';

  static const String sampleScriptCode = '''function doPost(e) {
  try {
    var data = JSON.parse(e.postData.contents);
    
    // 1. Find or create folder "Prem_Kirana_backup"
    var folders = DriveApp.getFoldersByName("Prem_Kirana_backup");
    var folder = folders.hasNext() ? folders.next() : DriveApp.createFolder("Prem_Kirana_backup");
    
    // 2. Save / update customers_backup.json
    if (data.customers) {
      var files = folder.getFilesByName("customers_backup.json");
      var jsonStr = JSON.stringify(data.customers, null, 2);
      if (files.hasNext()) {
        files.next().setContent(jsonStr);
      } else {
        folder.createFile("customers_backup.json", jsonStr, MimeType.PLAIN_TEXT);
      }
    }
    
    // 3. Save receipt photos into subfolder "photos"
    if (data.photos && Object.keys(data.photos).length > 0) {
      var photoFolders = folder.getFoldersByName("photos");
      var photoFolder = photoFolders.hasNext() ? photoFolders.next() : folder.createFolder("photos");
      
      for (var fileName in data.photos) {
        var base64Data = data.photos[fileName];
        var pFiles = photoFolder.getFilesByName(fileName);
        if (!pFiles.hasNext()) {
          var decoded = Utilities.base64Decode(base64Data);
          var blob = Utilities.newBlob(decoded, "image/jpeg", fileName);
          photoFolder.createFile(blob);
        }
      }
    }
    
    return ContentService.createTextOutput(JSON.stringify({ status: "success", timestamp: new Date().toISOString() }))
      .setMimeType(ContentService.MimeType.JSON);
  } catch (err) {
    return ContentService.createTextOutput(JSON.stringify({ status: "error", message: err.toString() }))
      .setMimeType(ContentService.MimeType.JSON);
  }
}

function doGet(e) {
  return ContentService.createTextOutput(JSON.stringify({ status: "ready", service: "Prem Kirana Ledger Sync" }))
    .setMimeType(ContentService.MimeType.JSON);
}''';

  String? _scriptUrl;
  bool _isSyncing = false;
  String _syncStatus = 'Not Connected';
  DateTime? _lastSyncTime;
  String? _lastError;

  // Track uploaded photo filenames to avoid re-sending large base64 payload
  final Set<String> _syncedPhotoNames = <String>{};

  String? get scriptUrl => _scriptUrl;
  bool get isConnected => _scriptUrl != null && _scriptUrl!.trim().isNotEmpty;
  bool get isSyncing => _isSyncing;
  String get syncStatus => _syncStatus;
  DateTime? get lastSyncTime => _lastSyncTime;
  String? get lastError => _lastError;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _scriptUrl = prefs.getString(_prefScriptUrl);
    final lastSyncMillis = prefs.getInt(_prefLastSync);
    if (lastSyncMillis != null) {
      _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMillis);
    }

    if (isConnected) {
      _syncStatus = _lastSyncTime != null ? 'Connected' : 'Ready to Sync';
    } else {
      _syncStatus = 'Not Connected';
    }
    notifyListeners();
  }

  Future<bool> connectWithUrl(String url, List<Customer> currentData) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty || !cleanUrl.startsWith('http')) {
      _lastError = 'Please enter a valid Google Apps Script Web App URL';
      notifyListeners();
      return false;
    }

    try {
      _lastError = null;
      _syncStatus = 'Connecting...';
      notifyListeners();

      _scriptUrl = cleanUrl;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefScriptUrl, cleanUrl);

      // Perform initial test sync
      await syncData(currentData);
      return true;
    } catch (e) {
      _lastError = e.toString();
      _syncStatus = 'Connection Failed';
      debugPrint('[GoogleDriveService] Connect error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefScriptUrl);
      _scriptUrl = null;
      _syncedPhotoNames.clear();
      _syncStatus = 'Not Connected';
      _lastError = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[GoogleDriveService] Disconnect error: $e');
    }
  }

  /// Automatically syncs customer ledger data and any attached images to Google Drive via the Web App.
  Future<void> syncData(List<Customer> customers) async {
    if (!isConnected) return;
    if (_isSyncing) return;

    _isSyncing = true;
    _syncStatus = 'Syncing...';
    _lastError = null;
    notifyListeners();

    try {
      // 1. Optimize any large photos down to KBs first
      await ImageOptimizer.optimizeAllCustomerImages(customers);

      // 2. Prepare customer JSON
      final customersJson = customers.map((c) => c.toJson()).toList();

      // 3. Gather any unsynced photos as base64
      final photosMap = <String, String>{};
      final allPhotoFiles = <File>[];

      for (final customer in customers) {
        if (customer.photoPath != null && customer.photoPath!.isNotEmpty) {
          final f = File(customer.photoPath!);
          if (f.existsSync()) allPhotoFiles.add(f);
        }
        for (final txn in customer.transactions) {
          if (txn.imagePath != null && txn.imagePath!.isNotEmpty) {
            final f = File(txn.imagePath!);
            if (f.existsSync()) allPhotoFiles.add(f);
          }
        }
      }

      for (final file in allPhotoFiles) {
        final fileName = file.uri.pathSegments.last;
        if (!_syncedPhotoNames.contains(fileName)) {
          try {
            final bytes = await file.readAsBytes();
            // Only send if <= 350 KB to stay within Apps Script request limits
            if (bytes.length <= 350 * 1024) {
              photosMap[fileName] = base64Encode(bytes);
            }
          } catch (e) {
            debugPrint('[GoogleDriveService] Photo encode error: $e');
          }
        }
      }

      final payload = jsonEncode({
        'customers': customersJson,
        'photos': photosMap,
      });

      final response = await http.post(
        Uri.parse(_scriptUrl!),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );

      if (response.statusCode >= 200 && response.statusCode < 400) {
        _syncedPhotoNames.addAll(photosMap.keys);
        _lastSyncTime = DateTime.now();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefLastSync, _lastSyncTime!.millisecondsSinceEpoch);
        _syncStatus = 'Synced just now';
      } else {
        throw Exception('Server returned HTTP ${response.statusCode}');
      }
    } catch (e) {
      _lastError = e.toString();
      _syncStatus = 'Sync error';
      debugPrint('[GoogleDriveService] Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
