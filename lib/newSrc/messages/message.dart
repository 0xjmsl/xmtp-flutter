import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef Message = xmtp.Message;

enum MessageDeliveryStatus { all, published, unpublished, failed }

enum MessageVersion {
  v1('v1'),
  v2('v2');

  final String rawValue;
  const MessageVersion(this.rawValue);

  static MessageVersion? fromRawValue(String rawValue) {
    return MessageVersion.values.firstWhere(
      (v) => v.rawValue == rawValue,
      // OR NULL ?
    );
  }
}

class MessageBuilder {
  static Message buildFromMessageV1(xmtp.MessageV1 v1) {
    return Message(v1: v1);
  }

  static Message buildFromMessageV2(xmtp.MessageV2 v2) {
    return Message(v2: v2);
  }
}
