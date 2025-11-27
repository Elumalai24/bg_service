import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../widgets/logo_widget.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final AuthController _auth = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              _buildHeader(),
              const SizedBox(height: 50),
              _buildForm(),
              const SizedBox(height: 30),
              _buildLoginButton(),
              const SizedBox(height: 20),
              _buildSignupLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const BrandedLogoWidget(size: 80, borderRadius: 20),
        const SizedBox(height: 20),
        Text(
          AppConstants.appName,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppConstants.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Track your steps, achieve your goals',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _auth.loginFormKey,
      child: Column(
        children: [
          CustomTextField(
            controller: _auth.emailCtrl,
            label: 'Email',
            hint: 'Enter your email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: _auth.validateEmail,
          ),
          const SizedBox(height: 20),
          Obx(() => PasswordTextField(
            controller: _auth.passwordCtrl,
            obscure: _auth.obscurePassword.value,
            onToggle: _auth.togglePasswordVisibility,
            validator: _auth.validatePassword,
          )),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Obx(() => PrimaryButton(
      text: 'Login',
      isLoading: _auth.isLoading.value,
      onPressed: _auth.login,
    ));
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.poppins(color: Colors.grey[600]),
        ),
        GestureDetector(
          onTap: _auth.goToSignup,
          child: Text(
            'Sign Up',
            style: GoogleFonts.poppins(
              color: AppConstants.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
