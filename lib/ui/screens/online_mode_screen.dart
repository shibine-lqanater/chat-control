import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

import '../../core/online_client.dart';
import 'chat_screen.dart';

class OnlineModeScreen extends StatefulWidget {
  const OnlineModeScreen({super.key});

  @override
  State<OnlineModeScreen> createState() => _OnlineModeScreenState();
}

class _OnlineModeScreenState extends State<OnlineModeScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _serverController = TextEditingController(text: 'http://localhost:3000');
  final _formKey = GlobalKey<FormState>();
  bool _isConnecting = false;

  String _generatePassword() {
    final random = Random();
    String password = '';
    for (int i = 0; i < 20; i++) {
      password += random.nextInt(10).toString();
    }
    return password;
  }

  void _joinOrCreateChannel(String password) async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isConnecting = true);
      
      final client = Provider.of<OnlineClient>(context, listen: false);
      final myId = "User-${const Uuid().v4().substring(0, 4)}";
      
      try {
        client.init(_serverController.text.trim(), myId);
        
        // Wait for connection
        int retry = 0;
        while (!client.isConnected && retry < 10) {
          await Future.delayed(const Duration(milliseconds: 500));
          retry++;
        }

        if (client.isConnected) {
          client.joinRoom(password);
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  channelId: password,
                  isOnlineMode: true,
                ),
              ),
            );
          }
        } else {
          throw Exception("Could not connect to server");
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isConnecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('online_mode'.tr()),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.public, size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _serverController,
                  decoration: InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'http://your-server-ip:3000',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.dns),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  keyboardType: TextInputType.number,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: 'channel_password'.tr(),
                    hintText: 'enter_password'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.length != 20) {
                      return 'invalid_password'.tr();
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isConnecting ? null : () => _joinOrCreateChannel(_passwordController.text),
                  child: _isConnecting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('join_channel'.tr(), style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordController.text = _generatePassword();
                    });
                  },
                  child: Text('create_channel'.tr(), style: const TextStyle(fontSize: 18)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
