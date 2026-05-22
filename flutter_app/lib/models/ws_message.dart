import 'dart:convert';

class WsMessage {
  final String type;
  final Map<String, dynamic> _raw;

  WsMessage._(this.type, this._raw);

  factory WsMessage.fromJson(String raw) {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return WsMessage._(map['type'] as String, map);
  }

  bool get isAgentStatus => type == 'agent_status';
  bool get isResponse => type == 'response';
  bool get isError => type == 'error';

  bool get agentOnline => _raw['online'] as bool;
  String get text => _raw['text'] as String;

  static String command(String text) =>
      jsonEncode({'type': 'command', 'text': text});
}
