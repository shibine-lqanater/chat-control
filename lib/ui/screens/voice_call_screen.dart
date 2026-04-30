import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../../core/webrtc_service.dart';
import '../../core/online_client.dart';
import '../../core/offline_client.dart';
import '../../core/offline_server.dart';

class VoiceCallScreen extends StatefulWidget {
  final bool isHost;
  final bool isOnlineMode;

  const VoiceCallScreen({
    super.key,
    required this.isHost,
    required this.isOnlineMode,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  final Set<String> _participants = {};

  @override
  void initState() {
    super.initState();
    _initAndJoin();
  }

  Future<void> _initAndJoin() async {
    final rtc = Provider.of<WebRTCService>(context, listen: false);
    await rtc.init();
    
    // Listen for signaling messages from the network
    if (widget.isOnlineMode) {
      final client = Provider.of<OnlineClient>(context, listen: false);
      client.onMessageReceived = (data) => _handleSignaling(data);
      // Announce presence
      client.sendWebRTCSignal('ALL', {'type': 'JOIN_VOICE', 'senderId': client.clientId});
    } else {
      if (widget.isHost) {
        final server = Provider.of<OfflineServer>(context, listen: false);
        server.onMessageReceived = (data) => _handleSignaling(data);
      } else {
        final client = Provider.of<OfflineClient>(context, listen: false);
        client.onMessageReceived = (data) => _handleSignaling(data);
        client.sendWebRTCSignal('Admin', {'type': 'JOIN_VOICE', 'senderId': client.clientId});
      }
    }
  }

  void _handleSignaling(Map<String, dynamic> data) async {
    if (data['type'] != 'WEBRTC_SIGNAL') return;
    
    final rtc = Provider.of<WebRTCService>(context, listen: false);
    final signal = data['signal'];
    final remoteId = data['senderId'];
    if (remoteId == null) return;

    switch (signal['type']) {
      case 'JOIN_VOICE':
        setState(() => _participants.add(remoteId));
        // We received a join, let's start negotiation by sending an Offer
        await _startNegotiation(remoteId);
        break;
      
      case 'OFFER':
        setState(() => _participants.add(remoteId));
        final pc = await rtc.createPeerConnection(remoteId, (candidate) {
          _sendSignal(remoteId, {'type': 'ICE', 'candidate': candidate.toMap()});
        });
        final answer = await rtc.createAnswer(remoteId, webrtc.RTCSessionDescription(signal['sdp'], 'offer'));
        _sendSignal(remoteId, {'type': 'ANSWER', 'sdp': answer.sdp});
        break;

      case 'ANSWER':
        await rtc.setRemoteDescription(remoteId, webrtc.RTCSessionDescription(signal['sdp'], 'answer'));
        break;

      case 'ICE':
        final candidateData = signal['candidate'];
        await rtc.addIceCandidate(remoteId, webrtc.RTCIceCandidate(candidateData['candidate'], candidateData['sdpMid'], candidateData['sdpMLineIndex']));
        break;
    }
  }

  Future<void> _startNegotiation(String remoteId) async {
    final rtc = Provider.of<WebRTCService>(context, listen: false);
    await rtc.createPeerConnection(remoteId, (candidate) {
      _sendSignal(remoteId, {'type': 'ICE', 'candidate': candidate.toMap()});
    });
    final offer = await rtc.createOffer(remoteId);
    _sendSignal(remoteId, {'type': 'OFFER', 'sdp': offer.sdp});
  }

  void _sendSignal(String targetId, Map<String, dynamic> signal) {
    if (widget.isOnlineMode) {
      Provider.of<OnlineClient>(context, listen: false).sendWebRTCSignal(targetId, signal);
    } else {
      if (widget.isHost) {
        // As host, we might need to send to a specific client
        // For simplicity, let's assume direct messaging for signaling is handled by OfflineServer
      } else {
        Provider.of<OfflineClient>(context, listen: false).sendWebRTCSignal(targetId, signal);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rtc = Provider.of<WebRTCService>(context);

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Voice Room (${_participants.length + 1})', style: const TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemCount: _participants.length + 1,
              itemBuilder: (context, index) {
                final name = index == 0 ? "Me" : "User $index";
                return _buildParticipantTile(name, index == 0);
              },
            ),
          ),
          _buildControls(rtc),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildParticipantTile(String name, bool isMe) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(16),
        border: isMe ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: isMe ? Colors.blue : Colors.grey[700],
            child: const Icon(Icons.person, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildControls(WebRTCService rtc) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildRoundButton(
          icon: rtc.isMuted ? Icons.mic_off : Icons.mic,
          color: rtc.isMuted ? Colors.red : Colors.grey[800]!,
          onPressed: rtc.toggleMute,
          label: 'mute'.tr(),
        ),
        _buildRoundButton(
          icon: Icons.call_end,
          color: Colors.red,
          onPressed: () => Navigator.pop(context),
          label: 'end_call'.tr(),
          isLarge: true,
        ),
        _buildRoundButton(
          icon: rtc.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          color: rtc.isSpeakerOn ? Colors.blue : Colors.grey[800]!,
          onPressed: rtc.toggleSpeaker,
          label: 'speaker'.tr(),
        ),
      ],
    );
  }

  Widget _buildRoundButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
    bool isLarge = false,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onPressed,
          child: Container(
            padding: EdgeInsets.all(isLarge ? 20 : 16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: isLarge ? 32 : 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
