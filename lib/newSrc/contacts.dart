import 'dart:convert';
import 'dart:typed_data';

import 'package:xmtp/newSrc/messages/bindingsCrypt.dart';
import 'package:xmtp/newSrc/client.dart';
import 'package:xmtp/newSrc/messages/contactBundle.dart';
import 'package:xmtp/newSrc/messages/envelope.dart';
import 'package:xmtp/newSrc/messages/paging_info.dart';
import 'package:xmtp/newSrc/messages/topic.dart';
import 'package:xmtp_proto/xmtp_proto.dart' as xmtp;

enum ConsentState {
  allowed,
  denied,
  unknown,
}

enum EntryType {
  address,
  groupId,
  inboxId,
}

class ConsentListEntry {
  final String value;
  final EntryType entryType;
  final ConsentState consentType;

  ConsentListEntry(
    this.value,
    this.entryType,
    this.consentType,
  );

  static ConsentListEntry address(
    String address, [
    ConsentState type = ConsentState.unknown,
  ]) {
    return ConsentListEntry(address, EntryType.address, type);
  }

  static ConsentListEntry groupId(
    Uint8List groupId, [
    ConsentState type = ConsentState.unknown,
  ]) {
    return ConsentListEntry(
        String.fromCharCodes(groupId), EntryType.groupId, type);
  }

  static ConsentListEntry inboxId(
    String inboxId, [
    ConsentState type = ConsentState.unknown,
  ]) {
    return ConsentListEntry(inboxId, EntryType.inboxId, type);
  }

  String get key => "${entryType.name}-$value";
}

class ConsentList {
  final Client client;
  final Map<String, ConsentListEntry> entries;
  DateTime? _lastFetched;
  late final Uint8List _publicKey;
  late final Uint8List _privateKey;
  late final Future<String> _identifier;

  ConsentList(
    this.client, {
    Map<String, ConsentListEntry>? entries,
  })  : entries = entries ?? {},
        _publicKey = Uint8List.fromList(client.privateKeyBundleV1.identityKey
            .publicKey.secp256k1Uncompressed.bytes),
        _privateKey = Uint8List.fromList(
            client.privateKeyBundleV1.identityKey.secp256k1.bytes),
        _identifier = generatePrivatePreferencesTopicIdentifier(
            Uint8List.fromList(
                client.privateKeyBundleV1.identityKey.secp256k1.bytes));

  Future<List<ConsentListEntry>> load() async {
    final newDate = DateTime.now();
    final envelopes = await client.apiClient.envelopes(
      Topic.preferenceList(await _identifier).description,
      pagination: Pagination(
          limit: 500,
          direction: xmtp.SortDirection.SORT_DIRECTION_ASCENDING,
          after: _lastFetched),
    );

    _lastFetched = newDate;
    final preferences = <xmtp.PrivatePreferencesAction>[];
    for (final envelope in envelopes) {
      final payload = userPreferencesDecrypt(
        _publicKey,
        _privateKey,
        Uint8List.fromList(envelope.message),
      );

      preferences.add(
        xmtp.PrivatePreferencesAction.fromBuffer(await payload),
      );
    }

    for (final preference in preferences) {
      for (final address in preference.allowAddress.walletAddresses) {
        allow(address);
      }
      for (final address in preference.denyAddress.walletAddresses) {
        deny(address);
      }
      for (final groupId in preference.allowGroup.groupIds) {
        allowGroup(Uint8List.fromList(groupId));
      }
      for (final groupId in preference.denyGroup.groupIds) {
        denyGroup(Uint8List.fromList(groupId));
      }

      for (final inboxId in preference.allowInboxId.inboxIds) {
        allowInboxId(inboxId);
      }
      for (final inboxId in preference.denyInboxId.inboxIds) {
        denyInboxId(inboxId);
      }
    }

    return entries.values.toList();
  }

  Future<void> publish(List<ConsentListEntry> entries) async {
    final payload = xmtp.PrivatePreferencesAction(
      allowAddress: xmtp.PrivatePreferencesAction_AllowAddress(
        walletAddresses: entries
            .where((entry) =>
                entry.entryType == EntryType.address &&
                entry.consentType == ConsentState.allowed)
            .map((entry) => entry.value)
            .toList(),
      ),
      denyAddress: xmtp.PrivatePreferencesAction_DenyAddress(
        walletAddresses: entries
            .where((entry) =>
                entry.entryType == EntryType.address &&
                entry.consentType == ConsentState.denied)
            .map((entry) => entry.value)
            .toList(),
      ),
      allowGroup: xmtp.PrivatePreferencesAction_AllowGroup(
        groupIds: entries
            .where((entry) =>
                entry.entryType == EntryType.groupId &&
                entry.consentType == ConsentState.allowed)
            .map((entry) => Uint8List.fromList(utf8.encode(entry.value)))
            .toList(),
      ),
      denyGroup: xmtp.PrivatePreferencesAction_DenyGroup(
        groupIds: entries
            .where((entry) =>
                entry.entryType == EntryType.groupId &&
                entry.consentType == ConsentState.denied)
            .map((entry) => Uint8List.fromList(utf8.encode(entry.value)))
            .toList(),
      ),
      allowInboxId: xmtp.PrivatePreferencesAction_AllowInboxId(
        inboxIds: entries
            .where((entry) =>
                entry.entryType == EntryType.inboxId &&
                entry.consentType == ConsentState.allowed)
            .map((entry) => entry.value)
            .toList(),
      ),
      denyInboxId: xmtp.PrivatePreferencesAction_DenyInboxId(
        inboxIds: entries
            .where((entry) =>
                entry.entryType == EntryType.inboxId &&
                entry.consentType == ConsentState.denied)
            .map((entry) => entry.value)
            .toList(),
      ),
    );

    final message = userPreferencesEncrypt(
      _publicKey,
      _privateKey,
      payload.writeToBuffer(),
    );

    final envelope = EnvelopeBuilder.buildFromTopic(
      Topic.preferenceList(await _identifier),
      DateTime.now(),
      await message,
    );

    await client.publish([envelope]);
  }

