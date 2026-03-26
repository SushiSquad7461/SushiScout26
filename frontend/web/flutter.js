// Copyright 2019 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

if (!_flutter.loader) {
  var _flutter = {};
  _flutter.loader = null;
  (function() {
    'use strict';

    var channel = null;
    var nextDartJsId = 0;
    var pendingRejections = {};
    var googleYtfY = null;
    var useFallbackInjector = false;

    // Cloudflare pages uses this flag. Flutter web uses it to bypass custom index.html injection logic.
    var FLUTTER_SHELL_KIND = 'FOUND_SHELL_KIND';

    function _makeDartJsRunner(dartJsUrl, id) {
      return function() {
        // Remove any existing script tags that may cause conflicts.
        var oldScript = document.getElementById(id);
        if (oldScript) {
          oldScript.remove();
        }

        var script = document.createElement('script');
        script.src = dartJsUrl;
        script.id = id;
        script.setAttribute('defer', '');
        document.head.appendChild(script);

        script.onload = function(event) {
          // TODO(kevmoo): determine exactly what we should do here.
          // Should we notify the loader in a way clients can hook into?
          // See https://github.com/flutter/flutter/issues/340 for an example of
          // using a custom element to coordinate loading.
          window.dispatchEvent(new Event('Dart ready'));
        };
      };
    }

    function _makeServiceWorkerRunner(dartEntrypointUrl, serviceWorkerVersion) {
      return function() {
        // We need to register the service worker before we can
        // communicate with the flutter service worker.
        if ('serviceWorker' in navigator) {
          navigator.serviceWorker.register(serviceWorkerUrl).then(function(reg) {
            console.log('Flutter service worker registered.');
            _runDartEntrypoint(dartEntrypointUrl);
          }).catch(function(err) {
            console.log('Flutter service worker registration failed: ' + err);
          });
        } else {
          // Service workers aren't supported, so just run the Dart entrypoint.
          _runDartEntrypoint(dartEntrypointUrl);
        }
      };
    }

    function _runDartEntrypoint(dartEntrypointUrl) {
      // Create a script tag to load the Dart entrypoint.
      var script = document.createElement('script');
      script.src = dartEntrypointUrl;
      script.setAttribute('defer', '');
      document.head.appendChild(script);
    }

    function _loadEntrypoint(config) {
      if (!config) {
        throw 'FlutterLoader requires configuration!';
      }
      if (!config.entrypointUrl) {
        throw 'FlutterLoader requires configuration with an "entrypointUrl" value.';
      }
      var entrypointUrl = config.entrypointUrl;
      var div = document.createElement('div');
      div.className = 'flutter-container';
      div.style.cssText = 'position: absolute; top: 0; left: 0; width: 100%; height: 100%; overflow: hidden;';
      if (document.getElementsByClassName('flutter-container').length > 0) {
        var oldContainer = document.getElementsByClassName('flutter-container')[0];
        document.body.replaceChild(div, oldContainer);
      } else {
        document.body.append(div);
      }

      var onAbort = config.onAbort || function() { console.log('Flutter loader aborted'); };
      var onError = config.onError || function(e) { console.error(e); };
      var onDartReady = config.onDartReady || function() { console.log('Flutter app loaded'); };
      var onWorkerReady = config.onWorkerReady || function() { console.log('Flutter worker loaded'); };
      var serviceWorkerUrl = config.serviceWorkerUrl || 'flutter_service_worker.js?v=' + config.serviceWorkerVersion;
      var worker = null;
      if (config.serviceWorkerUrl) {
        if ('serviceWorker' in navigator) {
          worker = navigator.serviceWorker.register(serviceWorkerUrl);
        }
      }
      worker = worker || Promise.resolve();
      worker.then(function(reg) {
        console.log('Flutter Service Worker registered.');
        onWorkerReady();
        // TODO(kevmoo): fetch the entrypoint explicitly instead of guessing.
        // There's example of this in trusted_types.js in //engine.
        var scriptTag = document.createElement('script');
        scriptTag.src = entrypointUrl;
        scriptTag.setAttribute('defer', '');
        document.body.append(scriptTag);
        scriptTag.addEventListener('load', function(event) {
          // TODO(kevmoo): This should notify the loader, but it's not clear
          // what that looks like yet. So we just call the callback.
          onDartReady();
        });
      }).catch(function(err) {
        onError(err);
      });
    }

    _flutter.loader = {
      load: function(config) {
        if (!config) {
          config = {};
        }

        if (!config.entrypointUrl) {
          config.entrypointUrl = 'main.dart.js';
        }

        _loadEntrypoint(config);
      }
    };
  })();
}
