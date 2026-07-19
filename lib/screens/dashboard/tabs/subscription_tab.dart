import 'package:flutter/material.dart';

/// UI-only placeholder for the Subscription tab. Shows a plan card
/// and a simple feature list -- wire the "Upgrade" button to your real
/// billing/payment flow later.
class SubscriptionTab extends StatelessWidget {
  const SubscriptionTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.primary, colorScheme.tertiary],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.workspace_premium, color: colorScheme.onPrimary, size: 36),
              const SizedBox(height: 12),
              Text(
                'Free Plan',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upgrade to unlock premium stories & documentaries',
                style: TextStyle(color: colorScheme.onPrimary.withOpacity(0.9)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.onPrimary,
                  foregroundColor: colorScheme.primary,
                ),
                onPressed: () {
                  // TODO: wire to real payment/upgrade flow
                },
                child: const Text('Upgrade now'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'What you get with Premium',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _FeatureRow(icon: Icons.block, text: 'Ad-free experience'),
        _FeatureRow(icon: Icons.download_outlined, text: 'Offline downloads'),
        _FeatureRow(icon: Icons.hd_outlined, text: 'HD quality streaming'),
        _FeatureRow(icon: Icons.new_releases_outlined, text: 'Early access to new releases'),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
