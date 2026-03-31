# neom_google_places

[![Pub](https://img.shields.io/pub/v/neom_google_places.svg)](https://pub.dev/packages/neom_google_places)
[![Maintained by Open Neom](https://img.shields.io/badge/Maintained%20by-Open%20Neom-blue)](https://openneom.dev)

**The definitive, maintenance-free solution for Google Places in Flutter.**

`neom_google_places` provides high-performance autocomplete widgets for your location-based applications. It is built on top of the robust [neom_maps_services](https://pub.dev/packages/neom_maps_services) core, ensuring strict type safety and full compatibility with the latest Google APIs.

---

### Explore the Open Neom Ecosystem
This package is part of the **Open Neom** modular suite. We build professional-grade, open-source infrastructure for Flutter developers.

* **Discover more modules:** [www.openneom.dev](https://www.openneom.dev)
* **Core Logic:** [neom_maps_services](https://pub.dev/packages/neom_maps_services)
* **Super App Architecture:** [Srznik](https://www.openneom.dev)

*Join us in building the future of sovereign digital infrastructure.*

---

## What's new in v2.0.0?
* **Google Places API V2 Ready:** Fully refactored to comply with the latest Google Places Web Service changes.
* **Clean Architecture:** Removed legacy bloat. Optimized for 60fps performance.
* **Strict Typing:** New `Prediction` and `PlaceDetails` models to prevent runtime errors.

> **Note:** As per [StackOverflow](https://stackoverflow.com/a/52545293), you must enable billing on your Google Cloud account to use the Places API, even for free tier usage.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  neom_google_places: ^2.0.0
```
