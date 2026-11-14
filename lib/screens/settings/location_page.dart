import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/bangladesh_districts.dart';
import '../../providers/settings_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/primitives.dart';
import '../../widgets/sub_page.dart';

/// Location: a division and a district, or coordinates typed by hand.
///
/// Stored locally on the phone for heat index, air quality, and the
/// Bangladesh season calculation.
class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  static Route<void> route(BuildContext context) {
    return MaterialPageRoute<void>(builder: (_) => const LocationPage());
  }

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late String _division;
  District? _district;
  String? _error;
  String? _statusMessage;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _latController = TextEditingController(
      text: _trim(settings.latitude.toString()),
    );
    _lonController = TextEditingController(
      text: _trim(settings.longitude.toString()),
    );

    final stored = _matchDistrict(settings.latitude, settings.longitude);
    _district = stored;
    _division = stored?.division ?? bangladeshDivisions.first;
  }

  static District? _matchDistrict(double latitude, double longitude) {
    for (final district in bangladeshDistricts) {
      if ((district.latitude - latitude).abs() < 0.005 &&
          (district.longitude - longitude).abs() < 0.005) {
        return district;
      }
    }
    return null;
  }

  void _showMinimalNotice(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(message),
      ),
    );
  }

  Future<void> _chooseDistrict(District district) async {
    setState(() {
      _saving = true;
      _error = null;
      _statusMessage = null;
    });
    final settings = context.read<SettingsProvider>();
    final ok = await settings.setLocation(
      latitude: district.latitude,
      longitude: district.longitude,
      label: district.label,
    );
    if (!mounted) return;
    final notice = 'Location saved to ${district.name}';
    setState(() {
      _saving = false;
      _district = ok ? district : _district;
      _error = ok ? null : settings.lastError;
      _statusMessage = ok ? notice : null;
    });
    if (!ok) return;
    _latController.text = _trim(district.latitude.toString());
    _lonController.text = _trim(district.longitude.toString());
    _showMinimalNotice(notice);
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  static String _trim(String value) {
    return value.length > 9 ? value.substring(0, 9) : value;
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());

    if (lat == null || lon == null) {
      setState(() {
        _error = 'Enter both coordinates as numbers.';
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _statusMessage = null;
    });

    final settings = context.read<SettingsProvider>();
    final matched = _matchDistrict(lat, lon);
    final ok = await settings.setLocation(
      latitude: lat,
      longitude: lon,
      label: matched?.label,
    );

    if (!mounted) return;
    final notice = matched != null
        ? 'Location saved to ${matched.name}'
        : 'Location saved';
    setState(() {
      _saving = false;
      _district = ok ? matched : _district;
      if (ok && matched != null) {
        _division = matched.division;
      }
      _error = ok ? null : settings.lastError;
      _statusMessage = ok ? notice : null;
    });

    if (ok) {
      _latController.text = _trim(lat.toString());
      _lonController.text = _trim(lon.toString());
      _showMinimalNotice(notice);
    }
  }

  Future<void> _useDhaka() async {
    final settings = context.read<SettingsProvider>();
    final d = districtsOf('Dhaka').firstWhere((d) => d.name == 'Dhaka');
    final ok = await settings.setLocation(
      latitude: d.latitude,
      longitude: d.longitude,
      label: d.label,
    );
    if (!mounted) return;
    if (ok) {
      _latController.text = _trim(d.latitude.toString());
      _lonController.text = _trim(d.longitude.toString());
      setState(() {
        _error = null;
        _district = d;
        _division = d.division;
        _statusMessage = 'Location saved to Dhaka';
      });
      _showMinimalNotice('Location saved to Dhaka');
    } else {
      setState(() => _error = settings.lastError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return ElaraSubPage(
      title: 'Location',
      subtitle:
          'Used for the local heat index, air quality, and the Bangladesh '
          'season. Saved locally on this phone.',
      children: [
        const ElaraOverline('BANGLADESH DISTRICT'),
        const SizedBox(height: ElaraSpacing.sm),
        ElaraGlassGroup(
          children: [
            _DivisionField(
              value: _division,
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                        _division = value;
                        _district = null;
                        _statusMessage = null;
                      }),
            ),
            _DistrictField(
              division: _division,
              value: _district,
              enabled: !_saving,
              onChanged: _chooseDistrict,
            ),
          ],
        ),
        const SizedBox(height: ElaraSpacing.sm),
        if (_statusMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: ElaraSpacing.xs),
            child: Text(
              _statusMessage!,
              style: type.caption(tokens.textSecondaryStrong),
            ),
          ),
        Text(
          'Selecting a district saves its town centre right away.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.xl),
        const ElaraOverline('COORDINATES'),
        const SizedBox(height: ElaraSpacing.sm),
        ElaraGlass(
          padding: ElaraSpacing.card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _CoordinateField(
                      label: 'Latitude',
                      controller: _latController,
                      hint: '23.8103',
                    ),
                  ),
                  const SizedBox(width: ElaraSpacing.md),
                  Expanded(
                    child: _CoordinateField(
                      label: 'Longitude',
                      controller: _lonController,
                      hint: '90.4125',
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: ElaraSpacing.sm),
                Text(_error!, style: type.caption(tokens.dangerText)),
              ],
              const SizedBox(height: ElaraSpacing.md),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        textStyle: type.label(tokens.textSecondaryStrong),
                        foregroundColor: tokens.textSecondaryStrong,
                        padding: const EdgeInsets.symmetric(
                          horizontal: ElaraSpacing.md,
                          vertical: 11,
                        ),
                      ),
                      onPressed: _useDhaka,
                      child: const Text('Use Dhaka'),
                    ),
                  ),
                  const SizedBox(width: ElaraSpacing.sm),
                  Expanded(
                    flex: 3,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        textStyle: type.bodyStrong(tokens.onPhase, size: 14),
                        padding: const EdgeInsets.symmetric(
                          horizontal: ElaraSpacing.lg,
                          vertical: 11,
                        ),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save location'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: ElaraSpacing.md),
        Text(
          'The sixty-four districts are stored at two decimal places, about a '
          'kilometre across, which is plenty of precision for regional weather '
          'and air quality.',
          style: type.caption(tokens.textSecondaryStrong),
        ),
      ],
    );
  }
}

