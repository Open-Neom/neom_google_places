
import 'package:flutter/material.dart';

import '../utils/constants/neom_google_places_constants.dart';

class PoweredByGoogleImage extends StatelessWidget {

  const PoweredByGoogleImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Image.asset(
            Theme.of(context).brightness == Brightness.light
                ? NeomGooglePlacesConstants.poweredByGoogleWhite
                : NeomGooglePlacesConstants.poweredByGoogleBlack,
            scale: 2.5,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        )
      ],
    );
  }
}
