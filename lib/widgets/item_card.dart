// lib/widgets/item_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/design_tokens.dart';

class ItemCard extends StatelessWidget {
  final String title;
  final String description;
  final String? imageUrl;
  final String ownerName;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback? onAction;

  const ItemCard({
    super.key,
    required this.title,
    required this.description,
    this.imageUrl,
    required this.ownerName,
    required this.status,
    this.onTap,
    this.onAction,
  });

  Color _statusColor(String s) {
    final st = s.toLowerCase();
    if (st == 'available') return AppColors.success;
    if (st == 'borrowed') return AppColors.info;
    if (st == 'pending') return Colors.orange;
    if (st == 'rejected') return AppColors.danger;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: AppRadius.card,
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            // 🖼 Image Preview
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 88,
                        height: 88,
                        color: Colors.grey.shade200,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 88,
                        height: 88,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image),
                      ),
                    )
                  : Container(
                      width: 88,
                      height: 88,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.inventory_2, size: 36),
                    ),
            ),

            const SizedBox(width: 12),

            // 📝 Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Status Pill
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleMedium, // ✅ 修正
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          status.replaceAll('_', ' ').toUpperCase()
,
                          style: AppText.labelMedium.copyWith(color: statusColor), // ✅ 修正
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMedium, // ✅ 修正
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Text("Owner: $ownerName", style: AppText.bodyMedium), // ✅ 修正
                      const Spacer(),
                     ElevatedButton(
  onPressed: onAction,
  style: AppButtons.primary.copyWith(
    minimumSize: MaterialStateProperty.all(const Size(0, 36)), // 卡片内小按钮
    padding: MaterialStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 14),
    ),
    textStyle: MaterialStateProperty.all(
      const TextStyle(fontSize: 13),
    ),
  ),
  child: const Text("View"),
),

                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
