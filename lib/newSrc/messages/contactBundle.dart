import 'package:xmtp/xmtp.dart';
import 'dart:typed_data';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef ContactBundle = xmtp.ContactBundle;
typedef ContactBundleV1 = xmtp.ContactBundleV1;
typedef ContactBundleV2 = xmtp.ContactBundleV2;

class ContactBundleBuilder {
  static ContactBundle buildFromEnvelope(Envelope envelope) {
    final data = envelope.message;
    // Try to deserialize legacy v1 bundle
    final publicKeyBundle = PublicKeyBundle.fromBuffer(data);
    final builder = ContactBundle();
    builder.v1 = ContactBundleV1()..keyBundle = publicKeyBundle;
    if (builder.v1.keyBundle.identityKey.secp256k1Uncompressed.bytes.isEmpty) {
      builder.mergeFromBuffer(data);
    }
    return builder;
  }
}

extension ContactBundleExtensions on ContactBundle {
  PublicKeyBundle toPublicKeyBundle() {
    switch (whichVersion()) {
      case ContactBundle_Version.v1:
        return v1.keyBundle;
      case ContactBundle_Version.v2:
        return PublicKeyBundle.create().buildFromSignedKeyBundle(v2.keyBundle);
      default:
        throw XMTPException('Invalid version');
    }
  }

  SignedPublicKeyBundle toSignedPublicKeyBundle() {
    switch (whichVersion()) {
      case ContactBundle_Version.v1:
        return SignedPublicKeyBundleBuilder.buildFromKeyBundle(v1.keyBundle);
      case ContactBundle_Version.v2:
        return v2.keyBundle;
      default:
        throw XMTPException('Invalid version');
    }
  }

  String? get walletAddress {
    switch (whichVersion()) {
      case ContactBundle_Version.v1:
        final key = v1.keyBundle.identityKey.recoverWalletSignerPublicKey();
        final address = getAddress(key.secp256K1Uncompressed.bytes.sublist(1));
        return toChecksumAddress(address.toHex());
      case ContactBundle_Version.v2:
        final key = v2.keyBundle.identityKey.recoverWalletSignerPublicKey();
        final address = getAddress(key.secp256K1Uncompressed.bytes.sublist(1));
        return toChecksumAddress(address.toHex());
      default:
        return null;
    }
  }

  String? get identityAddress {
    switch (whichVersion()) {
      case ContactBundle_Version.v1:
        return v1.keyBundle.identityKey.walletAddress;
      case ContactBundle_Version.v2:
        PublicKey? publicKey;
        try {
          publicKey = PublicKeyBuilder.buildFromSignedPublicKey(
              v2.keyBundle.identityKey);
        } catch (e) {
          publicKey = null;
        }
        return publicKey?.walletAddress;
      default:
        return null;
    }
  }
}

// Helper functions (you might need to implement these or import them from appropriate libraries)
String getAddress(Uint8List publicKey) {
  // Implementation needed
  throw UnimplementedError();
}

String toChecksumAddress(String address) {
  // Implementation needed
  throw UnimplementedError();
}

class XMTPException implements Exception {
  final String message;
  XMTPException(this.message);
}
