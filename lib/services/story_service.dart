import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/models/category_model.dart';
import 'package:my_app/models/story_content_model.dart';
import 'package:my_app/models/story_interaction_model.dart';
import 'package:my_app/models/story_model.dart';

class StoryService {
  final _dio = ApiClient.instance.dio;

  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['error'] != null) return data['error'].toString();
    return fallback;
  }

  /// All stories, newest first. Category/time filtering and sorting
  /// stays on-device -- catalog small enough for now.
  Future<List<StoryModel>> fetchStories() async {
    try {
      final res = await _dio.get('/stories');
      final list = res.data as List;
      return list.map((json) => StoryModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load stories.');
    }
  }

  /// Paginated + filtered variant -- used by the "All Stories" grid's
  /// infinite scroll. categoryId/from/to are optional; omit them for
  /// an unfiltered page.
  Future<({List<StoryModel> data, bool hasMore, int totalCount})> fetchStoriesPaged({
    required int page,
    int limit = 20,
    String? categoryId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final res = await _dio.get('/stories', queryParameters: {
        'page': page,
        'limit': limit,
        if (categoryId != null) 'categoryId': categoryId,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      });
      final json = res.data as Map<String, dynamic>;
      final list = json['data'] as List;
      return (
        data: list.map((j) => StoryModel.fromJson(j as Map<String, dynamic>)).toList(),
        hasMore: json['hasMore'] as bool,
        totalCount: json['totalCount'] as int,
      );
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load stories.');
    }
  }

  Future<List<CategoryModel>> fetchCategories() async {
    try {
      final res = await _dio.get('/categories');
      final list = res.data as List;
      return list.map((json) => CategoryModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load categories.');
    }
  }

  /// Admin only -- backend rejects this with 403 for non-admin users.
  Future<CategoryModel> addCategory({required String name}) async {
    try {
      final res = await _dio.post('/categories', data: {'name': name});
      return CategoryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not create category.');
    }
  }

  /// Admin only -- backend rejects this with 403 for non-admin users.
  /// title/categoryId text fields ki tarah, lekin cover ek image file
  /// (bytes) hai aur chapters ek list -- backend khud R2 pe upload
  /// karke JSON + image ke CDN URLs banata hai.
  Future<StoryModel> addStory({
    required String title,
    required String categoryId,
    required List<Map<String, dynamic>> chapters,
    required Uint8List coverBytes,
    required String coverFilename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'title': title,
        'categoryId': categoryId,
        'chapters': jsonEncode(chapters),
        'cover': MultipartFile.fromBytes(coverBytes, filename: coverFilename),
      });
      final res = await _dio.post('/stories', data: formData);
      return StoryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not create story.');
    }
  }

  /// Story ka actual text seedha CDN se fetch karta hai -- backend
  /// (_dio, jispe auth token attach hota hai) use nahi karta, kyunki
  /// ye ek alag public CDN domain hai, apna backend nahi.
  Future<StoryContentModel> fetchStoryContent(String contentUrl) async {
    try {
      final plainDio = Dio();
      final res = await plainDio.get(contentUrl);
      return StoryContentModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (_) {
      throw 'Could not load the story text.';
    }
  }
  /// Single story by id -- used by the story detail screen.
  Future<StoryModel> fetchStoryById(String id) async {
    try {
      final res = await _dio.get('/stories/$id');
      return StoryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load this story.');
    }
  }

  /// Stories the current user has started but not finished, most
  /// recently watched first -- powers the "Watching" section directly.
  Future<List<StoryModel>> fetchWatching() async {
    try {
      final res = await _dio.get('/stories/watching');
      final list = res.data as List;
      return list.map((json) => StoryModel.fromJson(json as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load your watching list.');
    }
  }

  /// The current user's personal state (liked / rating / progress) for
  /// one story. Requires login.
  Future<StoryInteractionModel> fetchInteractions(String storyId) async {
    try {
      final res = await _dio.get('/stories/$storyId/interactions');
      return StoryInteractionModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not load your activity for this story.');
    }
  }

  /// Registers that the current user opened this story. Safe to call
  /// every time the detail screen opens -- the backend only increments
  /// the aggregate viewCount once per user, so this never double-counts.
  Future<int> registerView(String storyId) async {
    try {
      final res = await _dio.post('/stories/$storyId/view');
      return res.data['viewCount'] as int;
    } on DioException catch (e) {
      throw _extractError(e, 'Could not register the view.');
    }
  }

  /// Toggles like on/off for the current user. Returns the new state.
  Future<({bool liked, int likeCount})> toggleLike(String storyId) async {
    try {
      final res = await _dio.post('/stories/$storyId/like');
      return (liked: res.data['liked'] as bool, likeCount: res.data['likeCount'] as int);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not update like.');
    }
  }

  /// Sets/updates the current user's 1-5 rating. Returns the story's
  /// new overall average rating.
  Future<double> rateStory(String storyId, int rating) async {
    try {
      final res = await _dio.put('/stories/$storyId/rating', data: {'rating': rating});
      return (res.data['rating'] as num).toDouble();
    } on DioException catch (e) {
      throw _extractError(e, 'Could not save your rating.');
    }
  }

  /// Saves watch/read progress (0.0 - 1.0) for the current user.
  Future<void> updateProgress(String storyId, double progress) async {
    try {
      await _dio.put('/stories/$storyId/progress', data: {'progress': progress});
    } on DioException catch (e) {
      throw _extractError(e, 'Could not save your progress.');
    }
  }
}
