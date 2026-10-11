import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';

/// Custom component: a grid of tappable category tiles. It is
/// *controlled*, holding no selection of its own: the parent owns
/// `selected` and updates it from `onChanged`.
///
/// Properties
///   categories    the options to show
///   selected      the currently selected categories
///   maxSelection  optional cap; 1 makes it single-select, where picking a
///                 new tile replaces the old one
///   columns       tiles per row (default 4)
/// Events
///   onChanged     the selection changed; receives the new set
class WasteCategoryPicker extends StatelessWidget {
  final List<WasteCategory> categories;
  final Set<WasteCategory> selected;
  final ValueChanged<Set<WasteCategory>> onChanged;
  final int? maxSelection;
  final int columns;

  const WasteCategoryPicker({
    super.key,
    required this.categories,
    required this.selected,
    required this.onChanged,
    this.maxSelection,
    this.columns = 4,
  });

  IconData _iconFor(WasteCategory c) => switch (c) {
    WasteCategory.plastic => Icons.local_drink_outlined,
    WasteCategory.glass => Icons.wine_bar_outlined,
    WasteCategory.paper => Icons.description_outlined,
    WasteCategory.metal => Icons.build_outlined,
    WasteCategory.illegalDumping => Icons.delete_forever_outlined,
    WasteCategory.overflowingBin => Icons.delete_outline,
    WasteCategory.eWaste => Icons.devices_other_outlined,
    WasteCategory.other => Icons.category_outlined,
  };

  void _toggle(WasteCategory c) {
    final max = maxSelection;
    final next = {...selected};
    if (next.contains(c)) {
      next.remove(c);
    } else if (max == 1) {
      next
        ..clear()
        ..add(c);
    } else if (max == null || next.length < max) {
      next.add(c);
    } else {
      return; // at the cap: ignore the tap
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 0.9,
      children: [for (final c in categories) _tile(c)],
    );
  }

  Widget _tile(WasteCategory c) {
    final isSelected = selected.contains(c);
    return Semantics(
      button: true,
      selected: isSelected,
      label: c.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: () => _toggle(c),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.lightGreen : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _iconFor(c),
                color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                c.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}