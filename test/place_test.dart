import 'package:dayline/src/model/place.dart';
import 'package:test/test.dart';

/// Distances between places, and what it means for two of them to overlap.
///
/// Dayline has no map and no geocoder, so this is the whole of its geometry:
/// how far apart two circles are, and whether the OS could tell them apart.
void main() {
  Place at(
    double latitude,
    double longitude, {
    double radius = Place.defaultRadiusMeters,
    String name = 'Somewhere',
  }) =>
      Place(
        id: 1,
        name: name,
        latitude: latitude,
        longitude: longitude,
        radiusMeters: radius,
        colorValue: 0xFF3B82F6,
      );

  group('how far apart', () {
    test('a thousandth of a degree of latitude is about 111 m', () {
      // True everywhere on earth: the meridians do not converge.
      expect(at(51.510, -0.130).metresTo(51.511, -0.130), closeTo(111.2, 0.5));
      expect(at(0, 0).metresTo(0.001, 0), closeTo(111.2, 0.5));
    });

    test('a degree of longitude shrinks with the latitude', () {
      // cos(51.51°) of the distance it covers at the equator.
      expect(at(51.510, -0.130).metresTo(51.510, -0.129), closeTo(69.2, 0.5));
      expect(at(0, 0).metresTo(0, 0.001), closeTo(111.2, 0.5));
    });

    test('nowhere is no distance at all', () {
      expect(at(51.51, -0.13).metresTo(51.51, -0.13), 0);
    });
  });

  group('overlapping', () {
    test('two circles a street apart are the same circle to the OS', () {
      // 44 m apart: at any radius the phone will watch, these two are one
      // place as far as the OS is concerned.
      final shop = at(51.5100, -0.1300, radius: 100, name: 'GS');
      final gym = at(51.5104, -0.1300, radius: 100, name: 'LUXE Gym');

      expect(shop.metresTo(gym.latitude, gym.longitude), closeTo(44.5, 1));
      expect(shop.overlaps(gym), isTrue);
      expect(gym.overlaps(shop), isTrue, reason: 'and the other way round');
      expect(
        at(51.5100, -0.1300, radius: Place.minimumRadiusMeters)
            .overlaps(at(51.5104, -0.1300, radius: Place.minimumRadiusMeters)),
        isTrue,
        reason: 'even drawn as tight as the phone allows',
      );
    });

    test('the tighter floor is what separates two places 150 m apart', () {
      // 167 m between them: at 100 m each the circles still touch, and at the
      // 50 m floor they do not. This is the whole reason a circle is allowed
      // to be drawn smaller than either vendor recommends.
      const northern = 51.5115;
      expect(
        at(51.5100, -0.1300, radius: Place.reliableRadiusMeters)
            .overlaps(at(northern, -0.1300, radius: Place.reliableRadiusMeters)),
        isTrue,
      );
      expect(
        at(51.5100, -0.1300, radius: Place.minimumRadiusMeters)
            .overlaps(at(northern, -0.1300, radius: Place.minimumRadiusMeters)),
        isFalse,
      );
    });

    test('far enough apart, or tight enough, and they do not', () {
      final office = at(51.5100, -0.1300, radius: 150);
      final home = at(51.5150, -0.1300, radius: 150);

      expect(office.overlaps(home), isFalse, reason: '556 m apart');
      expect(
        at(51.5100, -0.1300, radius: 100)
            .overlaps(at(51.5120, -0.1300, radius: 100)),
        isFalse,
        reason: '222 m apart, and 200 m of radius between them',
      );
    });

    test('a circle inside a bigger one overlaps it', () {
      // The gym in the office campus: the case the crossing has to resolve.
      final campus = at(51.5100, -0.1300, radius: 400);
      final gym = at(51.5101, -0.1300, radius: 100);

      expect(campus.overlaps(gym), isTrue);
    });
  });
}
