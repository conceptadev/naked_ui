@JS()
library;

import 'dart:async';
import 'dart:js_interop';

@JS('window')
external _BrowserWindow get _window;

extension type _BrowserWindow._(JSObject _) implements JSObject {
  external void addEventListener(
    String type,
    JSFunction listener, [
    JSAny options,
  ]);
}

extension type _BrowserEvent._(JSObject _) implements JSObject {
  external bool get altKey;
  external bool get ctrlKey;
  external bool get metaKey;
  external bool get shiftKey;
}

var _initialized = false;
var _modifiedClickInProgress = false;
var _clickGeneration = 0;
late final JSFunction _clickListener;

/// Installs the browser click observer when running on the web.
void ensureInitialized() {
  if (_initialized) return;
  _initialized = true;
  _clickListener = _recordClick.toJS;
  _window.addEventListener('click', _clickListener, true.toJS);
}

void _recordClick(_BrowserEvent event) {
  final generation = ++_clickGeneration;
  _modifiedClickInProgress =
      event.altKey || event.ctrlKey || event.metaKey || event.shiftKey;
  // Browsers may run microtasks between DOM listeners, so keep the modifier
  // available until Flutter's target listener has dispatched its semantics
  // action. Consumption normally clears it sooner.
  Timer.run(() {
    if (_clickGeneration == generation) _modifiedClickInProgress = false;
  });
}

/// Consumes a pending modified browser click.
bool consumeModifiedClick() {
  final modified = _modifiedClickInProgress;
  _modifiedClickInProgress = false;
  return modified;
}
