import 'package:flutter/material.dart';

class DaySelectorWidget extends StatelessWidget {
  final List<bool> selectedDays;
  final ValueChanged<List<bool>> onChanged;

  const DaySelectorWidget({
    super.key,
    required this.selectedDays,
    required this.onChanged,
  });

  static const List<String> _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_days.length, (index) {
        final isSelected = selectedDays.length > index
            ? selectedDays[index]
            : false;

        return FilterChip(
          label: Text(_days[index]),
          selected: isSelected,
          selectedColor: Colors.redAccent.withValues(alpha: 0.15),
          checkmarkColor: Colors.redAccent,
          labelStyle: TextStyle(
            color: isSelected ? Colors.redAccent : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (bool selected) {
            final updatedDays = List<bool>.from(selectedDays);
            updatedDays[index] = selected;
            onChanged(updatedDays);
          },
        );
      }),
    );
  }
}
