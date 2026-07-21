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
  /// stays on-device (same as the old dummy-data days) -- the catalog
  /// is small enough that fetching everything once and slicing it
  /// client-side is simpler than a query-param API.
  Future<List<StoryModel>> fetchStories() async {
    try {
      final res = await _dio.get('/stories');
      final list = res.data as List;
      return list.map((json) => StoryModel.fromJson(json as Map<String, dynamic>)).toList();
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
  Future<StoryModel> addStory({
    required String title,
    required String coverImageUrl,
    required String contentUrl,
    required String categoryId,
    double rating = 0,
    int viewCount = 0,
    int likeCount = 0,
    int commentCount = 0,
  }) async {
    try {
      final res = await _dio.post('/stories', data: {
        'title': title,
        'coverImageUrl': coverImageUrl,
        'contentUrl': contentUrl,
        'categoryId': categoryId,
        'rating': rating,
        'viewCount': viewCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
      });
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
