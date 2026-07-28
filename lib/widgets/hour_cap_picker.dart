import 'package:flutter/material.dart';
import '../utils/constants.dart';

class HourCapCard extends StatelessWidget {
  final String label;
  final double hours;
  final ValueChanged<double> onChanged;
  final List<double> options;

  const HourCapCard({
    super.key,
    this.label = 'DAILY LIMIT',
    required this.hours,
    required this.onChanged,
    this.options = const [1, 1.5, 2, 2.5, 3, 4],
  });

  static String fmtHours(double h) {
    if (h == h.roundToDouble()) return '${h.toInt()}h';
    return '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (hours * 60).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fmtHours(hours),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.bold,
              color: kDarkGreen,
            ),
          ),
          Text(
            '$minutes minutes max per day',
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((h) {
              final selected = h == hours;
              return GestureDetector(
                onTap: () => onChanged(h),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? kDarkGreen : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    fmtHours(h),
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
