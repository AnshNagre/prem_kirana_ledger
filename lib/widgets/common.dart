import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The pull-handle bar shown at the top of every bottom sheet.
Widget sheetGrabber([BuildContext? context]) => Builder(
      builder: (ctx) {
        final c = (context ?? ctx).colors;
        return Center(
          child: Container(
            width: 48,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: c.muted.withOpacity(0.35), borderRadius: BorderRadius.circular(3)),
          ),
        );
      },
    );

/// A field wrapped with an uppercase mini-label, matching the HTML form
/// layout (`<label class="...uppercase...">`).
Widget labeledField(BuildContext context, String label, Widget field) {
  final c = context.colors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: c.muted, letterSpacing: 0.8)),
      const SizedBox(height: 6),
      field,
    ],
  );
}

/// Standard rounded text-field decoration used across the app's forms.
InputDecoration formFieldDecoration(BuildContext context, String hint) {
  final c = context.colors;
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: c.muted, fontSize: 13),
    filled: true,
    fillColor: c.bgSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.borderHairline)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.borderHairline)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c.brandPrimary)),
  );
}
