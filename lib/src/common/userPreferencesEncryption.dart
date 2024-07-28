import 'dart:typed_data';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'dart:math';
import 'package:xmtp_proto/xmtp_proto.dart';
import 'package:web3dart/web3dart.dart';

const PRIVATE_PREFERENCES_ENCRYPTION_KEY_SALT =
    'XMTP_PRIVATE_PREFERENCES_ENCRYPTION';

Future<Uint8List> hkdf(Uint8List secret, Uint8List salt) async {
  final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
  final pseudoRandomKey = await hkdf.deriveKey(
    secretKey: SecretKey(secret),
    nonce: salt,
  );
  return uint8ListFromList(await pseudoRandomKey.extractBytes());
}

Future<Ciphertext> encrypt(
  Uint8List plaintextBytes,
  Uint8List secretBytes,
  Uint8List? additionalData,
) async {
  final payload = SecretBox(
    plaintextBytes,
    nonce: Uint8List(0),
    mac: Mac.empty,
  );
  return encryptRaw(payload, secretBytes, additionalData);
}

Future<Ciphertext> encryptRaw(
  SecretBox payload,
  Uint8List secretBytes,
  Uint8List? additionalData,
) async {
  final nonceBytes = _generateRandomBytes(12);
  final salt =
      Uint8List.fromList(utf8.encode(PRIVATE_PREFERENCES_ENCRYPTION_KEY_SALT));
  final derivedKey = await hkdf(secretBytes, salt);
  final aesGcm = AesGcm.with256bits();
  final secretBox = await aesGcm.encrypt(
    payload.cipherText,
    secretKey: SecretKey(derivedKey),
    nonce: nonceBytes,
    aad: additionalData!.cast<int>(),
  );

  return Ciphertext(
    aes256GcmHkdfSha256: Ciphertext_Aes256gcmHkdfsha256(
      payload: secretBox.cipherText,
      hkdfSalt: salt,
      gcmNonce: nonceBytes,
    ),
  );
}

Uint8List _generateRandomBytes(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

Future<Uint8List> userPreferencesEncrypt(
  Uint8List publicKey,
  Uint8List privateKey,
  Uint8List message,
) async {
  final ciphertext = await encrypt(message, privateKey, publicKey);
  final userPreferencesMessage = PrivatePreferencesPayload()..v1 = ciphertext;

  return userPreferencesMessage.writeToBuffer();
}

Future<Uint8List> userPreferencesDecrypt(
  Uint8List publicKey,
  Uint8List privateKey,
  Uint8List message,
) async {
  final ciphertext = await getCiphertext(message);
  final payloadBytes =
      await decryptCiphertext(privateKey, ciphertext, publicKey);
  return payloadBytes;
}

Future<Ciphertext> getCiphertext(Uint8List message) async {
  final eciesMessage = PrivatePreferencesPayload.fromBuffer(message);
  final ciphertext = eciesMessage.v1;
  return ciphertext;
}

Future<Uint8List> deriveEncryptionKey(Uint8List privateKey) async {
  final salt =
      Uint8List.fromList(utf8.encode(PRIVATE_PREFERENCES_ENCRYPTION_KEY_SALT));
  final derivedKey = await hkdf(privateKey, salt);
  return derivedKey;
}

Future<Uint8List> decryptCiphertext(
  Uint8List privateKey,
  Ciphertext ciphertext,
  Uint8List additionalData,
) async {
  final encryptionKey = await deriveEncryptionKey(privateKey);
  final unwrapped = await unwrapCiphertext(ciphertext);
  final decrypted = await decrypt(
    uint8ListFromList(unwrapped.payload),
    uint8ListFromList(unwrapped.hkdfSalt),
    uint8ListFromList(unwrapped.gcmNonce),
    encryptionKey,
    additionalData,
  );
  return decrypted;
}

Future<Ciphertext_Aes256gcmHkdfsha256> unwrapCiphertext(
    Ciphertext ciphertext) async {
  final aes256GcmHkdfSha256 = ciphertext.aes256GcmHkdfSha256;
  return aes256GcmHkdfSha256;
}

Future<Uint8List> decrypt(
  Uint8List payload,
  Uint8List hkdfSalt,
  Uint8List gcmNonce,
  Uint8List encryptionKey,
  Uint8List additionalData,
) async {
  final aesGcm = AesGcm.with256bits();
  final secretBox = SecretBox(
    payload,
    nonce: gcmNonce,
    mac: Mac.empty,
  );
  final decryptedBytes = await aesGcm.decrypt(
    secretBox,
    secretKey: SecretKey(encryptionKey),
    aad: additionalData,
  );
  return uint8ListFromList(decryptedBytes);
}
