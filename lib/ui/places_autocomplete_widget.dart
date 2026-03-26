library neom_google_places.src;
import 'package:sint/sint.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_api_headers/google_api_headers.dart';
import 'package:http/http.dart';
import 'package:neom_maps_services/data/google_maps_places.dart';
import 'package:neom_maps_services/domain/models/location.dart';
import 'package:neom_maps_services/domain/models/place_autocomplete_response.dart';
import 'package:neom_maps_services/domain/models/prediction.dart';
import 'package:neom_maps_services/utils/component.dart';
import 'package:rxdart/rxdart.dart';

import '../utils/enums/mode.dart';
import 'appbar_places_autocomplete_text_field.dart';
import 'places_autocomplete_result.dart';
import 'powered_by_google_image.dart';
import 'widgets/prediction_tile.dart';
import 'widgets/progress_loader.dart';

class PlacesAutocompleteWidget extends StatefulWidget {
  final String apiKey;
  final String? startText;
  final String hint;
  final BorderRadius? overlayBorderRadius;
  final Location? location;
  final num? offset;
  final num? radius;
  final String? language;
  final String? sessionToken;
  final List<String>? types;
  final List<Component>? components;
  final bool? strictBounds;
  final String? region;
  final Mode mode;
  final Widget? logo;
  final ValueChanged<PlacesAutocompleteResponse>? onError;
  final int debounce;
  final InputDecoration? decoration;
  final TextStyle? textStyle;
  final ThemeData? themeData;

  /// optional - sets 'proxy' value in google_maps_webservice
  ///
  /// In case of using a proxy the baseUrl can be set.
  /// The apiKey is not required in case the proxy sets it.
  /// (Not storing the apiKey in the app is good practice)
  final String? proxyBaseUrl;

  /// optional - set 'client' value in google_maps_webservice
  ///
  /// In case of using a proxy url that requires authentication
  /// or custom configuration
  final BaseClient? httpClient;

  /// optional - set 'resultTextStyle' value in google_maps_webservice
  ///
  /// In case of changing the default text style of result's text
  final TextStyle? resultTextStyle;

  const PlacesAutocompleteWidget({
    required this.apiKey,
    this.mode = Mode.fullscreen,
    this.hint = "Search",
    this.overlayBorderRadius,
    this.offset,
    this.location,
    this.radius,
    this.language,
    this.sessionToken,
    this.types,
    this.components,
    this.strictBounds,
    this.region,
    this.logo,
    this.onError,
    super.key,
    this.proxyBaseUrl,
    this.httpClient,
    this.startText,
    this.debounce = 300,
    this.decoration,
    this.textStyle,
    this.themeData,
    this.resultTextStyle,
  });

  @override
  State<PlacesAutocompleteWidget> createState() =>
      _PlacesAutocompleteOverlayState();

  static PlacesAutocompleteState? of(BuildContext context) =>
      context.findAncestorStateOfType<PlacesAutocompleteState>();
}

class _PlacesAutocompleteOverlayState extends PlacesAutocompleteState {
  @override
  Widget build(BuildContext context) {
    final theme = widget.themeData ?? Theme.of(context);
    if (widget.mode == Mode.fullscreen) {
      return Theme(
        data: theme,
        child: Scaffold(
          appBar: AppBar(
            title: AppBarPlacesAutoCompleteTextField(
              textDecoration: widget.decoration,
              textStyle: widget.textStyle,
            ),
          ),
          body: PlacesAutocompleteResult(
            onTap: (_) => Sint.back(),
            logo: widget.logo,
            resultTextStyle: widget.resultTextStyle,
          ),
        ),
      );
    } else {
      final headerTopLeftBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.topLeft
          : const Radius.circular(2);

      final headerTopRightBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.topRight
          : const Radius.circular(2);

      final header = Column(
        children: <Widget>[
          Material(
            color: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: headerTopLeftBorderRadius,
              topRight: headerTopRightBorderRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                IconButton(
                  color: theme.brightness == Brightness.light
                      ? Colors.black45
                      : null,
                  icon: _iconBack,
                  onPressed: () {
                    Sint.back();
                  },
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _textField(context),
                  ),
                ),
              ],
            ),
          ),
          const Divider()
        ],
      );

      Widget body;

      final bodyBottomLeftBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.bottomLeft
          : const Radius.circular(2);

      final bodyBottomRightBorderRadius = widget.overlayBorderRadius != null
          ? widget.overlayBorderRadius!.bottomRight
          : const Radius.circular(2);

      if (searching) {
        body = const Stack(
          alignment: FractionalOffset.bottomCenter,
          children: <Widget>[ProgressLoader()],
        );
      } else if (queryTextController!.text.isEmpty ||
          response == null ||
          response!.predictions.isEmpty) {
        body = Material(
          color: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            bottomLeft: bodyBottomLeftBorderRadius,
            bottomRight: bodyBottomRightBorderRadius,
          ),
          child: widget.logo ?? const PoweredByGoogleImage(),
        );
      } else {
        body = SingleChildScrollView(
          child: Material(
            borderRadius: BorderRadius.only(
              bottomLeft: bodyBottomLeftBorderRadius,
              bottomRight: bodyBottomRightBorderRadius,
            ),
            color: theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
            child: ListBody(
              children: response!.predictions
                  .map(
                    (p) => PredictionTile(
                      prediction: p,
                      onTap: (_) => Sint.back(),
                      resultTextStyle: widget.resultTextStyle,
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      }

      final container = Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 30.0),
        child: Stack(
          children: <Widget>[
            header,
            Padding(padding: const EdgeInsets.only(top: 48.0), child: body),
          ],
        ),
      );

      if (Theme.of(context).platform == TargetPlatform.iOS) {
        return Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: container,
        );
      }
      return container;
    }
  }

  Icon get _iconBack => Theme.of(context).platform == TargetPlatform.iOS
      ? const Icon(Icons.arrow_back_ios)
      : const Icon(Icons.arrow_back);

  Widget _textField(BuildContext context) => TextField(
        controller: queryTextController,
        autofocus: true,
        style: widget.textStyle ??
            TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.black87
                  : null,
              fontSize: 16.0,
            ),
        decoration: widget.decoration ??
            InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black45
                    : null,
                fontSize: 16.0,
              ),
              border: InputBorder.none,
            ),
      );
}
abstract class PlacesAutocompleteState extends State<PlacesAutocompleteWidget> {
  TextEditingController? queryTextController;
  PlacesAutocompleteResponse? response;
  GoogleMapsPlaces? places;
  late bool searching;
  Timer? debounce;

