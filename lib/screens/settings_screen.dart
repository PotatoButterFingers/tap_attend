import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/providers/attendance_provider.dart';
import 'package:tap_attend/screens/profile_screen.dart';
import 'package:tap_attend/screens/student_directory_screen.dart';
import 'package:tap_attend/screens/login_screen.dart';
import 'package:tap_attend/screens/sync_queue_screen.dart';
import 'package:tap_attend/screens/manage_history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final totalPending = provider.pendingRegistrations.length +
        provider.pendingDeletions.length +
        provider.unsyncedSessionIds.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Account',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: const Text('Profile'),
              subtitle: const Text('Update personal information'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'Management',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people, color: Colors.purple),
              ),
              title: const Text('Student Directory'),
              subtitle: const Text('View and manage enrolled students'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentDirectoryScreen()));
              },
            ),
            const SizedBox(height: 32),
            const Text(
              'System',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sync, color: Colors.orange),
              ),
              title: const Text('Sync Queue'),
              subtitle: const Text('Manage offline pending records'),
              trailing: totalPending > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$totalPending',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  : const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncQueueScreen()));
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dns, color: Colors.blue),
              ),
              title: const Text('Server IP Settings'),
              subtitle: Text('Current: ${provider.serverIp}'),
              trailing: const Icon(Icons.edit, size: 16),
              onTap: () => _showServerIpDialog(context, provider),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.delete_sweep, color: Colors.red),
              ),
              title: const Text('Manage History'),
              subtitle: const Text('Delete past session recordings'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageHistoryScreen()));
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.logout, color: Colors.red),
              ),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () async {
                await provider.signOutLecturer();
                if (context.mounted) {
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                }
              },
            ),
          ],
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
              content: Column(
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
                          final foundIp = await provider.autoDiscoverServer();
                          if (context.mounted) {
                            setState(() {
                              isSearching = false;
                            });
                            if (foundIp != null) {
                              controller.text = foundIp;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('XAMPP Server discovered at $foundIp!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
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
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

