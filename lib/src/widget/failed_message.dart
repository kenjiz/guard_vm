import 'package:flutter/material.dart';

/// {@template failed_message}
/// A simple widget that displays a failure message.
/// {@endtemplate}
class FailedMessage extends StatelessWidget {
  /// {@macro failed_message}
  const FailedMessage({
    this.message,
    super.key,
  });

  /// The message to display when something goes wrong.
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(message ?? 'Something went wrong.'),
    );
  }
}
