import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:get_storage/get_storage.dart';
import '../../core/constants/app_constants.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/events_controller.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'event_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const _WelcomePage(),
    EventsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _syncAuthToBackground();
  }

  void _syncAuthToBackground() {
    final storage = GetStorage();
    final token = storage.read(AppConstants.tokenKey);
    final userId = storage.read(AppConstants.userIdKey);

    if (token != null && userId != null) {
      FlutterBackgroundService().invoke("update_auth", {
        "token": token,
        "user_id": userId.toString(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppConstants.primaryColor,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event), label: 'Events'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final AuthController auth = Get.find<AuthController>();
    final EventsController eventsCtrl = Get.find<EventsController>();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Welcome Header
              Obx(() {
                final name = auth.currentUser.value?.displayName ?? 'User';
                final firstName = name.split(' ').first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
                    ),
                    Text(
                      firstName,
                      style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: AppConstants.primaryColor),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 30),

              // App Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radius * 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppConstants.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.directions_walk, size: 50, color: Colors.white),
                    const SizedBox(height: 12),
                    Text(
                      AppConstants.appName,
                      style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track your steps, achieve your goals',
                      style: GoogleFonts.poppins(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Your Events Section
              Text(
                'Your Events',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor),
              ),
              const SizedBox(height: 12),

              Obx(() {
                final events = eventsCtrl.events;
                if (events.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppConstants.radius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No events yet',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Check the Events tab for available challenges',
                          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                // Show events list
                return Column(
                  children: events.map((event) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {},
                      borderRadius: BorderRadius.circular(AppConstants.radius),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppConstants.radius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppConstants.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.emoji_events, color: AppConstants.primaryColor, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.eventName,
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppConstants.primaryColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Goal: ${event.eventGoal} steps',
                                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                );
              }),

              const SizedBox(height: 30),

              // Footer
              Center(
                child: Text(
                  '© ${DateTime.now().year} FestEx India',
                  style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
