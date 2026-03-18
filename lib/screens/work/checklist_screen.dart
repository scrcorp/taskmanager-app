/// 체크리스트 상세 화면 (개선)
///
/// 필터 탭 (전체/미완료/완료/반려)으로 항목 필터링.
/// 항목 탭: 완료 다이얼로그 or 채팅 화면 이동 (두 경로).
/// 항목 롱프레스: 체크 해제 (리뷰 없을 때만).
/// 모든 항목 완료 시 Send Report 버튼 활성화.
///
/// 사진 업로드: StorageService presigned URL 방식 (다중 사진 지원).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../models/checklist.dart';
import '../../models/my_schedule.dart';
import '../../providers/my_schedule_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';
import 'checklist_chat_screen.dart';

/// 체크리스트 필터 탭
enum _ChecklistFilter { all, todo, done, rejected }

/// 체크리스트 상세 화면 위젯
class ChecklistScreen extends ConsumerStatefulWidget {
  final String id;
  const ChecklistScreen({super.key, required this.id});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen>
    with SingleTickerProviderStateMixin {
  bool _celebrationShown = false;
  bool _isUploading = false;
  _ChecklistFilter _filter = _ChecklistFilter.all;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        _filter = _ChecklistFilter.values[_tabController.index];
      });
    });
    // If checklist is already complete on load, suppress the celebration toast
    final schedule = ref.read(myScheduleProvider).selected;
    if (schedule?.checklistSnapshot?.isAllCompleted == true) {
      _celebrationShown = true;
    }
    Future.microtask(
        () => ref.read(myScheduleProvider.notifier).loadSchedule(widget.id));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCompletionToast() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    ToastManager().success(context, 'All items completed! Great work.');
  }

  List<ChecklistItem> _applyFilter(List<ChecklistItem> items) {
    List<ChecklistItem> filtered;
    switch (_filter) {
      case _ChecklistFilter.all:
        filtered = List<ChecklistItem>.from(items);
        break;
      case _ChecklistFilter.todo:
        filtered = items.where((i) => !i.isCompleted).toList();
        break;
      case _ChecklistFilter.done:
        filtered = items.where((i) => i.isCompleted && !i.isRejected).toList();
        break;
      case _ChecklistFilter.rejected:
        filtered = items.where((i) => i.isRejected && !i.isResolved).toList();
        break;
    }
    // Sort: incomplete first, then completed
    if (_filter == _ChecklistFilter.all) {
      filtered.sort((a, b) {
        if (!a.isCompleted && b.isCompleted) return -1;
        if (a.isCompleted && !b.isCompleted) return 1;
        return 0;
      });
    }
    return filtered;
  }

  /// 항목 체크박스 영역 탭 → 미완료: 완료 다이얼로그 / 완료: undo 플로우
  void _onCheckTap(ChecklistItem item) async {
    if (_isUploading) return;

    // 반려 미해결 → resubmit 다이얼로그 (이전 제출 내용 미리 채움)
    if (item.isRejected && !item.isResolved) {
      await _handleResubmit(item);
      return;
    }

    // 완료 항목 → 제출 내역 다이얼로그 (체크 아이콘은 undo, 나머지는 여기)
    if (item.isCompleted) {
      _showSubmittedDialog(item);
      return;
    }

    // 미완료 → 완료 처리 다이얼로그
    await _handleCompletion(item);
  }

  /// 채팅 아이콘 버튼 탭 → 채팅 화면으로 이동
  Future<void> _openChatScreen(ChecklistItem item) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChecklistChatScreen(
          scheduleId: widget.id,
          item: item,
        ),
      ),
    );
    // 채팅 화면에서 돌아오면 데이터 새로고침
    if (mounted) {
      ref.read(myScheduleProvider.notifier).loadSchedule(widget.id);
    }
  }

  /// 재제출 — 이전 제출 내용 미리 채운 다이얼로그
  Future<void> _handleResubmit(ChecklistItem item) async {
    final result = await showDialog<_CompletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CompletionFormDialog(
        item: item,
        storageProvider: ref.read(storageServiceProvider),
        scheduleId: widget.id,
        isResubmit: true,
        initialPhotoUrls: item.photoUrls,
        initialNote: item.note,
      ),
    );
    if (result == null) return;

    try {
      await ref.read(myScheduleProvider.notifier).respondToRejection(
            widget.id,
            item.index,
            responseComment: result.note,
            photoUrls: result.photoUrls,
          );
      if (mounted) ToastManager().success(context, 'Resubmitted.');
    } catch (e) {
      if (mounted) ToastManager().error(context, 'Failed to resubmit. Please try again.');
    }
  }

  /// 항목 완료 처리 — 자기완결형 다이얼로그에서 사진+텍스트 수집+확인
  Future<void> _handleCompletion(ChecklistItem item) async {
    final result = await showDialog<_CompletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _CompletionFormDialog(
        item: item,
        storageProvider: ref.read(storageServiceProvider),
        scheduleId: widget.id,
      ),
    );
    if (result == null) return; // cancelled

    try {
      await ref.read(myScheduleProvider.notifier).toggleChecklistItem(
            widget.id,
            item.index,
            true,
            photoUrls: result.photoUrls.isEmpty ? null : result.photoUrls,
            note: result.note,
          );
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Failed to complete item. Please try again.');
      }
    }
  }

  /// 항목 롱프레스 → 체크 해제 옵션 (리뷰 없거나 pending_re_review 이고 미재검토 시만)
  void _onItemLongPress(ChecklistItem item) async {
    if (!item.isCompleted) return;
    // pass/fail 리뷰가 존재하면 해제 불가
    // pending_re_review는 아직 재검토 전이므로 해제 허용
    final canUncomplete = item.reviewResult == null ||
        (item.isPendingReReview && item.reviewsLog.isEmpty);
    if (!canUncomplete) {
      _showBlockedUncompleteDialog(item);
      return;
    }
    final confirmed = await _showUncompleteDialog(item);
    if (!confirmed) return;

    try {
      final schedule = ref.read(myScheduleProvider).selected;
      final instanceId = schedule?.checklistInstanceId;
      if (instanceId == null) return;
      await ref.read(myScheduleProvider.notifier).uncompleteItem(
            instanceId,
            item.index,
            scheduleId: widget.id,
          );
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Failed to undo. Please try again.');
      }
    }
  }

  // _showConfirmDialog, _showCompletionDialog 제거됨 → _CompletionFormDialog로 통합

  /// 체크 해제 확인 다이얼로그
  Future<bool> _showUncompleteDialog(ChecklistItem item) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: EdgeInsets.zero,
            content: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.warningBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.undo_rounded, color: AppColors.warning),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Undo Complete',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Are you sure you want to undo this item?',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Undo', style: TextStyle(color: AppColors.warning)),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// 리뷰 존재로 해제 불가 안내 다이얼로그
  void _showBlockedUncompleteDialog(ChecklistItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_rounded, color: AppColors.warning),
              ),
              const SizedBox(height: 14),
              const Text(
                'Cannot Uncheck',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Reviewed items cannot be unchecked.',
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  /// 리포트 제출 확인 다이얼로그
  Future<void> _onSendReport() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: EdgeInsets.zero,
            content: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send_rounded, color: AppColors.accent),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Submit Report',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Submit checklist completion report? Changes may be restricted after submission.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    try {
      final schedule = ref.read(myScheduleProvider).selected;
      final instanceId = schedule?.checklistInstanceId;
      if (instanceId == null) return;
      await ref.read(myScheduleProvider.notifier).sendReport(instanceId, scheduleId: widget.id);
      if (mounted) {
        ToastManager().success(context, 'Report submitted.');
      }
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Failed to submit report. Please try again.');
      }
    }
  }

  Future<String?> _handlePhotoCapture() async {
    final source = await _showPhotoSourceSheet();
    if (source == null) return null;

    final picker = ImagePicker();
    final XFile? picked = source == ImageSource.camera
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return null;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final filename = 'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const contentType = 'image/jpeg';
      final storage = ref.read(storageServiceProvider);
      final urls = await storage.getPresignedUrl(filename, contentType);
      await storage.uploadFile(urls['upload_url']!, bytes, contentType);
      return urls['file_url'];
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Photo upload failed');
      }
      return null;
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// 완료 항목 탭 → 제출 내역 보기 다이얼로그
  void _showSubmittedDialog(ChecklistItem item) {
    final photos = item.photoUrls;
    final note = item.note;
    final reviewStatus = item.reviewResult;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: item.isApproved
                          ? AppColors.success.withOpacity(0.15)
                          : item.isRejected
                              ? AppColors.danger.withOpacity(0.15)
                              : AppColors.accentBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      item.isApproved ? Icons.check_circle : item.isRejected ? Icons.cancel : Icons.info_outline,
                      color: item.isApproved ? AppColors.success : item.isRejected ? AppColors.danger : AppColors.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        if (reviewStatus != null)
                          Text(
                            reviewStatus == 'pass' ? 'Approved' : reviewStatus == 'fail' ? 'Rejected' : 'Pending Re-review',
                            style: TextStyle(
                              fontSize: 13,
                              color: reviewStatus == 'pass' ? AppColors.success : reviewStatus == 'fail' ? AppColors.danger : AppColors.warning,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Photos
              if (photos.isNotEmpty) ...[
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        photos[i], width: 80, height: 80, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 80, height: 80,
                          color: AppColors.bg,
                          child: const Icon(Icons.broken_image, color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Note
              if (note != null && note.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(note, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 12),
              ],

              if (photos.isEmpty && (note == null || note.isEmpty))
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('No attachments', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                ),

              // Close button
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    alignment: Alignment.center,
                    child: const Text('Close', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<ImageSource?> _showPhotoSourceSheet() {
    return showDialog<ImageSource>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppColors.accent, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Photo',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.accent),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.accent),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myScheduleProvider);
    final schedule = state.selected;

    if (schedule != null &&
        schedule.checklistSnapshot != null &&
        schedule.checklistSnapshot!.isAllCompleted &&
        !_celebrationShown) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showCompletionToast());
    }

    final snapshot = schedule?.checklistSnapshot;
    final allItems = snapshot?.items ?? [];
    final filteredItems = _applyFilter(allItems);

    final todoCount = allItems.where((i) => !i.isCompleted).length;
    final doneCount = allItems.where((i) => i.isCompleted && !i.isRejected).length;
    final rejectedCount = allItems.where((i) => i.isRejected && !i.isResolved).length;

    final isAllDone = snapshot?.isAllCompleted ?? false;
    final isAllPassed = snapshot?.isAllPassed ?? false;
    final hasUnresolvedRejection = snapshot?.unresolvedRejections.isNotEmpty ?? false;
    final isReported = schedule?.isReported ?? false;
    // all done (모든 리뷰 pass) → report 버튼 숨김
    // report 가능: 전부 완료 + 미해결 반려 없음 + 아직 report 안 보냄
    final canReport = isAllDone && !hasUnresolvedRejection && !isReported;
    final hideReport = isAllPassed; // 모든 리뷰 통과 → 완전 종료

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.bg,
          body: Column(
            children: [
              AppHeader(
                title: schedule?.store.name ?? 'Checklist',
                isDetail: true,
                onBack: () => context.pop(),
              ),
              if (state.isLoading && schedule == null)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (state.error != null && schedule == null)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Failed to load schedule',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => ref
                                .read(myScheduleProvider.notifier)
                                .loadSchedule(widget.id),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (schedule == null)
                const Expanded(child: Center(child: Text('Schedule not found.')))
              else ...[
                // Progress section
                _ProgressSection(schedule: schedule),
                // Filter tab bar
                _FilterTabBar(
                  controller: _tabController,
                  allCount: allItems.length,
                  todoCount: todoCount,
                  doneCount: doneCount,
                  rejectedCount: rejectedCount,
                ),
                // Item list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(myScheduleProvider.notifier)
                          .loadSchedule(widget.id);
                    },
                    child: filteredItems.isEmpty
                        ? ListView(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 40),
                                child: Center(
                                  child: Text(
                                    _emptyMessage(_filter),
                                    style: const TextStyle(
                                        color: AppColors.textMuted, fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(
                                top: 4, left: 0, right: 0, bottom: 8),
                            itemCount: filteredItems.length,
                            itemBuilder: (ctx, i) {
                              final item = filteredItems[i];
                              return _ChecklistItemTile(
                                item: item,
                                onCheckTap: () => _onCheckTap(item),
                                onChatTap: () => _openChatScreen(item),
                                onLongPress: () => _onItemLongPress(item),
                              );
                            },
                          ),
                  ),
                ),
                // Send Report bottom bar
                _SendReportBar(
                  isEnabled: canReport,
                  isReported: isReported,
                  isAllPassed: isAllPassed,
                  onTap: _onSendReport,
                ),
              ],
            ],
          ),
        ),
        if (_isUploading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 12),
                  Text(
                    'Uploading photo...',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _emptyMessage(_ChecklistFilter filter) {
    switch (filter) {
      case _ChecklistFilter.todo:
        return 'No pending items.';
      case _ChecklistFilter.done:
        return 'No completed items.';
      case _ChecklistFilter.rejected:
        return 'No rejected items.';
      case _ChecklistFilter.all:
        return 'No checklist items.';
    }
  }
}

// ─── Progress Section ──────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final MySchedule schedule;

  const _ProgressSection({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final snapshot = schedule.checklistSnapshot;
    final completed = snapshot?.completedItems ?? 0;
    final total = snapshot?.totalItems ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final isComplete = progress >= 1.0;

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schedule.label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            formatFixedDateWithDay(schedule.workDate),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isComplete ? 'Complete' : 'In Progress',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isComplete ? AppColors.success : AppColors.accent,
                ),
              ),
              Text(
                '$completed/$total items',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                isComplete ? AppColors.success : AppColors.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Tab Bar ─────────────────────────────────────────────────────────

class _FilterTabBar extends StatelessWidget {
  final TabController controller;
  final int allCount;
  final int todoCount;
  final int doneCount;
  final int rejectedCount;

  const _FilterTabBar({
    required this.controller,
    required this.allCount,
    required this.todoCount,
    required this.doneCount,
    required this.rejectedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: TabBar(
        controller: controller,
        labelColor: AppColors.accent,
        unselectedLabelColor: AppColors.textMuted,
        indicatorColor: AppColors.accent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: [
          _TabItem(label: 'All', count: allCount, isDanger: false),
          _TabItem(label: 'Todo', count: todoCount, isDanger: false),
          _TabItem(label: 'Done', count: doneCount, isDanger: false),
          _TabItem(label: 'Rejected', count: rejectedCount, isDanger: rejectedCount > 0),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool isDanger;

  const _TabItem({
    required this.label,
    required this.count,
    required this.isDanger,
  });

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isDanger ? AppColors.dangerBg : AppColors.border,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDanger ? AppColors.danger : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Checklist Item Tile ──────────────────────────────────────────────────

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onCheckTap;
  final VoidCallback onChatTap;
  final VoidCallback onLongPress;

  const _ChecklistItemTile({
    required this.item,
    required this.onCheckTap,
    required this.onChatTap,
    required this.onLongPress,
  });

  Color get _tileBgColor {
    if (item.isRejected && !item.isResolved) return const Color(0xFFFFF5F5);
    if (item.isPendingReReview) return const Color(0xFFFFFBF0);
    if (item.isApproved) return const Color(0xFFF0FFF9);
    if (item.isCompleted) return const Color(0xFFFBF8FC);
    return AppColors.white;
  }

  Color get _tileBorderColor {
    if (item.isRejected && !item.isResolved) return AppColors.danger.withOpacity(0.4);
    if (item.isPendingReReview) return AppColors.warning.withOpacity(0.4);
    if (item.isApproved) return AppColors.success.withOpacity(0.4);
    return AppColors.border;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
      onTap: onCheckTap,
      onLongPress: item.isCompleted ? onLongPress : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          color: _tileBgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _tileBorderColor, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status icon — 완료 항목은 체크 아이콘 탭 시 undo
            GestureDetector(
              onTap: item.isCompleted ? onLongPress : null,
              behavior: HitTestBehavior.opaque,
              child: Padding(
              padding: const EdgeInsets.only(top: 1, right: 8),
              child: _buildStatusIcon(),
            ),
            ),
            const SizedBox(width: 4),
            // Body
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      decoration: (item.isCompleted && !item.isRejected)
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Badges row
                  _buildBadgesRow(),
                  // Review comment preview
                  if (item.reviewComment != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '›',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.reviewComment!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  // Rejected resubmit badge
                  if (item.isRejected && !item.isResolved) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.redo_rounded,
                              size: 12, color: AppColors.danger),
                          SizedBox(width: 4),
                          Text(
                            'Resubmit Required',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Chat button
            GestureDetector(
              onTap: onChatTap,
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(left: 4, top: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5F7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    Color bgColor;
    Color borderColor;
    Widget child;

    if (item.isRejected) {
      bgColor = AppColors.dangerBg;
      borderColor = AppColors.danger;
      child = const Icon(Icons.close_rounded, size: 14, color: AppColors.danger);
    } else if (item.isPendingReReview) {
      bgColor = AppColors.warningBg;
      borderColor = AppColors.warning;
      child = const Icon(Icons.hourglass_top_rounded,
          size: 14, color: AppColors.warning);
    } else if (item.isApproved) {
      bgColor = AppColors.success;
      borderColor = AppColors.success;
      child = const Icon(Icons.check_rounded, size: 14, color: AppColors.white);
    } else if (item.isCompleted) {
      bgColor = AppColors.accent;
      borderColor = AppColors.accent;
      child = const Icon(Icons.check_rounded, size: 14, color: AppColors.white);
    } else {
      bgColor = Colors.transparent;
      borderColor = AppColors.border;
      child = const SizedBox.shrink();
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Center(child: child),
    );
  }

  Widget _buildBadgesRow() {
    final badges = <Widget>[];

    if (item.requiresPhoto) {
      badges.add(_Badge(
        label: '📷 Photo',
        bgColor: item.hasPhotos ? AppColors.successBg : AppColors.border,
        textColor: item.hasPhotos ? const Color(0xFF008F76) : AppColors.textMuted,
      ));
    }

    if (item.requiresComment) {
      badges.add(_Badge(
        label: '📝 Text',
        bgColor: (item.note?.isNotEmpty == true)
            ? AppColors.successBg
            : AppColors.border,
        textColor: (item.note?.isNotEmpty == true)
            ? const Color(0xFF008F76)
            : AppColors.textMuted,
      ));
    }

    if (item.isApproved) {
      badges.add(const _Badge(
        label: 'Approved',
        bgColor: AppColors.successBg,
        textColor: Color(0xFF008F76),
      ));
    } else if (item.isPendingReReview) {
      badges.add(const _Badge(
        label: 'Re-review Pending',
        bgColor: AppColors.warningBg,
        textColor: Color(0xFFC07C00),
      ));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Wrap(spacing: 5, runSpacing: 4, children: badges),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: textColor),
      ),
    );
  }
}

// ─── Send Report Bottom Bar ──────────────────────────────────────────────────

class _SendReportBar extends StatelessWidget {
  final bool isEnabled;
  final bool isReported;
  final bool isAllPassed;
  final VoidCallback onTap;

  const _SendReportBar({
    required this.isEnabled,
    this.isReported = false,
    this.isAllPassed = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isAllPassed
        ? 'All Reviewed'
        : isReported
            ? 'Report Submitted'
            : 'Submit Report';
    final icon = isAllPassed
        ? Icons.verified_rounded
        : isReported
            ? Icons.check_circle_outline
            : Icons.send_rounded;
    final bgColor = isAllPassed
        ? AppColors.success.withOpacity(0.15)
        : isReported
            ? AppColors.success.withOpacity(0.15)
            : isEnabled
                ? AppColors.accent
                : const Color(0xFFEDE6E9);
    final fgColor = isAllPassed
        ? AppColors.success
        : isReported
            ? AppColors.success
            : isEnabled
                ? AppColors.white
                : AppColors.textMuted;

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isEnabled ? onTap : null,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: ElevatedButton.styleFrom(
              backgroundColor: bgColor,
              foregroundColor: fgColor,
              disabledBackgroundColor: isReported
                  ? AppColors.success.withOpacity(0.15)
                  : const Color(0xFFEDE6E9),
              disabledForegroundColor: isReported
                  ? AppColors.success
                  : AppColors.textMuted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Completion Dialog (no note) ─────────────────────────────────────────────

/// 완료 다이얼로그 반환값
class _CompletionResult {
  final List<String> photoUrls;
  final String? note;
  _CompletionResult({required this.photoUrls, this.note});
}

/// 자기완결형 완료 다이얼로그 — 사진 추가/삭제/미리보기 + 텍스트 입력 모두 내장
/// 채팅 화면과 같은 SharedPreferences 키를 사용하여 draft 공유
class _CompletionFormDialog extends StatefulWidget {
  final ChecklistItem item;
  final StorageService storageProvider;
  final String scheduleId;
  final bool isResubmit;
  final List<String>? initialPhotoUrls;
  final String? initialNote;

  const _CompletionFormDialog({
    required this.item,
    required this.storageProvider,
    required this.scheduleId,
    this.isResubmit = false,
    this.initialPhotoUrls,
    this.initialNote,
  });

  @override
  State<_CompletionFormDialog> createState() => _CompletionFormDialogState();
}

class _CompletionFormDialogState extends State<_CompletionFormDialog> {
  final _noteController = TextEditingController();
  final List<String> _photoUrls = [];
  bool _isUploading = false;

  ChecklistItem get item => widget.item;
  int get _minPhotos => item.minPhotos ?? (item.requiresPhoto ? 1 : 0);
  bool get _photoMet => _photoUrls.length >= _minPhotos;
  bool get _canSubmit => _minPhotos == 0 || _photoMet;

  /// 채팅 화면과 동일한 키 — draft 공유
  String get _draftKey =>
      'checklist_draft_${widget.scheduleId}_${widget.item.index}';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _saveDraftSync();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final photos = (data['photoUrls'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final memo = data['memo'] as String? ?? '';
        if (mounted && (photos.isNotEmpty || memo.isNotEmpty)) {
          setState(() {
            _photoUrls.addAll(photos);
            _noteController.text = memo;
          });
          return;
        }
      }
    } catch (_) {}

    // draft가 없으면 이전 제출 내용으로 채움 (resubmit 시)
    if (widget.initialPhotoUrls != null || widget.initialNote != null) {
      if (mounted) {
        setState(() {
          if (widget.initialPhotoUrls != null) {
            _photoUrls.addAll(widget.initialPhotoUrls!);
          }
          if (widget.initialNote != null) {
            _noteController.text = widget.initialNote!;
          }
        });
      }
    }
  }

  void _saveDraft() {
    SharedPreferences.getInstance().then((prefs) {
      final data = jsonEncode({
        'photoUrls': _photoUrls,
        'memo': _noteController.text,
      });
      prefs.setString(_draftKey, data);
    }).catchError((_) {});
  }

  void _saveDraftSync() {
    // dispose 시 동기적으로 호출 — fire and forget
    _saveDraft();
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<void> _addPhoto(ImageSource source) async {
    final picker = ImagePicker();

    // Gallery → 여러 장 선택, Camera → 1장
    final List<XFile> picked;
    if (source == ImageSource.gallery) {
      picked = await picker.pickMultiImage(imageQuality: 80);
    } else {
      final single = await picker.pickImage(source: source, imageQuality: 80);
      picked = single != null ? [single] : [];
    }
    if (picked.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      for (final file in picked) {
        final bytes = await file.readAsBytes();
        final filename = 'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final urls = await widget.storageProvider.getPresignedUrl(filename, 'image/jpeg');
        await widget.storageProvider.uploadFile(urls['upload_url']!, bytes, 'image/jpeg');
        if (mounted) {
          setState(() {
            _photoUrls.add(urls['file_url']!);
          });
        }
      }
      _saveDraft();
    } catch (e) {
      if (mounted) ToastManager().error(context, 'Photo upload failed');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photoUrls.removeAt(index);
      _saveDraft();
    });
  }

  void _showPhotoSource() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 28),
              ),
              const SizedBox(height: 16),
              const Text('Add Photo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.accent),
                title: const Text('Take Photo'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.accent),
                title: const Text('Choose from Gallery'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) _addPhoto(source);
  }

  void _submit() {
    final note = _noteController.text.trim();
    _clearDraft();
    Navigator.pop(context, _CompletionResult(
      photoUrls: _photoUrls,
      note: note.isEmpty ? null : note,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final needsPhoto = item.requiresPhoto;
    final needsText = item.requiresComment;
    final hasInputs = needsPhoto || needsText;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: widget.isResubmit
                          ? AppColors.danger.withOpacity(0.15)
                          : AppColors.accentBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.isResubmit
                          ? Icons.redo_rounded
                          : hasInputs ? Icons.camera_alt_rounded : Icons.check_circle_rounded,
                      color: widget.isResubmit ? AppColors.danger : AppColors.accent,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.isResubmit ? 'Resubmit Item' : 'Complete Item',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.isResubmit
                        ? '"${item.title}"'
                        : hasInputs ? '"${item.title}"' : 'Mark "${item.title}" as complete?',
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.55),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // ── Input section (사진 + 텍스트)
            if (hasInputs) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Photo section
                    if (needsPhoto) ...[
                      // Photo thumbnails strip
                      if (_photoUrls.isNotEmpty) ...[
                        SizedBox(
                          height: 68,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photoUrls.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (ctx, i) {
                              if (i == _photoUrls.length) {
                                // Add more button
                                return GestureDetector(
                                  onTap: _isUploading ? null : _showPhotoSource,
                                  child: Container(
                                    width: 68, height: 68,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.border, width: 1.5, style: BorderStyle.solid),
                                      color: AppColors.bg,
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add, color: AppColors.textMuted, size: 20),
                                        Text('Add', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                );
                              }
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _photoUrls[i], width: 68, height: 68,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 68, height: 68,
                                        decoration: BoxDecoration(
                                          color: AppColors.bg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: AppColors.accent),
                                        ),
                                        child: const Icon(Icons.image, color: AppColors.accent),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -6, right: -6,
                                    child: GestureDetector(
                                      onTap: () => _removePhoto(i),
                                      child: Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.danger,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 1.5),
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        // Empty photo picker — dashed area
                        GestureDetector(
                          onTap: _isUploading ? null : _showPhotoSource,
                          child: Container(
                            width: double.infinity, height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, width: 1.5),
                            ),
                            child: _isUploading
                                ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, color: AppColors.textMuted, size: 20),
                                      SizedBox(width: 8),
                                      Text('Tap to add photo', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Photo counter
                      Row(
                        children: [
                          Icon(
                            _photoMet ? Icons.check_circle : Icons.camera_alt_outlined,
                            size: 14,
                            color: _photoMet ? AppColors.success : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Photos: ${_photoUrls.length}/$_minPhotos required',
                            style: TextStyle(
                              fontSize: 12,
                              color: _photoMet ? AppColors.success : AppColors.warning,
                              fontWeight: _photoMet ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                    // Text input
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      onChanged: (_) => _saveDraft(),
                      decoration: InputDecoration(
                        hintText: needsText
                            ? 'Text (required)...'
                            : 'Text (optional) — e.g. store front prep completed',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                        filled: true, fillColor: AppColors.bg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.accent),
                        ),
                      ),
                      style: const TextStyle(fontSize: 14, color: AppColors.text),
                    ),
                  ],
                ),
              ),
            ],

            // ── Uploading indicator
            if (_isUploading && _photoUrls.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              ),

            // ── Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: (_canSubmit && !_isUploading) ? _submit : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: (_canSubmit && !_isUploading) ? AppColors.accent : const Color(0xFFEDE6E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.isResubmit ? 'Resubmit' : 'Complete',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: (_canSubmit && !_isUploading) ? AppColors.white : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
