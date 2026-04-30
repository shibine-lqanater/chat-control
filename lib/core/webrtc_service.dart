import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:flutter/foundation.dart';

class WebRTCService extends ChangeNotifier {
  webrtc.MediaStream? _localStream;
  final Map<String, webrtc.RTCPeerConnection> _peerConnections = {};
  
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;

  Future<void> init() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };
    try {
      _localStream = await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      print('Error getting local stream: $e');
    }
  }

  Future<webrtc.RTCPeerConnection> createPeerConnection(
    String remoteId, 
    Function(webrtc.RTCIceCandidate) onIceCandidate,
  ) async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ]
    };

    final pc = await webrtc.createPeerConnection(configuration);
    
    _localStream?.getTracks().forEach((track) {
      pc.addTrack(track, _localStream!);
    });

    pc.onIceCandidate = (candidate) {
      onIceCandidate(candidate);
    };

    pc.onTrack = (event) {
      if (event.track.kind == 'audio') {
        print('Received remote audio track from $remoteId');
      }
    };

    _peerConnections[remoteId] = pc;
    return pc;
  }

  Future<webrtc.RTCSessionDescription> createOffer(String remoteId) async {
    final pc = _peerConnections[remoteId];
    if (pc == null) throw Exception('PeerConnection not found for $remoteId');
    
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    return offer;
  }

  Future<webrtc.RTCSessionDescription> createAnswer(String remoteId, webrtc.RTCSessionDescription offer) async {
    final pc = _peerConnections[remoteId];
    if (pc == null) throw Exception('PeerConnection not found for $remoteId');
    
    await pc.setRemoteDescription(offer);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    return answer;
  }

  Future<void> setRemoteDescription(String remoteId, webrtc.RTCSessionDescription description) async {
    final pc = _peerConnections[remoteId];
    await pc?.setRemoteDescription(description);
  }

  Future<void> addIceCandidate(String remoteId, webrtc.RTCIceCandidate candidate) async {
    final pc = _peerConnections[remoteId];
    await pc?.addCandidate(candidate);
  }

  void toggleMute() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      _isMuted = !_isMuted;
      _localStream!.getAudioTracks()[0].enabled = !_isMuted;
      notifyListeners();
    }
  }

  void toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    webrtc.Helper.setSpeakerphoneOn(_isSpeakerOn);
    notifyListeners();
  }

  void removePeer(String remoteId) {
    _peerConnections[remoteId]?.dispose();
    _peerConnections.remove(remoteId);
    notifyListeners();
  }

  @override
  void dispose() {
    _localStream?.dispose();
    for (var pc in _peerConnections.values) {
      pc.dispose();
    }
    _peerConnections.clear();
    super.dispose();
  }
}
