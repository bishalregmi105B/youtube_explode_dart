class YoutubeApiClient {
  final Map<String, dynamic> payload;
  final String apiUrl;
  final Map<String, dynamic> headers;

  const YoutubeApiClient(this.payload, this.apiUrl, {this.headers = const {}});

  YoutubeApiClient.fromJson(Map<String, dynamic> json)
      : payload = json['payload'],
        apiUrl = json['apiUrl'],
        headers = json['headers'];

  Map<String, dynamic> toJson() => {
        'payload': payload,
        'apiUrl': apiUrl,
        'headers': headers,
      };

  // Updated with latest client versions as of January 2025
  /// Has limited streams but doesn't require signature deciphering.
  static final ios = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'IOS',
        'clientVersion': '21.06.7',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
        'userAgent':
            'com.google.ios.youtube/21.06.7 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
        'hl': 'en',
        "platform": "MOBILE",
        'osName': 'IOS',
        'osVersion': '18.3.0.22C65',
        'timeZone': 'UTC',
        'gl': 'US',
        'utcOffsetMinutes': 0
      }
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// This provides also muxed streams but seems less reliable than [ios].
  /// If you require an android client use [androidVr] instead.
  static const android = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID',
        'clientVersion': '20.36.41',
        'androidSdkVersion': 34,
        'userAgent':
            'com.google.android.youtube/20.36.41 (Linux; U; Android 14) gzip',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// Has limited streams but doesn't require signature deciphering.
  /// As opposed to [android], this works only for music.
  static const androidMusic = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID_MUSIC',
        'clientVersion': '7.55.52',
        'androidSdkVersion': 34,
        'userAgent':
            'com.google.android.apps.youtube.music/7.55.52 (Linux; U; Android 14) gzip',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// Provides high quality videos (not only VR).
  static const androidVr = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'ANDROID_VR',
        'clientVersion': '1.69.36',
        'deviceModel': 'Quest 3',
        'osVersion': '14',
        'osName': 'Android',
        'androidSdkVersion': '34',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// This client also provide high quality muxed stream in the HLS manifest.
  /// The streams are in m3u8 format.
  static const safari = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'WEB',
        'clientVersion': '2.20250129.01.00',
        'userAgent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15,gzip(gfe)',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
    headers: {
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com',
    });

  /// Used to bypass some restrictions on videos.
  static const tv = YoutubeApiClient(
      {
        'context': {
          'client': {
            'clientName': 'TVHTML5',
            'clientVersion': '7.20250128.10.00',
            'hl': 'en',
            'timeZone': 'UTC',
            'gl': 'US',
            'utcOffsetMinutes': 0
          }
        },
        "contentCheckOk": true,
        "racyCheckOk": true
      },
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      headers: {
        'Sec-Fetch-Mode': 'navigate',
        'Content-Type': 'application/json',
        'Origin': 'https://www.youtube.com',
      });

  static const mediaConnect = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'MEDIA_CONNECT_FRONTEND',
        'clientVersion': '0.1',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
    headers: {
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com',
      'Content-Type': 'application/json',
    });

  /// Sometimes includes low quality streams (eg. 144p12).
  static const mweb = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'MWEB',
        'clientVersion': '2.20250129.01.00',
        'userAgent':
            'Mozilla/5.0 (Linux; Android 14; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
    headers: {
      'Origin': 'https://www.youtube.com',
      'Referer': 'https://www.youtube.com',
    });

  @Deprecated('Youtube always requires authentication for this client')
  static const webCreator = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'WEB_CREATOR',
        'clientVersion': '1.20240723.03.00',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// Fallback client for when other clients fail - WEB_EMBEDDED_PLAYER
  /// Sometimes works when other clients are blocked
  static const webEmbedded = YoutubeApiClient(
      {
        'context': {
          'client': {
            'clientName': 'WEB_EMBEDDED_PLAYER',
            'clientVersion': '1.20250129.01.00',
            'hl': 'en',
            'timeZone': 'UTC',
            'utcOffsetMinutes': 0,
          }
        },
        "thirdParty": {
          "embedUrl": "https://www.youtube.com/"
        },
        "contentCheckOk": true,
        "racyCheckOk": true
      },
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');

  /// Work even of restricted videos and provides low quality muxed streams, but requires signature deciphering.
  /// Does not work if the video has the embedding disabled.
  @Deprecated('Youtube always requires authentication for this client')
  static const tvSimplyEmbedded = YoutubeApiClient(
      {
        'context': {
          'client': {
            'clientName': 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
            'clientVersion': '2.0',
            'hl': 'en',
            'timeZone': 'UTC',
            'gl': 'US',
            'utcOffsetMinutes': 0
          }
        },
        'thirdParty': {'embedUrl': 'https://www.youtube.com/'},
        'contentCheckOk': true,
        'racyCheckOk': true
      },
      'https://www.youtube.com/youtubei/v1/player?prettyPrint=false',
      headers: {
        'Sec-Fetch-Mode': 'navigate',
        'Content-Type': 'application/json',
        'Origin': 'https://www.youtube.com',
      });
}
