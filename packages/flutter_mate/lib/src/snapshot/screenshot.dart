import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/flutter_mate.dart';

/// Screenshot capture service for Flutter Mate.
///
/// Provides methods to capture screenshots of the entire app or specific elements.
class ScreenshotService {
  /// Capture a screenshot of the entire app.
  ///
  /// Returns PNG-encoded bytes of the screenshot.
  ///
  /// ```dart
  /// final bytes = await ScreenshotService.capture();
  /// // Save to file or send to agent
  /// ```
  static Future<Uint8List?> capture({double pixelRatio = 1.0}) async {
    FlutterMate.ensureInitialized();

    try {
      // Get the render view from the binding
      final renderViews = RendererBinding.instance.renderViews;
      if (renderViews.isEmpty) {
        debugPrint('FlutterMate: No render views available');
        return null;
      }

      final renderView = renderViews.first;
      final size = renderView.size;

      // Create an image from the render view
      final image = await _captureRenderObject(renderView, size, pixelRatio);
      if (image == null) return null;

      // Encode to PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e, stack) {
      debugPrint('FlutterMate: Screenshot capture failed: $e\n$stack');
      return null;
    }
  }

  /// Capture a screenshot of a specific element by ref.
  ///
  /// Takes a full screenshot and crops it to the element's bounds.
  /// This approach works for any element, regardless of layer type.
  ///
  /// Returns PNG-encoded bytes of the element's screenshot, or null if not found.
  ///
  /// ```dart
  /// final bytes = await ScreenshotService.captureElement('w15');
  /// ```
  static Future<Uint8List?> captureElement(String ref,
      {double pixelRatio = 1.0}) async {
    FlutterMate.ensureInitialized();

    try {
      // Find the element from cached elements
      final element = FlutterMate.cachedElements[ref];
      if (element == null) {
        debugPrint('FlutterMate: Element not found: $ref');
        return null;
      }

      // Find the render object (must be a RenderBox for bounds)
      RenderBox? renderBox;
      if (element is RenderObjectElement && element.renderObject is RenderBox) {
        renderBox = element.renderObject as RenderBox;
      } else {
        // Search for a RenderBox in descendants
        void findRenderBox(Element el) {
          if (renderBox != null) return;
          if (el is RenderObjectElement && el.renderObject is RenderBox) {
            renderBox = el.renderObject as RenderBox;
            return;
          }
          el.visitChildren(findRenderBox);
        }

        findRenderBox(element);
      }

      if (renderBox == null) {
        debugPrint('FlutterMate: No RenderBox for: $ref');
        return null;
      }

      // Get the global position and size of the element
      final globalOffset = renderBox!.localToGlobal(Offset.zero);
      final size = renderBox!.size;

      if (size.isEmpty) {
        debugPrint('FlutterMate: Element has zero size: $ref');
        return null;
      }

      // Capture full screenshot first
      final renderViews = RendererBinding.instance.renderViews;
      if (renderViews.isEmpty) {
        debugPrint('FlutterMate: No render views available');
        return null;
      }

      final renderView = renderViews.first;
      final fullImage =
          await _captureRenderObject(renderView, renderView.size, pixelRatio);
      if (fullImage == null) return null;

      // Calculate the effective pixel ratio from the actual image dimensions
      // This handles Retina displays where the image may be captured at device pixel ratio
      final logicalSize = renderView.size;
      final effectivePixelRatio = fullImage.width / logicalSize.width;

      // Calculate crop rect in pixel coordinates using the effective ratio
      final cropRect = ui.Rect.fromLTWH(
        globalOffset.dx * effectivePixelRatio,
        globalOffset.dy * effectivePixelRatio,
        size.width * effectivePixelRatio,
        size.height * effectivePixelRatio,
      );

      // Clamp to image bounds
      final clampedRect = ui.Rect.fromLTWH(
        cropRect.left.clamp(0, fullImage.width.toDouble()),
        cropRect.top.clamp(0, fullImage.height.toDouble()),
        cropRect.width.clamp(0, fullImage.width - cropRect.left),
        cropRect.height.clamp(0, fullImage.height - cropRect.top),
      );

      if (clampedRect.isEmpty) {
        debugPrint('FlutterMate: Element is outside visible area: $ref');
        fullImage.dispose();
        return null;
      }

      // Crop the image using a picture recorder
      final croppedImage = await _cropImage(fullImage, clampedRect);
      fullImage.dispose();

      if (croppedImage == null) return null;

      // Encode to PNG
      final byteData =
          await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      croppedImage.dispose();

      return byteData?.buffer.asUint8List();
    } catch (e, stack) {
      debugPrint('FlutterMate: Element screenshot failed: $e\n$stack');
      return null;
    }
  }

  /// Crop an image to the specified rectangle.
  static Future<ui.Image?> _cropImage(ui.Image source, ui.Rect cropRect) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw the cropped portion
      canvas.drawImageRect(
        source,
        cropRect,
        ui.Rect.fromLTWH(0, 0, cropRect.width, cropRect.height),
        Paint(),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        cropRect.width.round(),
        cropRect.height.round(),
      );
      picture.dispose();

      return image;
    } catch (e) {
      debugPrint('FlutterMate: Failed to crop image: $e');
      return null;
    }
  }

  /// Capture a render object to an image.
  static Future<ui.Image?> _captureRenderObject(
    RenderObject renderObject,
    ui.Size size,
    double pixelRatio,
  ) async {
    try {
      // Use OffsetLayer.toImage if available (for most render objects)
      final layer = renderObject.debugLayer;
      if (layer is OffsetLayer) {
        final image = await layer.toImage(
          renderObject.paintBounds,
          pixelRatio: pixelRatio,
        );
        return image;
      }

      debugPrint('FlutterMate: Unsupported layer type: ${layer.runtimeType}');
      return null;
    } catch (e) {
      debugPrint('FlutterMate: Failed to capture render object: $e');
      return null;
    }
  }

  /// Get screenshot as base64-encoded PNG string.
  ///
  /// Useful for transmitting over VM Service or JSON.
  static Future<String?> captureAsBase64({double pixelRatio = 1.0}) async {
    final bytes = await capture(pixelRatio: pixelRatio);
    if (bytes == null) return null;

    // Convert to base64
    return _bytesToBase64(bytes);
  }

  /// Get element screenshot as base64-encoded PNG string.
  static Future<String?> captureElementAsBase64(String ref,
      {double pixelRatio = 1.0}) async {
    final bytes = await captureElement(ref, pixelRatio: pixelRatio);
    if (bytes == null) return null;

    return _bytesToBase64(bytes);
  }

  static String _bytesToBase64(Uint8List bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    final len = bytes.length;
    var i = 0;

    while (i < len) {
      final b1 = bytes[i++];
      final b2 = i < len ? bytes[i++] : 0;
      final b3 = i < len ? bytes[i++] : 0;

      buffer.write(chars[(b1 >> 2) & 0x3F]);
      buffer.write(chars[((b1 & 0x03) << 4) | ((b2 >> 4) & 0x0F)]);
      buffer.write(
          i > len + 1 ? '=' : chars[((b2 & 0x0F) << 2) | ((b3 >> 6) & 0x03)]);
      buffer.write(i > len ? '=' : chars[b3 & 0x3F]);
    }

    return buffer.toString();
  }
}
