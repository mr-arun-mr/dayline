/// What a place is for, which is only ever used to pick an icon and to group
/// the dashboard. Nothing is inferred from it.
enum PlaceKind {
  home(0),
  work(1),
  gym(2),
  shop(3),
  leisure(4),
  other(5);

  const PlaceKind(this.code);

  final int code;

  static PlaceKind fromCode(int code) =>
      PlaceKind.values.firstWhere((k) => k.code == code,
          orElse: () => PlaceKind.other);
}

/// Somewhere the user told us about.
///
/// Every place in Dayline is one the user added deliberately, standing there,
/// by tapping "use my location". Nothing is looked up: there is no places
/// database, no geocoder and no network permission, so the app cannot know
/// that a set of coordinates is a Tesco — only that it is the spot the user
/// called "Tesco".
class Place {
  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.colorValue,
    this.kind = PlaceKind.other,
    this.isActive = true,
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;

  /// How close counts as "here". Small radii miss arrivals; large ones catch
  /// the street outside.
  final double radiusMeters;

  final int colorValue;
  final PlaceKind kind;

  /// Whether the OS is currently watching for it.
  final bool isActive;

  /// The smallest radius the OS will reliably honour. Below roughly this,
  /// both platforms produce arrivals and departures that never happened.
  static const minimumRadiusMeters = 100.0;
  static const defaultRadiusMeters = 150.0;
  static const maximumRadiusMeters = 2000.0;
}

/// One stay at a place: when the device arrived and, once it has, when it left.
class Visit {
  const Visit({
    required this.id,
    required this.placeId,
    required this.arrivedAt,
    this.departedAt,
  });

  final int id;
  final int placeId;
  final DateTime arrivedAt;

  /// Null while the device is still inside the geofence.
  final DateTime? departedAt;

  bool get isOpen => departedAt == null;

  /// How long the stay lasted, treating an open visit as running up to [now].
  Duration durationAt(DateTime now) =>
      (departedAt ?? now).difference(arrivedAt);
}
