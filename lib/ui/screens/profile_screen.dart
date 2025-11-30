import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final AuthController _auth = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppConstants.primaryColor,
        actions: [
          IconButton(
            onPressed: () => _showSettingsBottomSheet(context),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _auth.refreshProfile(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Column(
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 25),
              _buildProfileInfo(),
              const SizedBox(height: 25),
              _buildQuickActions(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Obx(() {
      final user = _auth.currentUser.value;
      final name = user?.displayName ?? 'User';
      final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppConstants.radius * 2),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                initial,
                style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              user?.email ?? '',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withValues(alpha: 0.9)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildProfileInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile Information',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final user = _auth.currentUser.value;
          if (user == null) {
            return _buildCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'Pull down to refresh profile',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[500]),
                  ),
                ),
              ),
            );
          }

          // Check if we have any extra profile fields
          final hasPhone = user.profile?.mobileNumber.isNotEmpty == true;
          final hasGender = user.profile?.gender.isNotEmpty == true;
          final hasDob = user.profile?.dateOfBirth.isNotEmpty == true;

          return _buildCard(
            child: Column(children: [
              _buildInfoItem(Icons.person, 'Name', user.displayName.isNotEmpty ? user.displayName : 'Not set'),
              _buildInfoItem(Icons.email, 'Email', user.email.isNotEmpty ? user.email : 'Not set',
                isLast: !hasPhone && !hasGender && !hasDob),
              if (hasPhone)
                _buildInfoItem(Icons.phone, 'Phone', user.profile!.mobileNumber,
                  isLast: !hasGender && !hasDob),
              if (hasGender)
                _buildInfoItem(Icons.wc, 'Gender', user.profile!.gender,
                  isLast: !hasDob),
              if (hasDob)
                _buildInfoItem(Icons.cake, 'Date of Birth', user.profile!.dateOfBirth, isLast: true),
            ]),
          );
        }),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor),
        ),
        const SizedBox(height: 12),
        _buildCard(
          child: Column(
            children: [
              _buildActionItem(Icons.description_outlined, 'Terms & Conditions', () => _launchUrl(AppConstants.termsUrl)),
              _buildActionItem(Icons.policy_outlined, 'Privacy Policy', () => _launchUrl(AppConstants.privacyUrl)),
              _buildActionItem(Icons.logout, 'Logout', _showLogoutDialog, color: Colors.red, isLast: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radius),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: child,
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 20),
          const SizedBox(width: 16),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppConstants.primaryColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label, VoidCallback onTap, {Color? color, bool isLast = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? AppConstants.primaryColor, size: 20),
            const SizedBox(width: 16),
            Text(label, style: GoogleFonts.poppins(fontSize: 14, color: color ?? Colors.grey[800])),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Settings', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.description_outlined, color: AppConstants.primaryColor),
                title: const Text('Terms & Conditions'),
                onTap: () {
                  Get.back();
                  _launchUrl(AppConstants.termsUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.policy_outlined, color: AppConstants.primaryColor),
                title: const Text('Privacy Policy'),
                onTap: () {
                  Get.back();
                  _launchUrl(AppConstants.privacyUrl);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Get.back();
                  _showLogoutDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    Get.dialog(
      AlertDialog(
        title: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _auth.logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
