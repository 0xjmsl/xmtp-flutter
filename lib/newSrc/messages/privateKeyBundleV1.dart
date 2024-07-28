import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:web3dart/crypto.dart';
import 'package:xmtp/newSrc/client.dart';
import 'package:xmtp/newSrc/messages/privateKey.dart';
import 'package:xmtp/newSrc/signingKey.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef PrivateKeyBundleV1 = xmtp.PrivateKeyBundleV1;
typedef PrivateKeyBundle = xmtp.PrivateKeyBundle;

class PrivateKeyBundleV1Builder {
  static PrivateKeyBundleV1 fromEncodedData(String data) {
    return PrivateKeyBundleV1.fromBuffer(base64Decode(data));
  }

  static String encodeData(PrivateKeyBundleV1 privateKeyBundleV1) {
    return base64Encode(privateKeyBundleV1.writeToBuffer());
  }

  static PrivateKeyBundleV1 buildFromBundle(Uint8List bundleBytes) {
    final keys = xmtp.PrivateKeyBundle.fromBuffer(bundleBytes);
    if (keys.hasV1()) {
      return keys.v1;
    } else {
      throw ErrorDescription('No v1 bundle present');
    }
  }
}

extension PrivateKeyBundleV1Extension on PrivateKeyBundleV1 {
  PrivateKeyBundleV1 generate(
    SigningKey wallet, {
    ClientOptions? options,
  }) {
    final privateKey = PrivateKeyBuilder();
    final authorizedIdentity = wallet.createIdentity(
        privateKey.privateKey, options?.preCreateIdentityCallback);
    var bundle = authorizedIdentity.toBundle;
    var preKey = PrivateKey().generate();
    final bytesToSign =
        UnsignedPublicKeyBuilder.buildFromPublicKey(preKey.publicKey)
            .writeToBytes();
    final signature =
        privateKey.sign(bytesFromHexString(bytesToHex(keccak256(bytesToSign))));
    preKey = preKey.toBuilder()
      ..publicKey =
          (preKey.publicKey.toBuilder()..signature = signature).build();
    final signedPublicKey = privateKey.getPrivateKey().sign(
        key: UnsignedPublicKeyBuilder.buildFromPublicKey(preKey.publicKey));
    preKey = preKey.toBuilder()
      ..publicKey = PublicKeyBuilder.buildFromSignedPublicKey(signedPublicKey)
      ..publicKey = (preKey.publicKey.toBuilder()
            ..signature = signedPublicKey.signature)
          .build();
    bundle = bundle.toBuilder()
      ..v1 = (bundle.v1.toBuilder()
            ..identityKey = authorizedIdentity.identity
            ..identityKey = (bundle.v1.identityKey.toBuilder()
                  ..publicKey = authorizedIdentity.authorized)
                .build()
            ..addPreKeys(preKey))
          .build();
    return bundle.v1;
  }

  String get walletAddress =>
      identityKey.publicKey.recoverWalletSignerPublicKey().walletAddress;

  PrivateKeyBundleV2 toV2() {
    return PrivateKeyBundleV2(
      identityKey: SignedPrivateKeyBuilder.buildFromLegacy(identityKey),
      preKeys: preKeysList
          .map((key) => SignedPrivateKeyBuilder.buildFromLegacy(key))
          .toList(),
    );
  }

  PublicKeyBundle toPublicKeyBundle() {
    return PublicKeyBundle(
      identityKey: identityKey.publicKey,
      preKey: preKeysList[0].publicKey,
    );
  }

  Uint8List sharedSecret(
    PublicKeyBundle peer,
    PublicKey myPreKey,
    bool isRecipient,
  ) {
    final peerBundle = SignedPublicKeyBundleBuilder.buildFromKeyBundle(peer);
    final preKey = SignedPublicKeyBuilder.buildFromLegacy(myPreKey);
    return toV2().sharedSecret(
        peer: peerBundle, myPreKey: preKey, isRecipient: isRecipient);
  }
}
