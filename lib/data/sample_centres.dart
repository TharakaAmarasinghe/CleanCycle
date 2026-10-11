import '../core/constants.dart';
import '../domain/models/recycling_centre.dart';

/// SAMPLE DATA for demonstration. The names are fictional and the
/// coordinates are only approximate area centres. A real deployment would
/// load a verified directory from a backend.
const sampleCentres = <RecyclingCentre>[
  RecyclingCentre(
    name: 'Sample Centre · Fort',
    area: 'Colombo Fort',
    latitude: 6.9344,
    longitude: 79.8428,
    accepts: {WasteCategory.plastic, WasteCategory.paper, WasteCategory.metal},
  ),
  RecyclingCentre(
    name: 'Sample Centre · Dehiwala',
    area: 'Dehiwala',
    latitude: 6.8518,
    longitude: 79.8650,
    accepts: {WasteCategory.plastic, WasteCategory.glass, WasteCategory.paper},
  ),
  RecyclingCentre(
    name: 'Sample Centre · Kelaniya',
    area: 'Kelaniya',
    latitude: 6.9553,
    longitude: 79.9220,
    accepts: {WasteCategory.glass, WasteCategory.paper, WasteCategory.metal},
  ),
  RecyclingCentre(
    name: 'Sample Centre · Maharagama',
    area: 'Maharagama',
    latitude: 6.8480,
    longitude: 79.9265,
    accepts: {WasteCategory.plastic, WasteCategory.metal},
  ),
  RecyclingCentre(
    name: 'Sample Centre · Negombo',
    area: 'Negombo',
    latitude: 7.2083,
    longitude: 79.8358,
    accepts: {
      WasteCategory.plastic,
      WasteCategory.glass,
      WasteCategory.paper,
      WasteCategory.metal,
    },
  ),
  RecyclingCentre(
    name: 'Sample Centre · Kandy',
    area: 'Kandy',
    latitude: 7.2906,
    longitude: 80.6337,
    accepts: {WasteCategory.paper, WasteCategory.glass},
  ),
];