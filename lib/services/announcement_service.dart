import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement.dart';
import 'api_client.dart';

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  return AnnouncementService(ref.read(dioProvider));
});

class AnnouncementService {
  final Dio _dio;

  AnnouncementService(this._dio);

  Future<List<Announcement>> getAnnouncements({int? page, int? perPage}) async {
    final params = <String, dynamic>{};
    if (page != null) params['page'] = page;
    if (perPage != null) params['per_page'] = perPage;

    final response = await _dio.get('/app/announcements', queryParameters: params);
    final list = response.data is List ? response.data : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List).map((e) => Announcement.fromJson(e)).toList();
  }

  Future<Announcement> getAnnouncement(String id) async {
    final response = await _dio.get('/app/announcements/$id');
    return Announcement.fromJson(response.data);
  }
}
