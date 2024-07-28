import 'package:xmtp/newSrc/messages/publicKey.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef PublicKeyBundle = xmtp.PublicKeyBundle;
typedef SignedPublicKeyBundle = xmtp.SignedPublicKeyBundle;

class PublicKeyBundleBuilder {
  static PublicKeyBundle buildFromSignedKeyBundle(
      SignedPublicKeyBundle signedPublicKeyBundle) {
    return PublicKeyBundle(
      identityKey: PublicKeyBuilder.buildFromSignedPublicKey(
          signedPublicKeyBundle.identityKey),
      preKey: PublicKeyBuilder.buildFromSignedPublicKey(
          signedPublicKeyBundle.preKey),
    );
  }
}

extension PublicKeyBundleExtensions on PublicKeyBundle {
  String get walletAddress {
    try {
      return identityKey.recoverWalletSignerPublicKey().walletAddress;
    } catch (e) {
      return "";
    }
  }
}
