/* ENTRYPOINT_EXTENTION_MARKER */

(function() {
  let appName = "org-dartlang-app:/web_entrypoint.dart";

  dartDevEmbedder.debugger.registerDevtoolsFormatter();

  // Set up a final script that lets us know when all scripts have been loaded.
  // Only then can we call the main method.
  let onLoadEndSrc = 'on_load_end_bootstrap.js';
  window.$dartLoader.loadConfig.bootstrapScript = {
    src: onLoadEndSrc,
    id: onLoadEndSrc,
  };
  window.$dartLoader.loadConfig.tryLoadBootstrapScript = true;
  // Should be called by on_load_end_bootstrap.js once all the scripts have been
  // loaded.
  window.$onLoadEndCallback = function() {
    let child = {};
    child.main = function() {
      let sdkOptions = {
        nativeNonNullAsserts: true,
      };
      dartDevEmbedder.runMain(appName, sdkOptions);
    }
    /* MAIN_EXTENSION_MARKER */
    child.main();
  }
})();