  ConsentListEntry allow(String address) {
    final entry = ConsentListEntry.address(address, ConsentState.allowed);
    entries[entry.key] = entry;
    return entry;
  }

  ConsentListEntry deny(String address) {
    final entry = ConsentListEntry.address(address, ConsentState.denied);
    entries[entry.key] = entry;
    return entry;
  }

  ConsentListEntry allowGroup(Uint8List groupId) {
    final entry = ConsentListEntry.groupId(groupId, ConsentState.allowed);
    entries[entry.key] = entry;
    return entry;
  }

  ConsentListEntry denyGroup(Uint8List groupId) {
    final entry = ConsentListEntry.groupId(groupId, ConsentState.denied);
    entries[entry.key] = entry;
    return entry;
  }

  ConsentListEntry allowInboxId(String inboxId) {
    final entry = ConsentListEntry.inboxId(inboxId, ConsentState.allowed);
    entries[entry.key] = entry;
    return entry;
  }

  ConsentListEntry denyInboxId(String inboxId) {
    final entry = ConsentListEntry.inboxId(inboxId, ConsentState.denied);
    entries[entry.key] = entry;
    return entry;
  }

  ConsentState state(String address) {
    final entry = entries[ConsentListEntry.address(address).key];
    return entry?.consentType ?? ConsentState.unknown;
  }

  ConsentState groupState(Uint8List groupId) {
    final entry = entries[ConsentListEntry.groupId(groupId).key];
    return entry?.consentType ?? ConsentState.unknown;
  }

  ConsentState inboxIdState(String inboxId) {
    final entry = entries[ConsentListEntry.inboxId(inboxId).key];
    return entry?.consentType ?? ConsentState.unknown;
  }
}

class Contacts {
  final Client client;
  final Map<String, ContactBundle> knownBundles;
  final Map<String, bool> hasIntroduced;
  late final ConsentList consentList;

  Contacts(
    this.client, {
    Map<String, ContactBundle>? knownBundles,
    Map<String, bool>? hasIntroduced,
  })  : knownBundles = knownBundles ?? {},
        hasIntroduced = hasIntroduced ?? {},
        consentList = ConsentList(client);

  Future<ConsentList> refreshConsentList() async {
    await consentList.load();
    return consentList;
  }

  Future<void> allow(List<String> addresses) async {
    final entries =
        addresses.map((address) => consentList.allow(address)).toList();
    await consentList.publish(entries);
  }

  Future<void> deny(List<String> addresses) async {
    final entries =
        addresses.map((address) => consentList.deny(address)).toList();
    await consentList.publish(entries);
  }

  Future<void> allowGroups(List<Uint8List> groupIds) async {
    final entries =
        groupIds.map((groupId) => consentList.allowGroup(groupId)).toList();
    await consentList.publish(entries);
  }

  Future<void> denyGroups(List<Uint8List> groupIds) async {
    final entries =
        groupIds.map((groupId) => consentList.denyGroup(groupId)).toList();
    await consentList.publish(entries);
  }

  Future<void> allowInboxes(List<String> inboxIds) async {
    final entries =
        inboxIds.map((inboxId) => consentList.allowInboxId(inboxId)).toList();
    await consentList.publish(entries);
  }

  Future<void> denyInboxes(List<String> inboxIds) async {
    final entries =
        inboxIds.map((inboxId) => consentList.denyInboxId(inboxId)).toList();
    await consentList.publish(entries);
  }

  bool isAllowed(String address) {
    return consentList.state(address) == ConsentState.allowed;
  }

  bool isDenied(String address) {
    return consentList.state(address) == ConsentState.denied;
  }

  bool isGroupAllowed(Uint8List groupId) {
    return consentList.groupState(groupId) == ConsentState.allowed;
  }

  bool isGroupDenied(Uint8List groupId) {
    return consentList.groupState(groupId) == ConsentState.denied;
  }

  bool isInboxAllowed(String inboxId) {
    return consentList.inboxIdState(inboxId) == ConsentState.allowed;
  }

  bool isInboxDenied(String inboxId) {
    return consentList.inboxIdState(inboxId) == ConsentState.denied;
  }

  bool has(String peerAddress) => knownBundles[peerAddress] != null;

  bool needsIntroduction(String peerAddress) =>
      hasIntroduced[peerAddress] != true;

  Future<ContactBundle?> find(String peerAddress) async {
    final knownBundle = knownBundles[peerAddress];
    if (knownBundle != null) {
      return knownBundle;
    }
    final response = await client.query(Topic.contact(peerAddress));

    if (response.envelopes.isEmpty) return null;

    for (final envelope in response.envelopes) {
      final contactBundle = ContactBundleBuilder.buildFromEnvelope(envelope);
      knownBundles[peerAddress] = contactBundle;
      final address = contactBundle.walletAddress;
      if (address?.toLowerCase() == peerAddress.toLowerCase()) {
        return contactBundle;
      }
    }

    return null;
  }
}
