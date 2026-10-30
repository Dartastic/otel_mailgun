// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_mailgun/otel_mailgun.dart';

/// Traces Mailgun calls with OpenTelemetry.
///
/// `otel_mailgun` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Mailgun call in
/// [tracedMailgunSend]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'mailgun-example');

  // Wraps a Mailgun messages send in a CLIENT span.
  final mailgunSendId = await tracedMailgunSend<String>(
    domain: 'example',
    from: 'example',
    to: ['example'],
    subject: 'example',
    region: 'us-east-1',
    template: 'example',
    invoke: () async {
      // Make the Mailgun call here, then report what it returned.
      const id = 'mailgun_8f3a2c';
      return const MailgunSendResult(value: id, messageId: 'message_8f3a2c');
    },
  );
  OTelLog.info('tracedMailgunSend returned $mailgunSendId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutMailgunInstrumentationAsync.
  await runWithoutMailgunInstrumentationAsync(
    () => tracedMailgunSend<String>(
      domain: 'example',
      from: 'example',
      to: ['example'],
      subject: 'example',
      region: 'us-east-1',
      template: 'example',
      invoke: () async {
        const id = 'mailgun_8f3a2c';
        return const MailgunSendResult(value: id, messageId: 'message_8f3a2c');
      },
    ),
  );

  await OTel.shutdown();
}
