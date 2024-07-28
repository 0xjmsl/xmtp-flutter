import 'dart:convert';
import 'dart:typed_data';

import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:xmtp/newSrc/messages/authData.dart';
// import 'package:xmtp/newSrc/messages/privateKeyBundleV1.dart' hide PrivateKeyBundle, PrivateKeyBundleV1;
import 'package:xmtp/newSrc/messages/publicKey.dart' hide PublicKey;
import 'package:xmtp/xmtp.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef Token = xmtp.Token;

class AuthorizedIdentity {
  late String address;
  late xmtp.PublicKey authorized;
  late xmtp.PrivateKey identity;
  late EthPrivateKey privateKey;

  AuthorizedIdentity(this.address, this.authorized, this.identity);

  AuthorizedIdentity.fromPrivateKeyBundleV1(
      xmtp.PrivateKeyBundleV1 privateKeyBundleV1) {
    address = privateKeyBundleV1.identityKey.publicKey.walletAddress;
    authorized = privateKeyBundleV1.identityKey.publicKey;
    identity = privateKeyBundleV1.identityKey;
    privateKey = EthPrivateKey.fromHex(
        bytesToHex(privateKeyBundleV1.identityKey.secp256k1.bytes));
  }

  String createAuthToken() {
    final authData = AuthDataBuilder.buildFromWalletAddress(address);
    final signature = privateKey
        .signToUint8List(Uint8List.fromList(authData.writeToBuffer()));

    final token = Token.create()
      ..identityKey = authorized
      ..authDataBytes = authData.writeToBuffer()
      ..authDataSignature = xmtp.Signature.fromBuffer(signature);
    return base64.encode(token.writeToBuffer());
  }

  PrivateKeyBundle get toBundle {
    // Assuming 'identity' is a PrivateKey
    // and 'authorized' is a PublicKey
    final PublicKey newPub = authorized;
    final PrivateKey newPriv = identity.createEmptyInstance();
    newPriv.publicKey = newPub;

    return PrivateKeyBundle(
      v1: PrivateKeyBundleV1(
        identityKey: identity,
      ),
    );
  }
}
