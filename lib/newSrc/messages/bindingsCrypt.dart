import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:web3dart/web3dart.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

const PRIVATE_PREFERENCES_ENCRYPTION_KEY_SALT =
    'XMTP_PRIVATE_PREFERENCES_ENCRYPTION';
const PRIVATE_PREFERENCES_TOPIC_SALT = 'XMTP_PRIVATE_PREFERENCES_TOPIC';

Future<String> generateTopicIdentifier(Uint8List secret, Uint8List salt) async {
  final hkdfKey = await hkdf(secret, salt);
  final topicHash = crypto.sha256.convert(hkdfKey).bytes;
  return base64UrlEncode(topicHash);
}

Future<String> generatePrivatePreferencesTopicIdentifier(Uint8List secret) {
  final salt = Uint8List.fromList(utf8.encode(PRIVATE_PREFERENCES_TOPIC_SALT));
  return generateTopicIdentifier(secret, salt);
}

Future<Uint8List> userPreferencesEncrypt(
    Uint8List publicKey, Uint8List privateKey, Uint8List message) async {
  final ciphertext = await decryptMessage(publicKey, privateKey, message);
  return ciphertext;
}

Future<Uint8List> encryptMessage(
    Uint8List publicKey, Uint8List privateKey, Uint8List message) async {
  final ciphertext = await encryptToCiphertext(privateKey, message, publicKey);
  final userPreferencesMessage = xmtp.PrivatePreferencesPayload()
    ..v1 = ciphertext;
  return userPreferencesMessage.writeToBuffer();
}

Future<Uint8List> userPreferencesDecrypt(
    Uint8List publicKey, Uint8List privateKey, Uint8List message) async {
  final ciphertext = await decryptMessage(publicKey, privateKey, message);
  return ciphertext;
}

Future<Uint8List> decryptMessage(
    Uint8List publicKey, Uint8List privateKey, Uint8List message) async {
  final ciphertext = getCiphertext(message);
  return await decryptCiphertext(privateKey, ciphertext, publicKey);
}

xmtp.Ciphertext getCiphertext(Uint8List message) {
  final privatePreferencesPayload =
      xmtp.PrivatePreferencesPayload.fromBuffer(message);
  if (privatePreferencesPayload.whichVersion() ==
      xmtp.PrivatePreferencesPayload_Version.v1) {
    return privatePreferencesPayload.v1;
  }
  throw Exception('No ciphertext found');
}

Future<Uint8List> decryptCiphertext(Uint8List privateKey,
    xmtp.Ciphertext ciphertext, Uint8List additionalData) async {
  final encryptionKey = await deriveEncryptionKey(privateKey);
  final unwrapped = unwrapCiphertext(ciphertext);
  return await decrypt(
    Uint8List.fromList(unwrapped.payload),
    Uint8List.fromList(unwrapped.hkdfSalt),
    Uint8List.fromList(unwrapped.gcmNonce),
    encryptionKey,
    additionalData: additionalData,
  );
}

xmtp.Ciphertext_Aes256gcmHkdfsha256 unwrapCiphertext(
    xmtp.Ciphertext ciphertext) {
  if (ciphertext.hasAes256GcmHkdfSha256()) {
    return ciphertext.aes256GcmHkdfSha256;
  } else {
    throw const FormatException('Unrecognized format');
  }
}

Future<Uint8List> decrypt(
    Uint8List ciphertext, Uint8List salt, Uint8List nonce, Uint8List secret,
    {Uint8List? additionalData}) async {
  final aesGcm = AesGcm.with256bits();
  final secretKey = SecretKey(await hkdf(secret, salt));
  final nonceValue = nonce;
  return uint8ListFromList(await aesGcm.decrypt(
    SecretBox(ciphertext, nonce: nonceValue, mac: Mac.empty),
    secretKey: secretKey,
    aad: (additionalData is List)
        ? List<int>.from(additionalData!.cast<int>())
        : [],
  ));
}

// HKDF function implementation
Future<Uint8List> hkdf(Uint8List secret, Uint8List salt,
    {int length = 32, Uint8List? info}) async {
  // Helper function to perform HMAC-SHA256
  Uint8List hmacSha256(Uint8List key, Uint8List data) {
    var hmac = crypto.Hmac(crypto.sha256, key);
    var digest = hmac.convert(data);
    return Uint8List.fromList(digest.bytes);
  }

  // Step 1: Extract phase
  Uint8List prk = hmacSha256(salt, secret);

  // Step 2: Expand phase
  List<int> okm = [];
  Uint8List previousBlock = Uint8List(0);
  int blockCount = (length / 32).ceil();

  for (int i = 0; i < blockCount; i++) {
    List<int> data = previousBlock + (info ?? []) + [i + 1];
    previousBlock = hmacSha256(prk, Uint8List.fromList(data));
    okm.addAll(previousBlock);
  }

  // Return derived key truncated to the desired length
  return Uint8List.fromList(okm.take(length).toList());
}

Uint8List generateNonce(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

Future<xmtp.Ciphertext> encrypt(Uint8List plaintext, Uint8List secret,
    {Uint8List? additionalData}) async {
  final aesGcm = AesGcm.with256bits();
  final nonce = generateNonce(12);
  final salt = generateNonce(32);
  final secretKey = SecretKey(await hkdf(secret, salt));
  final secretBox = await aesGcm.encrypt(
    plaintext,
    secretKey: secretKey,
    nonce: nonce,
    aad: (additionalData is List)
        ? List<int>.from(additionalData!.cast<int>())
        : [],
  );
  return xmtp.Ciphertext(
    aes256GcmHkdfSha256: xmtp.Ciphertext_Aes256gcmHkdfsha256(
      hkdfSalt: salt,
      gcmNonce: nonce,
      payload: secretBox.cipherText,
    ),
  );
}

Future<Uint8List> deriveEncryptionKey(Uint8List privateKey) async {
  return await hkdf(
      privateKey, utf8.encode(PRIVATE_PREFERENCES_ENCRYPTION_KEY_SALT));
}

Future<xmtp.Ciphertext> encryptToCiphertext(
    Uint8List privateKey, Uint8List message, Uint8List additionalData) async {
  final secretKey = await deriveEncryptionKey(privateKey);
  return await encrypt(message, secretKey, additionalData: additionalData);
}
