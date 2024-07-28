import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

typedef ContentTypeId = xmtp.ContentTypeId;

class ContentTypeIdBuilder {
  static ContentTypeId builderFromAuthorityId(
    String authorityId,
    String typeId,
    int versionMajor,
    int versionMinor,
  ) {
    return ContentTypeId(
      authorityId: authorityId,
      typeId: typeId,
      versionMajor: versionMajor,
      versionMinor: versionMinor,
    );
  }
}

extension ContentTypeIdExtensions on ContentTypeId {
  String get id => '$authorityId:$typeId';

  String get description => '$authorityId/$typeId:$versionMajor.$versionMinor';
}
