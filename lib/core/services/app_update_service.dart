import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';

/// Service for handling app updates on both Android and iOS
class AppUpdateService extends GetxService {
  final RxBool isUpdateAvailable = false.obs;
  final RxBool isUpdateRequired = false.obs;
  final RxBool isCheckingUpdate = false.obs;
  final RxBool isAppBlocked = false.obs;
  final RxBool isFlexibleUpdateDownloading = false.obs;
  final RxBool isFlexibleUpdateReady = false.obs;
  final RxString latestVersion = ''.obs;
  final RxString currentVersion = ''.obs;
  final RxInt updatePriority = 0.obs;

  AppUpdateInfo? _updateInfo;
  Timer? _updateCheckTimer;

  @override
  void onInit() {
    super.onInit();
    _initializeService();
    _startPeriodicUpdateChecks();
  }

  @override
  void onClose() {
    _updateCheckTimer?.cancel();
    super.onClose();
  }

  Future<void> _initializeService() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      currentVersion.value = packageInfo.version;
      debugPrint('App Update Service initialized. Current version: ${currentVersion.value}');
    } catch (e) {
      debugPrint('Failed to initialize App Update Service: $e');
    }
  }

  void _startPeriodicUpdateChecks() {
    _updateCheckTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      checkForUpdates(showNoUpdateMessage: false);
    });
  }

  Future<void> checkForUpdates({bool showNoUpdateMessage = false}) async {
    try {
      isCheckingUpdate.value = true;

      if (Platform.isAndroid) {
        await _checkAndroidUpdate();
      }

      if (showNoUpdateMessage && !isUpdateAvailable.value) {
        Get.snackbar(
          'Up to Date',
          'You are using the latest version of ${AppConstants.appName}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    } finally {
      isCheckingUpdate.value = false;
    }
  }

  Future<void> _checkAndroidUpdate() async {
    try {
      _updateInfo = await InAppUpdate.checkForUpdate();

      if (_updateInfo != null) {
        isUpdateAvailable.value = _updateInfo!.updateAvailability == UpdateAvailability.updateAvailable;
        updatePriority.value = _updateInfo!.updatePriority;
        isUpdateRequired.value = _updateInfo!.updatePriority >= 4;
        isAppBlocked.value = _updateInfo!.updatePriority >= 5;

        debugPrint('Android update check: available=${isUpdateAvailable.value}, required=${isUpdateRequired.value}, blocked=${isAppBlocked.value}');

        if (isAppBlocked.value) {
          showCriticalUpdateDialog();
        }
      }
    } catch (e) {
      debugPrint('Android update check failed: $e');
    }
  }

  Future<void> startImmediateUpdate() async {
    if (!Platform.isAndroid || _updateInfo == null) return;

    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (e) {
      debugPrint('Failed to start immediate update: $e');
      Get.snackbar(
        'Update Failed',
        'Unable to start the update. Please try updating from Play Store.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> startFlexibleUpdate() async {
    if (!Platform.isAndroid || _updateInfo == null) return;

    if (isFlexibleUpdateDownloading.value) {
      Get.snackbar(
        'Update In Progress',
        'An update is already downloading. Please wait...',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    try {
      isFlexibleUpdateDownloading.value = true;
      await InAppUpdate.startFlexibleUpdate();

      Get.snackbar(
        'Update Started',
        'App update is downloading in the background...',
        backgroundColor: AppConstants.primaryColor,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
      );

      _monitorFlexibleUpdate();
    } catch (e) {
      isFlexibleUpdateDownloading.value = false;
      debugPrint('Failed to start flexible update: $e');

      Get.snackbar(
        'Update Failed',
        'Unable to download the update. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        mainButton: TextButton(
          onPressed: () => openPlayStore(),
          child: const Text('OPEN PLAY STORE', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  void _monitorFlexibleUpdate() {
    int attempts = 0;
    const maxAttempts = 150;

    Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;

      try {
        final updateInfo = await InAppUpdate.checkForUpdate();

        switch (updateInfo.installStatus) {
          case InstallStatus.downloaded:
            timer.cancel();
            isFlexibleUpdateDownloading.value = false;
            isFlexibleUpdateReady.value = true;

            Get.snackbar(
              'Update Ready!',
              'App update downloaded. Restart to apply changes.',
              backgroundColor: Colors.green,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP,
              duration: const Duration(seconds: 8),
              mainButton: TextButton(
                onPressed: () => restartApp(),
                child: const Text('RESTART NOW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
            break;

          case InstallStatus.failed:
          case InstallStatus.canceled:
            timer.cancel();
            isFlexibleUpdateDownloading.value = false;
            break;

          default:
            break;
        }

        if (attempts >= maxAttempts) {
          timer.cancel();
          isFlexibleUpdateDownloading.value = false;
        }
      } catch (e) {
        if (attempts >= 10) {
          timer.cancel();
          isFlexibleUpdateDownloading.value = false;
        }
      }
    });
  }

  Future<void> openPlayStore() async {
    try {
      const playStoreUrl = 'https://play.google.com/store/apps/details?id=com.festexindia.festplay';
      final uri = Uri.parse(playStoreUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to open Play Store: $e');
      Get.snackbar(
        'Error',
        'Unable to open Play Store. Please search for ${AppConstants.appName} manually.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    }
  }

  Future<void> openAppStore() async {
    try {
      // Replace with your actual App Store URL
      const appStoreUrl = 'https://apps.apple.com/app/id[YOUR_APP_ID]';
      final uri = Uri.parse(appStoreUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Failed to open App Store: $e');
    }
  }

  void showCriticalUpdateDialog() {
    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              const Text(
                'Critical Update Required',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A critical security update is required. You cannot continue using ${AppConstants.appName} until you update.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This update includes important security fixes.',
                        style: TextStyle(fontSize: 14, color: Colors.red[700], fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              if (currentVersion.value.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Current Version: ${currentVersion.value}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (Platform.isAndroid) {
                    startImmediateUpdate();
                  } else {
                    openAppStore();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  Platform.isAndroid ? 'Update Now' : 'Open App Store',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }

  void showUpdateDialog() {
    if (isAppBlocked.value) {
      showCriticalUpdateDialog();
      return;
    }

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(
              isUpdateRequired.value ? Icons.priority_high : Icons.system_update,
              color: isUpdateRequired.value ? Colors.orange : AppConstants.primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              isUpdateRequired.value ? 'Update Required' : 'Update Available',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUpdateRequired.value
                  ? 'An important update is required for ${AppConstants.appName}. Please update to continue.'
                  : 'A new version of ${AppConstants.appName} is available with improvements and bug fixes.',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        actions: [
          if (!isUpdateRequired.value)
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              if (Platform.isAndroid) {
                if (isUpdateRequired.value) {
                  startImmediateUpdate();
                } else {
                  startFlexibleUpdate();
                }
              } else {
                openAppStore();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isUpdateRequired.value ? Colors.orange : AppConstants.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(Platform.isAndroid ? 'Update Now' : 'Open App Store'),
          ),
        ],
      ),
      barrierDismissible: !isUpdateRequired.value,
    );
  }

  void restartApp() {
    InAppUpdate.completeFlexibleUpdate();
  }

  Future<void> autoCheckForUpdates() async {
    await checkForUpdates(showNoUpdateMessage: false);

    if (isUpdateAvailable.value && isUpdateRequired.value) {
      showUpdateDialog();
    } else if (isUpdateAvailable.value) {
      Get.snackbar(
        'Update Available',
        'A new version of ${AppConstants.appName} is available',
        backgroundColor: AppConstants.primaryColor,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 4),
        mainButton: TextButton(
          onPressed: () => showUpdateDialog(),
          child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
        ),
      );
    }
  }

  Future<bool> checkForForceUpdate() async {
    try {
      isCheckingUpdate.value = true;

      if (Platform.isAndroid) {
        await _checkAndroidUpdate();
        return isAppBlocked.value;
      }

      return false;
    } catch (e) {
      debugPrint('Error checking for force update: $e');
      return false;
    } finally {
      isCheckingUpdate.value = false;
    }
  }
}
