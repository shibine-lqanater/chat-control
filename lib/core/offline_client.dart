import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

enum OfflineClientStatus { idle, searching, connecting, waitingForApproval, approved, rejected, disconnected }

class OfflineClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  OfflineClientStatus _status = OfflineClientStatus.idle;
  String? _clientId;
  StreamSubscription? _subscription;

  OfflineClientStatus get status => _status;
  String? get clientId => _clientId;

  Function(Map<String, dynamic>)? onMessageReceived;
  Function(String)? onStatusChanged;

  void setClientId(String id) {
    _clientId = id;
  }

  void _updateStatus(OfflineClientStatus newStatus) {
    _status = newStatus;
    if (onStatusChanged != null) {
      onStatusChanged!(_status.toString());
    }
    notifyListeners();
  }

  Future<void> connect(String ip, int port) async {
    _updateStatus(OfflineClientStatus.connecting);
    try {
      final url = Uri.parse('ws://$ip:$port');
      _channel = WebSocketChannel.connect(url);
      
      // Send Auth Request
      _channel!.sink.add(jsonEncode({
        'type': 'AUTH_REQUEST',
        'clientId': _clientId,
        'timestamp': DateTime.now().toIso8601String(),
      }));

      _updateStatus(OfflineClientStatus.waitingForApproval);

      _subscription = _channel!.stream.listen((message) {
        try {
          final data = jsonDecode(message as String);
          final type = data['type'];

          if (type == 'AUTH_SUCCESS') {
            _updateStatus(OfflineClientStatus.approved);
          } else if (type == 'AUTH_REJECTED') {
            _updateStatus(OfflineClientStatus.rejected);
            _channel!.sink.close();
          } else if (type == 'CHAT_MESSAGE') {
            if (onMessageReceived != null) {
              onMessageReceived!(data);
            }
          } else if (type == 'WEBRTC_SIGNAL') {
             if (onMessageReceived != null) {
              onMessageReceived!(data);
            }
          }
        } catch (e) {
          print('Client Error parsing message: $e');
        }
      }, onDone: () {
        _updateStatus(OfflineClientStatus.disconnected);
        _channel = null;
      }, onError: (error) {
        print('Client Socket Error: $error');
        _updateStatus(OfflineClientStatus.disconnected);
        _channel = null;
      });
    } catch (e) {
      print('Connection Error: $e');
      _updateStatus(OfflineClientStatus.disconnected);
    }
  }

  void sendMessage(String content) {
    if (_status == OfflineClientStatus.approved && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'CHAT_MESSAGE',
        'senderId': _clientId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  void sendWebRTCSignal(String targetId, Map<String, dynamic> signal) {
    if (_status == OfflineClientStatus.approved && _channel != null) {
      _channel!.sink.add(jsonEncode({
        'type': 'WEBRTC_SIGNAL',
        'senderId': _clientId,
        'targetId': targetId,
        'signal': signal,
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateStatus(OfflineClientStatus.idle);
  }
}
