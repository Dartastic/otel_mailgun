// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_mailgun_suppression.dart';

const _tracerName = 'dartastic_otel_libs_mailgun';
const _systemValue = 'mailgun';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Pair returned from `tracedMailgunSend` callback.
class MailgunSendResult<T> {
  const MailgunSendResult({required this.value, this.messageId});
  final T value;
  final String? messageId;
}

/// Wraps a Mailgun `messages` send in a CLIENT span.
Future<T> tracedMailgunSend<T>({
  required String domain,
  required String from,
  required List<String> to,
  required Future<MailgunSendResult<T>> Function() invoke,
  String? subject,
  String? region,
  String? template,
}) async {
  if (mailgunInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'messaging.system': _systemValue,
    'messaging.operation': 'publish',
    'messaging.destination.name': 'email',
    'mailgun.domain': domain,
    'email.from': from,
    'email.to.count': to.length,
    if (subject != null) 'email.subject': subject,
    if (region != null) 'mailgun.region': region,
    if (template != null) 'mailgun.template': template,
  };

  final span = _tracer().startSpan(
    'mailgun send',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.messageId != null) {
      span.addAttributes(OTel.attributes([
        OTel.attributeString('messaging.message.id', r.messageId!),
        OTel.attributeString('mailgun.message_id', r.messageId!),
      ]));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
