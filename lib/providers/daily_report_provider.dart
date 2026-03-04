/// Daily Report 상태 관리 Provider
///
/// 일일 리포트 목록 조회, 상세 조회, 생성, 수정, 제출을 관리.
/// DailyReportListScreen, DailyReportDetailScreen 등에서 사용.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/daily_report.dart';
import '../services/daily_report_service.dart';

/// Daily Report 상태 데이터
class DailyReportState {
  final List<DailyReport> reports;
  final DailyReport? selected;
  final DailyReportTemplate? template;
  final bool isLoading;
  final String? error;

  const DailyReportState({
    this.reports = const [],
    this.selected,
    this.template,
    this.isLoading = false,
    this.error,
  });

  DailyReportState copyWith({
    List<DailyReport>? reports,
    DailyReport? selected,
    DailyReportTemplate? template,
    bool? isLoading,
    String? error,
  }) {
    return DailyReportState(
      reports: reports ?? this.reports,
      selected: selected ?? this.selected,
      template: template ?? this.template,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Daily Report Provider
final dailyReportProvider =
    StateNotifierProvider<DailyReportNotifier, DailyReportState>((ref) {
  return DailyReportNotifier(ref.read(dailyReportServiceProvider));
});

/// Daily Report 상태 관리 Notifier
class DailyReportNotifier extends StateNotifier<DailyReportState> {
  final DailyReportService _service;

  DailyReportNotifier(this._service) : super(const DailyReportState());

  /// 내 리포트 목록 로드
  Future<void> loadReports({String? storeId, String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.getMyReports(
        storeId: storeId,
        status: status,
      );
      state = state.copyWith(reports: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 리포트 상세 로드
  Future<void> loadReport(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final report = await _service.getReport(id);
      state = state.copyWith(selected: report, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 템플릿 로드
  Future<void> loadTemplate({String? storeId}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final template = await _service.getTemplate(storeId: storeId);
      state = state.copyWith(template: template, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 리포트 생성 — 성공 시 생성된 리포트 반환
  Future<DailyReport?> createReport({
    required String storeId,
    required String reportDate,
    required String period,
    String? templateId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final report = await _service.createReport(
        storeId: storeId,
        reportDate: reportDate,
        period: period,
        templateId: templateId,
      );
      state = state.copyWith(selected: report, isLoading: false);
      return report;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// 리포트 섹션 내용 업데이트
  Future<bool> updateReport(
    String id,
    List<Map<String, String?>> sections,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final report = await _service.updateReport(id, sections);
      state = state.copyWith(
        selected: report,
        reports: state.reports.map((r) => r.id == id ? report : r).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 리포트 제출
  Future<bool> submitReport(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final report = await _service.submitReport(id);
      state = state.copyWith(
        selected: report,
        reports: state.reports.map((r) => r.id == id ? report : r).toList(),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// 선택된 리포트 초기화
  void clearSelected() {
    state = state.copyWith(selected: null);
  }
}
