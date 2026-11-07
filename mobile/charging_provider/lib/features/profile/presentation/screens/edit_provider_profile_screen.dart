import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/provider_profile_model.dart';

class EditProviderProfileScreen extends StatefulWidget {
  const EditProviderProfileScreen({
    super.key,
    required this.profile,
    required this.onSave,
  });

  final ProviderProfileModel profile;
  final Future<void> Function(ProviderProfileModel profile) onSave;

  @override
  State<EditProviderProfileScreen> createState() =>
      _EditProviderProfileScreenState();
}

class _EditProviderProfileScreenState
    extends State<EditProviderProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _businessController;
  late final TextEditingController _addressController;

  late String _providerType;
  bool _saving = false;

  final List<String> _providerTypes = [
    'COMMERCIAL_PROPERTY',
    'RESIDENTIAL_HOST',
    'FLEET_OPERATOR',
  ];

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(text: widget.profile.fullName);
    _phoneController =
        TextEditingController(text: widget.profile.phone ?? '');
    _businessController =
        TextEditingController(text: widget.profile.businessName ?? '');
    _addressController =
        TextEditingController(text: widget.profile.address ?? '');

    final existingType = widget.profile.providerType;
    _providerType = _providerTypes.contains(existingType)
        ? existingType!
        : _providerTypes.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _businessController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter your mobile number';
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');
    final number = digits.startsWith('91') && digits.length == 12
        ? digits.substring(2)
        : digits;

    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(number)) {
      return 'Enter a valid 10-digit Indian mobile number';
    }

    return null;
  }

  String _normalizedPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    final number = digits.startsWith('91') && digits.length == 12
        ? digits.substring(2)
        : digits;

    return '+91$number';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;

    setState(() => _saving = true);

    try {
      final updatedProfile = ProviderProfileModel(
        id: widget.profile.id,
        fullName: _nameController.text.trim(),
        email: widget.profile.email,
        phone: _normalizedPhone(_phoneController.text.trim()),
        role: widget.profile.role,
        businessName: _businessController.text.trim(),
        providerType: _providerType,
        address: _addressController.text.trim(),
        onboardingCompleted: widget.profile.onboardingCompleted,
        onboardingStep: widget.profile.onboardingStep,
        createdAt: widget.profile.createdAt,
        updatedAt: widget.profile.updatedAt,
      );

      await widget.onSave(updatedProfile);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile update failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Personal Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Enter your full name'
                        : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: widget.profile.email,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                  helperText: 'Email cannot be changed here.',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: _validatePhone,
              ),

              const SizedBox(height: 28),

              Text(
                'Business Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _businessController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Business Name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Enter your business name'
                        : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _providerType,
                decoration: const InputDecoration(
                  labelText: 'Provider Type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: _providerTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(
                      type.replaceAll('_', ' '),
                    ),
                  );
                }).toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _providerType = value);
                        }
                      },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Operating Address',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Enter your operating address'
                        : null,
              ),

              const SizedBox(height: 30),

              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.black,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}