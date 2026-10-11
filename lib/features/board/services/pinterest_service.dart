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
/// every endpoint, parameter, pagination rule, and header below is taken
/// directly from reading that extractor's source (and its base
/// `Extractor._init_session()` in `common.py`), not guessed, confirmed on
/// 2026-10-11 by re-reading both files after a real-world 403 report (see
/// below).
///
/// Because this is an unofficial, undocumented API, it can change or
/// start rejecting requests at any time, and Pinterest's Terms of Service
/// don't sanction this kind of access - the user explicitly chose this
/// tradeoff after being told the alternatives (see the board chat this
/// shipped from).
///
/// **Known gap, found from a real 403 after this shipped:** gallery-dl's
/// extractor has no keyword board-search at all - its `search()` method
/// only supports `scope: "pins"`. The `scope: "boards"` parameter
/// [searchBoards] below uses was always an unverified guess (there is no
/// `search_boards()` anywhere in the reference source), and may simply not
/// be a real capability of this API - a 403 here could be Pinterest
/// rejecting an unsupported scope value as aggressively as it rejects a
/// non-browser-looking request. [resolveBoardUrl] is the one board-lookup
/// path gallery-dl's `PinterestBoardExtractor` actually confirms works: a
/// board URL's username+slug resolved via the `Board` resource, with no
/// search involved - prefer it; treat [searchBoards] as experimental.
class PinterestService {
  PinterestService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const String _root = 'https://www.pinterest.com';

  // A random 32-char hex string, regenerated per `PinterestService`
  // instance - mirrors gallery-dl's `util.generate_token()`, sent only as
  // a `csrftoken` cookie (gallery-dl passes it through its HTTP client's
  // cookie jar, not as a header - no `X-CSRFToken` header appears
  // anywhere in its source, so this deliberately doesn't send one either;
  // an earlier version of this file did, which may have made requests
  // look more suspicious, not less).
  static String _generateToken() {
    final rand = Random.secure();
    return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
  }

  final String _csrfToken = _generateToken();

  // Mirrors gallery-dl's `PinterestAPI.__init__` headers dict plus the
  // bare-default (no `browser` option) headers `Extractor._init_session()`
  // sets - every entry here is read verbatim from one or the other, not
  // invented. gallery-dl never fills in `X-Pinterest-Source-Url`, so this
  // leaves it out too rather than guessing a value for it.
  Map<String, String> get _headers => {
    'Accept': 'application/json, text/javascript, */*, q=0.01',
    'Accept-Language': 'en-US,en;q=0.5',
    'Accept-Encoding': 'gzip, deflate, br',
    'X-Requested-With': 'XMLHttpRequest',
    'X-APP-VERSION': 'a89153f',
    'X-Pinterest-AppState': 'active',
    'X-Pinterest-PWS-Handler': 'www/[username].js',
    'Alt-Used': 'www.pinterest.com',
    'Connection': 'keep-alive',
    'Sec-Fetch-Dest': 'empty',
    'Sec-Fetch-Mode': 'cors',
    'Sec-Fetch-Site': 'same-origin',
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

  /// Experimental keyword board search - see this class's doc comment.
  /// `scope: "boards"` is an unverified guess; gallery-dl's reference
  /// extractor has no board-search method at all. Prefer [resolveBoardUrl].
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

  /// Resolves a Pinterest board from its URL (or a bare `username/slug`
  /// pair) via the `Board` resource - the one board-lookup mechanism
  /// gallery-dl's `PinterestBoardExtractor` actually confirms works
  /// (`PinterestAPI.board(username, slug)`, calling `BoardResource` with
  /// `{slug, username, field_set_key: "detailed"}`). No search involved,
  /// so it isn't subject to [searchBoards]'s "is `scope: boards` even
  /// real" uncertainty. Throws [PinterestRequestException] if [input]
  /// doesn't parse as a board identifier (see [parseBoardIdentifier]) or
  /// the board resource comes back in an unexpected shape.
  Future<PinterestBoard> resolveBoardUrl(String input) async {
    final parsed = parseBoardIdentifier(input);
    if (parsed == null) {
      throw PinterestRequestException(
        'Enter a Pinterest board URL (e.g. pinterest.com/username/boardname) '
        'or a plain keyword to search.',
      );
    }
    final json = await _getResource('Board', {
      'slug': parsed.slug,
      'username': parsed.username,
      'field_set_key': 'detailed',
    });
    final data = json['resource_response'];
    final board = data is Map<String, dynamic> ? data['data'] : null;
    if (board is! Map<String, dynamic>) {
      throw PinterestRequestException('Board not found.');
    }
    final parsedBoard = PinterestBoard.fromJson(board);
    if (parsedBoard == null) {
      throw PinterestRequestException(
        'Unexpected response shape for this board.',
      );
    }
    return parsedBoard;
  }

  /// Parses a Pinterest board URL (`https://www.pinterest.com/username/
  /// boardname/`, with or without scheme/query/trailing slash), a bare
  /// `pinterest.com/username/boardname`, or a plain `username/boardname`
  /// pair (no domain at all, for pasting just the slug part) into its two
  /// path segments. Rejects a pin permalink (`pinterest.com/pin/12345/` -
  /// first segment `"pin"`, same exclusion gallery-dl's own
  /// `PinterestBoardExtractor` URL pattern applies) and anything with
  /// fewer than two non-empty path segments (e.g. a bare profile URL with
  /// no board, or a plain keyword-search query with no slash at all).
  ///
  /// A domain-less `username/boardname` can't just be run through
  /// `Uri.tryParse` with an `https://` prefix tacked on - that would parse
  /// `username` as the URL's *host*, not a path segment, leaving only
  /// `boardname` in `pathSegments` (one segment, so it would fail the
  /// length check for the wrong reason). Only `pinterest.com`-containing
  /// or scheme-prefixed input goes through `Uri`; anything else is split
  /// on `/` directly.
  ///
  /// Pure and synchronous - no network access - so it's unit-testable on
  /// its own.
  static ({String username, String slug})? parseBoardIdentifier(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final looksLikeUrl =
        trimmed.contains('://') ||
        trimmed.toLowerCase().contains('pinterest.com');
    final List<String> segments;
    if (looksLikeUrl) {
      final hasScheme = trimmed.contains('://');
      final uri = Uri.tryParse(hasScheme ? trimmed : 'https://$trimmed');
      if (uri == null) return null;
      segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    } else {
      segments = trimmed.split('/').where((s) => s.isNotEmpty).toList();
    }
    if (segments.length < 2 || segments.first.toLowerCase() == 'pin') {
      return null;
    }
    return (username: segments[0], slug: segments[1]);
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
