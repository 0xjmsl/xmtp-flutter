import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:xmtp/newSrc/keyUtil.dart';
import 'package:xmtp/newSrc/messages/signatures.dart';
import 'package:xmtp/xmtp.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:fixnum/fixnum.dart';
import 'package:web3dart/web3dart.dart' as web3;

typedef PublicKey = xmtp.PublicKey;
typedef SignedPublicKey = xmtp.SignedPublicKey;

class PublicKeyBuilder {
  static PublicKey buildFromSignedPublicKey(SignedPublicKey signedPublicKey) {
    final unsignedPublicKey = PublicKey.fromBuffer(signedPublicKey.keyBytes);
    final builder = PublicKey()
      ..timestamp = unsignedPublicKey.timestamp
      ..secp256k1Uncompressed = (PublicKey_Secp256k1Uncompressed()
        ..bytes = unsignedPublicKey.secp256k1Uncompressed.bytes);

    var sig = signedPublicKey.signature;
    if (sig.walletEcdsaCompact.bytes.isNotEmpty) {
      sig = (Signature()
        ..ecdsaCompact = (xmtp.Signature_ECDSACompact()
          ..bytes = signedPublicKey.signature.walletEcdsaCompact.bytes
          ..recovery = signedPublicKey.signature.walletEcdsaCompact.recovery));
    }
    builder.signature = sig;

    return builder;
  }

  static PublicKey buildFromBytes(Uint8List data) {
    return PublicKey()
      ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch)
      ..secp256k1Uncompressed =
          (PublicKey_Secp256k1Uncompressed()..bytes = data);
  }
}

extension PublicKeyExtensions on PublicKey {
  String get walletAddress {
    final addressBytes = secp256k1Uncompressed.bytes.sublist(1);
    final address =
        web3.EthereumAddress.fromPublicKey(Uint8List.fromList(addressBytes));
    return address.hexEip55;
  }

  PublicKey recoverWalletSignerPublicKey(PublicKey publicKey) {
    if (!publicKey.hasSignature()) {
      throw Exception('No signature found');
    }

// Create a slim version of the public key
    final slimKey = PublicKey(
      timestamp: timestamp,
      secp256k1Uncompressed: PublicKey_Secp256k1Uncompressed(
        bytes: secp256k1Uncompressed.bytes,
      ),
    );
    final signatureClass = Signature();
    final sigText = signatureClass.createIdentityText(slimKey.writeToBuffer());
    final sigHash = signatureClass.ethHash(sigText);

    final signatureData = KeyUtil.getSignatureData(
        Uint8List.fromList(publicKey.secp256k1Uncompressed.bytes));
    final recoveredPublicKey = KeyUtil.signedMessageHashToKey(
        Uint8List.fromList(sigHash), signatureData);

    return PublicKeyBuilder.buildFromBytes(
        KeyUtil.addUncompressedByte(_bigIntToBytes(recoveredPublicKey)));
  }
}

// Add this helper function to your class
Uint8List _bigIntToBytes(BigInt number) {
  var hexString = number.toRadixString(16);
  if (hexString.length % 2 != 0) {
    hexString = '0$hexString';
  }
  var bytes = Uint8List(hexString.length ~/ 2);
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = int.parse(hexString.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
