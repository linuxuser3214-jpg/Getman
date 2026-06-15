import 'dart:async';
import 'dart:io';

/// A hermetic localhost **WebSocket echo** server for the realtime E2E flows.
///
/// Binds an ephemeral loopback port, upgrades incoming HTTP requests to
/// WebSocket, and echoes every text frame straight back. Point a WS request's
/// URL at [wsUrl] and the real `web_socket_channel` path in the app connects to
/// this server — offline, fast, deterministic.
///
/// ```dart
/// final ws = await MockWebSocketServer.start();
/// addTearDown(ws.close);
/// // ... drive the app to connect to ws.wsUrl and send a frame ...
/// ```
class MockWebSocketServer {
  MockWebSocketServer._(this._server) {
    _server.listen(_handle);
  }

  final HttpServer _server;
  final List<WebSocket> _sockets = [];

  /// Every text frame the server received, in arrival order.
  final List<String> received = [];

  /// WebSocket URL (e.g. `ws://127.0.0.1:53412`) — no trailing slash.
  String get wsUrl => 'ws://${_server.address.address}:${_server.port}';

  /// Starts an echo server on an ephemeral loopback port.
  static Future<MockWebSocketServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    return MockWebSocketServer._(server);
  }

  Future<void> _handle(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    socket.listen(
      (data) {
        if (data is String) {
          received.add(data);
          socket.add(data); // echo
        }
      },
      onDone: () => _sockets.remove(socket),
      cancelOnError: true,
    );
  }

  /// Pushes a server-initiated frame to every connected client (for tests that
  /// assert on unsolicited incoming messages).
  void broadcast(String message) {
    for (final s in _sockets) {
      s.add(message);
    }
  }

  /// Shuts the server (and any open sockets) down. Always call in addTearDown.
  Future<void> close() async {
    for (final s in List<WebSocket>.of(_sockets)) {
      await s.close();
    }
    await _server.close(force: true);
  }
}

/// Builds a `MockResponder` (see `mock_server.dart`) that replies with a
/// `text/event-stream` body carrying [events] as SSE `data:` frames, then ends
/// the stream. The app's `SseParser` (over the live dio response stream) parses
/// each frame into an incoming realtime message; the stream end surfaces as a
/// close frame. Use with `MockServer.start(responder: sseResponder([...]))`.
void Function(HttpRequest request) sseResponder(List<String> events) {
  return (HttpRequest request) {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType('text', 'event-stream')
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
    for (final e in events) {
      request.response.write('data: $e\n\n');
    }
  };
}
