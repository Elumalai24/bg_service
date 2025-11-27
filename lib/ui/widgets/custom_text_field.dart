import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radius),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

class PasswordTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final String label;

  const PasswordTextField({
    super.key,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    this.validator,
    this.label = 'Password',
  });

  @override
  Widget build(BuildContext context) {
    return CustomTextField(
      controller: controller,
      label: label,
      hint: 'Enter your password',
      prefixIcon: Icons.lock_outlined,
      obscure: obscure,
      validator: validator,
      suffixIcon: IconButton(
        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: onToggle,
      ),
    );
  }
}
