import 'package:dio/dio.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/models/category_model.dart';
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
}
