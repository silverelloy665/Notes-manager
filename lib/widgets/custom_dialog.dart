import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import 'primary_button.dart';

/// Generic reusable form dialog adhering to application spacing and corner radius rules.
class CustomDialog extends StatelessWidget {
  final String title;
  final Widget content;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final bool isLoading;
  final IconData? titleIcon;

  const CustomDialog({
    super.key,
    required this.title,
    required this.content,
    this.confirmLabel = 'Save',
    this.onConfirm,
    this.cancelLabel = 'Cancel',
    this.onCancel,
    this.isLoading = false,
    this.titleIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      elevation: 4,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog header
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(titleIcon, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing),

              // Form body
              Flexible(
                child: SingleChildScrollView(
                  child: content,
                ),
              ),

              const SizedBox(height: AppTheme.spacingLg),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : (onCancel ?? () => Navigator.of(context).pop()),
                    child: Text(cancelLabel),
                  ),
                  const SizedBox(width: 12),
                  PrimaryButton(
                    label: confirmLabel,
                    width: 120,
                    height: 42,
                    isLoading: isLoading,
                    onPressed: onConfirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

