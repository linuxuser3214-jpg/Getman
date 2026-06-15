import 'dart:convert';
import 'dart:io';

/// A request the [MockServer] received, captured so a flow can assert on what
/// the app actually sent (e.g. that `{{var}}` was substituted before the send).
class RecordedRequest {
  RecordedRequest({
    required this.method,
    required this.uri,
    required this.headers,
    required this.body,
  });

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

/// Signature for a custom response writer. Write to `request.response` only —
/// the server closes it. Throwing is fine; it surfaces as a 500-style failure.
typedef MockResponder = void Function(HttpRequest request);

/// A hermetic localhost HTTP server for E2E flows.
///
/// Binds to an ephemeral port on the loopback interface (no fixed-port
/// collisions), records every request, and replies with a canned response.
/// Point a request's URL at [baseUrl] (or [url]) and the real Dio path in the
/// app exercises this server end to end — offline, fast, deterministic.
///
/// ```dart
/// final server = await MockServer.start(json: {'ok': true});
/// addTearDown(server.close);
/// // ... drive the app to send to server.baseUrl ...
/// expect(server.received.single.method, 'GET');
/// ```
class MockServer {
  MockServer._(this._server, this._responder) {
    _server.listen(_handle);
  }

  final HttpServer _server;
  final MockResponder _responder;

  /// Every request the server has received, in arrival order.
  final List<RecordedRequest> received = [];

  /// Base URL (e.g. `http://127.0.0.1:53412`) — no trailing slash.
  String get baseUrl => 'http://${_server.address.address}:${_server.port}';

  /// [baseUrl] joined with [path] (which should start with `/`).
  String url(String path) => '$baseUrl$path';

  /// Starts a server. By default it replies `status` with `json` as the body.
  /// Pass [responder] for full control over the response.
  static Future<MockServer> start({
    int status = 200,
    Object? json,
    MockResponder? responder,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final effective =
        responder ??
        (HttpRequest request) {
          request.response
            ..statusCode = status
            ..headers.contentType = ContentType.json
            ..write(jsonEncode(json ?? <String, Object?>{'ok': true}));
        };
    return MockServer._(server, effective);
  }

  Future<void> _handle(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    final headers = <String, String>{};
    request.headers.forEach((name, values) => headers[name] = values.join(','));
    received.add(
      RecordedRequest(
        method: request.method,
        uri: request.uri,
        headers: headers,
        body: body,
      ),
    );
    try {
      _responder(request);
    } finally {
      await request.response.close();
    }
  }

  /// Shuts the server down. Always call in `addTearDown`.
  Future<void> close() => _server.close(force: true);
}
