// ── Vehicle type model ─────────────────────────────────────────────
class VehicleType {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String baseFare;      // display string e.g. "Rs. 50"
  final String pricePerKm;   // display string e.g. "Rs. 25/km"
  final int capacity;
  final int etaMinutes;       // placeholder ETA

  const VehicleType({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.baseFare,
    required this.pricePerKm,
    required this.capacity,
    required this.etaMinutes,
  });
}

// ── EV Fleet catalogue ─────────────────────────────────────────────
const List<VehicleType> kEvFleet = [
  VehicleType(
    id:          'ev_bike',
    name:        'EV Bike',
    emoji:       '🛵',
    description: 'Quick & affordable',
    baseFare:    'Rs. 50',
    pricePerKm:  'Rs. 20/km',
    capacity:    1,
    etaMinutes:  3,
  ),
  VehicleType(
    id:          'ev_rickshaw',
    name:        'EV Rickshaw',
    emoji:       '🛺',
    description: 'Comfy for small groups',
    baseFare:    'Rs. 80',
    pricePerKm:  'Rs. 28/km',
    capacity:    3,
    etaMinutes:  5,
  ),
  VehicleType(
    id:          'ev_car',
    name:        'EV Car',
    emoji:       '🚗',
    description: 'Premium AC ride',
    baseFare:    'Rs. 150',
    pricePerKm:  'Rs. 40/km',
    capacity:    4,
    etaMinutes:  7,
  ),
  VehicleType(
    id:          'ev_van',
    name:        'EV Van',
    emoji:       '🚐',
    description: 'Group & cargo trips',
    baseFare:    'Rs. 200',
    pricePerKm:  'Rs. 50/km',
    capacity:    8,
    etaMinutes:  10,
  ),
];
