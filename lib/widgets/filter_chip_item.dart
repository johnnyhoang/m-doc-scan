import 'package:flutter/material.dart';
import '../models/document_model.dart';

class FilterChipItem extends StatelessWidget {
  final EnhancementMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const FilterChipItem({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  IconData _getModeIcon(EnhancementMode mode) {
    switch (mode) {
      case EnhancementMode.magicColor:
        return Icons.auto_awesome;
      case EnhancementMode.cleanBg:
        return Icons.cleaning_services;
      case EnhancementMode.sharpText:
        return Icons.text_fields;
      case EnhancementMode.restoreYellowed:
        return Icons.history_edu;
      case EnhancementMode.removeBleedthrough:
        return Icons.layers_clear;
      case EnhancementMode.highContrastStamp:
        return Icons.verified;
      case EnhancementMode.superSharpMono:
        return Icons.receipt_long;
      case EnhancementMode.bwScan:
        return Icons.document_scanner;
      case EnhancementMode.natural:
        return Icons.tune;
      case EnhancementMode.original:
        return Icons.image_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : theme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : Colors.grey.withOpacity(0.25),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getModeIcon(mode),
                size: 18,
                color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
              ),
              const SizedBox(width: 6),
              Text(
                mode.displayName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
