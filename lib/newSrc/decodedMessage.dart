import 'package:xmtp/newSrc/client.dart';
import 'package:xmtp/newSrc/codecs/content_Codec.dart';
import 'package:xmtp/newSrc/messages/message.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:xmtp/newSrc/codecs/textCodec.dart';

class DecodedMessage {
  String id;
  final Client client;
  String topic;
  xmtp.EncodedContent encodedContent;
  String senderAddress;
  DateTime sent;
  MessageDeliveryStatus deliveryStatus;

  DecodedMessage({
    this.id = "",
    required this.client,
    required this.topic,
    required this.encodedContent,
    required this.senderAddress,
    required this.sent,
    this.deliveryStatus = MessageDeliveryStatus.published,
  });

  static DecodedMessage preview(
    Client client,
    String topic,
    String body,
    String senderAddress,
    DateTime sent,
  ) {
    final encoded = TextCodec().encode(body);
    return DecodedMessage(
      client: client,
      topic: topic,
      encodedContent: encoded,
      senderAddress: senderAddress,
      sent: sent,
    );
  }

  T? content<T>() {
    return encodedContent.decoded();
  }

  String get fallbackContent => encodedContent.fallback;

  String get body => content<String>() ?? fallbackContent;
}
