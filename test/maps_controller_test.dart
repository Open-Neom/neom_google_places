import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/model/app_user.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_google_places/data/implementations/maps_controller.dart';
import 'package:sint/sint.dart';

class _FakeUserService extends Fake implements UserService {
  _FakeUserService(this._profile);

  @override
  final AppUser user = AppUser(id: 'u1');

  AppProfile _profile;

  @override
  AppProfile get profile => _profile;

  @override
  set profile(AppProfile value) {
    _profile = value;
  }
}

class _FakeGoogleMapController extends Fake implements GoogleMapController {
  final List<CameraUpdate> animatedUpdates = [];

  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate, {Duration? duration}) async {
    animatedUpdates.add(cameraUpdate);
  }
}

Position _pos(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Sint.reset);

  test(
    'prefers fresh GPS position over profile.position and animates ready GoogleMapController',
    () async {
      final staleProfilePos = _pos(19.4326, -99.1332);
      final freshGpsPos = _pos(20.6736, -103.3440);
      final gpsCompleter = Completer<Position?>();

      final userService = _FakeUserService(
        AppProfile(id: 'p1', name: 'Musician', position: staleProfilePos),
      );
      Sint.put<UserService>(userService);

      final mapsController = MapsController(
        currentPositionLoader: () => gpsCompleter.future,
      );
      final fakeMap = _FakeGoogleMapController();

      mapsController.onInit();

      // While GPS is still resolving, initialCameraPosition must never throw
      // and falls back cleanly to profile.position.
      final initialBeforeGps = mapsController.initialCameraPosition();
      expect(initialBeforeGps.target.latitude, closeTo(19.4326, 1e-4));
      expect(initialBeforeGps.target.longitude, closeTo(-99.1332, 1e-4));

      // Map becomes ready before GPS resolves.
      mapsController.googleMapController = fakeMap;
      expect(fakeMap.animatedUpdates, isEmpty);

      // GPS resolves with fresh coordinates -> preferred over profile.position,
      // updates profile, and animates camera cleanly.
      gpsCompleter.complete(freshGpsPos);
      await mapsController.initializationComplete;

      expect(mapsController.referencePosition, same(freshGpsPos));
      expect(mapsController.placePosition, same(freshGpsPos));
      expect(userService.profile.position, same(freshGpsPos));
      expect(fakeMap.animatedUpdates, hasLength(1));

      mapsController.onClose();
    },
  );

  test(
    'falls back to profile.position only when GPS returns null and profile.position is non-zero',
    () async {
      final savedPos = _pos(25.6866, -100.3161);
      final userService = _FakeUserService(
        AppProfile(id: 'p2', name: 'Venue', position: savedPos),
      );
      Sint.put<UserService>(userService);

      final mapsController = MapsController(
        currentPositionLoader: () async => null,
      );
      mapsController.onInit();
      await mapsController.initializationComplete;

      expect(mapsController.referencePosition, same(savedPos));
      final camera = mapsController.initialCameraPosition();
      expect(camera.target.latitude, closeTo(25.6866, 1e-4));
      expect(camera.target.longitude, closeTo(-100.3161, 1e-4));

      mapsController.onClose();
    },
  );

  test(
    'ignores zero profile.position when GPS returns null and initialCameraPosition never force-unwraps null',
    () async {
      final userService = _FakeUserService(
        AppProfile(id: 'p3', name: 'ZeroPos', position: _pos(0.0, 0.0)),
      );
      Sint.put<UserService>(userService);

      final mapsController = MapsController(
        currentPositionLoader: () async => null,
      );
      mapsController.onInit();
      await mapsController.initializationComplete;

      expect(mapsController.referencePosition, isNull);
      final camera = mapsController.initialCameraPosition();
      expect(camera.target, MapsController.defaultFallbackTarget);

      mapsController.onClose();
    },
  );

  test(
    'animates camera when GoogleMapController attaches after fallback initialCameraPosition was used',
    () async {
      final freshGpsPos = _pos(20.6736, -103.3440);
      final userService = _FakeUserService(
        AppProfile(id: 'p4', name: 'LateMap'),
      );
      Sint.put<UserService>(userService);

      final mapsController = MapsController(
        currentPositionLoader: () async => freshGpsPos,
      );
      mapsController.onInit();

      // Widget calls initialCameraPosition before GPS finishes -> fallback used.
      final initialCamera = mapsController.initialCameraPosition();
      expect(initialCamera.target, MapsController.defaultFallbackTarget);

      // GPS resolves before native map finishes onMapCreated.
      await mapsController.initializationComplete;
      expect(mapsController.referencePosition, same(freshGpsPos));

      // Native map controller now attaches -> animates to resolved referencePosition.
      final fakeMap = _FakeGoogleMapController();
      mapsController.googleMapController = fakeMap;
      await Future<void>.delayed(Duration.zero);

      expect(fakeMap.animatedUpdates, hasLength(1));

      mapsController.onClose();
    },
  );
}
