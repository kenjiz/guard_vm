import 'package:flutter/material.dart';

/// {@template adaptive_circular_progress_indicator}
/// A simple wrapper around CircularProgressIndicator.adaptive that centers it and allows for an optional color and value.
/// {@endtemplate}
class AdaptiveCircularProgressIndicator extends StatelessWidget {
  /// {@macro adaptive_circular_progress_indicator}
  const AdaptiveCircularProgressIndicator({
    this.color,
    this.value,
    super.key,
  });

  /// The color of the progress indicator.
  final Color? color;

  /// The value of the progress indicator. If null, the indicator will be indeterminate.
  final double? value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator.adaptive(
        backgroundColor: color,
        value: value,
      ),
    );
  }
}
