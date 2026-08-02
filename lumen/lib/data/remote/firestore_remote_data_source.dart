import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/entities/enums.dart';
import '../sync/remote_data_source.dart';

/// Cloud Firestore + Storage implementation of [RemoteDataSource].
///
/// Everything is scoped under `users/{uid}` so security rules can enforce
/// per-user isolation (see docs/FIREBASE_SETUP.md). Book file blobs go to
/// Storage; only metadata lives in Firestore to keep document reads cheap.
///
/// Native/Firebase-backed — verified on device, not in the pure-Dart suite.
class FirestoreRemoteDataSource implements RemoteDataSource {
  FirestoreRemoteDataSource({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Cannot sync without a signed-in user.');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _collection(SyncEntityType type) =>
      _db
          .collection(AppConstants.usersCollection)
          .doc(_uid)
          .collection(_name(type));

  String _name(SyncEntityType type) => switch (type) {
        SyncEntityType.book => AppConstants.booksCollection,
        SyncEntityType.annotation => AppConstants.annotationsCollection,
        SyncEntityType.progress => AppConstants.progressCollection,
        SyncEntityType.collection => AppConstants.collectionsCollection,
        SyncEntityType.settings => AppConstants.settingsCollection,
        SyncEntityType.statistics => AppConstants.statisticsCollection,
      };

  @override
  Future<void> push(
    SyncEntityType type,
    String id,
    Map<String, dynamic> data,
  ) async {
    await _collection(type).doc(id).set(
      {
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<void> remove(SyncEntityType type, String id) async {
    // Tombstone rather than hard-delete, so the deletion syncs to other devices
    // and user data is never silently lost.
    await _collection(type).doc(id).set(
      {
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  @override
  Future<String> uploadBookFile(String bookId, String localPath) async {
    final ref = _storage
        .ref()
        .child(AppConstants.usersCollection)
        .child(_uid)
        .child('books')
        .child(bookId)
        .child('original');
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }

  @override
  Future<List<RemoteChange>> pullSince(DateTime? since) async {
    final changes = <RemoteChange>[];
    for (final type in SyncEntityType.values) {
      Query<Map<String, dynamic>> query = _collection(type);
      if (since != null) {
        query = query.where(
          'updatedAt',
          isGreaterThan: Timestamp.fromDate(since),
        );
      }
      final snap = await query.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['updatedAt'];
        changes.add(
          RemoteChange(
            type: type,
            id: doc.id,
            data: data,
            updatedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
            deleted: data['isDeleted'] == true,
          ),
        );
      }
    }
    return changes;
  }
}
