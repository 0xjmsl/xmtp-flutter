import 'package:xmtp/newSrc/messages/topic.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:fixnum/fixnum.dart';

typedef Envelope = xmtp.Envelope;

class EnvelopeBuilder {
  static Envelope buildFromString(
      String topic, DateTime timestamp, List<int> message) {
    return xmtp.Envelope(
      contentTopic: topic,
      timestampNs: Int64(timestamp.microsecondsSinceEpoch * 1000),
      message: message,
    );
  }

  static Envelope buildFromTopic(
      Topic topic, DateTime timestamp, List<int> message) {
    return xmtp.Envelope(
      contentTopic: topic.description,
      timestampNs: Int64(timestamp.microsecondsSinceEpoch * 1000),
      message: message,
    );
  }
}
