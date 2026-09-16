import 'dart:math';

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
    this.addVisitsToDay = false,
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

  /// Whether a stay here should be written onto the day as an event of its
  /// own, so the timeline shows where the time actually went and not only what
  /// was planned.
  final bool addVisitsToDay;

  /// The smallest radius the OS will reliably honour. Below roughly this,
  /// both platforms produce arrivals and departures that never happened.
  static const minimumRadiusMeters = 100.0;
  static const defaultRadiusMeters = 150.0;
  static const maximumRadiusMeters = 2000.0;

  /// Metres from here to there, on a sphere.
  ///
  /// Haversine, with the earth as a ball: at the scale a geofence works on —
  /// a few hundred metres — the error against a proper ellipsoid is
  /// centimetres, and this needs no plugin, so it can be reasoned about and
  /// tested without a device.
  double metresTo(double lat, double lon) {
    const earthRadius = 6371008.8;
    const toRadians = pi / 180;

    final dLat = (lat - latitude) * toRadians;
    final dLon = (lon - longitude) * toRadians;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(latitude * toRadians) *
            cos(lat * toRadians) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return 2 * earthRadius * asin(min(1, sqrt(a)));
  }

  /// Whether this place's circle and [other]'s touch.
  ///
  /// Two circles that overlap cannot be told apart by the OS: standing in the
  /// overlap it reports both, and neither report is wrong. Worth saying out
  /// loud when a place is being drawn, because the floor on the radius makes
  /// it easy to do by accident — two shops on the same street are inside each
  /// other's hundred metres.
  bool overlaps(Place other) =>
      metresTo(other.latitude, other.longitude) <
      radiusMeters + other.radiusMeters;
}

/// Shorter than this and a stay we inferred the end of was not a stay.
///
/// Neither platform will call an arrival an arrival faster than about this —
/// Android waits it out as a loitering delay — so a stay that we ourselves cut
/// short, and that turns out to have lasted less, is the edge of a circle
/// clipped on the way somewhere else rather than somewhere the user went.
const shortestStay = Duration(minutes: 2);

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
