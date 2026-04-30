import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/foundation.dart';
import 'dart:convert';

class OnlineClient extends ChangeNotifier {
  io.Socket? _socket;
  bool _isConnected = false;
  String? _currentRoom;
  String? _clientId;

  bool get isConnected => _isConnected;
  String? get clientId => _clientId;

  Function(Map<String, dynamic>)? onMessageReceived;

  void init(String serverUrl, String clientId) {
    _clientId = clientId;
    _socket = io.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.onConnect((_) {
      _isConnected = true;
      print('Connected to Online Server');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      print('Disconnected from Online Server');
      notifyListeners();
    });

    _socket!.on('message', (data) {
      if (onMessageReceived != null) {
        onMessageReceived!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.on('webrtc_signal', (data) {
       if (onMessageReceived != null) {
        onMessageReceived!(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void joinRoom(String roomName) {
    if (_socket != null && _isConnected) {
      _currentRoom = roomName;
      _socket!.emit('join', roomName);
    }
  }

  void sendMessage(String content) {
    if (_socket != null && _isConnected && _currentRoom != null) {
      final data = {
        'type': 'CHAT_MESSAGE',
        'room': _currentRoom,
        'senderId': _clientId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _socket!.emit('message', data);
    }
  }

  void sendWebRTCSignal(String targetId, Map<String, dynamic> signal) {
    if (_socket != null && _isConnected && _currentRoom != null) {
      final data = {
        'type': 'WEBRTC_SIGNAL',
        'room': _currentRoom,
        'senderId': _clientId,
        'targetId': targetId,
        'signal': signal,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _socket!.emit('webrtc_signal', data);
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _isConnected = false;
    notifyListeners();
  }
}
