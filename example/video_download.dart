//TODO: Fixing the console printing.

import 'dart:async';
import 'dart:io';

import 'package:youtube_explode_dart_alpha/youtube_explode_dart_alpha.dart';
import 'package:logging/logging.dart';

// Initialize the YoutubeExplode instance.
final yt = YoutubeExplode();

Future<void> main() async {
  // Enable verbose logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    stdout.writeln('${record.level.name}: ${record.time}: ${record.message}');
  });

  stdout.writeln('Type the video id or url: ');

  final url = stdin.readLineSync()!.trim();
  stdout.writeln('Processing URL: $url');

  // Save the video to the download directory.
  Directory('downloads').createSync();

  try {
    // Download the video.
    await download(url);
    stdout.writeln('Download completed successfully!');
  } catch (e, stackTrace) {
    stdout.writeln('ERROR: Download failed: $e');
    stdout.writeln('Stack trace: $stackTrace');
  }

  yt.close();
  exit(0);
}

Future<void> download(String id) async {
  stdout.writeln('Step 1: Getting video metadata...');
  
  // Get video metadata.
  final video = await yt.videos.get(id);
  stdout.writeln('✓ Video found: "${video.title}"');
  stdout.writeln('  Duration: ${video.duration}');
  stdout.writeln('  Author: ${video.author}');
  stdout.writeln('  Views: ${video.engagement.viewCount}');

  stdout.writeln('\nStep 2: Getting stream manifest...');
  
  // Get the video manifest - AndroidVr client provides direct working URLs
  final manifest = await yt.videos.streams.getManifest(id, ytClients: [
    YoutubeApiClient.androidVr,  // Provides direct working URLs without signature deciphering
    YoutubeApiClient.android,    // Fallback option
  ]);
  
  final streams = manifest.audioOnly;
  stdout.writeln('✓ Found ${streams.length} audio streams');

  // Print all available audio streams
  stdout.writeln('\nAvailable audio streams:');
  for (final stream in streams) {
    stdout.writeln('  - ${stream.tag}: ${stream.container.name}, '
        '${stream.bitrate}, ${stream.size}');
  }

  // Get the audio track with the highest bitrate.
  final audio = streams.withHighestBitrate();
  stdout.writeln('\n✓ Selected best quality: ${audio.container.name}, ${audio.bitrate}, ${audio.size}');
  stdout.writeln('  Stream URL: ${audio.url.toString().substring(0, 100)}...');

  stdout.writeln('\nStep 3: Preparing download...');
  
  final audioStream = yt.videos.streams.get(audio);

  // Compose the file name removing the unallowed characters in windows.
  final fileName = '${video.title}.${audio.container.name}'
      .replaceAll(r'\', '')
      .replaceAll('/', '')
      .replaceAll('*', '')
      .replaceAll('?', '')
      .replaceAll('"', '')
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll(':', '')
      .replaceAll('|', '');
  final file = File('downloads/$fileName');

  stdout.writeln('✓ File will be saved as: $fileName');

  // Delete the file if exists.
  if (file.existsSync()) {
    file.deleteSync();
    stdout.writeln('✓ Deleted existing file');
  }

  // Open the file in writeAppend.
  final output = file.openWrite(mode: FileMode.writeOnlyAppend);

  // Track the file download status.
  final len = audio.size.totalBytes;
  var count = 0;
  var lastProgressUpdate = DateTime.now();

  stdout.writeln('\nStep 4: Starting download...');
  stdout.writeln('Total size: ${(len / 1024 / 1024).toStringAsFixed(2)} MB');
  
  // Create the message and set the cursor position.
  final msg = 'Downloading ${video.title}.${audio.container.name}';
  stdout.writeln(msg);

  try {
    var chunkCount = 0;
    
    // Listen for data received.
    await for (final data in audioStream) {
      chunkCount++;
      
      // Keep track of the current downloaded data.
      count += data.length;

      // Calculate the current progress.
      final progress = (count / len) * 100;
      final downloadedMB = count / 1024 / 1024;
      final totalMB = len / 1024 / 1024;

      // Update progress every second or every 100 chunks
      final now = DateTime.now();
      if (now.difference(lastProgressUpdate).inSeconds >= 1 || chunkCount % 100 == 0) {
        stdout.write('\r[${'=' * (progress / 5).floor()}${' ' * (20 - (progress / 5).floor())}] '
            '${progress.toStringAsFixed(1)}% '
            '(${downloadedMB.toStringAsFixed(2)}/${totalMB.toStringAsFixed(2)} MB) '
            'Chunks: $chunkCount');
        lastProgressUpdate = now;
      }

      // Write to file.
      output.add(data);
    }
    
    stdout.writeln('\n✓ Download stream completed');
    
  } catch (e, stackTrace) {
    stdout.writeln('\n✗ Error during download: $e');
    stdout.writeln('Stack trace: $stackTrace');
    rethrow;
  } finally {
    await output.close();
    stdout.writeln('✓ File closed');
  }

  // Verify file size
  final finalFileSize = file.lengthSync();
  stdout.writeln('✓ Final file size: ${(finalFileSize / 1024 / 1024).toStringAsFixed(2)} MB');
  
  if (finalFileSize == len) {
    stdout.writeln('✓ File size matches expected size - download successful!');
  } else {
    stdout.writeln('⚠ Warning: File size mismatch (expected: ${(len / 1024 / 1024).toStringAsFixed(2)} MB)');
  }
}
