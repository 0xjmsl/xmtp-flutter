import 'package:fixnum/fixnum.dart'; // Import the fixnum package
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef AuthData = xmtp.AuthData;

class AuthDataBuilder {
  static AuthData buildFromWalletAddress(String walletAddress,
      [DateTime? timestamp]) {
    final timestamped = timestamp?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;
    return AuthData(
      walletAddr: walletAddress,
      createdNs: Int64(timestamped * 1000000),
    );
  }
}
