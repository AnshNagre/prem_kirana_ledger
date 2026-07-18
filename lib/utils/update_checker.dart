import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class UpdateChecker {
  static const versionJsonUrl =
      'https://raw.githubusercontent.com/AnshNagre/prem_kirana_ledger/main/version.json';

  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(versionJsonUrl));
      if (response.statusCode != 200) return;

      final remote = jsonDecode(response.body);
      final remoteBuild = int.parse(remote['build'].toString());

      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.parse(info.buildNumber);

      if (remoteBuild > currentBuild && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Update Available'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Version ${remote['version']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text("What's new:",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  ...(remote['notes'] as String)
                      .split('\\n')
                      .where((line) => line.trim().isNotEmpty)
                      .map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(line.trim()),
                          )),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
              FilledButton(
                onPressed: () async {
                  final url = Uri.parse(remote['apk_url']);
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      }
    } catch (_) {
      // fail silently — no internet or repo not reachable
    }
  }
}
