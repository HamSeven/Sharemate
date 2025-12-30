// lib/widgets/auth_card.dart
import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Reusable Auth Card used by Login / Register / Verify pages.
/// UI is fully driven by design tokens.
class AuthCard extends StatelessWidget {
  final Widget? headerIcon;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? bottomActions;

  final EdgeInsetsGeometry padding;
  final double maxWidth;

  const AuthCard({
    super.key,
    this.headerIcon,
    required this.title,
    this.subtitle,
    required this.children,
    this.bottomActions,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    this.maxWidth = 460,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: padding,
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.card,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // =====================
              // Header Icon
              // =====================
              if (headerIcon != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    shape: BoxShape.circle,
                  ),
                  child: headerIcon,
                ),
              if (headerIcon != null) const SizedBox(height: 12),

              // =====================
              // Title
              // =====================
              Text(
                title,
                style: AppText.titleLarge,
                textAlign: TextAlign.center,
              ),

              if (subtitle != null) const SizedBox(height: 6),

              if (subtitle != null)
                Text(
                  subtitle!,
                  style: AppText.bodyMedium,
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 16),

              // =====================
              // Content (Form fields, errors, buttons)
              // =====================
              ...children,

              if (bottomActions != null) const SizedBox(height: 12),

              if (bottomActions != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: bottomActions!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
