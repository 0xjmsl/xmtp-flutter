import 'dart:async';
import 'package:protobuf/protobuf.dart';
import 'package:xmtp/newSrc/conversationV1.dart';
import 'package:xmtp_proto/xmtp_proto.dart';

/// This represents an ongoing conversation.
/// It can be provided to [Client] to [messages] and [send].
/// The [Client] also allows you to [streamMessages] from this [Conversation].
///
/// It attempts to give uniform shape to v1 and v2 conversations.
abstract class Conversation {
  static const String TAG = "CONVERSATION";

  factory Conversation.v1(ConversationV1 conversationV1) = V1;
  factory Conversation.v2(ConversationV2 conversationV2) = V2;
  factory Conversation.group(Group group) = GroupConversation;

  enum Version { v1, v2, group }

  // This indicates whether this a v1 or v2 conversation.
  Version get version;

  // When the conversation was first created.
  DateTime get createdAt;

  // This is the address of the peer that I am talking to.
  String get peerAddress;

  List<String> get peerAddresses;

  // This distinctly identifies between two addresses.
  // Note: this will be empty for older v1 conversations.
  String? get conversationId;

  List<int>? get keyMaterial;

  ConsentState consentState();

  /// This method is to create a TopicData object
  TopicData toTopicData();

  DecodedMessage decode(Envelope envelope, [MessageV3? message]);

  DecodedMessage? decodeOrNull(Envelope envelope) {
    try {
      return decode(envelope);
    } catch (e) {
      print("$TAG: discarding message that failed to decode: $e");
      return null;
    }
  }

  PreparedMessage<T> prepareMessage<T>(T content, {SendOptions? options});

  PreparedMessage prepareMessageEncoded(
    EncodedContent encodedContent, {
    SendOptions? options,
  });

  Future<String> send(PreparedMessage prepared);

  Future<String> sendContent<T>(T content, {SendOptions? options});

  Future<String> sendText(String text, {SendOptions? sendOptions, DateTime? sentAt});

  Future<String> sendEncodedContent(EncodedContent encodedContent, {SendOptions? options});

  String get clientAddress;

  // Is the topic of the conversation depending on the version
  String get topic;

  /// This lists messages sent to the [Conversation].
  Future<List<DecodedMessage>> messages({
    int? limit,
    DateTime? before,
    DateTime? after,
    PagingInfoSortDirection direction = MessageApiOuterClass_SortDirection.SORT_DIRECTION_DESCENDING,
  });

  Future<List<DecryptedMessage>> decryptedMessages({
    int? limit,
    DateTime? before,
    DateTime? after,
    PagingInfoSortDirection direction = MessageApiOuterClass_SortDirection.SORT_DIRECTION_DESCENDING,
  });

  DecryptedMessage decrypt(Envelope envelope, [MessageV3? message]);

  ConsentProofPayload? get consentProof;

  // Get the client according to the version
  Client get client;

  /// This exposes a stream of new messages sent to the [Conversation].
  Stream<DecodedMessage> streamMessages();

  Stream<DecryptedMessage> streamDecryptedMessages();

  Stream<Envelope> streamEphemeral();
}

class V1 implements Conversation {
  final ConversationV1 conversationV1;

  V1(this.conversationV1);

  @override
  Version get version => Version.v1;

  @override
  DateTime get createdAt => conversationV1.sentAt;

  @override
  String get peerAddress => conversationV1.peerAddress;

  @override
  List<String> get peerAddresses => [conversationV1.peerAddress];

  @override
  String? get conversationId => null;

  @override
  List<int>? get keyMaterial => null;

  // Implement other methods...

  @override
  Stream<Envelope> streamEphemeral() => conversationV1.streamEphemeral();
}

class V2 implements Conversation {
  final ConversationV2 conversationV2;

  V2(this.conversationV2);

  @override
  Version get version => Version.v2;

  @override
  DateTime get createdAt => conversationV2.createdAt;

  @override
  String get peerAddress => conversationV2.peerAddress;

  @override
  List<String> get peerAddresses => [conversationV2.peerAddress];

  @override
  String? get conversationId => conversationV2.context.conversationId;

  @override
  List<int>? get keyMaterial => conversationV2.keyMaterial;

  // Implement other methods...

  @override
  Stream<Envelope> streamEphemeral() => conversationV2.streamEphemeral();
}

class GroupConversation implements Conversation {
  final Group group;

  GroupConversation(this.group);

  @override
  Version get version => Version.group;

  @override
  DateTime get createdAt => group.createdAt;

  @override
  String get peerAddress => group.peerInboxIds().join(",");

  @override
  List<String> get peerAddresses => group.peerInboxIds();

  @override
  String? get conversationId => null;

  @override
  List<int>? get keyMaterial => null;

  // Implement other methods...

  @override
  Stream<Envelope> streamEphemeral() {
    throw XMTPException("Groups do not support ephemeral messages");
  }
}