import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../core/offline_server.dart';
import '../../core/offline_client.dart';
import '../../core/online_client.dart';
import 'voice_call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String channelId;
  final bool isOnlineMode;
  final bool isHost;

  const ChatScreen({
    super.key,
    required this.channelId,
    required this.isOnlineMode,
    this.isHost = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    if (widget.isOnlineMode) {
      final client = Provider.of<OnlineClient>(context, listen: false);
      client.onMessageReceived = (data) {
        setState(() {
          _messages.insert(0, data);
        });
      };
    } else {
      if (widget.isHost) {
        final server = Provider.of<OfflineServer>(context, listen: false);
        server.onMessageReceived = (data) {
          setState(() {
            _messages.insert(0, data);
          });
        };
      } else {
        final client = Provider.of<OfflineClient>(context, listen: false);
        client.onMessageReceived = (data) {
          setState(() {
            _messages.insert(0, data);
          });
        };
      }
    }
  }

  void _sendMessage() {
    final content = _msgController.text.trim();
    if (content.isEmpty) return;

    if (widget.isOnlineMode) {
      Provider.of<OnlineClient>(context, listen: false).sendMessage(content);
    } else {
      if (widget.isHost) {
        Provider.of<OfflineServer>(context, listen: false).sendMessage(content, "Admin");
      } else {
        Provider.of<OfflineClient>(context, listen: false).sendMessage(content);
      }
    }
    _msgController.clear();
  }

  void _startVoiceCall() {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          isHost: widget.isHost,
          isOnlineMode: widget.isOnlineMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('app_name'.tr(), style: const TextStyle(fontSize: 16)),
            Text(
              widget.isOnlineMode 
                ? 'Online ID: ${widget.channelId.substring(0, 5)}...'
                : 'Offline: ${widget.isHost ? "Host" : "Client"}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            tooltip: 'voice_call'.tr(),
            onPressed: _startVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              // Show Participants
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['senderId'] == (widget.isHost ? "Admin" : Provider.of<OfflineClient>(context, listen: false).clientId);
                
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? Theme.of(context).primaryColor : Colors.grey[300],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Text(
                            msg['senderId'] ?? "Unknown",
                            style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.bold),
                          ),
                        Text(
                          msg['content'] ?? "",
                          style: TextStyle(color: isMe ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        color: Theme.of(context).cardColor,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                decoration: InputDecoration(
                  hintText: 'start_chatting'.tr(),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
