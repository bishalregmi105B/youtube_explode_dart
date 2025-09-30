import 'dart:convert';

import 'package:meta/meta.dart';

import '../../youtube_explode_dart_alpha.dart';
import '../reverse_engineering/pages/watch_page.dart';
import '../reverse_engineering/player/player_response.dart';

@internal
class VideoController {
  @protected
  final YoutubeHttpClient httpClient;

  VideoController(this.httpClient);

  Future<PlayerResponse> getPlayerResponse(
      VideoId videoId, YoutubeApiClient client,
      {WatchPage? watchPage}) async {
    final payload = client.payload;
    assert(payload['context'] != null, 'client must contain a context');
    assert(payload['context']!['client'] != null,
        'client must contain a context.client');

    final userAgent = payload['context']!['client']!['userAgent'] as String?;
    final ytCfg = watchPage?.ytCfg;

    final body = {
      ...payload,
      'videoId': videoId.value,
      if (ytCfg?.containsKey('STS') ?? false)
        'playbackContext': {
          'contentPlaybackContext': {
            'html5Preference': 'HTML5_PREF_WANTS',
            'signatureTimestamp': ytCfg!['STS'].toString()
          }
        }
    };
    if (body['context']!['client']['clientName'] == 'IOS') {
      body['context']!['client']!['visitorData'] =
          await _extractVisitorData(httpClient, client);
    }

    final content = await httpClient.postString(
      client.apiUrl,
      body: body,
      headers: {
        if (userAgent != null) 'User-Agent': userAgent,
        'X-Youtube-Client-Name': payload['context']!['client']!['clientName'],
        'X-Youtube-Client-Version':
            payload['context']!['client']!['clientVersion'],
        if (ytCfg != null)
          'X-Goog-Visitor-Id': ytCfg['INNERTUBE_CONTEXT']['client']
              ['visitorData'],
        'Origin': 'https://www.youtube.com',
        'Sec-Fetch-Mode': 'navigate',
        'Content-Type': 'application/json',
        if (watchPage != null) 'Cookie': watchPage.cookieString,
        ...client.headers,
      },
    );
    return PlayerResponse.parse(content);
  }

  String? _visitorData;

  Future<String> _extractVisitorData(
      YoutubeHttpClient http, YoutubeApiClient client) async {
    if (_visitorData != null) {
      return _visitorData!;
    }

    try {
      var response =
          await http.getString('https://www.youtube.com/sw.js_data', headers: {
        'User-Agent': client.payload['context']['client']['userAgent']!,
        'Content-Type': 'application/json',
      });

      if (response.startsWith(")]}'")) {
        response = response.substring(4);
      }

      final data = json.decode(response) as List<dynamic>;
      
      // Try different possible locations for visitor data
      String? visitorData;
      try {
        visitorData = data[0][2][0][0][13];
      } catch (e) {
        // Try alternative locations if the structure changed
        try {
          visitorData = data[0][1][0][0][13];
        } catch (e) {
          try {
            visitorData = data[0][2][1][0][13];
          } catch (e) {
            // Generate a fallback visitor data
            visitorData = 'CgtseU5WbE4zZjdDayiDltnGBjIKCgJVUxIEGgAgZg%3D%3D';
          }
        }
      }

      return _visitorData = visitorData!;
    } catch (e) {
      // Fallback visitor data if extraction fails completely
      return _visitorData = 'CgtseU5WbE4zZjdDayiDltnGBjIKCgJVUxIEGgAgZg%3D%3D';
    }
  }
}
