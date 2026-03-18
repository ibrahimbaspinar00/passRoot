import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/vault_record.dart';

class FirebaseVaultSyncService {
  FirebaseVaultSyncService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<String> _requireUserId() async {
    final existing = _auth.currentUser;
    if (existing != null) {
      return existing.uid;
    }
    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw const _FirebaseSyncError(
          'Firebase anonim oturumu acilamadi.',
        );
      }
      return user.uid;
    } on FirebaseAuthException catch (error) {
      if (error.code == 'operation-not-allowed') {
        throw const _FirebaseSyncError(
          'Firebase Authentication icinde Anonymous sign-in aktif edilmeli.',
        );
      }
      throw _FirebaseSyncError(
        'Firebase giris hatasi: ${error.message ?? error.code}',
      );
    }
  }

  DocumentReference<Map<String, dynamic>> _backupRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('vault_backups')
        .doc('main');
  }

  Future<int> uploadEncryptedPayload({
    required String encryptedPayload,
    required int recordCount,
  }) async {
    final uid = await _requireUserId();
    await _backupRef(uid).set(<String, dynamic>{
      'encryptedPayload': encryptedPayload,
      'encryptionScheme': 'aes256gcm-pbkdf2-sha256-v1',
      'recordCount': recordCount,
      'records': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return recordCount;
  }

  Future<FirebaseVaultBackupData?> downloadBackupData() async {
    final uid = await _requireUserId();
    final snapshot = await _backupRef(uid).get();
    if (!snapshot.exists) {
      return null;
    }
    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final encryptedPayload = (data['encryptedPayload'] as String?)?.trim();
    if (encryptedPayload != null && encryptedPayload.isNotEmpty) {
      return FirebaseVaultBackupData.encrypted(encryptedPayload);
    }

    final rawRecords = data['records'];
    if (rawRecords is! List) {
      return const FirebaseVaultBackupData.plain(<VaultRecord>[]);
    }
    final parsed = <VaultRecord>[];
    for (final item in rawRecords) {
      if (item is Map<String, dynamic>) {
        parsed.add(VaultRecord.fromJson(item));
      } else if (item is Map) {
        parsed.add(VaultRecord.fromJson(item.cast<String, dynamic>()));
      }
    }
    return FirebaseVaultBackupData.plain(parsed);
  }
}

class FirebaseVaultBackupData {
  const FirebaseVaultBackupData._({
    required this.encryptedPayload,
    required this.plainRecords,
  });

  const FirebaseVaultBackupData.encrypted(String payload)
    : this._(encryptedPayload: payload, plainRecords: null);

  const FirebaseVaultBackupData.plain(List<VaultRecord> records)
    : this._(encryptedPayload: null, plainRecords: records);

  final String? encryptedPayload;
  final List<VaultRecord>? plainRecords;

  bool get isEncrypted =>
      (encryptedPayload ?? '').trim().isNotEmpty && plainRecords == null;
}

class _FirebaseSyncError implements Exception {
  const _FirebaseSyncError(this.message);

  final String message;

  @override
  String toString() => message;
}
