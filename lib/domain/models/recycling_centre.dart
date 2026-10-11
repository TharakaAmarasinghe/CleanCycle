import '../../core/constants.dart';

class RecyclingCentre {
  final String name;
  final String area;
  final double latitude;
  final double longitude;
  final Set<WasteCategory> accepts;

  const RecyclingCentre({
    required this.name,
    required this.area,
    required this.latitude,
    required this.longitude,
    required this.accepts,
  });
}