import 'dart:math';
import 'dart:typed_data';

import 'package:xmtp/newSrc/keyUtil.dart';
import 'package:xmtp/newSrc/messages/publicKey.dart';
import 'package:xmtp/newSrc/messages/signatures.dart';
import 'package:xmtp/newSrc/signingKey.dart';
import 'package:xmtp/xmtp.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:web3dart/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:eth_sig_util/eth_sig_util.dart';

class PrivateKeyBuilder implements SigningKey {
  late xmtp.PrivateKey privateKey;

  PrivateKeyBuilder() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final privateKeyData = Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    final publicData = KeyUtil.getPublicKey(privateKeyData);
    final uncompressedKey = KeyUtil.addUncompressedByte(publicData);

    privateKey = xmtp.PrivateKey(
      timestamp: Int64(timestamp),
      secp256k1: PrivateKey_Secp256k1.fromBuffer(privateKeyData),
      publicKey: xmtp.PublicKey(
        timestamp: Int64(timestamp),
        secp256k1Uncompressed: PublicKey_Secp256k1Uncompressed(
          bytes: uncompressedKey,
        ),
      ),
    );
  }

  PrivateKeyBuilder.fromPrivateKey(PrivateKey key) : privateKey = key;

  static PrivateKey buildFromPrivateKeyData(Uint8List privateKeyData) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final publicData = KeyUtil.getPublicKey(privateKeyData);
    final uncompressedKey = KeyUtil.addUncompressedByte(publicData);

    return xmtp.PrivateKey(
      timestamp: Int64(timestamp),
      secp256k1: PrivateKey_Secp256k1.fromBuffer(privateKeyData),
      publicKey: xmtp.PublicKey(
        timestamp: Int64(timestamp),
        secp256k1Uncompressed: PublicKey_Secp256k1Uncompressed(
          bytes: uncompressedKey,
        ),
      ),
    );
  }

  static PrivateKey buildFromSignedPrivateKey(
      SignedPrivateKey signedPrivateKey) {
    return xmtp.PrivateKey(
      timestamp: signedPrivateKey.createdNs ~/ 1000000,
      secp256k1:
          PrivateKey_Secp256k1.fromBuffer(signedPrivateKey.writeToBuffer()),
      publicKey:
          PublicKeyBuilder.buildFromSignedPublicKey(signedPrivateKey.publicKey),
    );
  }

  xmtp.PrivateKey getPrivateKey() => privateKey;

  @override
  xmtp.Signature sign(Uint8List data) {
    final privateKey = getPrivateKey();
    final signatureData = EthSigUtil.signMessage(
      privateKeyInBytes: Uint8List.fromList(privateKey.secp256k1.bytes),
      message: data,
    );
    final finalsignatureData = KeyUtil.convertSignature(signatureData);

    final signatureKey = KeyUtil.getSignatureBytes(finalsignatureData);

    return xmtp.Signature(
      ecdsaCompact: xmtp.Signature_ECDSACompact(
        bytes: signatureKey.sublist(0, 64),
        recovery: signatureKey[64],
      ),
    );
  }

  @override
  xmtp.Signature signMessage(String data) {
    final digest = xmtp.Signature().ethHash(data);
    return sign(Uint8List.fromList(digest));
  }

  @override
  String get address => privateKey.publicKey.walletAddress;
}

extension PrivateKeyExtension on xmtp.PrivateKey {
  xmtp.PrivateKey generate() {
    final privateKeyData = Uint8List.fromList(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)));
    return PrivateKeyBuilder.buildFromPrivateKeyData(privateKeyData);
  }
}


//   PublicKeyOuterClass_SignedPublicKey sign(
//       PublicKeyOuterClass_UnsignedPublicKey key) {
//     final bytes = key.writeToBytes();
//     final signedPublicKeyBuilder = PublicKeyOuterClass_SignedPublicKey.create();
//     final privateKeyBuilder = PrivateKeyBuilder.fromPrivateKey(this);
//     final signature = privateKeyBuilder.sign(bytesToHexString(bytes));
//     signedPublicKeyBuilder.signature = signature;
//     signedPublicKeyBuilder.keyBytes = bytes;
//     return signedPublicKeyBuilder;
//   }
// }
