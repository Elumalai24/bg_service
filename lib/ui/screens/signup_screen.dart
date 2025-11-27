import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/client_model.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/primary_button.dart';

class SignupScreen extends StatelessWidget {
  SignupScreen({super.key});

  final AuthController _auth = Get.find<AuthController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Account', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppConstants.primaryColor,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.padding),
          child: Form(
            key: _auth.signupFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 30),
                _buildBasicInfo(),
                const SizedBox(height: 25),
                _buildCompanySection(),
                const SizedBox(height: 25),
                _buildTermsSection(),
                const SizedBox(height: 30),
                _buildSignupButton(),
                const SizedBox(height: 20),
                _buildLoginLink(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Join ${AppConstants.appName}',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppConstants.primaryColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start your fitness journey today',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildBasicInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Basic Information'),
        const SizedBox(height: 15),
        CustomTextField(
          controller: _auth.nameCtrl,
          label: 'Full Name *',
          hint: 'Enter your full name',
          prefixIcon: Icons.person_outlined,
          validator: (v) => _auth.validateRequired(v, 'Name'),
        ),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _auth.emailCtrl,
          label: 'Email *',
          hint: 'Enter your email',
          prefixIcon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: _auth.validateEmail,
        ),
        const SizedBox(height: 16),
        Obx(() => PasswordTextField(
          controller: _auth.passwordCtrl,
          obscure: _auth.obscurePassword.value,
          onToggle: _auth.togglePasswordVisibility,
          validator: _auth.validatePassword,
          label: 'Password *',
        )),
        const SizedBox(height: 16),
        CustomTextField(
          controller: _auth.phoneCtrl,
          label: 'Phone Number *',
          hint: 'Enter your phone number',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (v) => _auth.validateRequired(v, 'Phone number'),
        ),
      ],
    );
  }

  Widget _buildCompanySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Company Information'),
        const SizedBox(height: 15),
        Obx(() {
          if (_auth.isLoadingClients.value) {
            return _loadingContainer('Loading companies...');
          }

          if (_auth.clients.isEmpty) {
            return GestureDetector(
              onTap: _auth.loadClients,
              child: _loadingContainer('Tap to load companies', showRefresh: true),
            );
          }

          return DropdownButtonFormField<ClientModel>(
            initialValue: _auth.selectedClient.value,
            decoration: InputDecoration(
              labelText: 'Company *',
              prefixIcon: const Icon(Icons.business_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radius),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: _auth.clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
            onChanged: (c) => c != null ? _auth.selectClient(c) : null,
            validator: (v) => v == null ? 'Please select a company' : null,
          );
        }),
      ],
    );
  }

  Widget _buildTermsSection() {
    return FormField<bool>(
      validator: (_) => _auth.acceptedTerms.value ? null : 'You must accept the Terms & Conditions',
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() => Checkbox(
                value: _auth.acceptedTerms.value,
                onChanged: _auth.toggleTerms,
                activeColor: AppConstants.primaryColor,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Wrap(
                    children: [
                      Text('I agree to the ', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700])),
                      _linkText('Terms & Conditions', AppConstants.termsUrl),
                      Text(' and ', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700])),
                      _linkText('Privacy Policy', AppConstants.privacyUrl),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Text(state.errorText!, style: GoogleFonts.poppins(fontSize: 12, color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _buildSignupButton() {
    return Obx(() => PrimaryButton(
      text: 'Create Account',
      isLoading: _auth.isLoading.value,
      onPressed: _auth.signup,
    ));
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Already have an account? ', style: GoogleFonts.poppins(color: Colors.grey[600])),
        GestureDetector(
          onTap: _auth.goToLogin,
          child: Text(
            'Login',
            style: GoogleFonts.poppins(color: AppConstants.primaryColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: AppConstants.primaryColor),
    );
  }

  Widget _loadingContainer(String text, {bool showRefresh = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(AppConstants.radius),
        color: Colors.grey[50],
      ),
      child: Row(
        children: [
          const Icon(Icons.business_outlined, color: Colors.grey),
          const SizedBox(width: 12),
          if (!showRefresh) ...[
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 12),
          ],
          Expanded(child: Text(text, style: const TextStyle(color: Colors.grey))),
          if (showRefresh) const Icon(Icons.refresh, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _linkText(String text, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: AppConstants.primaryColor,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
