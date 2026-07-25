import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/models/category_model.dart';
import 'package:my_app/models/documentary_model.dart';
import 'package:my_app/models/documentary_interaction_model.dart';
import 'package:my_app/models/story_content_model.dart'; // reused: identical {chapters:[{chapterNo,text}]} shape
import 'package:my_app/models/comment_model.dart';

class DocumentaryService {
  final _dio = ApiClient.instance.dio;

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return fallback;
  }

  Future<List<DocumentaryModel>> fetchDocumentaries() async {
    try {
      final res = await _dio.get('/documentaries');
      final list = res.data as List;
      return list.map((json) => DocumentaryModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load documentaries.');
    }
  }

  /// Paginated + filtered variant -- used by the documentary grid's
  /// infinite scroll. sort/from/to are optional.
  Future<({List<DocumentaryModel> data, bool hasMore, int totalCount})> fetchDocumentariesPaged({
    required int page,
    int limit = 20,
    String? sort,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final res = await _dio.get('/documentaries', queryParameters: {
        'page': page,
        'limit': limit,
        if (sort != null) 'sort': sort,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      });
      final json = res.data as Map<String, dynamic>;
      final list = json['data'] as List;
      return (
        data: list.map((j) => DocumentaryModel.fromJson(j as Map<String, dynamic>)).toList(),
        hasMore: json['hasMore'] as bool,
        totalCount: json['totalCount'] as int,
      );
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load documentaries.');
    }
  }
  /// Single documentary by id -- used by the documentary detail screen.
  Future<DocumentaryModel> fetchDocumentaryById(String id) async {
    try {
      final res = await _dio.get('/documentaries/$id');
      return DocumentaryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load this documentary.');
    }
  }

  Future<List<DocumentaryModel>> fetchWatching() async {
    try {
      final res = await _dio.get('/documentaries/watching');
      final list = res.data as List;
      return list.map((json) => DocumentaryModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load your watching list.');
    }
  }

  Future<({List<DocumentaryModel> data, bool hasMore, int totalCount})> fetchHistoryPaged({
    required int page,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get('/documentaries/history', queryParameters: {'page': page, 'limit': limit});
      final json = res.data as Map<String, dynamic>;
      final list = json['data'] as List;
      return (
        data: list.map((j) => DocumentaryModel.fromJson(j as Map<String, dynamic>)).toList(),
        hasMore: json['hasMore'] as bool,
        totalCount: json['totalCount'] as int,
      );
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load history.');
    }
  }

  Future<DocumentaryInteractionModel> fetchInteractions(String documentaryId) async {
    try {
      final res = await _dio.get('/documentaries/$documentaryId/interactions');
      return DocumentaryInteractionModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load your activity for this documentary.');
    }
  }

  Future<int> registerView(String documentaryId) async {
    try {
      final res = await _dio.post('/documentaries/$documentaryId/view');
      return res.data['viewCount'] as int;
    } on DioException catch (e) {
      throw _extractError(e, 'Could not register the view.');
    }
  }

  Future<({bool liked, int likeCount})> toggleLike(String documentaryId) async {
    try {
      final res = await _dio.post('/documentaries/$documentaryId/like');
      return (liked: res.data['liked'] as bool, likeCount: res.data['likeCount'] as int);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not update like.');
    }
  }

  Future<double> rateDocumentary(String documentaryId, int rating) async {
    try {
      final res = await _dio.put('/documentaries/$documentaryId/rating', data: {'rating': rating});
      return (res.data['rating'] as num).toDouble();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not save your rating.');
    }
  }

  Future<void> updateProgress(String documentaryId, double progress) async {
    try {
      await _dio.put('/documentaries/$documentaryId/progress', data: {'progress': progress});
    } on DioException catch (e) {
      throw _extractError(e, 'Could not save your progress.');
    }
  }

  /// Documentary-wide comments, paginated -- newest first.
  Future<({List<CommentModel> data, bool hasMore, int totalCount})> fetchComments(
    String documentaryId, {
    required int page,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get('/documentaries/$documentaryId/comments', queryParameters: {'page': page, 'limit': limit});
      final json = res.data as Map<String, dynamic>;
      final list = json['data'] as List;
      return (
        data: list.map((j) => CommentModel.fromJson(j as Map<String, dynamic>)).toList(),
        hasMore: json['hasMore'] as bool,
        totalCount: json['totalCount'] as int,
      );
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load comments.');
    }
  }

  Future<CommentModel> postComment(String documentaryId, String text) async {
    try {
      final res = await _dio.post('/documentaries/$documentaryId/comments', data: {'text': text});
      return CommentModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not post your comment.');
    }
  }

  /// Fetches the chapters JSON straight from the CDN, same as
  /// StoryService.fetchStoryContent -- identical shape, so it reuses
  /// StoryContentModel rather than duplicating a parsing class.
  Future<StoryContentModel> fetchDocumentaryContent(String contentUrl) async {
    try {
      final plainDio = Dio();
      final res = await plainDio.get(contentUrl);
      return StoryContentModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (_) {
      throw 'Could not load the documentary text.';
    }
  }

  Future<List<CategoryModel>> fetchDocumentaryCategories() async {
    try {
      final res = await _dio.get('/documentary-categories');
      final list = res.data as List;
      return list.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load categories.');
    }
  }

  Future<CategoryModel> addDocumentaryCategory({required String name}) async {
    try {
      final res = await _dio.post('/documentary-categories', data: {'name': name});
      return CategoryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not create category.');
    }
  }

  /// Admin only -- same multipart shape as StoryService.addStory now:
  /// cover image FILE + category + chapters, not a plain URL.
  Future<DocumentaryModel> addDocumentary({
    required String title,
    required String categoryId,
    required List<Map<String, dynamic>> chapters,
    required Uint8List coverBytes,
    required String coverFilename,
    String status = 'ongoing',
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'categoryId': categoryId,
        'chapters': jsonEncode(chapters),
        'status': status,
        'cover': MultipartFile.fromBytes(coverBytes, filename: coverFilename),
      });
      final res = await _dio.post('/documentaries', data: formData);
      return DocumentaryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not create documentary.');
    }
  }
}
