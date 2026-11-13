import 'package:material_ui/material_ui.dart';

/// Icon and color of a category. Unknown or missing categories get a neutral
/// style.
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;
}

CategoryStyle categoryStyle(String? category, Color neutral) => switch (category
    ?.trim()
    .toLowerCase()) {
  'mercado' => const CategoryStyle(
    Icons.shopping_cart_outlined,
    Color(0xFF2E9E6B),
  ),
  'moradia' => const CategoryStyle(Icons.home_outlined, Color(0xFF5B6EE1)),
  'transporte' => const CategoryStyle(
    Icons.directions_car_outlined,
    Color(0xFFE08A1E),
  ),
  'lazer' => const CategoryStyle(Icons.celebration_outlined, Color(0xFFD6558B)),
  'saúde' => const CategoryStyle(
    Icons.favorite_border_rounded,
    Color(0xFFD9534F),
  ),
  'assinaturas' => const CategoryStyle(
    Icons.autorenew_rounded,
    Color(0xFF7E57C2),
  ),
  'educação' => const CategoryStyle(Icons.school_outlined, Color(0xFF1E88E5)),
  'salário' => const CategoryStyle(Icons.payments_outlined, Color(0xFF17703F)),
  _ => CategoryStyle(Icons.receipt_long_outlined, neutral),
};
