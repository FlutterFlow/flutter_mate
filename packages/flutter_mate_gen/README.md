# flutter_mate_gen

Generated single-file bundle of flutter_mate for web injection.

## What is this?

This package contains a pre-generated single-file version of `flutter_mate` and `flutter_mate_types` combined into one library. When compiled to JavaScript via DDC (Dart Development Compiler), it produces a single JS module with no cross-library dependencies.

## Why?

When injecting flutter_mate into a Flutter web app running in a different runtime context (like Hologram's iframe sandbox), the normal multi-file compilation produces interdependent JS modules that can't be easily loaded. This single-file bundle solves that by compiling everything into one self-contained module.

## Regenerating

To regenerate the bundle after making changes to flutter_mate or flutter_mate_types:

```bash
cd cli/flutter_mate_cli
dart run bin/bundle_generator.dart
```

This will update `lib/src/flutter_mate_bundle.dart` with the latest code.

## Usage

For web injection, compile this package's main.dart to JS:

```bash
cd packages/flutter_mate_gen
flutter run -d web-server --web-port=8085
# Then extract the JS from build_js/
```

The resulting JS can be injected into any Flutter web app to enable FlutterMate automation.
