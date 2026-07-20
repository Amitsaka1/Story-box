import 'package:dio/dio.dart';
import 'package:my_app/core/api_client.dart';
import 'package:my_app/models/documentary_model.dart';

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

  /// Admin only -- backend rejects this with 403 for non-admin users.
  Future<DocumentaryModel> addDocumentary({
    required String title,
    required String coverImageUrl,
    double rating = 0,
    int viewCount = 0,
    int likeCount = 0,
    int commentCount = 0,
  }) async {
    try {
      final res = await _dio.post('/documentaries', data: {
        'title': title,
        'coverImageUrl': coverImageUrl,
        'rating': rating,
        'viewCount': viewCount,
        'likeCount': likeCount,
        'commentCount': commentCount,
      });
      return DocumentaryModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e, 'Could not create documentary.');
    }
  }
}
