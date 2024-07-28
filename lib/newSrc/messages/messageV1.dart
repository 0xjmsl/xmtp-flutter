import 'dart:typed_data';
import 'package:xmtp/newSrc/messages/privateKeyBundleV1.dart';
import 'package:xmtp/newSrc/messages/publicKeyBundle.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

class MessageV1Builder {
  static xmtp.MessageV1 buildEncode(
    PrivateKeyBundleV1 sender,
    PublicKeyBundle recipient,
    Uint8List message,
    DateTime timestamp,
  ) {
    final secret = sender.sharedSecret(
      recipient,
      sender.preKeys[0].publicKey,
      false,
    );
    final header = MessageHeaderV1Builder.buildFromPublicBundles(
      sender: sender.toPublicKeyBundle(),
      recipient: recipient,
      timestamp: timestamp.millisecondsSinceEpoch,
    );
    final headerBytes = header.writeToBuffer();
    final ciphertext =
        Crypto.encrypt(secret, message, additionalData: headerBytes);
    return buildFromCipherText(
        headerBytes: headerBytes, ciphertext: ciphertext);
  }

  static MessageV1 buildFromBytes(Uint8List bytes) {
    final message = Message.fromBuffer(bytes);
    late Uint8List headerBytes;
    late CipherText ciphertext;
    switch (message.whichVersion()) {
      case Message_Version.v1:
        headerBytes = message.v1.headerBytes;
        ciphertext = message.v1.ciphertext;
        break;
      case Message_Version.v2:
        headerBytes = message.v2.headerBytes;
        ciphertext = message.v2.ciphertext;
        break;
      default:
        throw XMTPException("Cannot decode from bytes");
    }
    return buildFromCipherText(
        headerBytes: headerBytes, ciphertext: ciphertext);
  }

  static MessageV1 buildFromCipherText(
    Uint8List headerBytes,
    CipherText? ciphertext,
  ) {
    return MessageV1(
      headerBytes: headerBytes,
      ciphertext: ciphertext,
    );
  }
}

extension MessageV1Extensions on MessageV1 {
  MessageHeaderV1 get header => MessageHeaderV1.fromBuffer(headerBytes);

  String get senderAddress =>
      header.sender.identityKey.recoverWalletSignerPublicKey().walletAddress;

  DateTime get sentAt => DateTime.fromMillisecondsSinceEpoch(header.timestamp);

  String get recipientAddress =>
      header.recipient.identityKey.recoverWalletSignerPublicKey().walletAddress;

  Uint8List? decrypt(PrivateKeyBundleV1? viewer) {
    final header = MessageHeaderV1.fromBuffer(headerBytes);
    final recipient = header.recipient;
    final sender = header.sender;
    late Uint8List secret;
    if (viewer?.walletAddress == sender.walletAddress) {
      secret = viewer!.sharedSecret(
        peer: recipient,
        myPreKey: sender.preKey,
        isRecipient: false,
      );
    } else {
      secret = viewer?.sharedSecret(
            peer: sender,
            myPreKey: recipient.preKey,
            isRecipient: true,
          ) ??
          Uint8List(0);
    }
    return Crypto.decrypt(secret, ciphertext, additionalData: headerBytes);
  }
}
