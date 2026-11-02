
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class ProviderSetupScreen extends StatefulWidget {
  const ProviderSetupScreen({
    super.key,
    required this.onContinue,
    required this.onBack,
    this.isLoading = false,
  });

  final void Function({
    required String providerType,
    required String legalName,
    required String phone,
    required String address,
  }) onContinue;

  final VoidCallback onBack;
  final bool isLoading;

  @override
  State<ProviderSetupScreen> createState() =>
      _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends State<ProviderSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _legalNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  String? _selectedProvider;

  final List<Map<String, dynamic>> _providerTypes = [
    {
      'value': 'COMMERCIAL_PROPERTY',
      'title': 'Commercial Property',
      'description': 'Businesses, malls, retail parks and office spaces.',
      'icon': Icons.business_rounded,
    },
    {
      'value': 'RESIDENTIAL_HOST',
      'title': 'Residential Host',
      'description': 'Homes, apartments and residential properties.',
      'icon': Icons.home_work_rounded,
    },
    {
      'value': 'FLEET_OPERATOR',
      'title': 'Fleet Operator',
      'description': 'Fleet depots, logistics hubs and private charging facilities.',
      'icon': Icons.local_shipping_rounded,
    },
  ];

  @override
  void dispose() {
    _legalNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _handleContinue() {
    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your provider type.'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    widget.onContinue(
      providerType: _selectedProvider!,
      legalName: _legalNameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
    );
  }

  Widget _buildProviderCard({
    required String value,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSelected = _selectedProvider == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProvider = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.secondary
                : theme.dividerColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: colors.onSurface,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: isSelected
                  ? AppColors.success
                  : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Provider Setup',
          style: theme.textTheme.titleMedium,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Step 2 of 3',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '66% Complete',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const LinearProgressIndicator(
                        value: 0.66,
                        minHeight: 6,
                        backgroundColor: AppColors.neutral200,
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Heading
                    Text(
                      'Set Up Your Provider Profile',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Tell us about your charging business '
                      'so we can configure your provider account.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 26),

                    // Provider type
                    Text(
                      'SELECT PROVIDER TYPE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.7,
                      ),
                    ),

                    const SizedBox(height: 12),

                    ..._providerTypes.map(
                      (provider) => _buildProviderCard(
                        value: provider['value'] as String,
                        title: provider['title'] as String,
                        description: provider['description'] as String,
                        icon: provider['icon'] as IconData,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Legal name
                    Text(
                      'Charging Entity Name',
                      style: theme.textTheme.labelLarge,
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _legalNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Enter business or entity name',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your entity name';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Phone
                    Text(
                      'Operations Phone Number',
                      style: theme.textTheme.labelLarge,
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: 'Enter phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+91  ',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your phone number';
                        }
                        if (!RegExp(r'^[6-9]\d{9}$')
                            .hasMatch(value.trim())) {
                          return 'Enter a valid 10-digit number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 18),

                    // Address
                    Text(
                      'Primary Operating Location',
                      style: theme.textTheme.labelLarge,
                    ),

                    const SizedBox(height: 8),

                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Enter your primary business address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your operating location';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // Continue
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: widget.isLoading
                            ? null
                            : _handleContinue,
                        child: widget.isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.black,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Continue'),
                                  SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 18,
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
