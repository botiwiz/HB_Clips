import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Talks to Pinterest's own internal "resource" JSON endpoints - the same
/// ones www.pinterest.com's web app itself calls, not a public developer
/// API (Pinterest doesn't offer one for arbitrary keyword board search or
/// bulk board-content reads; their official API only manages a business's
/// own pins). This is the technique documented by the long-established,
/// widely-used open-source `gallery-dl` project's Pinterest extractor
/// (github.com/mikf/gallery-dl, `gallery_dl/extractor/pinterest.py`) -
/// every endpoint, parameter, and pagination rule below is taken directly
/// from reading that extractor's source, not guessed.
///
/// Because this is an unofficial, undocumented API, it can change or
/// start rejecting requests at any time, and Pinterest's Terms of Service
/// don't sanction this kind of access - the user explicitly chose this
/// tradeoff after being told the alternatives (see the board chat this
/// shipped from). Two specific things below are inferred by analogy
/// rather than confirmed against a real response (this sandbox's network
/// policy blocks pinterest.com entirely, so none of this could be tested
/// here) - each is called out at its call site:
/// 1. The `scope: "boards"` search parameter (gallery-dl's own source
///    only documents `scope: "pins"`; `"boards"` is the obvious analogous
///    value but unverified).
/// 2. The exact field names on a board search result object (`id`,
///    `name`, `pin_count`, `owner.username`, `image_thumbnail_url`) -
///    inferred from Pinterest's generally-documented object conventions.
/// If results come back empty/malformed on a real run, these are the
/// first two things to check against the actual JSON (add a debugPrint
/// of the raw response body temporarily, inspect it, adjust the field
/// paths in [PinterestBoard.fromJson] below to match).
class PinterestService {
  PinterestService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _root = 'https://www.pinterest.com';

