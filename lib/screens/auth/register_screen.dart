import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/animations.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  final bool isTeacher;

  const RegisterScreen({
    super.key,
    this.isTeacher = false,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _rollNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedBranchId;
  int _selectedSemester = 1;
  bool _isHod = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _rollNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBranchId == null) {
      PremiumSnackBar.showError(context, 'Please select a branch');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    bool success;

    if (widget.isTeacher) {
      success = await authProvider.registerTeacher(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        branchId: _selectedBranchId,
        isHod: _isHod,
      );
    } else {
      success = await authProvider.registerStudent(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        rollNumber: _rollNumberController.text.trim(),
        branchId: _selectedBranchId!,
        semester: _selectedSemester,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      );
    }

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        SlidePageRoute(page: const HomeScreen()),
        (route) => false,
      );
    } else if (mounted && authProvider.error != null) {
      PremiumSnackBar.showError(context, authProvider.error!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = context.watch<AuthProvider>().branches;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: AppColors.glassDark,
              elevation: 0,
              leading: IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glassDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: AppColors.textPrimary),
                ),
              ),
              title: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.primary.createShader(bounds),
                child: Text(
                  widget.isTeacher
                      ? 'Teacher Registration'
                      : 'Student Registration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              Color(0xFF1A1A2E),
              AppColors.backgroundDark,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: widget.isTeacher
                                      ? AppGradients.warning
                                      : AppGradients.success,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (widget.isTeacher
                                              ? AppColors.warning
                                              : AppColors.success)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.isTeacher
                                      ? Icons.person_outline_rounded
                                      : Icons.school_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.isTeacher
                                    ? 'Join as Teacher'
                                    : 'Join as Student',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Fill in your details to create an account',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Name
                  _buildPremiumTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _buildPremiumTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Enter your email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Roll Number (Students only)
                  if (!widget.isTeacher) ...[
                    _buildPremiumTextField(
                      controller: _rollNumberController,
                      label: 'Roll Number',
                      hint: 'Enter your roll number',
                      icon: Icons.badge_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your roll number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Phone
                  _buildPremiumTextField(
                    controller: _phoneController,
                    label: 'Phone Number (Optional)',
                    hint: 'Enter your phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Branch Dropdown
                  _buildPremiumDropdown<String>(
                    value: _selectedBranchId,
                    label: 'Branch',
                    icon: Icons.school_outlined,
                    items: branches.map((branch) {
                      return DropdownMenuItem(
                        value: branch.id,
                        child: Text('${branch.code} - ${branch.name}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedBranchId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a branch';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Semester (Students only)
                  if (!widget.isTeacher) ...[
                    _buildPremiumDropdown<int>(
                      value: _selectedSemester,
                      label: 'Semester',
                      icon: Icons.calendar_today_outlined,
                      items: List.generate(8, (index) {
                        return DropdownMenuItem(
                          value: index + 1,
                          child: Text('Semester ${index + 1}'),
                        );
                      }),
                      onChanged: (value) {
                        setState(() {
                          _selectedSemester = value ?? 1;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // HOD Checkbox (Teachers only)
                  if (widget.isTeacher) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.glassDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          child: CheckboxListTile(
                            title: const Text(
                              'I am a Head of Department (HOD)',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            value: _isHod,
                            activeColor: AppColors.warning,
                            checkColor: Colors.white,
                            onChanged: (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _isHod = value ?? false;
                              });
                            },
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Password
                  _buildPremiumTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Create a password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password
                  _buildPremiumTextField(
                    controller: _confirmPasswordController,
                    label: 'Confirm Password',
                    hint: 'Confirm your password',
                    icon: Icons.lock_outline_rounded,
                    obscureText: _obscureConfirmPassword,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Register Button
                  Consumer<AuthProvider>(
                    builder: (context, auth, child) {
                      return GestureDetector(
                        onTap: auth.isLoading
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                _register();
                              },
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: auth.isLoading
                                ? null
                                : (widget.isTeacher
                                    ? AppGradients.warning
                                    : AppGradients.success),
                            color: auth.isLoading ? AppColors.glassDark : null,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: auth.isLoading
                                ? null
                                : [
                                    BoxShadow(
                                      color: (widget.isTeacher
                                              ? AppColors.warning
                                              : AppColors.success)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: auth.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.textPrimary,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.person_add_rounded,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Create Account',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.glassDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: AppColors.textMuted),
              prefixIcon: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.primary.createShader(bounds),
                child: Icon(icon, color: Colors.white),
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumDropdown<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    String? Function(T?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.glassDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: DropdownButtonFormField<T>(
            initialValue:
                items.isEmpty || !items.any((item) => item.value == value)
                    ? null
                    : value,
            dropdownColor: AppColors.cardDark,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              prefixIcon: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.primary.createShader(bounds),
                child: Icon(icon, color: Colors.white),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
            items: items,
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }
}
