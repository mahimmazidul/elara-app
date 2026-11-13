import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/bangladesh_districts.dart';
import '../../providers/settings_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/sub_page.dart';

/// Location: a division and a district, or coordinates typed by hand.
///
/// The device's location is never read, and neither is the phone's IP. Two
/// numbers are enough for a heat index and an air-quality reading, and asking
/// for a location permission - or handing a household's address to a
/// geolocation service - to draw a weather strip would be a poor trade for a
/// cycle app with no account.
///
/// The picker came later than it should have. The first version asked for a
/// latitude and a longitude and defaulted to Dhaka, which is fine if you live in
/// Dhaka and a research task otherwise. The district list is offline, sixty-four
/// entries long, and costs nothing to ship.
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

    // Preselect the district the stored coordinate came from, so the page opens
    // showing where the app thinks it is rather than two empty pickers.
    final stored = _matchDistrict(settings.latitude, settings.longitude);
    _district = stored;
    _division = stored?.division ?? bangladeshDivisions.first;
  }

  /// The district whose coordinates are the stored ones, to two decimals.
  ///
  /// An exact match on the rounded value, not a nearest-neighbour search: the
  /// table is written at two decimals, so anything the picker saved matches
  /// exactly, and a coordinate typed by hand for somewhere else correctly finds
  /// nothing.
  static District? _matchDistrict(double latitude, double longitude) {
    for (final district in bangladeshDistricts) {
      if ((district.latitude - latitude).abs() < 0.005 &&
          (district.longitude - longitude).abs() < 0.005) {
        return district;
      }
    }
    return null;
  }

  Future<void> _chooseDistrict(District district) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final settings = context.read<SettingsProvider>();
    final ok = await settings.setLocation(
      latitude: district.latitude,
      longitude: district.longitude,
      label: district.label,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _district = ok ? district : _district;
      _error = ok ? null : settings.lastError;
    });
    if (!ok) return;
    _latController.text = _trim(district.latitude.toString());
    _lonController.text = _trim(district.longitude.toString());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Set to ${district.name}.')),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  static String _trim(String value) {
    // 23.8103 rather than 23.810300000000001.
    return value.length > 9 ? value.substring(0, 9) : value;
  }

  Future<void> _save() async {
    final lat = double.tryParse(_latController.text.trim());
    final lon = double.tryParse(_lonController.text.trim());

    if (lat == null || lon == null) {
      setState(() => _error = 'Enter both coordinates as numbers.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final settings = context.read<SettingsProvider>();
    // No label: a typed coordinate is not a district, and the row should stop
    // claiming it is.
    final ok = await settings.setLocation(latitude: lat, longitude: lon);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? null : settings.lastError;
    });

    if (ok) {
      _latController.text = _trim(lat.toString());
      _lonController.text = _trim(lon.toString());
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Location saved.')));
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
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Set to Dhaka.')));
    } else {
      setState(() => _error = settings.lastError);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElaraSubPage(
      title: 'Location',
      subtitle:
          'Used for heat index, air quality and the Bangladesh season. Stored '
          'on this phone; the device\'s own location is never read.',
      children: [
        _DivisionField(
          value: _division,
          onChanged: _saving
              ? null
              : (value) => setState(() {
                    _division = value;
                    _district = null;
                  }),
        ),
        const SizedBox(height: ElaraSpacing.sm),
        _DistrictField(
          division: _division,
          value: _district,
          enabled: !_saving,
          onChanged: _chooseDistrict,
        ),
        const SizedBox(height: ElaraSpacing.md),
        Text(
          'Choosing a district saves it straight away. The two boxes below are '
          'for anywhere outside Bangladesh, and typing there clears the '
          'district name.',
          style: context.type.caption(context.elara.textSecondaryStrong),
        ),
        const SizedBox(height: ElaraSpacing.md),
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
          Text(_error!, style: context.type.caption(context.elara.dangerText)),
        ],
        const SizedBox(height: ElaraSpacing.md),
        // Two buttons that both need room for their labels. Equal shares and
        // wrapping keep them on screen at a 2x text scale, where a fixed-width
        // label pushed the primary action off the edge by 99 px. The reset says
        // where it resets to in one word, because "Dhaka default" wrapped onto
        // two lines on a 320dp phone and read as two ideas.
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _useDhaka,
                child: const Text('Use Dhaka'),
              ),
            ),
            const SizedBox(width: ElaraSpacing.sm),
            Expanded(
              child: FilledButton(
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
        const SizedBox(height: ElaraSpacing.lg),
        Text(
          'Coordinates are stored as numbers, so a wrong one gives a wrong heat '
          'index rather than an error. The district list holds the '
          'sixty-four district towns at two decimals, which is about a '
          'kilometre - far finer than a heat index needs.',
          style: context.type.caption(context.elara.textSecondaryStrong),
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
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
      style: context.type.number(tokens.textPrimary, size: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: context.type.label(tokens.textSecondaryStrong),
        hintStyle: context.type.number(tokens.textSecondary, size: 15),
        filled: true,
        fillColor: tokens.bgPrimary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: ElaraSpacing.md,
          vertical: ElaraSpacing.md,
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
    );
  }
}

/// The eight divisions.
class _DivisionField extends StatelessWidget {
  const _DivisionField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: _fieldDecoration(context, 'Division'),
      items: [
        for (final division in bangladeshDivisions)
          DropdownMenuItem(value: division, child: Text(division)),
      ],
      onChanged: onChanged == null
          ? null
          : (selected) {
              if (selected != null) onChanged!(selected);
            },
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
    final districts = districtsOf(division);
    final selected = districts.any((d) => d.name == value?.name) ? value : null;

    return DropdownButtonFormField<District>(
      initialValue: selected,
      isExpanded: true,
      decoration: _fieldDecoration(context, 'District'),
      hint: const Text('Choose a district'),
      items: [
        for (final district in districts)
          DropdownMenuItem(value: district, child: Text(district.name)),
      ],
      onChanged: enabled
          ? (district) {
              if (district != null) onChanged(district);
            }
          : null,
    );
  }
}

InputDecoration _fieldDecoration(BuildContext context, String label) {
  final tokens = context.elara;
  return InputDecoration(
    labelText: label,
    labelStyle: context.type.label(tokens.textSecondaryStrong),
    filled: true,
    fillColor: tokens.bgPrimary,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: ElaraSpacing.md,
      vertical: ElaraSpacing.md,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ElaraRadii.chip),
      borderSide: BorderSide(color: tokens.divider),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ElaraRadii.chip),
      borderSide: BorderSide(color: tokens.divider),
    ),
  );
}
