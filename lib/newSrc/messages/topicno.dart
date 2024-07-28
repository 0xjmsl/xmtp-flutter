import 'dart:typed_data';

import 'package:quiver/check.dart';
import 'package:web3dart/credentials.dart';
import 'package:xmtp/newSrc/messages/bindingsCrypt.dart';

/// Clients interact with XMTP by querying, subscribing, and publishing
/// to these topics.
///
/// NOTE: wallet addresses are normalized.
/// See [EIP 55](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-55.md)
class Topic {
  static const String _versionPrefix = "/xmtp/0";
  static const String _versionPrefixMls = "/xmtp/mls/1";

  final String? type;
  final String? address;
  final String? address1;
  final String? address2;
  final String? addresses;
  final String? identifier;
  final String? installationId;
  final String? groupId;

  const Topic._({
    this.type,
    this.address,
    this.address1,
    this.address2,
    this.addresses,
    this.identifier,
    this.installationId,
    this.groupId,
  });

  factory Topic.userPrivateStoreKeyBundle(String address) =>
      Topic._(address: address, type: 'userPrivateStoreKeyBundle');
  factory Topic.contact(String address) =>
      Topic._(address: address, type: 'contact');
  factory Topic.userIntro(String address) =>
      Topic._(address: address, type: 'userIntro');
  factory Topic.userInvite(String address) =>
      Topic._(address: address, type: 'userInvite');
  factory Topic.directMessageV1(String address1, String address2) =>
      Topic._(address1: address1, address2: address2, type: 'directMessageV1');
  factory Topic.directMessageV2(String addresses) =>
      Topic._(addresses: addresses, type: 'directMessageV2');
  factory Topic.preferenceList(String identifier) =>
      Topic._(identifier: identifier, type: 'preferenceList');
  factory Topic.userWelcome(String installationId) =>
      Topic._(installationId: installationId, type: 'userWelcome');
  factory Topic.groupMessage(String groupId) =>
      Topic._(groupId: groupId, type: 'groupMessage');

  String get description {
    switch (type) {
      case 'userPrivateStoreKeyBundle':
        return _content("privatestore-${_normalize(address)}/key_bundle");
      case 'contact':
        return _content("contact-$address");
      case 'userIntro':
        return _content("intro-$address");
      case 'userInvite':
        return _content("invite-$address");
      case 'directMessageV1':
        var addresses = [address1!, address2!];
        addresses.sort();
        return _content("dm-${addresses.join("-")}");
      case 'directMessageV2':
        return _content("m-$addresses");
      case 'preferenceList':
        return _content("userpreferences-$identifier");
      case 'groupMessage':
        return _contentMls("g-$groupId");
      case 'userWelcome':
        return _contentMls("w-$installationId");
      default:
        throw ArgumentError('Unknown topic type: $type');
    }
  }

  static String _content(String name) => '$_versionPrefix/$name/proto';
  static String _contentMls(String name) => '$_versionPrefixMls/$name/proto';

  static String getUserPrivateStoreKeyBundle(String walletAddress) =>
      _content('privatestore-${_normalize(walletAddress)}/key_bundle');

  static String getContact(String walletAddress) =>
      _content('contact-${_normalize(walletAddress)}');

  static String getUserIntro(String walletAddress) =>
      _content('intro-${_normalize(walletAddress)}');

  static String getUserInvite(String walletAddress) =>
      _content('invite-${_normalize(walletAddress)}');

  static String getDirectMessageV1(
      String senderAddress, String recipientAddress) {
    var addresses = [
      _normalize(senderAddress),
      _normalize(recipientAddress),
    ];
    addresses.sort();
    return _content('dm-${addresses.join('-')}');
  }

  static String getDirectMessageV2(String randomString) =>
      _content('m-$randomString');

  static String getPreferenceList(String identifier) =>
      _content('userpreferences-$identifier');

  static String getGroupMessage(String groupId) => _contentMls('g-$groupId');

  static String getUserWelcome(String installationId) =>
      _contentMls('w-$installationId');

  static String ephemeralMessage(String conversationTopic) {
    checkArgument(
        conversationTopic.startsWith('$_versionPrefix/dm-') ||
            conversationTopic.startsWith('$_versionPrefix/m-'),
        message: 'invalid conversation topic');
    return conversationTopic
        .replaceFirst('$_versionPrefix/dm-', '$_versionPrefix/dmE-')
        .replaceFirst('$_versionPrefix/m-', '$_versionPrefix/mE-');
  }

  static Future<String> userPreferences(List<int> privateKey) async =>
      generatePrivatePreferencesTopicIdentifier(Uint8List.fromList(privateKey));

  static String _normalize(String? walletAddress) =>
      EthereumAddress.fromHex(walletAddress!).hexEip55;

  /// This method allows to know if the [Topic] is valid according to the accepted characters
  static bool isValidTopic(String topic) {
    final regex =
        RegExp(r'^[\x00-\x7F]+$'); // Use this regex to filter non ASCII chars
    final index = topic.indexOf("0/");
    if (index != -1) {
      final unContentpedtopic =
          topic.substring(index + 2, topic.lastIndexOf("/proto"));
      return regex.hasMatch(unContentpedtopic);
    }
    return false;
  }
}