  // A random 32-char hex string, regenerated per `PinterestService`
  // instance - mirrors gallery-dl's `util.generate_token()`, sent as a
  // `csrftoken` cookie (and duplicated into the matching header, the
  // standard double-submit CSRF pattern) on every request.
  static String _generateToken() {
    final rand = Random.secure();
    return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  final String _csrfToken = _generateToken();

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/javascript, */*, q=0.01',
    'X-Requested-With': 'XMLHttpRequest',
    'X-CSRFToken': _csrfToken,
    'Referer': '$_root/',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Cookie': 'csrftoken=$_csrfToken',
  };

  Uri _resourceUrl(String resource, Map<String, dynamic> options) {
    return Uri.parse('$_root/resource/${resource}Resource/get/').replace(
      queryParameters: {
        'data': jsonEncode({'options': options}),
        'source_url': '',
      },
    );
  }

  /// Fetches one "resource" endpoint and returns its decoded JSON body, or
  /// throws a [PinterestRequestException] with the status code/a short
  /// reason on any non-200 response or network failure - callers surface
  /// this directly to the user rather than silently swallowing it, since
  /// a 403/429 here most likely means Pinterest is blocking this request
  /// pattern, which the user needs to actually see to know what happened.
  Future<Map<String, dynamic>> _getResource(
    String resource,
    Map<String, dynamic> options,
  ) async {
    final uri = _resourceUrl(resource, options);
    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers);
    } catch (e) {
      throw PinterestRequestException('Network error: $e');
    }
    if (response.statusCode != 200) {
      throw PinterestRequestException(
        'Pinterest returned HTTP ${response.statusCode} - it may be '
        'blocking this request.',
      );
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw PinterestRequestException(
        'Unexpected response shape from Pinterest (not valid JSON).',
      );
    }
  }

  /// Searches for boards matching [query]. See this class's doc comment -
  /// `scope: "boards"` is inferred by analogy with gallery-dl's documented
  /// `scope: "pins"` pin-search, not independently confirmed.
  Future<List<PinterestBoard>> searchBoards(String query) async {
    final json = await _getResource('BaseSearch', {
      'query': query,
      'scope': 'boards',
      'rs': 'typed',
    });
    final data = _extractDataList(json);
    return [
      for (final item in data)
        if (item is Map<String, dynamic>) PinterestBoard.fromJson(item),
    ].whereType<PinterestBoard>().toList();
  }

  /// Fetches every pin image in board [boardId], paginating via the
  /// `bookmarks` cursor exactly as gallery-dl's `_pagination` does: keep
  /// requesting with the previous response's bookmark until it comes back
  /// empty, `"-end-"`, or starting with the sentinel prefix `"Y2JOb25lO"`
  /// Pinterest itself uses to mark a truly-finished feed.
  Future<List<PinterestPinImage>> fetchBoardPins(
    String boardId, {
    int maxPins = 500,
  }) async {
    final images = <PinterestPinImage>[];
    String? bookmark;
    while (images.length < maxPins) {
      final json = await _getResource('BoardFeed', {
        'board_id': boardId,
        'field_set_key': 'react_grid_pin',
        'prepend': false,
        'bookmarks': bookmark == null ? null : [bookmark],
      });
      final data = _extractDataList(json);
      for (final item in data) {
        if (item is Map<String, dynamic>) {
          final image = PinterestPinImage.fromJson(item);
          if (image != null) images.add(image);
        }
      }
      final nextBookmark = _extractBookmark(json);
      if (nextBookmark == null ||
          nextBookmark.isEmpty ||
          nextBookmark == '-end-' ||
          nextBookmark.startsWith('Y2JOb25lO') ||
          data.isEmpty) {
        break;
      }
      bookmark = nextBookmark;
    }
    return images;
  }

  static List<dynamic> _extractDataList(Map<String, dynamic> json) {
    final response = json['resource_response'];
    if (response is Map<String, dynamic>) {
      final data = response['data'];
      if (data is List) return data;
      // BaseSearchResource nests pin/board results one level deeper under
      // a scope-named key in some Pinterest API versions.
      if (data is Map<String, dynamic>) {
        for (final value in data.values) {
          if (value is List) return value;
        }
      }
    }
    return const [];
  }

  static String? _extractBookmark(Map<String, dynamic> json) {
    final resource = json['resource'];
    if (resource is Map<String, dynamic>) {
      final options = resource['options'];
      if (options is Map<String, dynamic>) {
        final bookmarks = options['bookmarks'];
        if (bookmarks is List && bookmarks.isNotEmpty) {
          return bookmarks.first as String?;
        }
        if (bookmarks is String) return bookmarks;
      }
    }
    return null;
  }

  void close() => _client.close();
}

class PinterestRequestException implements Exception {
  PinterestRequestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One board search result. Field paths are inferred - see
/// [PinterestService]'s doc comment.
class PinterestBoard {
  PinterestBoard({
    required this.id,
    required this.name,
    this.ownerUsername,
    this.pinCount,
    this.thumbnailUrl,
  });

  final String id;
  final String name;
  final String? ownerUsername;
  final int? pinCount;
  final String? thumbnailUrl;

  static PinterestBoard? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) return null;
    final owner = json['owner'];
    final ownerUsername = owner is Map<String, dynamic>
        ? owner['username'] as String?
        : null;
    final pinCount = json['pin_count'];
    String? thumbnailUrl = json['image_thumbnail_url'] as String?;
    if (thumbnailUrl == null) {
      final images = json['images'];
      if (images is Map<String, dynamic>) {
        for (final value in images.values) {
          if (value is Map<String, dynamic> && value['url'] is String) {
            thumbnailUrl = value['url'] as String;
            break;
          }
        }
      }
    }
    return PinterestBoard(
      id: id,
      name: name,
      ownerUsername: ownerUsername,
      pinCount: pinCount is int ? pinCount : null,
      thumbnailUrl: thumbnailUrl,
    );
  }
}

/// One pin's original-resolution image, as documented by gallery-dl:
/// `pin["images"]["orig"]` for a normal image pin.
class PinterestPinImage {
  PinterestPinImage({
    required this.url,
    required this.width,
    required this.height,
  });

  final String url;
  final int width;
  final int height;

  static PinterestPinImage? fromJson(Map<String, dynamic> pin) {
    final images = pin['images'];
    if (images is! Map<String, dynamic>) return null;
    final orig = images['orig'];
    if (orig is! Map<String, dynamic>) return null;
    final url = orig['url'];
    final width = orig['width'];
    final height = orig['height'];
    if (url is! String || width is! int || height is! int) return null;
    return PinterestPinImage(url: url, width: width, height: height);
  }
}
