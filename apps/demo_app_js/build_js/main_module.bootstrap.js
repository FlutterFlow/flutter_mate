/* ENTRYPOINT_EXTENTION_MARKER */

(function() {
  const appName = "org-dartlang-app:/web_entrypoint.dart";

  dartDevEmbedder.debugger.registerDevtoolsFormatter();

  
  // Set up a final script that lets us know when all scripts have been loaded.
  // Only then can we call the main method.
  const onLoadEndSrc = 'on_load_end_bootstrap.js';
  window.$dartLoader.loadConfig.bootstrapScript = {
    src: onLoadEndSrc,
    id: onLoadEndSrc,
  };
  window.$dartLoader.loadConfig.tryLoadBootstrapScript = true;
  // Should be called by on_load_end_bootstrap.js once all the scripts have been
  // loaded.
  window.$onLoadEndCallback = function() {
    const child = {};
    child.main = function() {
      const sdkOptions = {
        nativeNonNullAsserts: true,
      };
      dartDevEmbedder.runMain(appName, sdkOptions);
    }  // Injected by dwds for debugging support.
  if(!window.$dwdsInitialized) {
    window.$dwdsInitialized = true;
    window.$dartMainTearOffs = [child.main];
    window.$dartRunMain = function() {
      window.$dartMainExecuted = true;
      window.$dartMainTearOffs.forEach(function(main){
         main();
      });
    }
    window.$dartAppId = "riKHvRHDJwgmYP1rqArjsg==";
window.$dartReloadConfiguration = "ReloadConfiguration.none";
window.$dartModuleStrategy = "ddc-library-bundle";
window.$loadModuleConfig = function() { throw new Error('LoadStrategy.loadModuleSnippet is used. This is currently unsupported in the DDC library bundle format.'); };
window.$dwdsVersion = "25.1.0+2";
window.$dwdsDevHandlerPath = "ws://localhost:8085/$dwdsSseHandler";
window.$dwdsEnableDevToolsLaunch = true;
window.$dartEntrypointPath = "main_module.bootstrap.js";
window.$dartEmitDebugEvents = true;
window.$isInternalBuild = false;
window.$isFlutterApp = true;
window.$reloadedSourcesPath = "http://localhost:8085/reloaded_sources.json";
window.$dartLoader.forceLoadModule("dwds/src/injected/client");
window.$dartExtensionUri = "ws://[::]:63783/$debug";

  } else {
    if(window.$dartMainExecuted){
     child.main();
    }else {
     window.$dartMainTearOffs.push(child.main);
    }
  }
    }
})();
var baseUrl = (function () {
  // Attempt to detect --precompiled mode for tests, and set the base url
  // appropriately, otherwise set it to '/'.
  var pathParts = location.pathname.split("/");
  if (pathParts[0] == "") {
    pathParts.shift();
  }
  if (pathParts.length > 1 && pathParts[1] == "test") {
    return "/" + pathParts.slice(0, 2).join("/") + "/";
  }
  // Attempt to detect base url using <base href> html tag
  // base href should start and end with "/"
  if (typeof document !== 'undefined') {
    var el = document.getElementsByTagName('base');
    if (el && el[0] && el[0].getAttribute("href") && el[0].getAttribute
    ("href").startsWith("/") && el[0].getAttribute("href").endsWith("/")){
      return el[0].getAttribute("href");
    }
  }
  // return default value
  return "/";
}());

