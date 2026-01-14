import 'package:flutter/material.dart';
import '../services/license_service.dart';

/// Widget that displays demo mode information and upgrade prompts
class DemoModeBanner extends StatefulWidget {
  final VoidCallback? onUpgradePressed;
  
  const DemoModeBanner({
    super.key,
    this.onUpgradePressed,
  });

  @override
  State<DemoModeBanner> createState() => _DemoModeBannerState();
}

class _DemoModeBannerState extends State<DemoModeBanner> {
  late Future<bool> _isPurchasedFuture;

  @override
  void initState() {
    super.initState();
    _isPurchasedFuture = LicenseService.isPurchased();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isPurchasedFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        if (snapshot.data == true) {
          // Full version - show premium badge
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              border: Border.all(color: Colors.amber, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, size: 16, color: Colors.amber),
                SizedBox(width: 8),
                Text(
                  '🔓 Full Version',
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        } else {
          // Demo mode - show upgrade button
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              border: Border.all(color: Colors.blue, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '📱 Demo Mode',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: widget.onUpgradePressed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Upgrade',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

/// Dialog to show demo limit reached
class DemoLimitDialog extends StatelessWidget {
  final String limitType; // "staff", "roster", "weeks"
  final VoidCallback? onUpgradePressed;

  const DemoLimitDialog({
    super.key,
    required this.limitType,
    this.onUpgradePressed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.orange),
          SizedBox(width: 8),
          Text('Demo Limit Reached'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You\'ve reached the maximum number of $limitType allowed in demo mode.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Demo Limits:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('• Maximum ${LicenseService.maxStaffInDemo} staff members'),
                Text('• Maximum ${LicenseService.maxRostersInDemo} rosters'),
                Text('• Maximum ${LicenseService.maxWeeksInDemo} weeks'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upgrade to the full app to enjoy unlimited features and cloud synchronization!',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onUpgradePressed?.call();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_cart, size: 16),
              SizedBox(width: 4),
              Text('Upgrade Now'),
            ],
          ),
        ),
      ],
    );
  }
}

/// Show demo limit dialog
void showDemoLimitDialog(
  BuildContext context, {
  required String limitType,
  VoidCallback? onUpgradePressed,
}) {
  showDialog(
    context: context,
    builder: (context) => DemoLimitDialog(
      limitType: limitType,
      onUpgradePressed: onUpgradePressed,
    ),
  );
}
