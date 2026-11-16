library neom_google_places.src;

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
import 'package:sint/sint.dart';

import '../utils/enums/mode.dart';
import 'powered_by_google_image.dart';
import 'widgets/prediction_list_view.dart';
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
  final Client? httpClient;

  /// optional - set 'resultTextStyle' value in google_maps_webservice
  ///
  /// In case of changing the default text style of result's text
  final TextStyle? resultTextStyle;

  /// Optional custom callback invoked when a [Prediction] is selected instead of
  /// popping the current route with `prediction`.
  final ValueChanged<Prediction>? onTap;

  /// Optional side-effect callback invoked when a [Prediction] item is tapped
  /// before returning the selected [Prediction] via navigation.
  final ValueChanged<Prediction>? itmClick;

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
    this.onTap,
    this.itmClick,
  });

  @override
  State<PlacesAutocompleteWidget> createState() =>
      _PlacesAutocompleteOverlayState();

  static PlacesAutocompleteState? of(BuildContext context) =>
      context.findAncestorStateOfType<PlacesAutocompleteState>();
}

class _PlacesAutocompleteOverlayState extends PlacesAutocompleteState {
  void _handlePredictionSelection(Prediction prediction) {
    widget.itmClick?.call(prediction);
    if (widget.onTap != null) {
      widget.onTap!(prediction);
      return;
    }
    Sint.pop(prediction);
  }

