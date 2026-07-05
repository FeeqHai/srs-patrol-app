import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../features/notifications/services/notification_service.dart';

const MethodChannel _downloadsChannel = MethodChannel('srs_app/downloads');

Future<void> savePdf(
  BuildContext context,
  Uint8List bytes,
  String filename,
) async {
  try {
    if (Platform.isAndroid) {
      final savedUri = await _downloadsChannel.invokeMethod<String>(
        'savePdfToDownloads',
        {'bytes': bytes, 'filename': filename},
      );
      if (savedUri == null || savedUri.isEmpty) {
        throw Exception('Android did not return a saved file URI.');
      }

      await NotificationService().showDownloadCompleteNotification(
        filePath: savedUri,
        fileName: filename,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fail berjaya disimpan ke folder Download: $filename',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    Directory? directory;
    if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getDownloadsDirectory();
    }

    if (directory == null) {
      throw Exception('Could not find directory to save file.');
    }

    final filePath = '${directory.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    await NotificationService().showDownloadCompleteNotification(
      filePath: filePath,
      fileName: filename,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fail berjaya disimpan ke: $filePath'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan fail: ${e.toString()}')),
      );
    }
  }
}
