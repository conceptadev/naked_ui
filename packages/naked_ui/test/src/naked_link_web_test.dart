import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naked_ui/naked_ui.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'web_modifier_listener_stub.dart'
    if (dart.library.js_interop) 'web_modifier_listener_web.dart'
    as web_modifier_listener;

void main() {
  late UrlLauncherPlatform originalPlatform;
  late _FakeUrlLauncherPlatform platform;

  setUp(() {
    originalPlatform = UrlLauncherPlatform.instance;
    platform = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = platform;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = originalPlatform;
  });

  testWidgets('web delegates browser and OS handler schemes to FollowLink', (
    tester,
  ) async {
    final destinations = [
      Uri.parse('mailto:person@example.com'),
      Uri.parse('tel:+15551234567'),
      Uri.parse('custom-scheme:destination'),
    ];

    for (final destination in destinations) {
      platform.clear();
      await tester.pumpWidget(_testApp(destination));
      await tester.tap(find.text('Open destination'));
      await tester.pump();

      expect(platform.followedUrls, [destination]);
      expect(platform.launchCalls, isEmpty);
    }
  }, skip: !kIsWeb);

  testWidgets('web keeps modified handler schemes browser-owned', (
    tester,
  ) async {
    final destination = Uri.parse('mailto:person@example.com');

    await tester.pumpWidget(_testApp(destination));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    try {
      await tester.tap(find.text('Open destination'));
      await tester.pump();

      expect(platform.followedUrls, [destination]);
      expect(platform.launchCalls, isEmpty);
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
  }, skip: !kIsWeb);

  testWidgets('web retains DOM modifiers through target click listeners', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(Uri.parse('https://example.com/docs')));

    expect(await web_modifier_listener.probeCaptureToTarget(), isTrue);
    await tester.pump(Duration.zero);
  }, skip: !kIsWeb);

  testWidgets('web opens HTTP and HTTPS destinations in the current tab', (
    tester,
  ) async {
    final destinations = [
      Uri.parse('http://example.com/docs'),
      Uri.parse('https://example.com/docs'),
    ];

    for (final destination in destinations) {
      platform.clear();
      await tester.pumpWidget(_testApp(destination));
      await tester.tap(find.text('Open destination'));
      await tester.pump();

      expect(platform.followedUrls, isEmpty);
      expect(platform.launchCalls, hasLength(1));
      expect(platform.launchCalls.single.$1, destination.toString());
      expect(platform.launchCalls.single.$2.webOnlyWindowName, '_self');
    }
  }, skip: !kIsWeb);

  testWidgets('web routes javascript to url_launcher launchUrl', (
    tester,
  ) async {
    final destination = Uri.parse('javascript:alert("blocked")');

    await tester.pumpWidget(_testApp(destination));
    await tester.tap(find.text('Open destination'));
    await tester.pump();

    expect(platform.followedUrls, isEmpty);
    expect(platform.launchCalls, hasLength(1));
    expect(platform.launchCalls.single.$1, destination.toString());
  }, skip: !kIsWeb);

  testWidgets('web routes modified javascript to url_launcher launchUrl', (
    tester,
  ) async {
    final destination = Uri.parse('javascript:alert("blocked")');

    await tester.pumpWidget(_testApp(destination));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    try {
      await tester.tap(find.text('Open destination'));
      await tester.pump();

      expect(platform.followedUrls, isEmpty);
      expect(platform.launchCalls, hasLength(1));
      expect(platform.launchCalls.single.$1, destination.toString());
    } finally {
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }
  }, skip: !kIsWeb);

  testWidgets('web delegates scheme-less routes to Link followLink', (
    tester,
  ) async {
    final destination = Uri.parse('/account/settings');

    await tester.pumpWidget(_testApp(destination));
    await tester.tap(find.text('Open destination'));
    await tester.pump();

    expect(platform.followedUrls, [destination]);
    expect(platform.launchCalls, isEmpty);
  }, skip: !kIsWeb);
}

Widget _testApp(Uri destination) {
  return MaterialApp(
    home: Scaffold(
      body: NakedLink(
        linkUrl: destination,
        child: const SizedBox(
          width: 160,
          height: 48,
          child: Text('Open destination'),
        ),
      ),
    ),
  );
}

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  final followedUrls = <Uri>[];
  final launchCalls = <(String, LaunchOptions)>[];

  @override
  LinkDelegate get linkDelegate {
    return (link) => Builder(
      builder: (context) => link.builder(
        context,
        link.isDisabled
            ? null
            : () async {
                followedUrls.add(link.uri!);
              },
      ),
    );
  }

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchCalls.add((url, options));
    return true;
  }

  void clear() {
    followedUrls.clear();
    launchCalls.clear();
  }
}
