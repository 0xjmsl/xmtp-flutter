import 'dart:async';
import 'package:grpc/grpc.dart';
import 'package:protobuf/protobuf.dart';
import 'package:fixnum/fixnum.dart';

class Conversations {
  static const String TAG = "CONVERSATIONS";

  Client client;
  Map<String, Conversation> conversationsByTopic = {};
  FfiConversations? libXMTPConversations;

  Conversations(this.client, {this.libXMTPConversations});

  Conversation fromInvite(Envelope envelope) {
    // Should parse the envelope, get the invitation, and create a ConversationV2
    return Conversation.V2(ConversationV2());
  }

  Conversation fromIntro(Envelope envelope) {
    // Should parse the envelope, extract sender and recipient addresses, and create a ConversationV1
    return Conversation.V1(ConversationV1());
  }

  Future<Group> fromWelcome(List<int> envelopeBytes) async {
    // Should process the welcome message and create a Group, or throw an exception if not supported
    return Group(client, FfiGroup());
  }

  Future<Group> newGroup({
    required List<String> accountAddresses,
    GroupPermissions permissions = GroupPermissions.ALL_MEMBERS,
    String groupName = "",
    String groupImageUrlSquare = "",
  }) async {
    // Should validate addresses, create a new group, allow group in contacts, and return the Group
    return Group(client, FfiGroup());
  }

  Future<void> syncGroups() async {
    // Should synchronize groups
  }

  Future<List<Group>> listGroups({
    DateTime? after,
    DateTime? before,
    int? limit,
  }) async {
    // Should list groups based on the given parameters
    return [];
  }

  Future<void> handleConsentProof(
    Invitation_ConsentProofPayload consentProof,
    String peerAddress,
  ) async {
    // Should validate the consent signature and update the consent list if necessary
  }

  Future<Conversation> newConversation(
    String peerAddress, {
    Invitation_InvitationV1_Context? context,
    Invitation_ConsentProofPayload? consentProof,
  }) async {
    // Should create a new conversation or return an existing one, handling v1 and v2 conversations
    return Conversation.V2(ConversationV2());
  }

  Future<List<Conversation>> list({bool includeGroups = false}) async {
    // Should list all conversations, including groups if specified
    return [];
  }

  Conversation importTopicData(TopicData data) {
    // Should create a conversation from topic data and add it to conversationsByTopic
    return Conversation.V2(ConversationV2());
  }

  Keystore_GetConversationHmacKeysResponse getHmacKeys({
    Keystore_GetConversationHmacKeysRequest? request,
  }) {
    // Should generate and return HMAC keys for conversations
    return Keystore_GetConversationHmacKeysResponse();
  }

  Future<Map<String, DateTime>> listIntroductionPeers(
      {Pagination? pagination}) async {
    // Should list introduction peers with their last seen dates
    return {};
  }

  Future<List<SealedInvitation>> listInvitations(
      {Pagination? pagination}) async {
    // Should list sealed invitations
    return [];
  }

  ConversationV2 conversation(SealedInvitation sealedInvitation) {
    // Should create a ConversationV2 from a sealed invitation
    return ConversationV2();
  }

  Future<List<DecodedMessage>> listBatchMessages(
    List<Pair<String, Pagination?>> topics,
  ) async {
    // Should list messages for multiple conversations in batches
    return [];
  }

  Future<List<DecryptedMessage>> listBatchDecryptedMessages(
    List<Pair<String, Pagination?>> topics,
  ) async {
    // Should list and decrypt messages for multiple conversations in batches
    return [];
  }

  Future<SealedInvitation> sendInvitation(
    SignedPublicKeyBundle recipient,
    InvitationV1 invitation,
    DateTime created,
  ) async {
    // Should create and send a sealed invitation
    return SealedInvitation();
  }

  Stream<Conversation> stream() async* {
    // Should stream new conversations (both v1 and v2)
  }

  Stream<Conversation> streamAll() {
    // Should stream all conversations, including groups
    return const Stream.empty();
  }

  Stream<Conversation> streamGroupConversations() {
    // Should stream group conversations
    return const Stream.empty();
  }

  Stream<Group> streamGroups() {
    // Should stream groups
    return const Stream.empty();
  }

  Stream<DecodedMessage> streamAllGroupMessages() {
    // Should stream all group messages
    return const Stream.empty();
  }

  Stream<DecryptedMessage> streamAllGroupDecryptedMessages() {
    // Should stream all decrypted group messages
    return const Stream.empty();
  }

  Stream<DecodedMessage> streamAllMessages({bool includeGroups = false}) {
    // Should stream all messages, optionally including group messages
    return const Stream.empty();
  }

  Stream<DecryptedMessage> streamAllDecryptedMessages(
      {bool includeGroups = false}) {
    // Should stream all decrypted messages, optionally including group messages
    return const Stream.empty();
  }

  Stream<DecodedMessage> streamAllV2Messages() async* {
    // Should stream all v2 messages
  }

  Stream<DecryptedMessage> streamAllV2DecryptedMessages() async* {
    // Should stream all decrypted v2 messages
  }
}
