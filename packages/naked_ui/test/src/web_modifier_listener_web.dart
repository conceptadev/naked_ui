@JS()
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:naked_ui/src/utilities/web_event_modifiers_web.dart';

@JS('document')
external _Document get _document;

extension type _EventTarget._(JSObject _) implements JSObject {
  external void addEventListener(
    String type,
    JSFunction listener, [
    JSAny options,
  ]);

  external bool dispatchEvent(_MouseEvent event);
}

extension type _Document._(JSObject _) implements JSObject {
  external _Element createElement(String localName);
  external _Element get body;
}

extension type _Element._(JSObject _) implements _EventTarget, JSObject {
  external void append(_Element child);
  external void remove();
}

@JS('MouseEvent')
extension type _MouseEvent._(JSObject _) implements JSObject {
  external factory _MouseEvent(String type, [_MouseEventInit eventInit]);
}

@JS('Object')
extension type _MouseEventInit._(JSObject _) implements JSObject {
  external factory _MouseEventInit({bool bubbles, bool ctrlKey});
}

Future<bool> probeCaptureToTarget() async {
  ensureInitialized();
  final target = _document.createElement('button');
  final result = Completer<bool>();
  target.addEventListener(
    'click',
    ((JSAny _) => result.complete(consumeModifiedClick())).toJS,
  );
  _document.body.append(target);
  try {
    target.dispatchEvent(
      _MouseEvent('click', _MouseEventInit(bubbles: true, ctrlKey: true)),
    );
    return await result.future;
  } finally {
    target.remove();
  }
}
