/// The eight divisions and their sixty-four districts, with the coordinate the
/// weather strip uses for each one.
///
/// The app asks for a latitude and a longitude and has always taken them typed
/// by hand, with Dhaka as the default. That is honest but it is not something
/// anyone wants to do: a person in Satkhira should not have to look up 22.72,
/// 89.07 to see whether today is a heat day.
///
/// This is a picker instead, and it is still offline. The alternative — asking
/// an IP geolocation service where the phone is — would send a household's
/// address to a third party to save two taps, in an app whose entire claim is
/// that nothing leaves the phone. A typed coordinate is still accepted below the
/// picker, for anywhere outside Bangladesh.
///
/// Coordinates are district-town centres, to two decimal places, which is about
/// a kilometre: the heat index does not change at that scale, and rounding keeps
/// the table readable.
class District {
  const District({
    required this.division,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  final String division;
  final String name;
  final double latitude;
  final double longitude;

  /// How the district is written on screen, e.g. "Khulna, Khulna".
  String get label => '$name, $division';
}

/// The divisions, in the order the picker lists them.
const List<String> bangladeshDivisions = [
  'Barishal',
  'Chattogram',
  'Dhaka',
  'Khulna',
  'Mymensingh',
  'Rajshahi',
  'Rangpur',
  'Sylhet',
];

/// Every district, grouped by division.
const List<District> bangladeshDistricts = [
  // ---- Barishal
  District(division: 'Barishal', name: 'Barguna', latitude: 22.15, longitude: 90.13),
  District(division: 'Barishal', name: 'Barishal', latitude: 22.70, longitude: 90.37),
  District(division: 'Barishal', name: 'Bhola', latitude: 22.69, longitude: 90.65),
  District(division: 'Barishal', name: 'Jhalokathi', latitude: 22.64, longitude: 90.20),
  District(division: 'Barishal', name: 'Patuakhali', latitude: 22.36, longitude: 90.33),
  District(division: 'Barishal', name: 'Pirojpur', latitude: 22.58, longitude: 89.98),

  // ---- Chattogram
  District(division: 'Chattogram', name: 'Bandarban', latitude: 22.20, longitude: 92.22),
  District(division: 'Chattogram', name: 'Brahmanbaria', latitude: 23.96, longitude: 91.11),
  District(division: 'Chattogram', name: 'Chandpur', latitude: 23.23, longitude: 90.65),
  District(division: 'Chattogram', name: 'Chattogram', latitude: 22.34, longitude: 91.83),
  District(division: 'Chattogram', name: 'Coxs Bazar', latitude: 21.44, longitude: 92.00),
  District(division: 'Chattogram', name: 'Cumilla', latitude: 23.46, longitude: 91.18),
  District(division: 'Chattogram', name: 'Feni', latitude: 23.02, longitude: 91.40),
  District(division: 'Chattogram', name: 'Khagrachhari', latitude: 23.12, longitude: 91.98),
  District(division: 'Chattogram', name: 'Lakshmipur', latitude: 22.94, longitude: 90.83),
  District(division: 'Chattogram', name: 'Noakhali', latitude: 22.87, longitude: 91.10),
  District(division: 'Chattogram', name: 'Rangamati', latitude: 22.65, longitude: 92.18),

  // ---- Dhaka
  District(division: 'Dhaka', name: 'Dhaka', latitude: 23.81, longitude: 90.41),
  District(division: 'Dhaka', name: 'Faridpur', latitude: 23.60, longitude: 89.83),
  District(division: 'Dhaka', name: 'Gazipur', latitude: 23.99, longitude: 90.42),
  District(division: 'Dhaka', name: 'Gopalganj', latitude: 23.01, longitude: 89.83),
  District(division: 'Dhaka', name: 'Kishoreganj', latitude: 24.44, longitude: 90.78),
  District(division: 'Dhaka', name: 'Madaripur', latitude: 23.17, longitude: 90.20),
  District(division: 'Dhaka', name: 'Manikganj', latitude: 23.86, longitude: 90.00),
  District(division: 'Dhaka', name: 'Munshiganj', latitude: 23.54, longitude: 90.53),
  District(division: 'Dhaka', name: 'Narayanganj', latitude: 23.62, longitude: 90.50),
  District(division: 'Dhaka', name: 'Narsingdi', latitude: 23.92, longitude: 90.72),
  District(division: 'Dhaka', name: 'Rajbari', latitude: 23.76, longitude: 89.64),
  District(division: 'Dhaka', name: 'Shariatpur', latitude: 23.20, longitude: 90.35),
  District(division: 'Dhaka', name: 'Tangail', latitude: 24.25, longitude: 89.92),

  // ---- Khulna
  District(division: 'Khulna', name: 'Bagerhat', latitude: 22.66, longitude: 89.79),
  District(division: 'Khulna', name: 'Chuadanga', latitude: 23.64, longitude: 88.86),
  District(division: 'Khulna', name: 'Jashore', latitude: 23.17, longitude: 89.21),
  District(division: 'Khulna', name: 'Jhenaidah', latitude: 23.54, longitude: 89.18),
  District(division: 'Khulna', name: 'Khulna', latitude: 22.82, longitude: 89.55),
  District(division: 'Khulna', name: 'Kushtia', latitude: 23.90, longitude: 89.12),
  District(division: 'Khulna', name: 'Magura', latitude: 23.49, longitude: 89.42),
  District(division: 'Khulna', name: 'Meherpur', latitude: 23.76, longitude: 88.63),
  District(division: 'Khulna', name: 'Narail', latitude: 23.17, longitude: 89.50),
  District(division: 'Khulna', name: 'Satkhira', latitude: 22.72, longitude: 89.07),

  // ---- Mymensingh
  District(division: 'Mymensingh', name: 'Jamalpur', latitude: 24.92, longitude: 89.94),
  District(division: 'Mymensingh', name: 'Mymensingh', latitude: 24.75, longitude: 90.40),
  District(division: 'Mymensingh', name: 'Netrokona', latitude: 24.87, longitude: 90.73),
  District(division: 'Mymensingh', name: 'Sherpur', latitude: 25.02, longitude: 90.02),

  // ---- Rajshahi
  District(division: 'Rajshahi', name: 'Bogura', latitude: 24.85, longitude: 89.37),
  District(division: 'Rajshahi', name: 'Chapainawabganj', latitude: 24.60, longitude: 88.28),
  District(division: 'Rajshahi', name: 'Joypurhat', latitude: 25.10, longitude: 89.02),
  District(division: 'Rajshahi', name: 'Naogaon', latitude: 24.80, longitude: 88.94),
  District(division: 'Rajshahi', name: 'Natore', latitude: 24.41, longitude: 89.00),
  District(division: 'Rajshahi', name: 'Pabna', latitude: 24.00, longitude: 89.24),
  District(division: 'Rajshahi', name: 'Rajshahi', latitude: 24.37, longitude: 88.60),
  District(division: 'Rajshahi', name: 'Sirajganj', latitude: 24.45, longitude: 89.70),

  // ---- Rangpur
  District(division: 'Rangpur', name: 'Dinajpur', latitude: 25.63, longitude: 88.64),
  District(division: 'Rangpur', name: 'Gaibandha', latitude: 25.33, longitude: 89.53),
  District(division: 'Rangpur', name: 'Kurigram', latitude: 25.81, longitude: 89.65),
  District(division: 'Rangpur', name: 'Lalmonirhat', latitude: 25.92, longitude: 89.45),
  District(division: 'Rangpur', name: 'Nilphamari', latitude: 25.93, longitude: 88.86),
  District(division: 'Rangpur', name: 'Panchagarh', latitude: 26.33, longitude: 88.55),
  District(division: 'Rangpur', name: 'Rangpur', latitude: 25.75, longitude: 89.25),
  District(division: 'Rangpur', name: 'Thakurgaon', latitude: 26.03, longitude: 88.47),

  // ---- Sylhet
  District(division: 'Sylhet', name: 'Habiganj', latitude: 24.38, longitude: 91.42),
  District(division: 'Sylhet', name: 'Moulvibazar', latitude: 24.48, longitude: 91.78),
  District(division: 'Sylhet', name: 'Sunamganj', latitude: 25.07, longitude: 91.40),
  District(division: 'Sylhet', name: 'Sylhet', latitude: 24.89, longitude: 91.87),
];

/// The districts in one division, in the order the picker lists them.
List<District> districtsOf(String division) =>
    bangladeshDistricts.where((d) => d.division == division).toList();
