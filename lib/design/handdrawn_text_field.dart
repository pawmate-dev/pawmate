import 'package:flutter/material.dart';

/// A URL-friendly form field that keeps native Flutter semantics and focus.
class HanddrawnTextField extends StatelessWidget {
  const HanddrawnTextField({
    required this.controller,
    required this.labelText,
    super.key,
    this.hintText,
    this.validator,
    this.prefixIcon,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final FormFieldValidator<String>? validator;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autocorrect: false,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
      validator: validator,
    );
  }
}
