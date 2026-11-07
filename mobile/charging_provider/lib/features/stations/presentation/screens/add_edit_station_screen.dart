
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

class StationFormData {
  const StationFormData({
    required this.id,
    required this.stationName,
    required this.providerType,
    required this.accessType,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.connectorType,
    required this.powerKw,
    required this.pricePerKwh,
    required this.isActive,
  });

  final String id;
  final String stationName;
  final String providerType;
  final String accessType;
  final String address;
  final double latitude;
  final double longitude;
  final String connectorType;
  final double powerKw;
  final double pricePerKwh;
  final bool isActive;
}

class AddEditStationScreen extends StatefulWidget {
  const AddEditStationScreen({
    super.key,
    this.initialStation,
    required this.onSave,
    required this.onCancel,
    this.isSaving = false,
  });

  final StationFormData? initialStation;

  final void Function({
    required String stationName,
    required String providerType,
    required String accessType,
    required String address,
    required double latitude,
    required double longitude,
    required String connectorType,
    required double powerKw,
    required double pricePerKwh,
    required bool isActive,
  }) onSave;

  final VoidCallback onCancel;
  final bool isSaving;

  @override
  State<AddEditStationScreen> createState() =>
      _AddEditStationScreenState();
}

class _AddEditStationScreenState extends State<AddEditStationScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final TextEditingController _powerController;
  late final TextEditingController _priceController;

  late String _providerType;
  late String _accessType;
  late String _connectorType;
  late bool _isActive;

  bool get _isEditing => widget.initialStation != null;

  // Verify these values against your backend enums before Phase 3.
  static const List<String> _providerTypes = [
    'COMMERCIAL_PROPERTY',
    'RESIDENTIAL_HOST',
    'FLEET_OPERATOR',
  ];

  static const List<String> _accessTypes = [
    'PUBLIC',
    'PRIVATE',
  ];

  static const List<String> _connectorTypes = [
    'CCS2',
    'TYPE2',
    'CHADEMO',
    'GB_T',
  ];

  @override
  void initState() {
    super.initState();

    final station = widget.initialStation;

    _nameController = TextEditingController(
      text: station?.stationName ?? '',
    );

    _addressController = TextEditingController(
      text: station?.address ?? '',
    );

    _latitudeController = TextEditingController(
      text: station?.latitude.toString() ?? '',
    );

    _longitudeController = TextEditingController(
      text: station?.longitude.toString() ?? '',
    );

    _powerController = TextEditingController(
      text: station?.powerKw.toString() ?? '',
    );

    _priceController = TextEditingController(
      text: station?.pricePerKwh.toString() ?? '',
    );

    _providerType = station?.providerType ?? _providerTypes.first;
    _accessType = station?.accessType ?? _accessTypes.first;
    _connectorType = station?.connectorType ?? _connectorTypes.first;
    _isActive = station?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _powerController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }

    return null;
  }

  String? _validateNumber(
    String? value,
    String label, {
    required double minimum,
    double? maximum,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }

    final number = double.tryParse(value.trim());

    if (number == null || !number.isFinite) {
      return 'Enter a valid $label';
    }

    if (number < minimum) {
      return '$label must be at least $minimum';
    }

    if (maximum != null && number > maximum) {
      return '$label cannot exceed $maximum';
    }

    return null;
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    widget.onSave(
      stationName: _nameController.text.trim(),
      providerType: _providerType,
      accessType: _accessType,
      address: _addressController.text.trim(),
      latitude: double.parse(_latitudeController.text.trim()),
      longitude: double.parse(_longitudeController.text.trim()),
      connectorType: _connectorType,
      powerKw: double.parse(_powerController.text.trim()),
      pricePerKwh: double.parse(_priceController.text.trim()),
      isActive: _isActive,
    );
  }

  Widget _sectionHeading(
    BuildContext context,
    String number,
    String title,
  ) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          height: 27,
          width: 27,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, label),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          textCapitalization: label == 'Station Name' ||
                  label == 'Physical Address'
              ? TextCapitalization.words
              : TextCapitalization.none,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon == null ? null : Icon(icon),
            alignLabelWithHint: maxLines > 1,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(context, label),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: const InputDecoration(),
          items: options.map((option) {
            return DropdownMenuItem(
              value: option,
              child: Text(
                option.replaceAll('_', ' '),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: widget.isSaving ? null : onChanged,
        ),
      ],
    );
  }

  Widget _sectionCard({
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
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
          onPressed: widget.onCancel,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          _isEditing ? 'Edit Station' : 'Add Station',
        ),
      ),

      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing
                      ? 'Update Station Details'
                      : 'Register Charging Station',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Enter the details of your charging station.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                // Section 1: Station identity
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        context,
                        '1',
                        'Station Identity',
                      ),

                      const SizedBox(height: 20),

                      _textField(
                        controller: _nameController,
                        label: 'Station Name',
                        hint: 'Enter station name',
                        icon: Icons.ev_station_outlined,
                        validator: (value) =>
                            _validateRequired(value, 'Station name'),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: _dropdown(
                              label: 'Provider Type',
                              value: _providerType,
                              options: _providerTypes,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _providerType = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _dropdown(
                              label: 'Access Type',
                              value: _accessType,
                              options: _accessTypes,
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _accessType = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section 2: Location
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        context,
                        '2',
                        'Station Location',
                      ),

                      const SizedBox(height: 20),

                      _textField(
                        controller: _addressController,
                        label: 'Physical Address',
                        hint: 'Enter complete station address',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                        validator: (value) =>
                            _validateRequired(value, 'Address'),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              controller: _latitudeController,
                              label: 'Latitude',
                              hint: 'e.g. 19.0760',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^-?\d*\.?\d*'),
                                ),
                              ],
                              validator: (value) => _validateNumber(
                                value,
                                'Latitude',
                                minimum: -90,
                                maximum: 90,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _textField(
                              controller: _longitudeController,
                              label: 'Longitude',
                              hint: 'e.g. 72.8777',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                                signed: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^-?\d*\.?\d*'),
                                ),
                              ],
                              validator: (value) => _validateNumber(
                                value,
                                'Longitude',
                                minimum: -180,
                                maximum: 180,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Section 3: Charging specifications
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionHeading(
                        context,
                        '3',
                        'Charging Specifications',
                      ),

                      const SizedBox(height: 20),

                      _dropdown(
                        label: 'Connector Type',
                        value: _connectorType,
                        options: _connectorTypes,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _connectorType = value;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: [
                          Expanded(
                            child: _textField(
                              controller: _powerController,
                              label: 'Power Capacity (kW)',
                              hint: 'e.g. 22',
                              icon: Icons.bolt_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              validator: (value) => _validateNumber(
                                value,
                                'Power capacity',
                                minimum: 0.01,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _textField(
                              controller: _priceController,
                              label: 'Price per kWh (₹)',
                              hint: 'e.g. 12.50',
                              icon: Icons.currency_rupee_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              validator: (value) => _validateNumber(
                                value,
                                'Price',
                                minimum: 0,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Active status
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _isActive,
                          onChanged: widget.isSaving
                              ? null
                              : (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                          title: Text(
                            'Active Station',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Allow this station to be active.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed:
                        widget.isSaving ? null : _handleSave,
                    icon: widget.isSaving
                        ? const SizedBox(
                            height: 19,
                            width: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.black,
                            ),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      widget.isSaving
                          ? 'Saving...'
                          : _isEditing
                              ? 'Update Station'
                              : 'Save Station',
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                OutlinedButton(
                  onPressed:
                      widget.isSaving ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
