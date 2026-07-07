import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerDownloadList extends StatelessWidget {
  final int count;

  const ShimmerDownloadList({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final block = isDark ? Colors.grey.shade900 : Colors.white;

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: block,
            radius: 22,
          ),
          title: Container(
            height: 14,
            width: 180,
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 10,
                  width: 140,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 8,
                  width: 80,
                  decoration: BoxDecoration(
                    color: block,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          trailing: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
