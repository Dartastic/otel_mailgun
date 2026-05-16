// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_mailgun/otel_mailgun.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_mailgun-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('send records CLIENT span', () async {
    await tracedMailgunSend<String>(
      domain: 'mg.dartastic.io',
      from: 'noreply@dartastic.io',
      to: ['x@y.com'],
      subject: 'Welcome',
      region: 'us',
      template: 'welcome-v1',
      invoke: () async => const MailgunSendResult(
        value: 'ok',
        messageId: '<20260514@mg>',
      ),
    );
    final a = attrsOf(spans.findSpanByName('mailgun send')!);
    expect(a['messaging.system'], 'mailgun');
    expect(a['mailgun.domain'], 'mg.dartastic.io');
    expect(a['email.from'], 'noreply@dartastic.io');
    expect(a['email.to.count'], 1);
    expect(a['email.subject'], 'Welcome');
    expect(a['mailgun.region'], 'us');
    expect(a['mailgun.template'], 'welcome-v1');
    expect(a['messaging.message.id'], '<20260514@mg>');
  });

  test('suppression skips spans', () async {
    await runWithoutMailgunInstrumentationAsync(() async {
      await tracedMailgunSend<String>(
        domain: 'd',
        from: 'a@x',
        to: ['b@x'],
        invoke: () async => const MailgunSendResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('mailgun '), isEmpty);
  });
}