class _CoordinateField extends StatelessWidget {
  const _CoordinateField({
    required this.label,
    required this.controller,
    required this.hint,
  });

  final String label;
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: type.caption(tokens.textSecondaryStrong)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
          ],
          style: type.number(
            tokens.textPrimary,
            size: 15,
            weight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            hintStyle: type.number(
              tokens.textSecondary,
              size: 15,
              weight: FontWeight.w400,
            ),
            filled: true,
            fillColor: tokens.bgPrimary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ElaraSpacing.md,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ElaraRadii.chip),
              borderSide: BorderSide(color: tokens.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ElaraRadii.chip),
              borderSide: BorderSide(color: tokens.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(ElaraRadii.chip),
              borderSide: BorderSide(color: tokens.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// The eight divisions, presented as a clean row inside [ElaraGlassGroup].
class _DivisionField extends StatelessWidget {
  const _DivisionField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        style: type.body(tokens.textPrimary, size: 15),
        dropdownColor: tokens.bgCard,
        decoration: _fieldDecoration(context, 'Division'),
        items: [
          for (final division in bangladeshDivisions)
            DropdownMenuItem(
              value: division,
              child: Text(
                division,
                style: type.body(tokens.textPrimary, size: 15),
              ),
            ),
        ],
        onChanged: onChanged == null
            ? null
            : (selected) {
                if (selected != null) onChanged!(selected);
              },
      ),
    );
  }
}

/// The districts of the chosen division. Choosing one saves immediately.
class _DistrictField extends StatelessWidget {
  const _DistrictField({
    required this.division,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String division;
  final District? value;
  final bool enabled;
  final ValueChanged<District> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.elara;
    final type = context.type;
    final districts = districtsOf(division);
    final selected = districts.any((d) => d.name == value?.name) ? value : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DropdownButtonFormField<District>(
        initialValue: selected,
        isExpanded: true,
        style: type.body(tokens.textPrimary, size: 15),
        dropdownColor: tokens.bgCard,
        decoration: _fieldDecoration(context, 'District'),
        hint: Text(
          'Choose a district',
          style: type.label(tokens.textSecondaryStrong),
        ),
        items: [
          for (final district in districts)
            DropdownMenuItem(
              value: district,
              child: Text(
                district.name,
                style: type.body(tokens.textPrimary, size: 15),
              ),
            ),
        ],
        onChanged: enabled
            ? (district) {
                if (district != null) onChanged(district);
              }
            : null,
      ),
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, String label) {
  final tokens = context.elara;
  return InputDecoration(
    labelText: label,
    labelStyle: context.type.caption(tokens.textSecondaryStrong, size: 13),
    floatingLabelStyle: context.type.caption(
      tokens.textSecondaryStrong,
      size: 12,
    ),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8),
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
  );
}
