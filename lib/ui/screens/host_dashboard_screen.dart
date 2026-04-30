import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../../core/offline_server.dart';
import '../../core/network_discovery.dart';
import 'chat_screen.dart';

class HostDashboardScreen extends StatefulWidget {
  const HostDashboardScreen({super.key});

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  @override
  void initState() {
    super.initState();
    _startHosting();
  }

  void _startHosting() async {
    final server = Provider.of<OfflineServer>(context, listen: false);
    final discovery = Provider.of<NetworkDiscoveryService>(context, listen: false);

    await server.startServer();
    await discovery.startHosting(server.port);
  }

  @override
  void dispose() {
    // Note: We might want to keep the server running if we go to chat
    // but usually if we exit dashboard we stop.
    super.dispose();
  }

  void _stopHosting() async {
    final server = Provider.of<OfflineServer>(context, listen: false);
    final discovery = Provider.of<NetworkDiscoveryService>(context, listen: false);

    await discovery.stopHosting();
    await server.stopServer();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final server = Provider.of<OfflineServer>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('host_network'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle, color: Colors.red),
            onPressed: _stopHosting,
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.green.withOpacity(0.1),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Admin: Hosting on port ${server.port}. Waiting for users...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Pending Requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: server.pendingRequests.length,
              itemBuilder: (context, index) {
                final clientId = server.pendingRequests[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(clientId),
                  subtitle: const Text('Wants to join the chat'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        onPressed: () => server.approveClient(clientId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        onPressed: () => server.rejectClient(clientId),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Approved Users: ${server.approvedClients.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatScreen(
                      channelId: 'Host-Local',
                      isOnlineMode: false,
                      isHost: true,
                    ),
                  ),
                );
              },
              child: Text('start_chatting'.tr()),
            ),
          ),
        ],
      ),
    );
  }
}