  final _queryBehavior = BehaviorSubject<String>.seeded('');

  @override
  void initState() {
    super.initState();

    queryTextController = TextEditingController(text: widget.startText);
    queryTextController!.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.startText?.length ?? 0,
    );

    _initPlaces();
    searching = false;

    queryTextController!.addListener(_onQueryChange);

    _queryBehavior.stream.listen(doSearch);
  }

  Future<void> _initPlaces() async {
    places = GoogleMapsPlaces(
      apiKey: widget.apiKey,
      baseUrl: widget.proxyBaseUrl,
      httpClient: widget.httpClient,
      apiHeaders: await const GoogleApiHeaders().getHeaders(),
    );
  }

  Future<void> doSearch(String value) async {
    if (mounted && value.isNotEmpty && places != null) {
      setState(() {
        searching = true;
      });

      final res = await places!.autocomplete(
        value,
        offset: widget.offset,
        location: widget.location,
        radius: widget.radius,
        language: widget.language,
        sessionToken: widget.sessionToken,
        types: widget.types ?? [],
        components: widget.components ?? [],
        strictBounds: widget.strictBounds ?? false,
        region: widget.region,
      );

      if (res.errorMessage?.isNotEmpty == true ||
          res.status == "REQUEST_DENIED") {
        onResponseError(res);
      } else {
        onResponse(res);
      }
    } else {
      onResponse(null);
    }
  }

  void _onQueryChange() {
    if (debounce?.isActive ?? false) debounce!.cancel();
    debounce = Timer(Duration(milliseconds: widget.debounce), () {
      if (!_queryBehavior.isClosed) {
        _queryBehavior.add(queryTextController!.text);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();

    places?.dispose();
    debounce?.cancel();
    _queryBehavior.close();
    queryTextController?.removeListener(_onQueryChange);
  }

  @mustCallSuper
  void onResponseError(PlacesAutocompleteResponse res) {
    if (!mounted) return;

    widget.onError?.call(res);
    setState(() {
      response = null;
      searching = false;
    });
  }

  @mustCallSuper
  void onResponse(PlacesAutocompleteResponse? res) {
    if (!mounted) return;

    setState(() {
      response = res;
      searching = false;
    });
  }
}

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
    bool? strictbounds,
    String? region,
    Widget? logo,
    ValueChanged<PlacesAutocompleteResponse>? onError,
    String? proxyBaseUrl,
    Client? httpClient,
    InputDecoration? decoration,
    String startText = "",
    Duration transitionDuration = const Duration(seconds: 300),
    TextStyle? textStyle,
    ThemeData? themeData,
    TextStyle? resultTextStyle,
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
      strictBounds: strictbounds,
      region: region,
      offset: offset,
      hint: hint,
      logo: logo,
      onError: onError,
      proxyBaseUrl: proxyBaseUrl,
      httpClient: httpClient as BaseClient?,
      startText: startText,
      decoration: decoration,
      textStyle: textStyle,
      themeData: themeData,
      resultTextStyle: resultTextStyle,
    );

    if (mode == Mode.overlay) {
      return showDialog(
        context: context,
        builder: (BuildContext ctx) => autoCompleteWidget,
      );
    } else {
      return Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => autoCompleteWidget,
          transitionDuration: transitionDuration,
        ),
      );
    }
  }
}
