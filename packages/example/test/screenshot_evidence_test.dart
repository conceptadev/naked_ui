import 'package:example/src/testing/screenshot_evidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screenshot evidence uses stable artifact names and full manifest', () {
    final evidence = ScreenshotEvidence(
      component: 'dialog',
      scenario: 'open_focused',
    );

    expect(
      evidence.artifactNameFor('macos'),
      'dialog__open_focused__macos__reference.png',
    );
    expect(evidence.manifestEntryFor('macos'), <String, Object>{
      'component': 'dialog',
      'scenario': 'open_focused',
      'file': 'dialog__open_focused__macos__reference.png',
      'gitCommit': 'local',
      'flutter': 'local',
      'target': 'macos',
      'surface': '800x600 logical pixels',
      'devicePixelRatio': 1.0,
      'locale': 'en-US',
      'direction': 'LTR',
      'textScale': 1.0,
      'animationMode': 'disabled',
      'testResult': 'pass',
      'reviewer': 'unreviewed',
    });
  });

  test('screenshot evidence rejects unstable artifact segments', () {
    expect(
      () => ScreenshotEvidence(component: 'Alert Dialog', scenario: 'open'),
      throwsArgumentError,
    );
  });

  test('Link evidence preserves all required stable artifact names', () {
    for (final entry in <(String, String), String>{
      ('default_inline', 'macos'): 'link__default_inline__macos__reference.png',
      ('hover', 'web'): 'link__hover__web__reference.png',
      ('keyboard_focus', 'macos'): 'link__keyboard_focus__macos__reference.png',
      ('disabled', 'android'): 'link__disabled__android__reference.png',
      ('external_hint', 'web'): 'link__external_hint__web__reference.png',
      ('long_text_200', 'macos'): 'link__long_text_200__macos__reference.png',
      ('rtl', 'web'): 'link__rtl__web__reference.png',
    }.entries) {
      final (scenario, target) = entry.key;
      final evidence = ScreenshotEvidence(
        component: 'link',
        scenario: scenario,
      );
      expect(evidence.artifactNameFor(target), entry.value);
      expect(evidence.manifestEntryFor(target)['testResult'], 'pass');
    }
  });

  test('alert dialog evidence uses every required native artifact name', () {
    expect(
      ScreenshotEvidence(
        component: 'alert_dialog',
        scenario: 'open_safe_focus',
      ).artifactNameFor('macos'),
      'alert_dialog__open_safe_focus__macos__reference.png',
    );
    expect(
      ScreenshotEvidence(
        component: 'alert_dialog',
        scenario: 'destructive_action',
      ).artifactNameFor('android'),
      'alert_dialog__destructive_action__android__reference.png',
    );
    expect(
      ScreenshotEvidence(
        component: 'alert_dialog',
        scenario: 'long_message_200_text',
        textScale: 2,
      ).artifactNameFor('macos'),
      'alert_dialog__long_message_200_text__macos__reference.png',
    );
  });

  test('toggle group evidence uses required native artifact names', () {
    expect(
      ScreenshotEvidence(
        component: 'toggle_group',
        scenario: 'roving_rtl',
        direction: 'RTL',
      ).artifactNameFor('macos'),
      'toggle_group__roving_rtl__macos__reference.png',
    );
    final verticalDisabled = ScreenshotEvidence(
      component: 'toggle_group',
      scenario: 'vertical_disabled',
      textScale: 2,
    );
    expect(
      verticalDisabled.artifactNameFor('android'),
      'toggle_group__vertical_disabled__android__reference.png',
    );
    expect(verticalDisabled.manifestEntryFor('android')['textScale'], 2.0);
  });
}
