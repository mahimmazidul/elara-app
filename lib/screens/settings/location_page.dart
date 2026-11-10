import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_keys.dart';
import '../../providers/settings_provider.dart';
import '../../theme/elara_theme.dart';
import '../../widgets/sub_page.dart';

/// Location, as typed coordinates.
///
/// The device's location is never read. Two numbers typed once are enough for a
/// heat index and an air-quality reading, and asking for a location permission
/// to draw a weather strip would be a poor trade for a cycle app with no
/// account. Dhaka is the default because the app is written for Bangladesh and
/// a first launch in Khulna should not need anyone to look up a latitude.
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
    final ok = await settings.setLocation(
      latitude: SettingsKeys.defaultLatitude,
      longitude: SettingsKeys.defaultLongitude,
    );
    if (!mounted) return;
    if (ok) {
      _latController.text = _trim(SettingsKeys.defaultLatitude.toString());
      _lonController.text = _trim(SettingsKeys.defaultLongitude.toString());
      setState(() => _error = null);
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
        // "Dhaka default" pushed the primary action off the edge by 99 px.
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _useDhaka,
                child: const Text('Dhaka default'),
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
          'Khulna reads about 22.8456, 89.5403. Coordinates are stored as '
          'numbers, so a wrong one gives a wrong heat index rather than an '
          'error.',
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
