import 'package:flutter/material.dart';

import 'theme.dart';

/// Ícono según el nombre de la categoría (las por defecto de `create_group`
/// y variantes comunes). Las desconocidas usan un recibo.
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);

  if (has(['super', 'almacén', 'verdu', 'carni'])) {
    return Icons.shopping_basket_outlined;
  }
  if (has(['alquiler', 'expensa'])) return Icons.home_outlined;
  if (has(['servicio', 'luz', 'gas', 'agua', 'internet'])) {
    return Icons.bolt_outlined;
  }
  if (has(['limpieza'])) return Icons.cleaning_services_outlined;
  if (has(['comida', 'resto', 'delivery'])) return Icons.restaurant_outlined;
  if (has(['hogar', 'mueble'])) return Icons.chair_outlined;
  if (has(['transporte', 'nafta', 'auto', 'uber'])) {
    return Icons.directions_bus_outlined;
  }
  return Icons.receipt_long_outlined;
}

/// Círculo negro con el ícono de la categoría.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.categoryName});

  final String categoryName;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.ink,
      foregroundColor: AppColors.onInk,
      child: Icon(categoryIcon(categoryName), size: 22),
    );
  }
}
