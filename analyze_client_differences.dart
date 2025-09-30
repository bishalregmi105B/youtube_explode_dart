import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final yt = YoutubeExplode();
  
  final clients = [
    ('AndroidVr', YoutubeApiClient.androidVr),
    ('Android', YoutubeApiClient.android),
    ('iOS', YoutubeApiClient.ios),
    ('Safari', YoutubeApiClient.safari),
    ('TV', YoutubeApiClient.tv),
    ('WebEmbedded', YoutubeApiClient.webEmbedded),
    ('AndroidMusic', YoutubeApiClient.androidMusic),
  ];
  
  try {
    print('🔍 Analyzing differences between YouTube API clients...\n');
    
    for (final (name, client) in clients) {
      print('=' * 60);
      print('ANALYZING CLIENT: $name');
      print('=' * 60);
      
      try {
        // Print client configuration
        final payload = client.payload;
        final clientInfo = payload['context']['client'];
        print('Client Name: ${clientInfo['clientName']}');
        print('Client Version: ${clientInfo['clientVersion']}');
        if (clientInfo['userAgent'] != null) {
          print('User Agent: ${clientInfo['userAgent']}');
        }
        if (clientInfo['osName'] != null) {
          print('OS: ${clientInfo['osName']} ${clientInfo['osVersion'] ?? ''}');
        }
        print('API URL: ${client.apiUrl}');
        print('Headers: ${client.headers}');
        
        print('\n--- Testing Stream Extraction ---');
        
        final manifest = await yt.videos.streams.getManifest(
          'fRh_vgS2dFE',
          ytClients: [client],
        );
        
        if (manifest.audioOnly.isNotEmpty) {
          final stream = manifest.audioOnly.withHighestBitrate();
          print('✓ Successfully got ${manifest.audioOnly.length} audio streams');
          print('✓ Best stream: ${stream.bitrate}, ${stream.size}');
          
          // Analyze URL structure
          final url = stream.url;
          final params = url.queryParameters;
          
          print('\n--- URL Analysis ---');
          print('Stream URL length: ${url.toString().length} characters');
          print('Query parameters (${params.length} total):');
          
          // Categorize parameters
          final securityParams = ['sig', 's', 'signature', 'n'];
          final identificationParams = ['id', 'itag', 'videoId'];
          final timingParams = ['expire', 'lmt', 'mt'];
          final qualityParams = ['mime', 'clen', 'dur', 'bitrate'];
          
          for (final param in params.keys) {
            String category = '';
            if (securityParams.contains(param)) {
              category = ' 🔒 SECURITY';
            } else if (identificationParams.contains(param)) {
              category = ' 🆔 ID';
            } else if (timingParams.contains(param)) {
              category = ' ⏰ TIMING';  
            } else if (qualityParams.contains(param)) {
              category = ' 📊 QUALITY';
            }
            
            final value = params[param]!;
            final displayValue = value.length > 50 ? '${value.substring(0, 50)}...' : value;
            print('  $param$category = $displayValue');
          }
          
          // Check what deciphering is needed
          final needsSignature = params.containsKey('s') || params.containsKey('sig');
          final needsNParam = params.containsKey('n');
          final hasDirectSignature = params.containsKey('signature');
          
          print('\n--- Deciphering Requirements ---');
          print('Needs signature deciphering: $needsSignature');
          print('Needs n-parameter deciphering: $needsNParam');
          print('Has direct signature: $hasDirectSignature');
          
          // Test direct access
          print('\n--- Direct Access Test ---');
          final httpClient = http.Client();
          try {
            final response = await httpClient.head(url);
            final status = response.statusCode;
            final contentLength = response.headers['content-length'] ?? '0';
            
            print('HTTP Status: $status');
            print('Content-Length: $contentLength bytes');
            
            if (status == 200) {
              print('✅ SUCCESS: Direct access works!');
              print('🎉 This client provides working URLs without additional processing');
            } else if (status == 403) {
              print('❌ 403 Forbidden: URL needs signature/n-parameter deciphering');
            } else {
              print('❌ Error $status: URL may have other issues');
            }
            
          } catch (e) {
            print('❌ HTTP request failed: $e');
          } finally {
            httpClient.close();
          }
          
        } else {
          print('❌ No audio streams found');
        }
        
      } catch (e, stackTrace) {
        print('❌ Client completely failed: $e');
        if (e.toString().contains('decipher')) {
          print('   → This is likely a signature deciphering issue');
        } else if (e.toString().contains('404')) {
          print('   → API endpoint not found (wrong API key or URL?)');
        } else if (e.toString().contains('unplayable')) {
          print('   → Video marked as unplayable by this client');  
        }
      }
      
      print('\n');
    }
    
  } finally {
    yt.close();
  }
}
