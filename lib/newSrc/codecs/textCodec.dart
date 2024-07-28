import 'dart:convert';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;
import 'package:xmtp/newSrc/xmtpException.dart';
import 'package:xmtp/newSrc/codecs/content_codec.dart';
import 'package:xmtp/newSrc/codecs/contentTypeId.dart';

final ContentTypeId contentTypeText =
    ContentTypeIdBuilder.builderFromAuthorityId(
  'xmtp.org',
  'text',
  1,
  0,
);

const Set<String> supportedEncodings = {'UTF-8'};
const String defaultEncoding = 'UTF-8';

class TextCodec implements ContentCodec<String> {
  @override
  ContentTypeId get contentType => contentTypeText;

  @override
  String get id => contentTypeText.id;

  @override
  xmtp.EncodedContent encode(String content) {
    return xmtp.EncodedContent(
      type: contentTypeText,
      parameters: {'encoding': 'UTF-8'},
      content: utf8.encode(content),
    );
  }

  @override
  String decode(xmtp.EncodedContent content) {
    final encoding = content.parameters['encoding'] ?? defaultEncoding;
    if (!supportedEncodings.contains(encoding)) {
      throw XMTPException("unsupported text encoding '$encoding'");
    }
    try {
      return utf8.decode(content.content);
    } catch (e) {
      throw XMTPException('Unknown decoding');
    }
  }

  @override
  String? fallback(String content) {
    return null;
  }

  @override
  bool shouldPush(String content) => true;
}
