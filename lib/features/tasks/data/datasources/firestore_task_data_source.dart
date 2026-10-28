import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:todo/core/error/exceptions.dart';
import 'package:todo/features/auth/domain/repositories/current_user_id_provider.dart';
import 'package:todo/features/tasks/data/datasources/task_remote_data_source.dart';
import 'package:todo/features/tasks/data/models/task_model.dart';

/// Android, iOS and macOS, through the FlutterFire SDK, at
/// `users/{uid}/tasks/{taskId}`.
///
/// Reads go to the server and writes run in transactions, which fail when
/// offline instead of being queued. That keeps the behavior equal to the REST
/// data source on Windows: a failed change is reported and never applied
/// later behind the user's back.
final class FirestoreTaskDataSource implements TaskRemoteDataSource {
  const FirestoreTaskDataSource(
    this._firestore,
    this._userIdProvider, {
    this.timeout = const Duration(seconds: 15),
  });

  final FirebaseFirestore _firestore;
  final CurrentUserIdProvider _userIdProvider;
  final Duration timeout;

  @override
  Future<List<TaskModel>> getAll() => _guard(() async {
    final snapshot = await _tasks().get(
      const GetOptions(source: Source.server),
    );
    return [
      for (final doc in snapshot.docs)
        TaskModel.fromMap(doc.id, _withDateTimes(doc.data())),
    ];
  });

  @override
  Future<TaskModel> create(TaskModel draft) => _guard(() async {
    final ref = _tasks().doc();
    final created = draft.withId(ref.id);
    await _firestore.runTransaction((tx) async => tx.set(ref, created.toMap()));
    return created;
  });

  @override
  Future<void> update(TaskModel task) => _guard(() async {
    final ref = _tasks().doc(task.id);
    await _firestore.runTransaction((tx) async {
      final current = await tx.get(ref);
      if (!current.exists) {
        throw const RemoteException(RemoteErrorKind.notFound);
      }
      tx.set(ref, task.toMap());
    });
  });

  @override
  Future<void> delete(String id) => _guard(() async {
    final ref = _tasks().doc(id);
    await _firestore.runTransaction((tx) async => tx.delete(ref));
  });

  CollectionReference<Map<String, Object?>> _tasks() {
    final uid = _userIdProvider.currentUserId;
    if (uid == null) {
      throw const RemoteException(RemoteErrorKind.unauthenticated);
    }
    return _firestore.collection('users').doc(uid).collection('tasks');
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(timeout);
    } on TimeoutException {
      throw const RemoteException(RemoteErrorKind.network, 'timeout');
    } on FirebaseException catch (e) {
      throw RemoteException(switch (e.code) {
        'unavailable' || 'deadline-exceeded' => RemoteErrorKind.network,
        'unauthenticated' => RemoteErrorKind.unauthenticated,
        'permission-denied' => RemoteErrorKind.permissionDenied,
        'not-found' => RemoteErrorKind.notFound,
        _ => RemoteErrorKind.unknown,
      }, e.code);
    }
  }

  static Map<String, Object?> _withDateTimes(Map<String, Object?> data) => {
    for (final MapEntry(:key, :value) in data.entries)
      key: value is Timestamp ? value.toDate().toUtc() : value,
  };
}
