library neom_google_places.src;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:neom_maps_services/domain/models/location.dart';
import 'package:neom_maps_services/domain/models/place_autocomplete_response.dart';
import 'package:neom_maps_services/domain/models/prediction.dart';
import 'package:neom_maps_services/utils/component.dart';
import 'package:sint/sint.dart';

import '../utils/enums/mode.dart';
import 'places_autocomplete_widget.dart';

class PlacesAutocomplete {
  static Future<Prediction?> show({
    required BuildContext context,
    required String apiKey,
    Mode mode = Mode.fullscreen,
    String hint = "Search",
    BorderRadius? overlayBorderRadius,
    num? offset,
    Location? location,
    num? radius,
    String? language,
    String? sessionToken,
    List<String>? types,
    List<Component>? components,
    bool? strictBounds,
    String? region,
    Widget? logo,
    ValueChanged<PlacesAutocompleteResponse>? onError,
    String? proxyBaseUrl,
    Client? httpClient,
    InputDecoration? decoration,
    String startText = "",
    Duration transitionDuration = const Duration(milliseconds: 300),
    TextStyle? textStyle,
    ThemeData? themeData,
    TextStyle? resultTextStyle,
    ValueChanged<Prediction>? onTap,
    ValueChanged<Prediction>? itmClick,
  }) {
    final autoCompleteWidget = PlacesAutocompleteWidget(
      apiKey: apiKey,
      mode: mode,
      overlayBorderRadius: overlayBorderRadius,
      language: language,
      sessionToken: sessionToken,
      components: components,
      types: types,
      location: location,
      radius: radius,
      strictBounds: strictBounds,
      region: region,
      offset: offset,
      hint: hint,
      logo: logo,
      onError: onError,
      proxyBaseUrl: proxyBaseUrl,
      httpClient: httpClient,
      startText: startText,
      decoration: decoration,
      textStyle: textStyle,
      themeData: themeData,
      resultTextStyle: resultTextStyle,
      onTap: onTap,
      itmClick: itmClick,
    );

    if (mode == Mode.overlay) {
      return showDialog(
        context: context,
        builder: (BuildContext ctx) => autoCompleteWidget,
      );
    } else {
      return Sint.to<Prediction>(
            () => autoCompleteWidget,
            duration: transitionDuration,
          ) ??
          Future<Prediction?>.value();
    }
  }
}
