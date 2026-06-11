import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/screens/main_screen.dart';

class NfcLoginScreen extends StatefulWidget {
  const NfcLoginScreen({super.key});

  @override
  State<NfcLoginScreen> createState() => _NfcLoginScreenState();
}

class _NfcLoginScreenState extends State<NfcLoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isScanning = false;
  bool _isProcessing = false;
  String _statusMessage = "Ready to Scan";
  String? _errorMessage;

  static const MethodChannel _nfcChannel = MethodChannel('com.example.tap_attend/nfc');
  static const EventChannel _nfcEventChannel = EventChannel('com.example.tap_attend/nfc_events');
  StreamSubscription? _nfcSubscription;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _startNfcSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _stopNfcSession();
    super.dispose();
  }

  Future<void> _startNfcSession() async {
    if (mounted) {
      setState(() {
        _isScanning = true;
        _errorMessage = null;
        _statusMessage = "Hold your university NFC card near the back of your phone";
      });
    }

    try {
      if (Platform.isAndroid) {
        await _nfcChannel.invokeMethod('startNfc');
        _nfcSubscription?.cancel();
        _nfcSubscription = _nfcEventChannel.receiveBroadcastStream().listen((dynamic uid) async {
          if (uid is String) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Card detected! UID: $uid'),
                  backgroundColor: Colors.blue,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            await _handleNfcLogin(uid);
          }
        });
      } else {
        if (mounted) {
          setState(() {
            _isScanning = false;
            _statusMessage = "NFC scanning is currently configured for Android only.\nPlease use the simulation button below.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _errorMessage = "Error initializing NFC: $e";
        });
      }
    }
  }

  Future<void> _stopNfcSession() async {
    try {
      _nfcSubscription?.cancel();
      if (Platform.isAndroid) {
        await _nfcChannel.invokeMethod('stopNfc');
      }
    } catch (_) {}
  }

  Future<void> _handleNfcLogin(String cardUid) async {
    // Do not await this, to avoid blocking the UI if the platform channel hangs
    _stopNfcSession();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Starting authentication for UID: $cardUid...'),
        duration: const Duration(seconds: 2),
      ),
    );

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _statusMessage = "Authenticating card...";
    });

    try {
      final provider = context.read<AttendanceProvider>();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Server connection: ${provider.isServerConnectionActive ? "Active (IP: ${provider.serverIp})" : "Inactive (Offline fallback)"}'),
          duration: const Duration(seconds: 2),
        ),
      );

      final success = await provider.loginWithNfc(cardUid);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'NFC login successful!' : 'NFC login failed: Card not registered.'),
            backgroundColor: success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        if (success) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        } else {
          setState(() {
            _errorMessage = "Invalid card (UID: $cardUid). This NFC card is not registered to any lecturer.";
          });
          // Restart NFC listening for retry
          _startNfcSession();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = "Authentication failed: $e";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        _startNfcSession();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('NFC Card Sign In'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'University Card Sign In',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Hold your lecturer smart card close to the NFC sensor.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              
              // Radar Pulse Animation
              Center(
                child: SizedBox(
                  height: 200,
                  width: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isScanning && !_isProcessing)
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Container(
                              width: 120 * _pulseAnimation.value,
                              height: 120 * _pulseAnimation.value,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: primaryColor.withValues(alpha: 0.15 * (1.6 - _pulseAnimation.value)),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.5 * (1.6 - _pulseAnimation.value)),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isProcessing 
                              ? Colors.grey.withValues(alpha: 0.1) 
                              : primaryColor.withValues(alpha: 0.1),
                          border: Border.all(
                            color: _isProcessing ? Colors.grey : primaryColor,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _isProcessing ? Icons.sync : Icons.nfc,
                          size: 48,
                          color: _isProcessing ? Colors.grey : primaryColor,
                        ),
                      ),
                      if (_isProcessing)
                        const SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Status & Error Messages
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: _errorMessage != null 
                    ? Colors.redAccent.withValues(alpha: 0.05) 
                    : (isDark ? Colors.grey[900] : Colors.grey[100]),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    children: [
                      Text(
                        _errorMessage ?? _statusMessage,
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w500,
                          color: _errorMessage != null ? Colors.redAccent : (isDark ? Colors.white70 : Colors.black87),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Simulator Button
              ElevatedButton.icon(
                onPressed: _isProcessing 
                    ? null 
                    : () => _showSimulateDialog(),
                icon: const Icon(Icons.flash_on),
                label: const Text('Simulate NFC Scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Cancel Button
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Cancel & Return to Login'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showSimulateDialog() {
    final controller = TextEditingController(text: 'lecturer_card_1');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Simulate NFC Card Scan'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Enter a mock card UID to simulate a scan. Default lecturer sharvin is seeded with "lecturer_card_1".',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Simulated Card UID',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final cardUid = controller.text.trim();
                Navigator.pop(context);
                if (cardUid.isNotEmpty) {
                  _handleNfcLogin(cardUid);
                }
              },
              child: const Text('Simulate Tap'),
            ),
          ],
        );
      },
    );
  }
}
