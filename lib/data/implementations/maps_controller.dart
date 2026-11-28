import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/cloud_properties.dart';
import 'package:neom_core/data/implementations/geolocator_controller.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/model/place.dart';
import 'package:neom_core/domain/use_cases/maps_service.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/constants/core_constants.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:neom_core/utils/position_utilities.dart';
import 'package:neom_maps_services/data/google_maps_places.dart';
import 'package:neom_maps_services/domain/models/location.dart';
import 'package:neom_maps_services/domain/models/place_autocomplete_response.dart';
import 'package:neom_maps_services/domain/models/place_details.dart';
import 'package:neom_maps_services/domain/models/prediction.dart';
import 'package:neom_maps_services/utils/component.dart';
import 'package:sint/sint.dart';

import '../../ui/places_autocomplete.dart';
import '../../utils/enums/mode.dart';

class MapsController extends SintController implements MapsService {
  MapsController({
    Future<Position?> Function()? currentPositionLoader,
  }) : _currentPositionLoader =
            currentPositionLoader ?? (() => GeoLocatorController().getCurrentPosition());

  final Future<Position?> Function() _currentPositionLoader;

  /// Safe default coordinates used only while GPS and profile coordinates are
  /// still resolving or unavailable.
  static const LatLng defaultFallbackTarget = LatLng(20.6597, -103.3496);

  final userServiceImpl = Sint.find<UserService>();

  GoogleMapController? _googleMapController;
  final RxSet<Marker> _markers = <Marker>{}.obs;
  bool _usedFallbackInitialPosition = false;
  Future<void>? _initFuture;

  @visibleForTesting
  Future<void> get initializationComplete => _initFuture ?? Future.value();

  /// Cached Google API key — fetched from Cloud Functions in secure mode.
  String _googleApiKey = '';

  AppProfile profile = AppProfile();
  Position? referencePosition;
  final Rx<Position> _placePosition = Position(
      latitude: 0.0,
      longitude: 0.0,
      timestamp: DateTime.now(), accuracy: 0.0, altitude: 0.0, heading: 0.0, speed: 0.0, speedAccuracy: 0.0,
      altitudeAccuracy: 1.0, headingAccuracy: 1.0
  ).obs;
  Location location = Location(latitude: 0, longitude: 0);
  final Rx<Prediction> prediction = Prediction().obs;

  static bool _hasValidCoordinates(Position? position) =>
      position != null &&
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      (position.latitude != 0 || position.longitude != 0);

  @override
  void onInit() {
    super.onInit();
    AppConfig.logger.t("Maps Controller Init");
    profile = userServiceImpl.profile;
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    try {
      // On web, ALWAYS fetch Google API key from Cloud Functions (even if
      // getConfig failed — the key is never in client-side properties).
      if (CloudProperties.isSecureMode || kIsWeb) {
        _googleApiKey = await CloudProperties.getSecretFromCloud('googleApiKey');
      } else {
        _googleApiKey = CloudProperties.getGoogleApiKey();
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_google_places',
        operation: 'onInit.apiKey',
      );
    }

    if (isClosed) return;
    profile = userServiceImpl.profile;

    Position? gpsPosition;
    try {
      gpsPosition = await _currentPositionLoader();
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_google_places',
        operation: 'onInit.gps',
      );
    }

    if (isClosed) return;

    if (_hasValidCoordinates(gpsPosition)) {
      referencePosition = gpsPosition;
      profile.position = gpsPosition;
      userServiceImpl.profile = profile;
    } else if (_hasValidCoordinates(profile.position)) {
      referencePosition = profile.position;
    } else {
      referencePosition = null;
    }

