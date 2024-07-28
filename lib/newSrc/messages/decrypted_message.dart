import 'package:meta/meta.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

enum MessageDeliveryStatus {
  published
  // Add other status values as needed
}

@immutable
class DecryptedMessage {
  final String id;
  final xmtp.EncodedContent encodedContent;
  final String senderAddress;
  final DateTime sentAt;
  final String topic;
  final MessageDeliveryStatus deliveryStatus;

  const DecryptedMessage({
    required this.id,
    required this.encodedContent,
    required this.senderAddress,
    required this.sentAt,
    this.topic = "",
    this.deliveryStatus = MessageDeliveryStatus.published,
  });

  // If you need to modify the values later, you can add copyWith method
  DecryptedMessage copyWith({
    String? id,
    xmtp.EncodedContent? encodedContent,
    String? senderAddress,
    DateTime? sentAt,
    String? topic,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return DecryptedMessage(
      id: id ?? this.id,
      encodedContent: encodedContent ?? this.encodedContent,
      senderAddress: senderAddress ?? this.senderAddress,
      sentAt: sentAt ?? this.sentAt,
      topic: topic ?? this.topic,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }
}
