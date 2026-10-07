/// JavaScript injected into every micro-app document before its own code.
///
/// Defines:
///   * `window.mcro` - promise-based API (`mcro.geolocation`, `mcro.sms`)
///   * `window.__mcroComplete` - completion hook Dart calls into the page
///   * a standard `navigator.geolocation` implementation backed by the bridge
///
/// Raw string: no Dart interpolation is applied.
const String bridgeJs = r'''
(function () {
  "use strict";

  var callbacks = {};
  var seq = 0;
  var watches = {};
  var watchSeq = 0;

  function call(method, params) {
    return new Promise(function (resolve, reject) {
      var id = "cb" + (++seq) + "_" + Date.now();
      callbacks[id] = { resolve: resolve, reject: reject };
      try {
        McroBridge.postMessage(JSON.stringify({ id: id, method: method, params: params || {} }));
      } catch (err) {
        delete callbacks[id];
        reject({ code: "INTERNAL", message: String(err) });
      }
    });
  }

  function toPosition(pos) {
    return {
      coords: {
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        altitude: pos.altitude,
        altitudeAccuracy: null,
        heading: null,
        speed: pos.speed
      },
      timestamp: pos.timestamp
    };
  }

  function toPositionError(err) {
    var code = 2;
    if (err && err.code === "PERMISSION_DENIED") {
      code = 1;
    } else if (err && err.code === "TIMEOUT") {
      code = 3;
    }
    var error = new Error(err && err.message ? err.message : "Position unavailable");
    error.code = code;
    error.PERMISSION_DENIED = 1;
    error.POSITION_UNAVAILABLE = 2;
    error.TIMEOUT = 3;
    return error;
  }

  window.__mcroComplete = function (id, ok, json) {
    var cb = callbacks[id];
    if (!cb) {
      return;
    }
    delete callbacks[id];
    var data;
    try {
      data = JSON.parse(json);
    } catch (err) {
      data = { code: "INTERNAL", message: String(err) };
      ok = false;
    }
    if (ok) {
      cb.resolve(data);
    } else {
      cb.reject(data);
    }
  };

  var geolocation = {
    getCurrentPosition: function (success, error, options) {
      var params = {};
      if (options && typeof options.timeout === "number") {
        params.timeout = options.timeout;
      }
      call("geolocation.getCurrentPosition", params).then(function (pos) {
        if (typeof success === "function") {
          success(toPosition(pos));
        }
      }, function (err) {
        if (typeof error === "function") {
          error(toPositionError(err));
        }
      });
    },
    watchPosition: function (success, error, options) {
      var id = ++watchSeq;
      function tick() {
        if (!watches[id]) {
          return;
        }
        geolocation.getCurrentPosition(success, error, options);
        watches[id] = setTimeout(tick, 5000);
      }
      watches[id] = setTimeout(tick, 0);
      return id;
    },
    clearWatch: function (id) {
      if (watches[id]) {
        clearTimeout(watches[id]);
        delete watches[id];
      }
    }
  };

  window.mcro = {
    version: 1,
    call: call,
    geolocation: {
      getCurrentPosition: function (options) {
        return call(
          "geolocation.getCurrentPosition",
          options && typeof options === "object" ? options : {}
        ).then(toPosition);
      }
    },
    sms: {
      send: function (to, body) {
        var payload = typeof to === "string" ? { to: to, body: body } : (to || {});
        return call("sms.send", payload);
      }
    }
  };

  try {
    Object.defineProperty(navigator, "geolocation", {
      value: geolocation,
      configurable: true,
      writable: true
    });
  } catch (err) {
    // Some engines may not allow the override; window.mcro still works.
  }
})();
''';
