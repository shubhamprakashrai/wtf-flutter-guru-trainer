import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class RoleBadge extends StatelessWidget {
  final String label;
  final Color color;
  const RoleBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class UserAvatar extends StatelessWidget {
  final String? url;
  final String fallbackInitial;
  final double size;
  const UserAvatar({super.key, this.url, required this.fallbackInitial, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: const Color(0xFFE4E7EC),
        child: Text(fallbackInitial, style: const TextStyle(color: Color(0xFF344054), fontWeight: FontWeight.w600)),
      );
    }
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0xFFE4E7EC),
          child: Text(fallbackInitial, style: const TextStyle(color: Color(0xFF344054))),
        ),
        errorWidget: (context, _, error) => CircleAvatar(
          radius: size / 2,
          backgroundColor: const Color(0xFFE4E7EC),
          child: Text(fallbackInitial, style: const TextStyle(color: Color(0xFF344054))),
        ),
      ),
    );
  }
}

/// Big tappable home card/tile used by both Home screens (spec section 4).
class HomeActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const HomeActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });

  @override
  State<HomeActionCard> createState() => _HomeActionCardState();
}

class _HomeActionCardState extends State<HomeActionCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EC)),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.color),
                  ),
                  if (widget.badgeCount != null && widget.badgeCount! > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: const BoxDecoration(color: Color(0xFFD92D20), shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '${widget.badgeCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600, color: const Color(0xFF1D2939))),
                    const SizedBox(height: 2),
                    Text(widget.subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingSkeleton extends StatelessWidget {
  final double height;
  final double? width;
  const LoadingSkeleton({super.key, this.height = 16, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(color: const Color(0xFFE4E7EC), borderRadius: BorderRadius.circular(8)),
    );
  }
}
