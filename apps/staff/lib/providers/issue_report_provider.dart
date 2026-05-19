/// Issue Report Riverpod provider — 목록 + 디테일 캐싱.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/issue_report.dart';
import '../services/issue_report_service.dart';

class IssueReportListState {
  final List<IssueReport> items;
  final int total;
  final bool isLoading;
  final String? error;
  final String? storeFilter;
  final String? statusFilter;

  const IssueReportListState({
    this.items = const [],
    this.total = 0,
    this.isLoading = false,
    this.error,
    this.storeFilter,
    this.statusFilter,
  });

  IssueReportListState copyWith({
    List<IssueReport>? items,
    int? total,
    bool? isLoading,
    String? error,
    String? storeFilter,
    String? statusFilter,
    bool clearError = false,
  }) {
    return IssueReportListState(
      items: items ?? this.items,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      storeFilter: storeFilter ?? this.storeFilter,
      statusFilter: statusFilter ?? this.statusFilter,
    );
  }
}

class IssueReportNotifier extends StateNotifier<IssueReportListState> {
  final IssueReportService _service;

  IssueReportNotifier(this._service) : super(const IssueReportListState());

  Future<void> load({String? storeId, String? status}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final r = await _service.listReports(
        storeId: storeId,
        status: status,
      );
      state = state.copyWith(
        items: r.items,
        total: r.total,
        isLoading: false,
        storeFilter: storeId,
        statusFilter: status,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<IssueReport?> createReport({
    required String storeId,
    required String title,
    required String category,
    required String severity,
    String? description,
    List<IssueAttachment> attachments = const [],
    Map<String, dynamic> customFieldValues = const {},
    List<String> extraViewerUserIds = const [],
    Map<String, List<String>> links = const {},
  }) async {
    try {
      final created = await _service.createReport(
        storeId: storeId,
        title: title,
        category: category,
        severity: severity,
        description: description,
        attachments: attachments,
        customFieldValues: customFieldValues,
        extraViewerUserIds: extraViewerUserIds,
        links: links,
      );
      await load(storeId: state.storeFilter, status: state.statusFilter);
      return created;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

final issueReportProvider =
    StateNotifierProvider<IssueReportNotifier, IssueReportListState>((ref) {
  return IssueReportNotifier(ref.read(issueReportServiceProvider));
});
