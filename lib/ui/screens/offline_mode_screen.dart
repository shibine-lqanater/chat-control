import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/network_discovery.dart';
import '../../core/offline_client.dart';
import 'host_dashboard_screen.dart';
import 'chat_screen.dart';

class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  bool _isSearching = false;

  void _hostNetwork() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HostDashboardScreen()),
    );
  }

  void _joinNetwork() async {
    setState(() => _isSearching = true);
    
    final discovery = Provider.of<NetworkDiscoveryService>(context, listen: false);
    final client = Provider.of<OfflineClient>(context, listen: false);
    
    final service = await discovery.discoverHost();
    
    if (service != null && service.host != null && service.port != null) {
      final myId = "User-${const Uuid().v4().substring(0, 4)}";
      client.setClientId(myId);
      
      await client.connect(service.host!, service.port!);
      
      if (mounted) {
        // Listen for approval status
        client.onStatusChanged = (status) {
          if (status == OfflineClientStatus.approved.toString()) {
             Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  channelId: 'Local-Network',
                  isOnlineMode: false,
                  isHost: false,
                ),
              ),
            );
          } else if (status == OfflineClientStatus.rejected.toString()) {
            setState(() => _isSearching = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Join request rejected by Admin')),
            );
          }
        };
      }
    } else {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No Host found on this network')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('offline_mode'.tr()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.wifi_tethering, size: 80, color: Colors.green),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _hostNetwork,
                icon: const Icon(Icons.admin_panel_settings),
                label: Text('host_network'.tr(), style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: const BorderSide(color: Colors.green),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSearching ? null : _joinNetwork,
                icon: _isSearching
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  _isSearching ? 'waiting_for_admin'.tr() : 'join_network'.tr(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