    if (referencePosition != null) {
      _placePosition.value = referencePosition!;
      location = Location(
        latitude: referencePosition!.latitude,
        longitude: referencePosition!.longitude,
      );
      await goToHomePosition();
    }
  }

  @override
  Future<void> goToPosition(Position position) async {
    AppConfig.logger.d("Go to position on Maps Controller");

    try {
      _usedFallbackInitialPosition = false;
      _placePosition.value = position;
      await _googleMapController?.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
          target: LatLng(_placePosition.value.latitude, _placePosition.value.longitude),
          zoom: CoreConstants.cameraPositionZoom
      )));

      _markers.clear();
      _markers.add(
          Marker(
            markerId: const MarkerId("selectedPlace"),
            position: LatLng(position.latitude, position.longitude),
          )
      );

    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_google_places', operation: 'goToPosition');
    }

    update();
  }

  @override
  Future<void> goToHomePosition() async {
    AppConfig.logger.t("goToHomePosition on Maps Controller");

    try {
      final targetPosition = referencePosition;
      if (!_hasValidCoordinates(targetPosition)) {
        AppConfig.logger.d("Reference position is null or zero, cannot go to home position");
        return;
      }

      final mapController = _googleMapController;
      if (mapController == null) {
        AppConfig.logger.d("GoogleMapController not ready yet");
        return;
      }

      _usedFallbackInitialPosition = false;
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(targetPosition!.latitude, targetPosition.longitude),
            zoom: CoreConstants.cameraPositionZoom,
          ),
        ),
      );
    } catch (e) {
      AppConfig.logger.d(e.toString());
    }
  }

  @override
  void onError(PlacesAutocompleteResponse response) {
    try {
      AppConfig.logger.d(response.errorMessage);
    } catch (e) {
      AppConfig.logger.d(e.toString());
    }
  }

  @override
  Future<Prediction> placeAutoComplete(BuildContext context, String startText) async {
    AppConfig.logger.d("Entering placeAutoComplete with startText: $startText");

    Prediction prediction = Prediction();

    try {
      Prediction? retrievedPrediction =  await PlacesAutocomplete.show(
        startText: startText,
        offset: 0,
        radius: 1000,
        types: [],
        location: location,
        strictBounds: false,
        mode: Mode.fullscreen,
        context: context,
        apiKey: _googleApiKey,
        onError: onError,
        language: "es-MX",
        decoration: InputDecoration(
          hintText: CoreConstants.search.tr,
          fillColor: Colors.yellow
        ),
        components: [Component(Component.country, "mx")],
      );

      if(retrievedPrediction != null) prediction = retrievedPrediction;

    } catch (e) {
      AppConfig.logger.d(e.toString());
    }

    return prediction;
  }

  @override
  CameraPosition initialCameraPosition() {
    final fallbackProfilePos = profile.position ?? userServiceImpl.profile.position;
    if (_hasValidCoordinates(referencePosition)) {
      _usedFallbackInitialPosition = false;
      return CameraPosition(
        target: LatLng(referencePosition!.latitude, referencePosition!.longitude),
        zoom: CoreConstants.cameraPositionZoom,
      );
    }
    _usedFallbackInitialPosition = true;
    if (_hasValidCoordinates(fallbackProfilePos)) {
      return CameraPosition(
        target: LatLng(fallbackProfilePos!.latitude, fallbackProfilePos.longitude),
        zoom: CoreConstants.cameraPositionZoom,
      );
    }
    return const CameraPosition(
      target: defaultFallbackTarget,
      zoom: CoreConstants.cameraPositionZoom,
    );
  }

  @override
  CameraPosition getCameraPosition(Position position){
    return CameraPosition(
      target: LatLng(position.latitude, position.longitude),
      zoom: CoreConstants.cameraPositionZoom,
    );
  }

  @override
  Future<Place> predictionToGooglePlace(Prediction prediction) async {
    AppConfig.logger.d("Entering predictionToGooglePlace with prediction: ${prediction.toString()}");

    Place place = Place();

    ///DEPRECATED
    // if(p.terms?.isNotEmpty ?? false) {
    //   placeName = p.terms!.elementAt(0).value;
    //
    //   if(p.terms!.length == 4) {
    //     address = Address(
    //       city: p.terms!.elementAt(1).value,
    //       state: p.terms!.elementAt(2).value,
    //       country: p.terms!.elementAt(3).value,
    //     );
    //   } else if(p.terms!.length == 5) {
    //     address = Address(
    //       street: p.terms!.elementAt(1).value,
    //       city: p.terms!.elementAt(2).value,
    //       state: p.terms!.elementAt(3).value,
    //       country: p.terms!.elementAt(4).value,
    //     );
    //   } else if(p.terms!.length == 6) {
    //     address = Address(
    //       street: p.terms!.elementAt(1).value,
    //       neighborhood: p.terms!.elementAt(2).value,
    //       city: p.terms!.elementAt(3).value,
    //       state: p.terms!.elementAt(4).value,
    //       country: p.terms!.elementAt(5).value,
    //     );
    //   }
    //
    // }

    try {
      GoogleMapsPlaces places = GoogleMapsPlaces(
        apiKey: _googleApiKey,
        apiHeaders: await const GoogleApiHeaders().getHeaders(),
      );

      // placeId may be null if API returns only 'place' field (format: "places/ChIJ...")
      final effectivePlaceId = (prediction.placeId?.isNotEmpty == true)
          ? prediction.placeId!
          : (prediction.place?.replaceFirst('places/', '') ?? '');

      if (effectivePlaceId.isEmpty) {
        AppConfig.logger.w('predictionToGooglePlace: No placeId in prediction');
        return place;
      }

      PlaceDetails placeDetails = await places.getDetailsByPlaceId(
          effectivePlaceId,
          language: Sint.locale?.languageCode
      );

      place.name = placeDetails.displayName?.text ?? '' ;
      place.address = await PositionUtilities.getAddressFromFormattedAddress(placeDetails.formattedAddress ?? '');
      place.position = Position(
          latitude: placeDetails.location?.latitude ?? 0.0,
          longitude: placeDetails.location?.longitude ?? 0.0,
          timestamp: DateTime.now(), accuracy: 0.0, altitude: 0.0, heading: 0.0, speed: 0.0, speedAccuracy: 0.0,
          altitudeAccuracy: 1.0, headingAccuracy: 1.0
      );
      AppConfig.logger.i(place.toString());
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_google_places', operation: 'predictionToGooglePlace');
    }

    return place;
  }

  @override
  GoogleMapController? get googleMapController => _googleMapController;

  @override
  set googleMapController(GoogleMapController? controller) {
    _googleMapController = controller;
    if (controller != null &&
        _usedFallbackInitialPosition &&
        _hasValidCoordinates(referencePosition)) {
      unawaited(goToHomePosition());
    }
  }

  @override
  // TODO: implement placePosition
  Position get placePosition => _placePosition.value;

  @override
  Set<Marker> get markers => _markers.value;

}
