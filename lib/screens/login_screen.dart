import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/screens/main_screen.dart';
import 'package:tap_attend/screens/nfc_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _lecturerIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;

  Future<bool> _showExitDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.exit_to_app, color: Colors.blue),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Exit App'),
                ),
              ],
            ),
            content: const Text('Are you sure you want to exit TapAttend?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleSignIn() async {
    final lecturerId = _lecturerIdController.text.trim();
    final password = _passwordController.text.trim();

    if (lecturerId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both Lecturer ID and Password.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final provider = context.read<AttendanceProvider>();
    final success = await provider.loginLecturer(lecturerId, password);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.isServerConnectionActive
                ? 'Invalid Lecturer ID or Password.'
                : 'Could not connect to server and no offline login cache found.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<AttendanceProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final shouldExit = await _showExitDialog(context);
        if (shouldExit && context.mounted) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24), // Leave room for floating settings button
                  Center(
                    child: Icon(
                      Icons.school,
                      size: 64,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'TapAttend',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'NFC Attendance Management System',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Lecturer Sign In',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        
                        TextField(
                          controller: _lecturerIdController,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Lecturer ID',
                            hintText: 'Enter your ID',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: _obscureText,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleSignIn,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('Or sign in with', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NfcLoginScreen()),
                            );
                          },
                          icon: const Icon(Icons.nfc),
                          label: const Text('University NFC Card', style: TextStyle(fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(color: Theme.of(context).dividerColor),
                            foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Server Connection Settings',
                onPressed: () => _showServerIpDialog(context, provider),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showServerIpDialog(BuildContext context, AttendanceProvider provider) {
    final controller = TextEditingController(text: provider.serverIp);
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Server IP Configuration', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your XAMPP backend Server IP Address or Hostname.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      enabled: !isSearching,
                      decoration: const InputDecoration(
                        labelText: 'Server IP Address',
                        hintText: 'e.g. 10.232.207.170',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    if (isSearching)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Scanning local network for XAMPP server...', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () async {
                            setState(() {
                              isSearching = true;
                            });
                            final foundServer = await provider.autoDiscoverServer();
                            if (context.mounted) {
                              setState(() {
                                isSearching = false;
                              });
                              if (foundServer != null) {
                                if (provider.trustedServerToken != null &&
                                    foundServer.token == provider.trustedServerToken) {
                                  controller.text = foundServer.ip;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Reconnected to trusted server "${foundServer.name}"!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else {
                                  await _showPairingDialog(context, provider, foundServer, controller);
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not find XAMPP server automatically. Please check Apache/MySQL status or type IP manually.'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.youtube_searched_for),
                          label: const Text('Auto-Discover Server IP'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                            foregroundColor: Theme.of(context).primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      '💡 Quick Tips:\n'
                      '• USB Tethering IP: 10.232.207.170\n'
                      '• Android Emulator: 10.0.2.2\n'
                      '• Make sure Apache/MySQL are running in XAMPP.',
                      style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
                    ),
                  ],
                ),
              ),
              actionsOverflowDirection: VerticalDirection.down,
              actionsOverflowButtonSpacing: 8,
              actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              actions: [
                TextButton(
                  onPressed: isSearching ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSearching
                      ? null
                      : () {
                          final newIp = controller.text.trim();
                          if (newIp.isNotEmpty) {
                            provider.updateServerIp(newIp);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Server IP updated to $newIp. Testing connection...'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPairingDialog(
    BuildContext context,
    AttendanceProvider provider,
    DiscoveredServer server,
    TextEditingController controller,
  ) async {
    final bool? shouldPair = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.wifi_tethering, color: Colors.blue),
              SizedBox(width: 8),
              Expanded(
                child: Text('Pair with Server?', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We found a Tap Attend server on your network. Would you like to pair with it?',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.computer, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Name: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Expanded(
                            child: Text(
                              server.name,
                              style: const TextStyle(fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.link, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('IP Address: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(server.ip, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.fingerprint, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          const Text('Token ID: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text(
                            server.token.length > 8 ? '${server.token.substring(0, 8)}...' : server.token,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsOverflowDirection: VerticalDirection.down,
          actionsOverflowButtonSpacing: 8,
          actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Pair & Connect'),
            ),
          ],
        );
      },
    );

    if (shouldPair == true) {
      await provider.setTrustedServer(server);
      controller.text = server.ip;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully paired with "${server.name}"!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
