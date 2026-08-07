import 'package:flutter/material.dart';

import '../models/call_request.dart';

class DayChip extends StatelessWidget {
  final DateTime date;
  final bool selected;
  final VoidCallback onTap;
  const DayChip({super.key, required this.date, required this.selected, required this.onTap});

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary : scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? primary : scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(_weekdays[date.weekday - 1],
                style: TextStyle(fontSize: 12, color: selected ? Colors.white70 : scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('${date.day}',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600, color: selected ? Colors.white : scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class TimeSlotChip extends StatelessWidget {
  final DateTime slot;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  const TimeSlotChip({super.key, required this.slot, required this.selected, this.disabled = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final h = slot.hour % 12 == 0 ? 12 : slot.hour % 12;
    final m = slot.minute.toString().padLeft(2, '0');
    final ampm = slot.hour >= 12 ? 'PM' : 'AM';
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? scheme.surfaceContainerHighest : (selected ? primary : scheme.surface),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? primary : scheme.outlineVariant),
        ),
        child: Text(
          '$h:$m $ampm',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: disabled ? scheme.onSurfaceVariant.withValues(alpha: 0.6) : (selected ? Colors.white : scheme.onSurface),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final CallRequestStatus status;
  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      CallRequestStatus.pending => (const Color(0xFFF79009), 'Pending'),
      CallRequestStatus.approved => (const Color(0xFF12B76A), 'Approved'),
      CallRequestStatus.declined => (const Color(0xFFD92D20), 'Declined'),
      CallRequestStatus.cancelled => (const Color(0xFF98A2B3), 'Cancelled'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
