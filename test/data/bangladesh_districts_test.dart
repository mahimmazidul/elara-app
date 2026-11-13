import 'package:elara_app/data/bangladesh_districts.dart';
import 'package:flutter_test/flutter_test.dart';

/// The district table is data, and data is where a typo goes unnoticed: a
/// latitude with a missing digit still parses, still saves, and simply asks the
/// weather service about a point in the Indian Ocean. Nothing crashes, and the
/// heat index is quietly wrong.
///
/// These are the checks that would have caught it.
void main() {
  // Bangladesh runs from about 20.5N to 26.7N and 88.0E to 92.7E. A district
  // town outside that box is either a typo or not in Bangladesh.
  const minLat = 20.5, maxLat = 26.7, minLon = 88.0, maxLon = 92.8;

  test('there are eight divisions and sixty-four districts', () {
    expect(bangladeshDivisions.length, 8);
    expect(bangladeshDistricts.length, 64);
  });

  test('every district sits inside Bangladesh', () {
    for (final district in bangladeshDistricts) {
      expect(
        district.latitude,
        inInclusiveRange(minLat, maxLat),
        reason: '${district.name} has latitude ${district.latitude}',
      );
      expect(
        district.longitude,
        inInclusiveRange(minLon, maxLon),
        reason: '${district.name} has longitude ${district.longitude}',
      );
    }
  });

  test('every district belongs to a division that exists', () {
    for (final district in bangladeshDistricts) {
      expect(
        bangladeshDivisions,
        contains(district.division),
        reason: '${district.name} claims ${district.division}',
      );
    }
  });

  test('no division is empty, and no district is listed twice', () {
    for (final division in bangladeshDivisions) {
      expect(
        districtsOf(division),
        isNotEmpty,
        reason: '$division has no districts',
      );
    }

    final seen = <String>{};
    for (final district in bangladeshDistricts) {
      expect(
        seen.add(district.label),
        isTrue,
        reason: '${district.label} is listed twice',
      );
    }
  });

  test('two districts never share a coordinate', () {
    // The picker preselects by matching the stored coordinate back to a
    // district. Two districts at the same point would make that match arbitrary.
    final seen = <String>{};
    for (final district in bangladeshDistricts) {
      final key = '${district.latitude},${district.longitude}';
      expect(
        seen.add(key),
        isTrue,
        reason: '${district.name} shares $key with another district',
      );
    }
  });

  test('the label reads like a place', () {
    final khulna = bangladeshDistricts.firstWhere(
      (d) => d.name == 'Khulna' && d.division == 'Khulna',
    );
    expect(khulna.label, 'Khulna, Khulna');

    final dhaka = districtsOf('Dhaka').firstWhere((d) => d.name == 'Dhaka');
    expect(dhaka.label, 'Dhaka, Dhaka');
  });
}
