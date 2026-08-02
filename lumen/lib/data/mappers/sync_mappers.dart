import 'dart:convert';

import '../../domain/entities/sync_operation.dart';
import '../local/isar_ids.dart';
import '../local/models/sync_models.dart';

extension SyncOperationModelMapper on SyncOperationModel {
  SyncOperation toEntity() => SyncOperation(
        id: uid,
        entityType: entityType,
        entityId: entityId,
        action: action,
        createdAt: createdAt,
        status: status,
        retryCount: retryCount,
        lastError: lastError,
        nextAttemptAt: nextAttemptAt,
        payload: payloadJson == null
            ? null
            : jsonDecode(payloadJson!) as Map<String, dynamic>,
      );
}

extension SyncOperationEntityMapper on SyncOperation {
  SyncOperationModel toModel() => SyncOperationModel()
    ..id = fastHash(id)
    ..uid = id
    ..entityType = entityType
    ..entityId = entityId
    ..action = action
    ..status = status
    ..retryCount = retryCount
    ..lastError = lastError
    ..nextAttemptAt = nextAttemptAt
    ..payloadJson = payload == null ? null : jsonEncode(payload)
    ..createdAt = createdAt;
}
