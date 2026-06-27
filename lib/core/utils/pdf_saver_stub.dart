import 'dart:typed_data';
import 'package:flutter/material.dart';

Future<void> savePdf(
  BuildContext context,
  Uint8List bytes,
  String filename,
) async {
  throw UnsupportedError('Cannot save PDF on this platform');
}
