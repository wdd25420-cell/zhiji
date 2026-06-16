import 'package:flutter/material.dart';
import '../../../core/theme/dimensions.dart';
import '../../../core/database/app_database.dart';

class CategoryFilterChips extends StatelessWidget {
  const CategoryFilterChips({
    super.key,
    required this.db,
    required this.selected,
    required this.onChanged,
  });

  final AppDatabase db;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategoryModel>>(
      future: db.knowledgeDao.listCategories(),
      builder: (ctx, snap) {
        final cats = snap.data ?? [];
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: FilterChip(
                  label: const Text('全部'),
                  selected: selected == null,
                  onSelected: (_) => onChanged(null),
                ),
              ),
              ...cats.map((c) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: selected == c.id,
                      onSelected: (_) => onChanged(c.id),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}
