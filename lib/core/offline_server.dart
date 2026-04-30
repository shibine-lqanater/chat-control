import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart';

class OfflineServer extends ChangeNotifier {
  HttpServer? _server;
  final Map<String, WebSocketChannel> _clients = {}; // Approved clients
  final Map<String, WebSocketChannel> _pendingClients = {}; // Waiting for approval

  int _port = 8080;
  int get port => _port;

  List<String> get pendingRequests => _pendingClients.keys.toList();
  List<String> get approvedClients => _clients.keys.toList();

  Function(Map<String, dynamic>)? onMessageReceived;

  Future<void> startServer() async {
    var handler = webSocketHandler((webSocket) {
      String? clientId;
      
      webSocket.stream.listen((message) {
        try {
          final data = jsonDecode(message as String);
          final type = data['type'];

          if (type == 'AUTH_REQUEST') {
            clientId = data['clientId'];
            if (clientId != null) {
              _pendingClients[clientId!] = webSocket;
              notifyListeners();
            }
          } else if (type == 'CHAT_MESSAGE' && clientId != null && _clients.containsKey(clientId)) {
            // Broadcast to all approved clients
            _broadcast(message);
            // Notify UI
            if (onMessageReceived != null) {
              onMessageReceived!(data);
            }
          } else if (type == 'WEBRTC_SIGNAL' && clientId != null && _clients.containsKey(clientId)) {
             // Forward WebRTC signal to the target client
             final targetId = data['targetId'];
             if (targetId != null && _clients.containsKey(targetId)) {
               _clients[targetId]!.sink.add(message);
             }
          }
        } catch (e) {
          print('Server Error parsing message: $e');
        }
      }, onDone: () {
        if (clientId != null) {
          _clients.remove(clientId);
          _pendingClients.remove(clientId);
          notifyListeners();
        }
      });
    });

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 0);
    _port = _server!.port;
    print('WebSocket Server running on port $_port');
  }

  void approveClient(String clientId) {
    if (_pendingClients.containsKey(clientId)) {
      final socket = _pendingClients.remove(clientId)!;
      _clients[clientId] = socket;
      
      socket.sink.add(jsonEncode({
        'type': 'AUTH_SUCCESS',
        'message': 'You have been approved by the Admin.'
      }));
      notifyListeners();
    }
  }

  void rejectClient(String clientId) {
    if (_pendingClients.containsKey(clientId)) {
      final socket = _pendingClients.remove(clientId)!;
      socket.sink.add(jsonEncode({
        'type': 'AUTH_REJECTED',
        'message': 'Admin rejected your request.'
      }));
      socket.sink.close();
      notifyListeners();
    }
  }

  void sendMessage(String messageContent, String senderId) {
    final message = jsonEncode({
      'type': 'CHAT_MESSAGE',
      'senderId': senderId,
      'content': messageContent,
      'timestamp': DateTime.now().toIso8601String(),
    });
    _broadcast(message);
    if (onMessageReceived != null) {
      onMessageReceived!(jsonDecode(message));
    }
  }

  void _broadcast(String message) {
    for (var client in _clients.values) {
      client.sink.add(message);
    }
  }

  Future<void> stopServer() async {
    for (var client in _clients.values) {
      client.sink.close();
    }
    for (var client in _pendingClients.values) {
      client.sink.close();
    }
    _clients.clear();
    _pendingClients.clear();
    await _server?.close(force: true);
    _server = null;
    notifyListeners();
  }
}