var scripts = [
 {
  "src": "web_entrypoint.dart.lib.js",
  "id": "web_entrypoint.dart"
 },
 {
  "src": "web_plugin_registrant.dart.lib.js",
  "id": "web_plugin_registrant.dart"
 },
 {
  "src": "packages/demo_app/main.dart.lib.js",
  "id": "packages/demo_app/main.dart"
 },
 {
  "src": "packages/flutter_mate/flutter_mate.dart.lib.js",
  "id": "packages/flutter_mate/flutter_mate.dart"
 },
 {
  "src": "packages/flutter/src/cupertino/text_form_field_row.dart.lib.js",
  "id": "packages/flutter/src/cupertino/text_form_field_row.dart"
 },
 {
  "src": "packages/flutter/painting.dart.lib.js",
  "id": "packages/flutter/painting.dart"
 },
 {
  "src": "packages/flutter/src/painting/placeholder_span.dart.lib.js",
  "id": "packages/flutter/src/painting/placeholder_span.dart"
 },
 {
  "src": "packages/flutter/src/painting/text_scaler.dart.lib.js",
  "id": "packages/flutter/src/painting/text_scaler.dart"
 },
 {
  "src": "packages/flutter/foundation.dart.lib.js",
  "id": "packages/flutter/foundation.dart"
 },
 {
  "src": "packages/flutter/src/foundation/unicode.dart.lib.js",
  "id": "packages/flutter/src/foundation/unicode.dart"
 },
 {
  "src": "packages/flutter/src/foundation/timeline.dart.lib.js",
  "id": "packages/flutter/src/foundation/timeline.dart"
 },
 {
  "src": "packages/flutter/src/foundation/constants.dart.lib.js",
  "id": "packages/flutter/src/foundation/constants.dart"
 },
 {
  "src": "packages/flutter/src/foundation/_timeline_web.dart.lib.js",
  "id": "packages/flutter/src/foundation/_timeline_web.dart"
 },
 {
  "src": "packages/meta/meta.dart.lib.js",
  "id": "packages/meta/meta.dart"
 },
 {
  "src": "packages/meta/meta_meta.dart.lib.js",
  "id": "packages/meta/meta_meta.dart"
 },
 {
  "src": "packages/flutter/src/foundation/synchronous_future.dart.lib.js",
  "id": "packages/flutter/src/foundation/synchronous_future.dart"
 },
 {
  "src": "packages/flutter/src/foundation/stack_frame.dart.lib.js",
  "id": "packages/flutter/src/foundation/stack_frame.dart"
 },
 {
  "src": "packages/flutter/src/foundation/object.dart.lib.js",
  "id": "packages/flutter/src/foundation/object.dart"
 },
 {
  "src": "packages/flutter/src/foundation/service_extensions.dart.lib.js",
  "id": "packages/flutter/src/foundation/service_extensions.dart"
 },
 {
  "src": "packages/flutter/src/foundation/serialization.dart.lib.js",
  "id": "packages/flutter/src/foundation/serialization.dart"
 },
 {
  "src": "packages/flutter/src/foundation/print.dart.lib.js",
  "id": "packages/flutter/src/foundation/print.dart"
 },
 {
  "src": "packages/flutter/src/foundation/_platform_web.dart.lib.js",
  "id": "packages/flutter/src/foundation/_platform_web.dart"
 },
 {
  "src": "packages/flutter/src/foundation/basic_types.dart.lib.js",
  "id": "packages/flutter/src/foundation/basic_types.dart"
 },
 {
  "src": "packages/flutter/src/foundation/persistent_hash_map.dart.lib.js",
  "id": "packages/flutter/src/foundation/persistent_hash_map.dart"
 },
 {
  "src": "packages/flutter/src/foundation/observer_list.dart.lib.js",
  "id": "packages/flutter/src/foundation/observer_list.dart"
 },
 {
  "src": "packages/flutter/src/foundation/node.dart.lib.js",
  "id": "packages/flutter/src/foundation/node.dart"
 },
 {
  "src": "packages/flutter/src/foundation/licenses.dart.lib.js",
  "id": "packages/flutter/src/foundation/licenses.dart"
 },
 {
  "src": "packages/flutter/src/foundation/key.dart.lib.js",
  "id": "packages/flutter/src/foundation/key.dart"
 },
 {
  "src": "packages/flutter/src/foundation/_isolates_web.dart.lib.js",
  "id": "packages/flutter/src/foundation/_isolates_web.dart"
 },
 {
  "src": "packages/flutter/src/foundation/consolidate_response.dart.lib.js",
  "id": "packages/flutter/src/foundation/consolidate_response.dart"
 },
 {
  "src": "packages/flutter/src/foundation/collections.dart.lib.js",
  "id": "packages/flutter/src/foundation/collections.dart"
 },
 {
  "src": "packages/flutter/src/foundation/change_notifier.dart.lib.js",
  "id": "packages/flutter/src/foundation/change_notifier.dart"
 },
 {
  "src": "packages/flutter/src/foundation/capabilities.dart.lib.js",
  "id": "packages/flutter/src/foundation/capabilities.dart"
 },
 {
  "src": "packages/flutter/src/foundation/_capabilities_web.dart.lib.js",
  "id": "packages/flutter/src/foundation/_capabilities_web.dart"
 },
 {
  "src": "packages/flutter/src/foundation/_bitfield_web.dart.lib.js",
  "id": "packages/flutter/src/foundation/_bitfield_web.dart"
 },
 {
  "src": "packages/flutter/src/foundation/binding.dart.lib.js",
  "id": "packages/flutter/src/foundation/binding.dart"
 },
 {
  "src": "packages/flutter/src/foundation/annotations.dart.lib.js",
  "id": "packages/flutter/src/foundation/annotations.dart"
 },
 {
  "src": "packages/flutter/src/services/undo_manager.dart.lib.js",
  "id": "packages/flutter/src/services/undo_manager.dart"
 },
 {
  "src": "packages/flutter/src/services/text_layout_metrics.dart.lib.js",
  "id": "packages/flutter/src/services/text_layout_metrics.dart"
 },
 {
  "src": "packages/flutter/src/services/text_editing.dart.lib.js",
  "id": "packages/flutter/src/services/text_editing.dart"
 },
 {
  "src": "packages/flutter/src/services/text_editing_delta.dart.lib.js",
  "id": "packages/flutter/src/services/text_editing_delta.dart"
 },
 {
  "src": "packages/vector_math/vector_math_64.dart.lib.js",
  "id": "packages/vector_math/vector_math_64.dart"
 },
 {
  "src": "packages/flutter/scheduler.dart.lib.js",
  "id": "packages/flutter/scheduler.dart"
 },
 {
  "src": "packages/flutter/src/scheduler/ticker.dart.lib.js",
  "id": "packages/flutter/src/scheduler/ticker.dart"
 },
 {
  "src": "packages/flutter/src/scheduler/binding.dart.lib.js",
  "id": "packages/flutter/src/scheduler/binding.dart"
 },
 {
  "src": "packages/flutter/src/scheduler/priority.dart.lib.js",
  "id": "packages/flutter/src/scheduler/priority.dart"
 },
 {
  "src": "packages/flutter/src/scheduler/service_extensions.dart.lib.js",
  "id": "packages/flutter/src/scheduler/service_extensions.dart"
 },
 {
  "src": "packages/flutter/src/scheduler/debug.dart.lib.js",
  "id": "packages/flutter/src/scheduler/debug.dart"
 },
 {
  "src": "packages/collection/collection.dart.lib.js",
  "id": "packages/collection/collection.dart"
 },
 {
  "src": "packages/collection/src/wrappers.dart.lib.js",
  "id": "packages/collection/src/wrappers.dart"
 },
 {
  "src": "packages/collection/src/union_set_controller.dart.lib.js",
  "id": "packages/collection/src/union_set_controller.dart"
 },
 {
  "src": "packages/collection/src/union_set.dart.lib.js",
  "id": "packages/collection/src/union_set.dart"
 },
 {
  "src": "packages/collection/src/queue_list.dart.lib.js",
  "id": "packages/collection/src/queue_list.dart"
 },
 {
  "src": "packages/collection/src/priority_queue.dart.lib.js",
  "id": "packages/collection/src/priority_queue.dart"
 },
 {
  "src": "packages/collection/src/utils.dart.lib.js",
  "id": "packages/collection/src/utils.dart"
 },
 {
  "src": "packages/collection/src/list_extensions.dart.lib.js",
  "id": "packages/collection/src/list_extensions.dart"
 },
 {
  "src": "packages/collection/src/equality.dart.lib.js",
  "id": "packages/collection/src/equality.dart"
 },
 {
  "src": "packages/collection/src/comparators.dart.lib.js",
  "id": "packages/collection/src/comparators.dart"
 },
 {
  "src": "packages/collection/src/algorithms.dart.lib.js",
  "id": "packages/collection/src/algorithms.dart"
 },
 {
  "src": "packages/collection/src/iterable_zip.dart.lib.js",
  "id": "packages/collection/src/iterable_zip.dart"
 },
 {
  "src": "packages/collection/src/iterable_extensions.dart.lib.js",
  "id": "packages/collection/src/iterable_extensions.dart"
 },
 {
  "src": "packages/collection/src/functions.dart.lib.js",
  "id": "packages/collection/src/functions.dart"
 },
 {
  "src": "packages/collection/src/equality_set.dart.lib.js",
  "id": "packages/collection/src/equality_set.dart"
 },
 {
  "src": "packages/collection/src/equality_map.dart.lib.js",
  "id": "packages/collection/src/equality_map.dart"
 },
 {
  "src": "packages/collection/src/combined_wrappers/combined_map.dart.lib.js",
  "id": "packages/collection/src/combined_wrappers/combined_map.dart"
 },
 {
  "src": "packages/collection/src/combined_wrappers/combined_iterable.dart.lib.js",
  "id": "packages/collection/src/combined_wrappers/combined_iterable.dart"
 },
 {
  "src": "packages/collection/src/combined_wrappers/combined_iterator.dart.lib.js",
  "id": "packages/collection/src/combined_wrappers/combined_iterator.dart"
 },
 {
  "src": "packages/collection/src/combined_wrappers/combined_list.dart.lib.js",
  "id": "packages/collection/src/combined_wrappers/combined_list.dart"
 },
 {
  "src": "packages/collection/src/canonicalized_map.dart.lib.js",
  "id": "packages/collection/src/canonicalized_map.dart"
 },
 {
  "src": "packages/collection/src/boollist.dart.lib.js",
  "id": "packages/collection/src/boollist.dart"
 },
 {
  "src": "packages/flutter/src/services/keyboard_key.g.dart.lib.js",
  "id": "packages/flutter/src/services/keyboard_key.g.dart"
 },
 {
  "src": "packages/flutter/src/services/keyboard_maps.g.dart.lib.js",
  "id": "packages/flutter/src/services/keyboard_maps.g.dart"
 },
 {
  "src": "packages/flutter/src/services/binary_messenger.dart.lib.js",
  "id": "packages/flutter/src/services/binary_messenger.dart"
 },
 {
  "src": "packages/flutter/src/services/service_extensions.dart.lib.js",
  "id": "packages/flutter/src/services/service_extensions.dart"
 },
 {
  "src": "packages/flutter/src/services/keyboard_inserted_content.dart.lib.js",
  "id": "packages/flutter/src/services/keyboard_inserted_content.dart"
 },
 {
  "src": "packages/flutter/src/services/text_formatter.dart.lib.js",
  "id": "packages/flutter/src/services/text_formatter.dart"
 },
 {
  "src": "packages/characters/characters.dart.lib.js",
  "id": "packages/characters/characters.dart"
 },
 {
  "src": "packages/characters/src/extensions.dart.lib.js",
  "id": "packages/characters/src/extensions.dart"
 },
 {
  "src": "packages/characters/src/characters_impl.dart.lib.js",
  "id": "packages/characters/src/characters_impl.dart"
 },
 {
  "src": "packages/characters/src/grapheme_clusters/table.dart.lib.js",
  "id": "packages/characters/src/grapheme_clusters/table.dart"
 },
 {
  "src": "packages/characters/src/grapheme_clusters/constants.dart.lib.js",
  "id": "packages/characters/src/grapheme_clusters/constants.dart"
 },
 {
  "src": "packages/characters/src/grapheme_clusters/breaks.dart.lib.js",
  "id": "packages/characters/src/grapheme_clusters/breaks.dart"
 },
 {
  "src": "packages/flutter/src/services/text_boundary.dart.lib.js",
  "id": "packages/flutter/src/services/text_boundary.dart"
 },
 {
  "src": "packages/flutter/src/services/system_sound.dart.lib.js",
  "id": "packages/flutter/src/services/system_sound.dart"
 },
 {
  "src": "packages/flutter/src/services/system_navigator.dart.lib.js",
  "id": "packages/flutter/src/services/system_navigator.dart"
 },
 {
  "src": "packages/flutter/src/services/spell_check.dart.lib.js",
  "id": "packages/flutter/src/services/spell_check.dart"
 },
 {
  "src": "packages/flutter/src/services/sensitive_content.dart.lib.js",
  "id": "packages/flutter/src/services/sensitive_content.dart"
 },
 {
  "src": "packages/flutter/src/services/scribe.dart.lib.js",
  "id": "packages/flutter/src/services/scribe.dart"
 },
 {
  "src": "packages/flutter/src/services/process_text.dart.lib.js",
  "id": "packages/flutter/src/services/process_text.dart"
 },
 {
  "src": "packages/flutter/src/services/predictive_back_event.dart.lib.js",
  "id": "packages/flutter/src/services/predictive_back_event.dart"
 },
 {
  "src": "packages/flutter/src/services/platform_views.dart.lib.js",
  "id": "packages/flutter/src/services/platform_views.dart"
 },
 {
  "src": "packages/flutter/gestures.dart.lib.js",
  "id": "packages/flutter/gestures.dart"
 },
 {
  "src": "packages/flutter/src/gestures/velocity_tracker.dart.lib.js",
  "id": "packages/flutter/src/gestures/velocity_tracker.dart"
 },
 {
  "src": "packages/flutter/src/gestures/lsq_solver.dart.lib.js",
  "id": "packages/flutter/src/gestures/lsq_solver.dart"
 },
 {
  "src": "packages/flutter/src/gestures/events.dart.lib.js",
  "id": "packages/flutter/src/gestures/events.dart"
 },
 {
  "src": "packages/flutter/src/gestures/gesture_settings.dart.lib.js",
  "id": "packages/flutter/src/gestures/gesture_settings.dart"
 },
 {
  "src": "packages/flutter/src/gestures/constants.dart.lib.js",
  "id": "packages/flutter/src/gestures/constants.dart"
 },
 {
  "src": "packages/flutter/src/gestures/binding.dart.lib.js",
  "id": "packages/flutter/src/gestures/binding.dart"
 },
 {
  "src": "packages/flutter/src/gestures/pointer_signal_resolver.dart.lib.js",
  "id": "packages/flutter/src/gestures/pointer_signal_resolver.dart"
 },
 {
  "src": "packages/flutter/src/gestures/pointer_router.dart.lib.js",
  "id": "packages/flutter/src/gestures/pointer_router.dart"
 },
 {
  "src": "packages/flutter/src/gestures/hit_test.dart.lib.js",
  "id": "packages/flutter/src/gestures/hit_test.dart"
 },
 {
  "src": "packages/flutter/src/gestures/arena.dart.lib.js",
  "id": "packages/flutter/src/gestures/arena.dart"
 },
 {
  "src": "packages/flutter/src/gestures/debug.dart.lib.js",
  "id": "packages/flutter/src/gestures/debug.dart"
 },
 {
  "src": "packages/flutter/src/gestures/resampler.dart.lib.js",
  "id": "packages/flutter/src/gestures/resampler.dart"
 },
 {
  "src": "packages/flutter/src/gestures/converter.dart.lib.js",
  "id": "packages/flutter/src/gestures/converter.dart"
 },
 {
  "src": "packages/flutter/src/gestures/team.dart.lib.js",
  "id": "packages/flutter/src/gestures/team.dart"
 },
 {
  "src": "packages/flutter/src/gestures/tap_and_drag.dart.lib.js",
  "id": "packages/flutter/src/gestures/tap_and_drag.dart"
 },
 {
  "src": "packages/flutter/src/gestures/tap.dart.lib.js",
  "id": "packages/flutter/src/gestures/tap.dart"
 },
 {
  "src": "packages/flutter/src/gestures/recognizer.dart.lib.js",
  "id": "packages/flutter/src/gestures/recognizer.dart"
 },
 {
  "src": "packages/flutter/src/gestures/gesture_details.dart.lib.js",
  "id": "packages/flutter/src/gestures/gesture_details.dart"
 },
 {
  "src": "packages/flutter/src/gestures/scale.dart.lib.js",
  "id": "packages/flutter/src/gestures/scale.dart"
 },
 {
  "src": "packages/flutter/src/gestures/monodrag.dart.lib.js",
  "id": "packages/flutter/src/gestures/monodrag.dart"
 },
 {
  "src": "packages/flutter/src/gestures/drag_details.dart.lib.js",
  "id": "packages/flutter/src/gestures/drag_details.dart"
 },
 {
  "src": "packages/flutter/src/gestures/drag.dart.lib.js",
  "id": "packages/flutter/src/gestures/drag.dart"
 },
 {
  "src": "packages/flutter/src/gestures/multitap.dart.lib.js",
  "id": "packages/flutter/src/gestures/multitap.dart"
 },
 {
  "src": "packages/flutter/src/gestures/multidrag.dart.lib.js",
  "id": "packages/flutter/src/gestures/multidrag.dart"
 },
 {
  "src": "packages/flutter/src/gestures/long_press.dart.lib.js",
  "id": "packages/flutter/src/gestures/long_press.dart"
 },
 {
  "src": "packages/flutter/src/gestures/force_press.dart.lib.js",
  "id": "packages/flutter/src/gestures/force_press.dart"
 },
 {
  "src": "packages/flutter/src/gestures/eager.dart.lib.js",
  "id": "packages/flutter/src/gestures/eager.dart"
 },
 {
  "src": "packages/flutter/src/services/mouse_tracking.dart.lib.js",
  "id": "packages/flutter/src/services/mouse_tracking.dart"
 },
 {
  "src": "packages/flutter/src/services/mouse_cursor.dart.lib.js",
  "id": "packages/flutter/src/services/mouse_cursor.dart"
 },
 {
  "src": "packages/flutter/src/services/live_text.dart.lib.js",
  "id": "packages/flutter/src/services/live_text.dart"
 },
 {
  "src": "packages/flutter/src/services/haptic_feedback.dart.lib.js",
  "id": "packages/flutter/src/services/haptic_feedback.dart"
 },
 {
  "src": "packages/flutter/src/services/font_loader.dart.lib.js",
  "id": "packages/flutter/src/services/font_loader.dart"
 },
 {
  "src": "packages/flutter/src/services/flutter_version.dart.lib.js",
  "id": "packages/flutter/src/services/flutter_version.dart"
 },
 {
  "src": "packages/flutter/src/services/flavor.dart.lib.js",
  "id": "packages/flutter/src/services/flavor.dart"
 },
 {
  "src": "packages/flutter/src/services/deferred_component.dart.lib.js",
  "id": "packages/flutter/src/services/deferred_component.dart"
 },
 {
  "src": "packages/flutter/src/services/browser_context_menu.dart.lib.js",
  "id": "packages/flutter/src/services/browser_context_menu.dart"
 },
 {
  "src": "packages/flutter/src/services/asset_manifest.dart.lib.js",
  "id": "packages/flutter/src/services/asset_manifest.dart"
 },
 {
  "src": "packages/flutter/src/painting/basic_types.dart.lib.js",
  "id": "packages/flutter/src/painting/basic_types.dart"
 },
 {
  "src": "packages/flutter/src/painting/colors.dart.lib.js",
  "id": "packages/flutter/src/painting/colors.dart"
 },
 {
  "src": "packages/flutter/src/painting/star_border.dart.lib.js",
  "id": "packages/flutter/src/painting/star_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/stadium_border.dart.lib.js",
  "id": "packages/flutter/src/painting/stadium_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/rounded_rectangle_border.dart.lib.js",
  "id": "packages/flutter/src/painting/rounded_rectangle_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/circle_border.dart.lib.js",
  "id": "packages/flutter/src/painting/circle_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/borders.dart.lib.js",
  "id": "packages/flutter/src/painting/borders.dart"
 },
 {
  "src": "packages/flutter/src/painting/edge_insets.dart.lib.js",
  "id": "packages/flutter/src/painting/edge_insets.dart"
 },
 {
  "src": "packages/flutter/src/painting/debug.dart.lib.js",
  "id": "packages/flutter/src/painting/debug.dart"
 },
 {
  "src": "packages/flutter/src/painting/border_radius.dart.lib.js",
  "id": "packages/flutter/src/painting/border_radius.dart"
 },
 {
  "src": "packages/flutter/src/painting/shape_decoration.dart.lib.js",
  "id": "packages/flutter/src/painting/shape_decoration.dart"
 },
 {
  "src": "packages/flutter/src/painting/_network_image_web.dart.lib.js",
  "id": "packages/flutter/src/painting/_network_image_web.dart"
 },
 {
  "src": "packages/flutter/src/painting/image_stream.dart.lib.js",
  "id": "packages/flutter/src/painting/image_stream.dart"
 },
 {
  "src": "packages/flutter/src/painting/image_cache.dart.lib.js",
  "id": "packages/flutter/src/painting/image_cache.dart"
 },
 {
  "src": "packages/flutter/src/painting/binding.dart.lib.js",
  "id": "packages/flutter/src/painting/binding.dart"
 },
 {
  "src": "packages/flutter/src/painting/shader_warm_up.dart.lib.js",
  "id": "packages/flutter/src/painting/shader_warm_up.dart"
 },
 {
  "src": "packages/flutter/src/painting/_web_image_info_web.dart.lib.js",
  "id": "packages/flutter/src/painting/_web_image_info_web.dart"
 },
 {
  "src": "packages/flutter/src/web.dart.lib.js",
  "id": "packages/flutter/src/web.dart"
 },
 {
  "src": "packages/flutter/src/painting/gradient.dart.lib.js",
  "id": "packages/flutter/src/painting/gradient.dart"
 },
 {
  "src": "packages/flutter/src/painting/alignment.dart.lib.js",
  "id": "packages/flutter/src/painting/alignment.dart"
 },
 {
  "src": "packages/flutter/src/painting/decoration_image.dart.lib.js",
  "id": "packages/flutter/src/painting/decoration_image.dart"
 },
 {
  "src": "packages/flutter/src/painting/box_fit.dart.lib.js",
  "id": "packages/flutter/src/painting/box_fit.dart"
 },
 {
  "src": "packages/flutter/src/painting/decoration.dart.lib.js",
  "id": "packages/flutter/src/painting/decoration.dart"
 },
 {
  "src": "packages/flutter/src/painting/box_shadow.dart.lib.js",
  "id": "packages/flutter/src/painting/box_shadow.dart"
 },
 {
  "src": "packages/flutter/src/painting/box_decoration.dart.lib.js",
  "id": "packages/flutter/src/painting/box_decoration.dart"
 },
 {
  "src": "packages/flutter/src/painting/box_border.dart.lib.js",
  "id": "packages/flutter/src/painting/box_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/paint_utilities.dart.lib.js",
  "id": "packages/flutter/src/painting/paint_utilities.dart"
 },
 {
  "src": "packages/flutter/src/painting/oval_border.dart.lib.js",
  "id": "packages/flutter/src/painting/oval_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/notched_shapes.dart.lib.js",
  "id": "packages/flutter/src/painting/notched_shapes.dart"
 },
 {
  "src": "packages/flutter/src/painting/matrix_utils.dart.lib.js",
  "id": "packages/flutter/src/painting/matrix_utils.dart"
 },
 {
  "src": "packages/flutter/src/painting/linear_border.dart.lib.js",
  "id": "packages/flutter/src/painting/linear_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/image_resolution.dart.lib.js",
  "id": "packages/flutter/src/painting/image_resolution.dart"
 },
 {
  "src": "packages/flutter/src/painting/image_decoder.dart.lib.js",
  "id": "packages/flutter/src/painting/image_decoder.dart"
 },
 {
  "src": "packages/flutter/src/painting/geometry.dart.lib.js",
  "id": "packages/flutter/src/painting/geometry.dart"
 },
 {
  "src": "packages/flutter/src/painting/fractional_offset.dart.lib.js",
  "id": "packages/flutter/src/painting/fractional_offset.dart"
 },
 {
  "src": "packages/flutter/src/painting/flutter_logo.dart.lib.js",
  "id": "packages/flutter/src/painting/flutter_logo.dart"
 },
 {
  "src": "packages/flutter/src/painting/continuous_rectangle_border.dart.lib.js",
  "id": "packages/flutter/src/painting/continuous_rectangle_border.dart"
 },
 {
  "src": "packages/flutter/src/painting/clip.dart.lib.js",
  "id": "packages/flutter/src/painting/clip.dart"
 },
 {
  "src": "packages/flutter/src/painting/beveled_rectangle_border.dart.lib.js",
  "id": "packages/flutter/src/painting/beveled_rectangle_border.dart"
 },
 {
  "src": "packages/flutter/src/rendering/service_extensions.dart.lib.js",
  "id": "packages/flutter/src/rendering/service_extensions.dart"
 },
 {
  "src": "packages/flutter/semantics.dart.lib.js",
  "id": "packages/flutter/semantics.dart"
 },
 {
  "src": "packages/flutter/src/semantics/semantics_service.dart.lib.js",
  "id": "packages/flutter/src/semantics/semantics_service.dart"
 },
 {
  "src": "packages/flutter/src/semantics/semantics_event.dart.lib.js",
  "id": "packages/flutter/src/semantics/semantics_event.dart"
 },
 {
  "src": "packages/flutter/src/semantics/semantics.dart.lib.js",
  "id": "packages/flutter/src/semantics/semantics.dart"
 },
 {
  "src": "packages/flutter/src/semantics/binding.dart.lib.js",
  "id": "packages/flutter/src/semantics/binding.dart"
 },
 {
  "src": "packages/flutter/src/semantics/debug.dart.lib.js",
  "id": "packages/flutter/src/semantics/debug.dart"
 },
 {
  "src": "packages/flutter/physics.dart.lib.js",
  "id": "packages/flutter/physics.dart"
 },
 {
  "src": "packages/flutter/src/physics/utils.dart.lib.js",
  "id": "packages/flutter/src/physics/utils.dart"
 },
 {
  "src": "packages/flutter/src/physics/tolerance.dart.lib.js",
  "id": "packages/flutter/src/physics/tolerance.dart"
 },
 {
  "src": "packages/flutter/src/physics/spring_simulation.dart.lib.js",
  "id": "packages/flutter/src/physics/spring_simulation.dart"
 },
 {
  "src": "packages/flutter/src/physics/simulation.dart.lib.js",
  "id": "packages/flutter/src/physics/simulation.dart"
 },
 {
  "src": "packages/flutter/src/physics/gravity_simulation.dart.lib.js",
  "id": "packages/flutter/src/physics/gravity_simulation.dart"
 },
 {
  "src": "packages/flutter/src/physics/friction_simulation.dart.lib.js",
  "id": "packages/flutter/src/physics/friction_simulation.dart"
 },
 {
  "src": "packages/flutter/src/physics/clamped_simulation.dart.lib.js",
  "id": "packages/flutter/src/physics/clamped_simulation.dart"
 },
 {
  "src": "packages/flutter/src/widgets/scroll_simulation.dart.lib.js",
  "id": "packages/flutter/src/widgets/scroll_simulation.dart"
 },
 {
  "src": "packages/flutter/src/widgets/service_extensions.dart.lib.js",
  "id": "packages/flutter/src/widgets/service_extensions.dart"
 },
 {
  "src": "packages/flutter/src/foundation/_features.dart.lib.js",
  "id": "packages/flutter/src/foundation/_features.dart"
 },
 {
  "src": "packages/flutter/src/widgets/constants.dart.lib.js",
  "id": "packages/flutter/src/widgets/constants.dart"
 },
 {
  "src": "packages/flutter/src/widgets/_web_browser_detection_web.dart.lib.js",
  "id": "packages/flutter/src/widgets/_web_browser_detection_web.dart"
 },
 {
  "src": "packages/flutter/src/widgets/icon_data.dart.lib.js",
  "id": "packages/flutter/src/widgets/icon_data.dart"
 },
 {
  "src": "packages/flutter/src/rendering/table_border.dart.lib.js",
  "id": "packages/flutter/src/rendering/table_border.dart"
 },
 {
  "src": "packages/flutter/src/widgets/standard_component_type.dart.lib.js",
  "id": "packages/flutter/src/widgets/standard_component_type.dart"
 },
 {
  "src": "packages/flutter/src/widgets/date.dart.lib.js",
  "id": "packages/flutter/src/widgets/date.dart"
 },
 {
  "src": "packages/flutter/material.dart.lib.js",
  "id": "packages/flutter/material.dart"
 },
 {
  "src": "packages/flutter/src/material/user_accounts_drawer_header.dart.lib.js",
  "id": "packages/flutter/src/material/user_accounts_drawer_header.dart"
 },
 {
  "src": "packages/flutter/src/material/time.dart.lib.js",
  "id": "packages/flutter/src/material/time.dart"
 },
 {
  "src": "packages/flutter/src/material/colors.dart.lib.js",
  "id": "packages/flutter/src/material/colors.dart"
 },
 {
  "src": "packages/material_color_utilities/material_color_utilities.dart.lib.js",
  "id": "packages/material_color_utilities/material_color_utilities.dart"
 },
 {
  "src": "packages/material_color_utilities/utils/string_utils.dart.lib.js",
  "id": "packages/material_color_utilities/utils/string_utils.dart"
 },
 {
  "src": "packages/material_color_utilities/utils/color_utils.dart.lib.js",
  "id": "packages/material_color_utilities/utils/color_utils.dart"
 },
 {
  "src": "packages/material_color_utilities/utils/math_utils.dart.lib.js",
  "id": "packages/material_color_utilities/utils/math_utils.dart"
 },
 {
  "src": "packages/material_color_utilities/temperature/temperature_cache.dart.lib.js",
  "id": "packages/material_color_utilities/temperature/temperature_cache.dart"
 },
 {
  "src": "packages/material_color_utilities/hct/hct.dart.lib.js",
  "id": "packages/material_color_utilities/hct/hct.dart"
 },
 {
  "src": "packages/material_color_utilities/hct/viewing_conditions.dart.lib.js",
  "id": "packages/material_color_utilities/hct/viewing_conditions.dart"
 },
 {
  "src": "packages/material_color_utilities/hct/src/hct_solver.dart.lib.js",
  "id": "packages/material_color_utilities/hct/src/hct_solver.dart"
 },
 {
  "src": "packages/material_color_utilities/hct/cam16.dart.lib.js",
  "id": "packages/material_color_utilities/hct/cam16.dart"
 },
 {
  "src": "packages/material_color_utilities/score/score.dart.lib.js",
  "id": "packages/material_color_utilities/score/score.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_vibrant.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_vibrant.dart"
 },
 {
  "src": "packages/material_color_utilities/palettes/tonal_palette.dart.lib.js",
  "id": "packages/material_color_utilities/palettes/tonal_palette.dart"
 },
 {
  "src": "packages/material_color_utilities/dynamiccolor/variant.dart.lib.js",
  "id": "packages/material_color_utilities/dynamiccolor/variant.dart"
 },
 {
  "src": "packages/material_color_utilities/dynamiccolor/src/tone_delta_pair.dart.lib.js",
  "id": "packages/material_color_utilities/dynamiccolor/src/tone_delta_pair.dart"
 },
 {
  "src": "packages/material_color_utilities/dynamiccolor/src/contrast_curve.dart.lib.js",
  "id": "packages/material_color_utilities/dynamiccolor/src/contrast_curve.dart"
 },
 {
  "src": "packages/material_color_utilities/contrast/contrast.dart.lib.js",
  "id": "packages/material_color_utilities/contrast/contrast.dart"
 },
 {
  "src": "packages/material_color_utilities/dislike/dislike_analyzer.dart.lib.js",
  "id": "packages/material_color_utilities/dislike/dislike_analyzer.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_tonal_spot.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_tonal_spot.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_rainbow.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_rainbow.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_neutral.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_neutral.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_monochrome.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_monochrome.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_fruit_salad.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_fruit_salad.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_fidelity.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_fidelity.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_expressive.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_expressive.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme_content.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme_content.dart"
 },
 {
  "src": "packages/material_color_utilities/scheme/scheme.dart.lib.js",
  "id": "packages/material_color_utilities/scheme/scheme.dart"
 },
 {
  "src": "packages/material_color_utilities/palettes/core_palette.dart.lib.js",
  "id": "packages/material_color_utilities/palettes/core_palette.dart"
 },
 {
  "src": "packages/material_color_utilities/quantize/quantizer_wu.dart.lib.js",
  "id": "packages/material_color_utilities/quantize/quantizer_wu.dart"
 },
 {
  "src": "packages/material_color_utilities/quantize/quantizer_map.dart.lib.js",
  "id": "packages/material_color_utilities/quantize/quantizer_map.dart"
 },
 {
  "src": "packages/material_color_utilities/quantize/quantizer.dart.lib.js",
  "id": "packages/material_color_utilities/quantize/quantizer.dart"
 },
 {
  "src": "packages/material_color_utilities/quantize/quantizer_wsmeans.dart.lib.js",
  "id": "packages/material_color_utilities/quantize/quantizer_wsmeans.dart"
 },
 {
  "src": "packages/material_color_utilities/quantize/src/point_provider_lab.dart.lib.js",
  "id": "packages/material_color_utilities/quantize/src/point_provider_lab.dart"
 },
 {
  "src": "packages/material_color_utilities/quantize/src/point_provider.dart.lib.js",
  "id": "packages/material_color_utilities/quantize/src/point_provider.dart"
 },
 {
  "src": "packages/material_color_utilities/quantize/quantizer_celebi.dart.lib.js",
  "id": "packages/material_color_utilities/quantize/quantizer_celebi.dart"
 },
 {
  "src": "packages/material_color_utilities/blend/blend.dart.lib.js",
  "id": "packages/material_color_utilities/blend/blend.dart"
 },
 {
  "src": "packages/flutter/src/material/material_state.dart.lib.js",
  "id": "packages/flutter/src/material/material_state.dart"
 },
 {
  "src": "packages/flutter/src/material/input_border.dart.lib.js",
  "id": "packages/flutter/src/material/input_border.dart"
 },
 {
  "src": "packages/flutter/src/material/constants.dart.lib.js",
  "id": "packages/flutter/src/material/constants.dart"
 },
 {
  "src": "packages/flutter/src/material/tooltip_visibility.dart.lib.js",
  "id": "packages/flutter/src/material/tooltip_visibility.dart"
 },
 {
  "src": "packages/flutter/src/material/icons.dart.lib.js",
  "id": "packages/flutter/src/material/icons.dart"
 },
 {
  "src": "packages/flutter/src/material/floating_action_button_theme.dart.lib.js",
  "id": "packages/flutter/src/material/floating_action_button_theme.dart"
 },
 {
  "src": "packages/flutter/src/material/material_state_mixin.dart.lib.js",
  "id": "packages/flutter/src/material/material_state_mixin.dart"
 },
 {
  "src": "packages/flutter/src/material/curves.dart.lib.js",
  "id": "packages/flutter/src/material/curves.dart"
 },
 {
  "src": "packages/flutter/src/material/motion.dart.lib.js",
  "id": "packages/flutter/src/material/motion.dart"
 },
 {
  "src": "packages/flutter/src/material/bottom_sheet_theme.dart.lib.js",
  "id": "packages/flutter/src/material/bottom_sheet_theme.dart"
 },
 {
  "src": "packages/flutter/src/material/tab_indicator.dart.lib.js",
  "id": "packages/flutter/src/material/tab_indicator.dart"
 },
 {
  "src": "packages/flutter/src/material/tab_controller.dart.lib.js",
  "id": "packages/flutter/src/material/tab_controller.dart"
 },
 {
  "src": "packages/flutter/src/material/drawer_header.dart.lib.js",
  "id": "packages/flutter/src/material/drawer_header.dart"
 },
 {
  "src": "packages/flutter/src/material/toggle_buttons.dart.lib.js",
  "id": "packages/flutter/src/material/toggle_buttons.dart"
 },
 {
  "src": "packages/flutter/src/material/time_picker.dart.lib.js",
  "id": "packages/flutter/src/material/time_picker.dart"
 },
 {
  "src": "packages/flutter/src/material/text_form_field.dart.lib.js",
  "id": "packages/flutter/src/material/text_form_field.dart"
 },
 {
  "src": "packages/flutter/src/material/text_field.dart.lib.js",
  "id": "packages/flutter/src/material/text_field.dart"
 },
 {
  "src": "packages/flutter/src/material/text_selection.dart.lib.js",
  "id": "packages/flutter/src/material/text_selection.dart"
 },
 {
  "src": "packages/flutter/src/material/text_selection_toolbar_text_button.dart.lib.js",
  "id": "packages/flutter/src/material/text_selection_toolbar_text_button.dart"
 },
 {
  "src": "packages/flutter/src/material/text_selection_toolbar.dart.lib.js",
  "id": "packages/flutter/src/material/text_selection_toolbar.dart"
 },
 {
  "src": "packages/flutter/src/material/spell_check_suggestions_toolbar.dart.lib.js",
  "id": "packages/flutter/src/material/spell_check_suggestions_toolbar.dart"
 },
 {
  "src": "packages/flutter/src/material/spell_check_suggestions_toolbar_layout_delegate.dart.lib.js",
  "id": "packages/flutter/src/material/spell_check_suggestions_toolbar_layout_delegate.dart"
 },
 {
  "src": "packages/flutter/src/material/adaptive_text_selection_toolbar.dart.lib.js",
  "id": "packages/flutter/src/material/adaptive_text_selection_toolbar.dart"
 },
 {
  "src": "packages/flutter/src/material/desktop_text_selection_toolbar_button.dart.lib.js",
  "id": "packages/flutter/src/material/desktop_text_selection_toolbar_button.dart"
 },
 {
  "src": "packages/flutter/src/material/desktop_text_selection_toolbar.dart.lib.js",
  "id": "packages/flutter/src/material/desktop_text_selection_toolbar.dart"
 },
 {
  "src": "packages/flutter/src/material/selectable_text.dart.lib.js",
  "id": "packages/flutter/src/material/selectable_text.dart"
 },
 {
  "src": "packages/flutter/src/material/magnifier.dart.lib.js",
  "id": "packages/flutter/src/material/magnifier.dart"
 },
 {
  "src": "packages/flutter/src/material/desktop_text_selection.dart.lib.js",
  "id": "packages/flutter/src/material/desktop_text_selection.dart"
 },
 {
  "src": "packages/flutter/src/material/dialog.dart.lib.js",
  "id": "packages/flutter/src/material/dialog.dart"
 },
 {
  "src": "packages/flutter/src/material/switch_list_tile.dart.lib.js",
  "id": "packages/flutter/src/material/switch_list_tile.dart"
 },
 {
  "src": "packages/flutter/src/material/switch.dart.lib.js",
  "id": "packages/flutter/src/material/switch.dart"
 },
 {
  "src": "packages/flutter/src/material/shadows.dart.lib.js",
  "id": "packages/flutter/src/material/shadows.dart"
 },
 {
  "src": "packages/flutter/src/material/stepper.dart.lib.js",
  "id": "packages/flutter/src/material/stepper.dart"
 },
 {
  "src": "packages/flutter/src/material/selection_area.dart.lib.js",
  "id": "packages/flutter/src/material/selection_area.dart"
 },
 {
  "src": "packages/flutter/src/material/segmented_button.dart.lib.js",
  "id": "packages/flutter/src/material/segmented_button.dart"
 },
 {
  "src": "packages/flutter/src/material/search_anchor.dart.lib.js",
  "id": "packages/flutter/src/material/search_anchor.dart"
 },
 {
  "src": "packages/flutter/src/material/back_button.dart.lib.js",
  "id": "packages/flutter/src/material/back_button.dart"
 },
 {
  "src": "packages/flutter/src/material/search.dart.lib.js",
  "id": "packages/flutter/src/material/search.dart"
 },
 {
  "src": "packages/flutter/src/material/reorderable_list.dart.lib.js",
  "id": "packages/flutter/src/material/reorderable_list.dart"
 },
 {
  "src": "packages/flutter/src/material/refresh_indicator.dart.lib.js",
  "id": "packages/flutter/src/material/refresh_indicator.dart"
 },
 {
  "src": "packages/flutter/src/material/progress_indicator.dart.lib.js",
  "id": "packages/flutter/src/material/progress_indicator.dart"
 },
 {
  "src": "packages/flutter/src/material/range_slider.dart.lib.js",
  "id": "packages/flutter/src/material/range_slider.dart"
 },
 {
  "src": "packages/flutter/src/material/radio_list_tile.dart.lib.js",
  "id": "packages/flutter/src/material/radio_list_tile.dart"
 },
 {
  "src": "packages/flutter/src/material/popup_menu.dart.lib.js",
  "id": "packages/flutter/src/material/popup_menu.dart"
 },
 {
  "src": "packages/flutter/src/material/paginated_data_table.dart.lib.js",
  "id": "packages/flutter/src/material/paginated_data_table.dart"
 },
 {
  "src": "packages/flutter/src/material/dropdown.dart.lib.js",
  "id": "packages/flutter/src/material/dropdown.dart"
 },
 {
  "src": "packages/flutter/src/material/data_table_source.dart.lib.js",
  "id": "packages/flutter/src/material/data_table_source.dart"
 },
 {
  "src": "packages/flutter/src/material/data_table.dart.lib.js",
  "id": "packages/flutter/src/material/data_table.dart"
 },
 {
  "src": "packages/flutter/src/material/card.dart.lib.js",
  "id": "packages/flutter/src/material/card.dart"
 },
 {
  "src": "packages/flutter/src/material/page.dart.lib.js",
  "id": "packages/flutter/src/material/page.dart"
 },
 {
  "src": "packages/flutter/src/material/no_splash.dart.lib.js",
  "id": "packages/flutter/src/material/no_splash.dart"
 },
 {
  "src": "packages/flutter/src/material/mergeable_material.dart.lib.js",
  "id": "packages/flutter/src/material/mergeable_material.dart"
 },
 {
  "src": "packages/flutter/src/material/input_date_picker_form_field.dart.lib.js",
  "id": "packages/flutter/src/material/input_date_picker_form_field.dart"
 },
 {
  "src": "packages/flutter/src/material/date.dart.lib.js",
  "id": "packages/flutter/src/material/date.dart"
 },
 {
  "src": "packages/flutter/src/material/input_chip.dart.lib.js",
  "id": "packages/flutter/src/material/input_chip.dart"
 },
 {
  "src": "packages/flutter/src/material/chip.dart.lib.js",
  "id": "packages/flutter/src/material/chip.dart"
 },
 {
  "src": "packages/flutter/src/material/grid_tile_bar.dart.lib.js",
  "id": "packages/flutter/src/material/grid_tile_bar.dart"
 },
 {
  "src": "packages/flutter/src/material/grid_tile.dart.lib.js",
  "id": "packages/flutter/src/material/grid_tile.dart"
 },
 {
  "src": "packages/flutter/src/material/filter_chip.dart.lib.js",
  "id": "packages/flutter/src/material/filter_chip.dart"
 },
 {
  "src": "packages/flutter/src/material/expansion_tile.dart.lib.js",
  "id": "packages/flutter/src/material/expansion_tile.dart"
 },
 {
  "src": "packages/flutter/src/material/expansion_panel.dart.lib.js",
  "id": "packages/flutter/src/material/expansion_panel.dart"
 },
 {
  "src": "packages/flutter/src/material/expand_icon.dart.lib.js",
  "id": "packages/flutter/src/material/expand_icon.dart"
 },
 {
  "src": "packages/flutter/src/material/dropdown_menu_form_field.dart.lib.js",
  "id": "packages/flutter/src/material/dropdown_menu_form_field.dart"
 },
 {
  "src": "packages/flutter/src/material/dropdown_menu.dart.lib.js",
  "id": "packages/flutter/src/material/dropdown_menu.dart"
 },
 {
  "src": "packages/flutter/src/material/date_picker.dart.lib.js",
  "id": "packages/flutter/src/material/date_picker.dart"
 },
 {
  "src": "packages/flutter/src/material/calendar_date_picker.dart.lib.js",
  "id": "packages/flutter/src/material/calendar_date_picker.dart"
 },
 {
  "src": "packages/flutter/src/material/circle_avatar.dart.lib.js",
  "id": "packages/flutter/src/material/circle_avatar.dart"
 },
 {
  "src": "packages/flutter/src/material/choice_chip.dart.lib.js",
  "id": "packages/flutter/src/material/choice_chip.dart"
 },
 {
  "src": "packages/flutter/src/material/checkbox_list_tile.dart.lib.js",
  "id": "packages/flutter/src/material/checkbox_list_tile.dart"
 },
 {
  "src": "packages/flutter/src/material/button_bar.dart.lib.js",
  "id": "packages/flutter/src/material/button_bar.dart"
 },
 {
  "src": "packages/flutter/src/material/bottom_app_bar.dart.lib.js",
  "id": "packages/flutter/src/material/bottom_app_bar.dart"
 },
 {
  "src": "packages/flutter/src/material/badge.dart.lib.js",
  "id": "packages/flutter/src/material/badge.dart"
 },
 {
  "src": "packages/flutter/src/material/autocomplete.dart.lib.js",
  "id": "packages/flutter/src/material/autocomplete.dart"
 },
 {
  "src": "packages/flutter/src/material/arc.dart.lib.js",
  "id": "packages/flutter/src/material/arc.dart"
 },
 {
  "src": "packages/flutter/src/material/app.dart.lib.js",
  "id": "packages/flutter/src/material/app.dart"
 },
 {
  "src": "packages/flutter/src/material/animated_icons.dart.lib.js",
  "id": "packages/flutter/src/material/animated_icons.dart"
 },
 {
  "src": "packages/flutter/src/material/action_chip.dart.lib.js",
  "id": "packages/flutter/src/material/action_chip.dart"
 },
 {
  "src": "packages/flutter/src/material/about.dart.lib.js",
  "id": "packages/flutter/src/material/about.dart"
 }
];
window.$dartLoader.loadConfig.loadScriptFn = function(loader) {
  loader.addScriptsToQueue(scripts, null);
  loader.loadEnqueuedModules();
};
window.$dartLoader.loader.nextAttempt();
