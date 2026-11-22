import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/core/constants/api_constants.dart';
import 'package:frontend/core/network/api_client.dart';
import 'package:frontend/features/document/domain/document_model.dart';

final Provider<DocumentRepository> documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return DocumentRepository(client);
});

/// Repository for Document CRUD operations against Oversee API backend.
class DocumentRepository {
  final ApiClient _client;

  DocumentRepository(this._client);

  /// Lists all non-deleted documents in a project (`GET /api/v1/projects/{project_id}/documents`).
  Future<List<DocumentModel>> listProjectDocuments(String projectId) async {
    final response = await _client.get<List<dynamic>>(
      '${ApiConstants.projects}/$projectId/documents',
    );
    return (response.data ?? [])
        .map((item) => DocumentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new document in a project (`POST /api/v1/projects/{project_id}/documents`).
  Future<DocumentModel> createDocument(
    String projectId, {
    required String title,
    String? content,
  }) async {
    final payload = <String, dynamic>{
      'title': title.trim(),
      if (content != null && content.trim().isNotEmpty) 'content': content.trim(),
    };

    final response = await _client.post<Map<String, dynamic>>(
      '${ApiConstants.projects}/$projectId/documents',
      data: payload,
    );
    return DocumentModel.fromJson(response.data!);
  }

  /// Retrieves a single document (`GET /api/v1/documents/{document_id}`).
  Future<DocumentModel> getDocument(String documentId) async {
    final response = await _client.get<Map<String, dynamic>>(
      '${ApiConstants.documents}/$documentId',
    );
    return DocumentModel.fromJson(response.data!);
  }

  /// Updates an existing document (`PATCH /api/v1/documents/{document_id}`).
  Future<DocumentModel> updateDocument(
    String documentId, {
    String? title,
    String? content,
  }) async {
    final payload = <String, dynamic>{
      if (title != null) 'title': title.trim(),
      if (content != null) 'content': content,
    };

    final response = await _client.patch<Map<String, dynamic>>(
      '${ApiConstants.documents}/$documentId',
      data: payload,
    );
    return DocumentModel.fromJson(response.data!);
  }

  /// Soft deletes a document (`DELETE /api/v1/documents/{document_id}`).
  Future<void> deleteDocument(String documentId) async {
    await _client.delete<void>('${ApiConstants.documents}/$documentId');
  }
}