  void _handleDismiss() {
    Sint.pop();
  }

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
            onTap: _handlePredictionSelection,
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
                  onPressed: _handleDismiss,
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
                      onTap: _handlePredictionSelection,
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
  static const int maxAutocompleteQueryChars = 512;
  static final RegExp _unsafeQueryControls = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B\u200C\u200E\u200F\u2028\u2029\u202A-\u202E\u2060-\u2069\uFEFF]',
  );
  static final RegExp _gemma4ThoughtClosed = RegExp(
    r'<\|(?:channel|turn)>\s*thought\b[\s\S]*?<(?:channel|turn)\|>'
    r'|<\|tool_call>[\s\S]*?<tool_call\|>',
    caseSensitive: false,
  );
  static final RegExp _gemma4ThoughtTruncated = RegExp(
    r'<\|(?:channel|turn)>\s*thought\b[\s\S]*$'
    r'|<\|tool_call>[\s\S]*$',
    caseSensitive: false,
  );
  static final RegExp _internalReasoningBlock = RegExp(
    r'<\s*(think|thought|memory_recall|auto_memory|system_context)\b[^>]*>[\s\S]*?(?:<\s*/\s*\1\s*>|$)'
    r'|\[\s*(BIOCHIP|MEMORY_RECALL|AUTO_MEMORY|SYSTEM_CONTEXT)\b[^\]]*\][\s\S]*?\[\s*/\s*\2\s*\]',
    caseSensitive: false,
  );
  static final RegExp _sentinelBracketBlock = RegExp(
    r'\[\s*/?\s*(?:BIOCHIP|MEMORY_RECALL|AUTO_MEMORY|SYSTEM_CONTEXT)\b[^\]]*\]',
    caseSensitive: false,
  );
  static final RegExp _turnTokens = RegExp(
    r'(?:<\|/?(?:turn|channel|eot|im_start|im_end|tool_call)[^>]*\|?>|<(?:turn|channel|tool_call)\|>)',
    caseSensitive: false,
  );
  static final RegExp _closingContentBoundary = RegExp(
    r'<\s*/\s*content\s*>',
    caseSensitive: false,
  );
  static final RegExp _sensitiveSecretPattern = RegExp(
    r'(?:\b(?:Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+|\b(?:sk_live_|sk_test_|rk_live_|rk_test_|whsec_|sk-|AIza|ghp_|github_pat_|glpat-|xox[baprs]-|AKIA|hf_)[A-Za-z0-9_-]{8,}|\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{8,}|(?:x-goog-api-key|api[_-]?key|key|token|access_token|refresh_token|session_token|client_secret|private_key|secret|password|authorization)\s*[=:]\s*[^\s&",;]+|://[^/\s:@]+:[^/\s@]+@)',
    caseSensitive: false,
  );

  static String sanitizeAutocompleteQuery(
    String raw, {
    int maxChars = maxAutocompleteQueryChars,
  }) {
    if (!maxChars.toDouble().isFinite || maxChars <= 0) return '';
    var cleaned = raw
        .replaceAll(_gemma4ThoughtClosed, ' ')
        .replaceAll(_gemma4ThoughtTruncated, ' ')
        .replaceAll(_internalReasoningBlock, ' ')
        .replaceAll(_sentinelBracketBlock, ' ')
        .replaceAll(_turnTokens, ' ')
        .replaceAll(_closingContentBoundary, '[content_end]')
        .replaceAll(_unsafeQueryControls, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= maxChars) return cleaned;
    var end = maxChars;
    final cu = cleaned.codeUnitAt(end - 1);
    if (cu >= 0xD800 && cu <= 0xDBFF) end -= 1;
    if (end <= 0) return '';
    return cleaned.substring(0, end).trimRight();
  }

  static String sanitizeAutocompleteError(
    Object error, {
    int maxChars = 300,
  }) {
    if (!maxChars.toDouble().isFinite || maxChars <= 0) return '';
    var cleaned = error
        .toString()
        .replaceAll(_gemma4ThoughtClosed, ' ')
        .replaceAll(_gemma4ThoughtTruncated, ' ')
        .replaceAll(_internalReasoningBlock, ' ')
        .replaceAll(_sentinelBracketBlock, ' ')
        .replaceAll(_turnTokens, ' ')
        .replaceAll(_closingContentBoundary, '[content_end]')
        .replaceAll(_unsafeQueryControls, ' ')
        .replaceAll(_sensitiveSecretPattern, '[REDACTED]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length <= maxChars) return cleaned;
    var end = maxChars;
    final cu = cleaned.codeUnitAt(end - 1);
    if (cu >= 0xD800 && cu <= 0xDBFF) end -= 1;
    if (end <= 0) return '';
    return cleaned.substring(0, end).trimRight();
  }

  TextEditingController? queryTextController;
  PlacesAutocompleteResponse? response;
  GoogleMapsPlaces? places;
  late bool searching;
  Timer? debounce;
  StreamSubscription<String>? _querySub;

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

    _querySub = _queryBehavior.stream.listen(doSearch);
  }

  Future<void> _initPlaces() async {
    Map<String, String>? headers;
    try {
      headers = await const GoogleApiHeaders().getHeaders();
    } catch (_) {
      headers = null;
    }
    if (!mounted) return;
    try {
      places = GoogleMapsPlaces(
        apiKey: widget.apiKey,
        baseUrl: widget.proxyBaseUrl,
        httpClient: widget.httpClient,
        apiHeaders: headers,
      );
    } catch (e) {
      places = null;
      onResponseError(
        PlacesAutocompleteResponse(
          predictions: const [],
          status: 'REQUEST_DENIED',
          errorMessage: 'Invalid Maps proxy endpoint',
        ),
      );
    }
  }

  Future<void> doSearch(String value) async {
    final trimmed = sanitizeAutocompleteQuery(value);
    if (mounted && trimmed.isNotEmpty && places != null) {
      setState(() {
        searching = true;
      });

      try {
        final res = await places!.autocomplete(
          trimmed,
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
          onResponseError(
            PlacesAutocompleteResponse(
              predictions: res.predictions,
              status: res.status,
              errorMessage: res.errorMessage != null
                  ? sanitizeAutocompleteError(res.errorMessage!)
                  : null,
            ),
          );
        } else {
          onResponse(res);
        }
      } catch (e) {
        onResponseError(
          PlacesAutocompleteResponse(
            predictions: [],
            status: 'REQUEST_DENIED',
            errorMessage: sanitizeAutocompleteError(e),
          ),
        );
      }
    } else {
      onResponse(null);
    }
  }

  void _onQueryChange() {
    if (debounce?.isActive ?? false) debounce!.cancel();
    final safeMs = widget.debounce.toDouble().isFinite
        ? widget.debounce.clamp(0, 10000)
        : 300;
    debounce = Timer(Duration(milliseconds: safeMs), () {
      if (!_queryBehavior.isClosed && queryTextController != null) {
        _queryBehavior.add(queryTextController!.text);
      }
    });
  }

  @override
  void dispose() {
    debounce?.cancel();
    _querySub?.cancel();
    _queryBehavior.close();
    queryTextController?.removeListener(_onQueryChange);
    queryTextController?.dispose();
    places?.dispose();
    super.dispose();
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
      strictBounds: strictbounds,
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

class AppBarPlacesAutoCompleteTextField extends StatefulWidget {
  final InputDecoration? textDecoration;
  final TextStyle? textStyle;

  const AppBarPlacesAutoCompleteTextField({
    super.key,
    this.textDecoration,
    this.textStyle,
  });

  @override
  AppBarPlacesAutoCompleteTextFieldState createState() =>
      AppBarPlacesAutoCompleteTextFieldState();
}

class AppBarPlacesAutoCompleteTextFieldState
    extends State<AppBarPlacesAutoCompleteTextField> {
  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context)!;

    return Container(
      alignment: Alignment.topLeft,
      margin: const EdgeInsets.only(top: 4.0),
      child: TextField(
        controller: state.queryTextController,
        autofocus: true,
        style: widget.textStyle ?? _defaultStyle(),
        decoration:
        widget.textDecoration ?? _defaultDecoration(state.widget.hint),
      ),
    );
  }

  InputDecoration _defaultDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Theme.of(context).brightness == Brightness.light
          ? Colors.white30
          : Colors.black38,
      hintStyle: TextStyle(
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.black38
            : Colors.white30,
        fontSize: 16.0,
      ),
      border: InputBorder.none,
    );
  }

  TextStyle _defaultStyle() {
    return TextStyle(
      color: Theme.of(context).brightness == Brightness.light
          ? Colors.black.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.9),
      fontSize: 16.0,
    );
  }
}

class PlacesAutocompleteResult extends StatefulWidget {
  final ValueChanged<Prediction>? onTap;
  final Widget? logo;
  final TextStyle? resultTextStyle;

  const PlacesAutocompleteResult({
    super.key,
    this.onTap,
    this.logo,
    this.resultTextStyle,
  });

  @override
  PlacesAutocompleteResultState createState() =>
      PlacesAutocompleteResultState();
}

class PlacesAutocompleteResultState extends State<PlacesAutocompleteResult> {
  @override
  Widget build(BuildContext context) {
    final state = PlacesAutocompleteWidget.of(context)!;

    if (state.queryTextController!.text.isEmpty ||
        state.response == null ||
        state.response!.predictions.isEmpty) {
      final children = <Widget>[];
      if (state.searching) {
        children.add(const ProgressLoader());
      }
      children.add(widget.logo ?? const PoweredByGoogleImage());
      return Stack(children: children);
    }
    return PredictionsListView(
      predictions: state.response!.predictions,
      onTap: widget.onTap,
      resultTextStyle: widget.resultTextStyle,
    );
  }
}
