import 'dart:convert';

class WsMessage {
  final String type;
  final Map<String, dynamic> _raw;

  WsMessage._(this.type, this._raw);

  factory WsMessage.fromJson(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return WsMessage._(map['type'] as String, map);
    } catch (e) {
      throw FormatException('Invalid WsMessage JSON: $e', raw);
    }
  }

  bool get isAgentStatus => type == 'agent_status';
  bool get isResponse => type == 'response';
  bool get isError => type == 'error';

  bool get agentOnline {
    assert(isAgentStatus, 'agentOnline called on non-agent_status message');
    return _raw['online'] as bool;
  }

  String get text {
    assert(isResponse || isError, 'text called on non-response/error message');
    return _raw['text'] as String;
  }

  static String command(String text) =>
      jsonEncode({'type': 'command', 'text': text});
}
