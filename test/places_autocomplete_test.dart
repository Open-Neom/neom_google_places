import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:neom_google_places/places_autocomplete_form_field.dart';
import 'package:neom_google_places/ui/places_autocomplete.dart';
import 'package:neom_google_places/ui/places_autocomplete_field.dart';
import 'package:neom_google_places/utils/enums/mode.dart';
import 'package:neom_maps_services/domain/models/prediction.dart';

void main() {
  MockClient buildMockPlacesClient() {
    return MockClient((request) async {
      final body = jsonEncode({
        'suggestions': [
          {
            'placePrediction': {
              'place': 'places/pid_gdl',
              'placeId': 'pid_gdl',
              'text': {'text': 'Guadalajara, Jalisco, Mexico'},
              'types': ['locality'],
            },
          },
        ],
      });
      return http.Response(
        body,
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  testWidgets(
    'PlacesAutocomplete returns selected Prediction and invokes itmClick in fullscreen and overlay modes',
    (tester) async {
      for (final mode in <Mode>[Mode.fullscreen, Mode.overlay]) {
        Prediction? returnedPrediction;
        Prediction? clickedItem;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    returnedPrediction = await PlacesAutocomplete.show(
                      context: context,
                      apiKey: 'test_key',
                      mode: mode,
                      logo: const SizedBox.shrink(),
                      httpClient: buildMockPlacesClient(),
                      itmClick: (p) => clickedItem = p,
                    );
                  },
                  child: Text('Open $mode'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open $mode'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Guadalajara');
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();

        expect(find.text('Guadalajara, Jalisco, Mexico'), findsOneWidget);
        await tester.tap(find.text('Guadalajara, Jalisco, Mexico'));
        await tester.pumpAndSettle();

        expect(clickedItem, isNotNull);
        expect(clickedItem!.placeId, 'pid_gdl');
        expect(returnedPrediction, isNotNull);
        expect(returnedPrediction!.placeId, 'pid_gdl');
        expect(returnedPrediction!.text?.text, 'Guadalajara, Jalisco, Mexico');
      }
    },
  );

  testWidgets(
    'PlacesAutocompleteField handles null <-> non-null controller transitions and disposes internal controller cleanly',
    (tester) async {
      final externalController = TextEditingController(text: 'Zapopan');
      addTearDown(externalController.dispose);

      // Start with null controller -> transitions to non-null controller (previously crashed with null dereference!)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteField(
              apiKey: 'test_key',
              hint: 'Search place',
            ),
          ),
        ),
      );
      expect(find.text('Search place'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteField(
              apiKey: 'test_key',
              controller: externalController,
              hint: 'Search place',
            ),
          ),
        ),
      );
      expect(find.text('Zapopan'), findsOneWidget);

      // Transition back from external controller to null controller (preserves text)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteField(
              apiKey: 'test_key',
              hint: 'Search place',
            ),
          ),
        ),
      );
      expect(find.text('Zapopan'), findsOneWidget);

      // Unmount widget + form field to verify dispose() completes without errors
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteFormField(
              apiKey: 'test_key',
              initialValue: 'Tlaquepaque',
            ),
          ),
        ),
      );
      expect(find.text('Tlaquepaque'), findsOneWidget);

      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      expect(tester.takeException(), isNull);
    },
  );
}
