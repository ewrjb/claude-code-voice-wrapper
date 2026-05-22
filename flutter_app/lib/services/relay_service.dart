import 'dart:async';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ws_message.dart';

class RelayService {
  final String wsUrl;
  final String token;

  void Function(bool online)? onAgentStatus;
  void Function(String text)? onResponse;
  void Function(String text)? onError;
  void Function()? onDisconnected;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  RelayService({required this.wsUrl, required this.token});

  Future<void> connect() async {
    final uri = Uri.parse('$wsUrl/ws/app?token=$token');
    _channel = WebSocketChannel.connect(uri);
    _subscription = _channel!.stream.listen(
      _onData,
      onDone: _onDone,
      onError: (_) => _onDone(),
    );
  }

  void _onData(dynamic data) {
    processIncoming(
      data as String,
      onAgentStatus: onAgentStatus ?? (_) {},
      onResponse: onResponse ?? (_) {},
      onError: onError ?? (_) {},
    );
  }

  void _onDone() {
    onAgentStatus?.call(false);
    onDisconnected?.call();
  }

  void sendCommand(String text) {
    _channel?.sink.add(WsMessage.command(text));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
  }

  /// Pure function for message parsing — testable without WebSocket.
  static void processIncoming(
    String raw, {
    required void Function(bool) onAgentStatus,
    required void Function(String) onResponse,
    required void Function(String) onError,
  }) {
    try {
      final msg = WsMessage.fromJson(raw);
      if (msg.isAgentStatus) {
        onAgentStatus(msg.agentOnline);
      } else if (msg.isResponse) {
        onResponse(msg.text);
      } else if (msg.isError) {
        onError(msg.text);
      }
    } catch (_) {
      // Silently ignore malformed messages
    }
  }
}
