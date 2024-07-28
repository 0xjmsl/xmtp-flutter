import 'dart:async';
import 'dart:typed_data';
import 'package:web3dart/crypto.dart';
import 'package:xmtp/newSrc/client.dart';
import 'package:xmtp/newSrc/decodedMessage.dart';
import 'package:xmtp/newSrc/messages/decrypted_message.dart';
import 'package:xmtp/newSrc/messages/envelope.dart';
import 'package:xmtp/newSrc/messages/paging_info.dart';
import 'package:xmtp/newSrc/messages/topic.dart';
import 'package:xmtp/newSrc/xmtpException.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

class ConversationV1 {
  final Client client;
  final String peerAddress;
  final DateTime sentAt;

  ConversationV1({
    required this.client,
    required this.peerAddress,
    required this.sentAt,
  });

  Topic get topic => Topic.directMessageV1(client.address, peerAddress);

  Stream<DecodedMessage> streamMessages() async* {
    await for (final envelope in client.subscribe([topic.description])) {
      yield decode(envelope);
    }
  }

  Future<List<DecodedMessage>> messages({
    int? limit,
    DateTime? before,
    DateTime? after,
    PagingInfoSortDirection direction =
        xmtp.SortDirection.SORT_DIRECTION_DESCENDING,
  }) async {
    final pagination = Pagination(
      limit: limit!,
      before: before,
      after: after,
      direction: direction,
    );
    final result = await client.apiClient.envelopes(
      topic.description,
      pagination: pagination,
    );

    return result
        .map((envelope) => decodeOrNull(envelope))
        .whereType<DecodedMessage>()
        .toList();
  }

  Future<List<DecryptedMessage>> decryptedMessages({
    int? limit,
    DateTime? before,
    DateTime? after,
    PagingInfoSortDirection direction =
        xmtp.SortDirection.SORT_DIRECTION_DESCENDING,
  }) async {
    final pagination = Pagination(
      limit: limit!,
      before: before,
      after: after,
      direction: direction,
    );

    final envelopes = await client.apiClient.envelopes(
      Topic.directMessageV1(client.address, peerAddress).description,
      pagination: pagination,
    );

    return envelopes.map((e) => decrypt(e)).toList();
  }

  DecryptedMessage decrypt(envelope) {
    try {
      final message = xmtp.Message.fromBuffer(envelope.message);
      final decrypted = message.v1.decrypt(client.privateKeyBundleV1);

      final encodedMessage = EncodedContent.fromBuffer(decrypted);
      final header = message.v1.header;

      return DecryptedMessage(
        id: generateId(envelope),
        encodedContent: encodedMessage,
        senderAddress: header.sender.walletAddress,
        sentAt: message.v1.sentAt,
      );
    } catch (e) {
      throw XMTPException("Error decrypting message", e);
    }
  }

  DecodedMessage decode(envelope) {
    try {
      final decryptedMessage = decrypt(envelope);

      return DecodedMessage(
        id: generateId(envelope),
        client: client,
        topic: envelope.contentTopic,
        encodedContent: decryptedMessage.encodedContent,
        senderAddress: decryptedMessage.senderAddress,
        sent: decryptedMessage.sentAt,
      );
    } catch (e) {
      throw XMTPException("Error decoding message");
    }
  }

  DecodedMessage? decodeOrNull(envelope) {
    try {
      return decode(envelope);
    } catch (e) {
      print("CONV_V1: discarding message that failed to decode: $e");
      return null;
    }
  }

  Future<String> send(String text, {SendOptions? options}) async {
    return sendWithOptions(text: text, sendOptions: options, sentAt: null);
  }

  Future<String> sendWithOptions({
    required String text,
    SendOptions? sendOptions,
    DateTime? sentAt,
  }) async {
    final preparedMessage = prepareMessage(content: text, options: sendOptions);
    return sendPrepared(preparedMessage);
  }

  Future<String> sendContent<T>(T content, {SendOptions? options}) async {
    final preparedMessage = prepareMessage(content: content, options: options);
    return sendPrepared(preparedMessage);
  }

  Future<String> sendEncodedContent(EncodedContent encodedContent,
      {SendOptions? options}) async {
    final preparedMessage =
        prepareMessageEncoded(encodedContent: encodedContent, options: options);
    return sendPrepared(preparedMessage);
  }

  Future<String> sendPrepared(PreparedMessage prepared) async {
    await client.publish(envelopes: prepared.envelopes);
    if (client.contacts.consentList.state(address: peerAddress) ==
        ConsentState.UNKNOWN) {
      await client.contacts.allow(addresses: [peerAddress]);
    }
    return prepared.messageId;
  }

  PreparedMessage<T> prepareMessage<T>(T content, {SendOptions? options}) {
    final codec = Client.codecRegistry.find(options?.contentType);

    EncodedContent encode<Codec extends ContentCodec<T>>(
        Codec codec, dynamic content) {
      if (content is T) {
        return codec.encode(content: content);
      } else {
        throw XMTPException("Codec type is not registered");
      }
    }

    var encoded = encode(codec as ContentCodec<T>, content);

    final fallback = codec.fallback(content);
    if (fallback != null && fallback.isNotEmpty) {
      encoded = encoded.rebuild((b) => b..fallback = fallback);
    }
    final compression = options?.compression;
    if (compression != null) {
      encoded = encoded.compress(compression);
    }
    return prepareMessageEncoded(encodedContent: encoded, options: options);
  }

  PreparedMessage prepareMessageEncoded({
    required EncodedContent encodedContent,
    SendOptions? options,
  }) {
    final contact = client.contacts.find(peerAddress);
    final recipient = contact.toPublicKeyBundle();
    if (!recipient.identityKey.hasSignature) {
      throw Exception("no signature for id key");
    }
    final date = DateTime.now();
    final message = MessageV1Builder.buildEncode(
      sender: client.privateKeyBundleV1,
      recipient: recipient,
      message: encodedContent.writeToBuffer(),
      timestamp: date,
    );

    final isEphemeral = options != null && options.ephemeral;

    final env = EnvelopeBuilder.buildFromString(
      topic: isEphemeral ? ephemeralTopic : topic.description,
      timestamp: date,
      message: MessageBuilder.buildFromMessageV1(v1: message).writeToBuffer(),
    );

    final envelopes = <Envelope>[env];
    if (client.contacts.needsIntroduction(peerAddress) && !isEphemeral) {
      envelopes.addAll([
        env.rebuild(
            (b) => b..contentTopic = Topic.userIntro(peerAddress).description),
        env.rebuild((b) =>
            b..contentTopic = Topic.userIntro(client.address).description),
      ]);
      client.contacts.hasIntroduced[peerAddress] = true;
    }
    return PreparedMessage(envelopes);
  }

  String generateId(Envelope envelope) =>
      bytesToHex(keccak256(Uint8List.fromList(envelope.message)));

  String get ephemeralTopic =>
      topic.description.replaceFirst("/xmtp/0/dm-", "/xmtp/0/dmE-");

  Stream<Envelope> streamEphemeral() {
    return client.subscribe([ephemeralTopic]);
  }

  Stream<DecryptedMessage> streamDecryptedMessages() async* {
    await for (final envelope in client.subscribe([topic.description])) {
      yield decrypt(envelope);
    }
  }
}
