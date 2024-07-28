import 'dart:typed_data';
import 'package:xmtp/newSrc/keyUtil.dart';
import 'package:xmtp/newSrc/messages/signatures.dart';
import 'package:xmtp/xmtp.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:web3dart/web3dart.dart'; // For Ethereum-related functionality
import 'package:fixnum/fixnum.dart';
import 'package:eth_sig_util/eth_sig_util.dart';

abstract class SigningKey {
  String get address;

  xmtp.Signature? sign(Uint8List data);

  xmtp.Signature? signMessage(String message);
}

typedef PreEventCallback = Future<void> Function();

extension SigningKeyExtension on SigningKey {
  AuthorizedIdentity createIdentity(
    xmtp.PrivateKey identity, {
    PreEventCallback? preCreateIdentityCallback,
  }) {
    final slimKey = xmtp.PublicKey(
      timestamp: Int64(DateTime.now().millisecondsSinceEpoch),
      secp256k1Uncompressed: identity.publicKey.secp256k1Uncompressed,
    );

    if (preCreateIdentityCallback != null) {
      preCreateIdentityCallback();
    }

    final signatureClass = xmtp.Signature();
    final signatureText =
        signatureClass.createIdentityText(slimKey.writeToBuffer());
    final digest = signatureClass.ethHash(signatureText);

    final signature = sign(Uint8List.fromList(signatureText.codeUnits));

    // // Convert the raw data to a hexadecimal string
    // String hexSignature = '0x' + rawData.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final List<int> rawData = signature!.rawData;
    String hexSignature =
        '0x${rawData.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    final publicKey = EthSigUtil.recoverPersonalSignature(
      signature: hexSignature,
      message: Uint8List.fromList(digest),
    );

    final authorized = PublicKey()
      ..secp256k1Uncompressed = slimKey.secp256k1Uncompressed
      ..timestamp = slimKey.timestamp
      ..signature = signature;

    return AuthorizedIdentity(
      address: publicKey,
      authorized: authorized,
      identity: identity,
    );
  }
}

class AuthorizedIdentity {
  final String address;
  final PublicKey authorized;
  final xmtp.PrivateKey identity;

  AuthorizedIdentity({
    required this.address,
    required this.authorized,
    required this.identity,
  });
}
