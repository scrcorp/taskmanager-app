import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../config/constants.dart';
import '../models/announcement.dart';
import 'mock_services.dart';

final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  if (AppConstants.useMock) return MockAnnouncementService();
  return AnnouncementService(ref.read(dioProvider));
});

class AnnouncementService {
  final Dio _dio;
  AnnouncementService(this._dio);

  Future<List<Announcement>> getAnnouncements({int? page, int? perPage}) async {
    final response = await _dio.get('/app/my/announcements', queryParameters: {
      if (page != null) 'page': page,
      if (perPage != null) 'per_page': perPage,
    });
    final items = response.data['items'] ?? response.data;
    return (items as List).map((e) => Announcement.fromJson(e)).toList();
  }

  Future<Announcement> getAnnouncement(String id) async {
    final response = await _dio.get('/app/my/announcements/$id');
    return Announcement.fromJson(response.data);
  }
}
