import 'dart:io';
import 'package:nsd/nsd.dart';

class NetworkDiscoveryService {
  final String _serviceType = '_connectchat._tcp';
  Registration? _registration;
  Discovery? _discovery;

  /// Starts broadcasting the Host IP and Port via mDNS
  Future<void> startHosting(int port) async {
    try {
      _registration = await register(
        Service(
          name: 'ConnectChatHost',
          type: _serviceType,
          port: port,
        ),
      );
      print('Service registered: ${_registration?.service.name}');
    } catch (e) {
      print('Error starting host: $e');
    }
  }

  /// Stops broadcasting
  Future<void> stopHosting() async {
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
  }

  /// Searches for the Host on the local network
  Future<Service?> discoverHost() async {
    try {
      _discovery = await startDiscovery(_serviceType);
      
      // Wait for a service to be discovered (timeout after 10 seconds)
      for (int i = 0; i < 20; i++) {
        if (_discovery!.services.isNotEmpty) {
          final service = _discovery!.services.first;
          await stopDiscovery(_discovery!);
          return service;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      await stopDiscovery(_discovery!);
      return null;
    } catch (e) {
      print('Error discovering host: $e');
      if (_discovery != null) {
        await stopDiscovery(_discovery!);
      }
      return null;
    }
  }
}
