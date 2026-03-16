/// 체크리스트 상세 화면
///
/// 특정 근무배정의 체크리스트 항목을 표시하고 완료/반려 응답 처리.
///
/// 주요 플로우:
/// 1. 일반 항목 탭 → 완료 처리 (사진/메모 필요시 먼저 수집)
/// 2. 반려된 항목 탭 → 재응답 (코멘트 + 선택적 사진)
/// 3. 완료된 항목 탭 → 상세 정보 바텀시트 (타임라인 이벤트 포함)
/// 4. 모든 항목 완료 시 → 축하 토스트 표시
///
/// 사진 업로드는 StorageService의 presigned URL 방식 사용.
/// 각 항목에 requiresPhoto/requiresComment 플래그로 입력 요구사항 분기.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/my_schedule.dart';
import '../../models/checklist.dart';
import '../../providers/my_schedule_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';

/// 체크리스트 상세 화면 위젯
class ChecklistScreen extends ConsumerStatefulWidget {
  final String id;
  const ChecklistScreen({super.key, required this.id});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  bool _celebrationShown = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(myScheduleProvider.notifier).loadSchedule(widget.id));
  }

  void _showCompletionToast() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    ToastManager().success(context, 'All tasks completed! Great work!');
  }

  void _onItemTap(ChecklistItem item) async {
    if (_isUploading) return;

    // Rejected item → respond to rejection flow
    if (item.isRejected && !item.isResolved) {
      await _handleRespondToRejection(item);
      return;
    }

    // Already completed → show detail sheet
    if (item.isCompleted) {
      _showItemDetailSheet(context, item);
      return;
    }

    // Normal completion flow
    String? photoUrl;
    String? note;

    if (item.requiresPhoto) {
      photoUrl = await _handlePhotoCapture();
      if (photoUrl == null) return;
    }

    if (item.requiresComment) {
      note = await _showNoteDialog();
      if (note == null) return;
    }

    ref.read(myScheduleProvider.notifier).toggleChecklistItem(
          widget.id,
          item.index,
          true,
          photoUrl: photoUrl,
          note: note,
        );
  }

  Future<void> _handleRespondToRejection(ChecklistItem item) async {
    String? photoUrl;
    String? responseComment;

    if (item.requiresPhoto) {
      photoUrl = await _handlePhotoCapture();
      if (photoUrl == null) return;
    }

    responseComment = await _showNoteDialog(
      title: 'Response',
      hint: 'Enter your response to the rejection...',
    );
    if (responseComment == null) return;

    ref.read(myScheduleProvider.notifier).respondToRejection(
          widget.id,
          item.index,
          responseComment: responseComment,
          photoUrl: photoUrl,
        );
  }

  Future<String?> _handlePhotoCapture() async {
    final source = await _showPhotoSourceSheet();
    if (source == null) return null;

    final picker = ImagePicker();
    final XFile? picked;
    if (source == ImageSource.camera) {
      picked =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    } else {
      picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80);
    }
    if (picked == null) return null;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final filename =
          'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

  Future<ImageSource?> _showPhotoSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Photo',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.accent),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.accent),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNoteDialog({
    String title = 'Add Note',
    String hint = 'Enter verification note...',
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx, text);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showItemDetailSheet(BuildContext context, ChecklistItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemDetailSheet(item: item),
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
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
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
                const Expanded(
                    child: Center(child: Text('Schedule not found')))
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await ref
                          .read(myScheduleProvider.notifier)
                          .loadSchedule(widget.id);
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Schedule header card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schedule.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatFixedDateWithDay(schedule.workDate),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildProgressSection(schedule),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Checklist items header
                        Row(
                          children: [
                            const Text(
                              'Checklist Items',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (schedule.checklistSnapshot != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${schedule.checklistSnapshot!.totalItems}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Checklist items
                        if (schedule.checklistSnapshot == null ||
                            schedule.checklistSnapshot!.items.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: Text(
                                'No checklist items',
                                style: TextStyle(
                                    color: AppColors.textMuted, fontSize: 14),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: List.generate(
                                schedule.checklistSnapshot!.items.length,
                                (index) {
                                  final item = schedule
                                      .checklistSnapshot!.items[index];
                                  return Column(
                                    children: [
                                      if (index > 0)
                                        const Divider(
                                            height: 1,
                                            color: AppColors.border),
                                      _ChecklistItemTile(
                                        item: item,
                                        onToggle: () => _onItemTap(item),
                                        onTapDetail: () =>
                                            _showItemDetailSheet(
                                                context, item),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
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

  Widget _buildProgressSection(MySchedule schedule) {
    final snapshot = schedule.checklistSnapshot;
    final completed = snapshot?.completedItems ?? 0;
    final total = snapshot?.totalItems ?? 0;
    final progress = total > 0 ? completed / total : 0.0;
    final isComplete = progress >= 1.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isComplete ? 'Completed' : 'In Progress',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isComplete ? AppColors.success : AppColors.accent,
              ),
            ),
            Text(
              '$completed/$total items',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(
              isComplete ? AppColors.success : AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Checklist item tile with rejection support ──────────────────────────────

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onToggle;
  final VoidCallback onTapDetail;

  const _ChecklistItemTile({
    required this.item,
    required this.onToggle,
    required this.onTapDetail,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      onLongPress: onTapDetail,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: item.isRejected
                      ? AppColors.warningBg
                      : item.isApproved
                          ? AppColors.success
                          : item.isCompleted
                              ? AppColors.success
                              : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isRejected
                        ? AppColors.warning
                        : item.isApproved
                            ? AppColors.success
                            : item.isCompleted
                                ? AppColors.success
                                : AppColors.border,
                    width: 2,
                  ),
                ),
                child: item.isRejected
                    ? const Icon(Icons.refresh,
                        size: 14, color: AppColors.warning)
                    : item.isApproved
                        ? const Icon(Icons.check_circle,
                            size: 16, color: Colors.white)
                        : item.isCompleted
                            ? const Icon(Icons.check,
                                size: 16, color: Colors.white)
                            : null,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: item.isCompleted && !item.isRejected
                                ? AppColors.textMuted
                                : AppColors.text,
                            decoration: item.isCompleted && !item.isRejected
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      if (item.isApproved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.successBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Approved',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.success,
                            ),
                          ),
                        )
                      else if (item.isRejected && !item.isResolved)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.warningBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Action Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (item.description != null &&
                      item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (item.isCompleted &&
                      !item.isRejected &&
                      item.completedAtDisplay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Completed ${item.completedAtDisplay}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                  // Inline approval feedback
                  if (item.isApproved &&
                      (item.approvalComment != null ||
                          item.approvalPhotoUrls.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onTapDetail,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.successBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 12, color: AppColors.success),
                                const SizedBox(width: 4),
                                if (item.approvedBy != null)
                                  Text(
                                    item.approvedBy!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.success,
                                    ),
                                  ),
                              ],
                            ),
                            if (item.approvalComment != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.approvalComment!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.text,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                  // Inline rejection feedback
                  if (item.isRejected &&
                      (item.rejectionComment != null ||
                          item.rejectionPhotoUrls.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: onTapDetail,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.chat_bubble_outline,
                                    size: 12, color: AppColors.warning),
                                const SizedBox(width: 4),
                                if (item.rejectedBy != null)
                                  Text(
                                    item.rejectedBy!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                const Spacer(),
                                if (item.rejectedAtDisplay != null)
                                  Text(
                                    item.rejectedAtDisplay!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.warning
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                              ],
                            ),
                            if (item.rejectionComment != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.rejectionComment!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.text,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (item.rejectionPhotoUrls.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 48,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: item.rejectionPhotoUrls.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 4),
                                  itemBuilder: (context, i) => ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      item.rejectionPhotoUrls[i],
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 48,
                                        height: 48,
                                        color: AppColors.border,
                                        child: const Icon(Icons.broken_image,
                                            size: 16,
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Verification type icons
            if (item.requiresVerification &&
                !item.isCompleted &&
                !item.isRejected) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.requiresPhoto)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.camera_alt_outlined,
                          size: 16,
                          color: AppColors.accent.withValues(alpha: 0.7)),
                    ),
                  if (item.requiresComment)
                    Icon(Icons.edit_note,
                        size: 18,
                        color: AppColors.accent.withValues(alpha: 0.7)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Item detail bottom sheet with timeline ──────────────────────────────────

class _ItemDetailSheet extends StatelessWidget {
  final ChecklistItem item;

  const _ItemDetailSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final events = item.fullHistory;
    final hasPending = item.isRejected && !item.isResolved;
    final totalSteps = events.length + (hasPending ? 1 : 0);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Status header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (item.description != null &&
                        item.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.description!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildCurrentStatusBadge(),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item.completedBy ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(Icons.access_time,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          item.completedAtDisplay ?? '-',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.border),

              // Timeline
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  itemCount: totalSteps,
                  itemBuilder: (context, index) {
                    if (hasPending && index == events.length) {
                      return const _TimelineStepCard(
                        type: 'pending',
                        comment: 'Awaiting resubmission',
                        isLast: true,
                      );
                    }
                    final event = events[index];
                    return _TimelineStepCard(
                      type: event.type,
                      by: event.by,
                      at: event.atDisplay,
                      comment: event.comment,
                      photoUrls: event.photoUrls,
                      isLast: index == totalSteps - 1,
                    );
                  },
                ),
              ),

              // Close button
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: AppColors.bg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCurrentStatusBadge() {
    final String label;
    final Color color;
    final Color bg;
    final IconData icon;

    if (item.isApproved) {
      label = 'Approved';
      color = const Color(0xFF10B981);
      bg = const Color(0xFFD1FAE5);
      icon = Icons.check_circle;
    } else if (item.isRejected && !item.isResolved) {
      label = 'Revision Requested';
      color = const Color(0xFFF59E0B);
      bg = const Color(0xFFFFFBEB);
      icon = Icons.edit_note;
    } else if (item.isResolved) {
      label = 'Resubmitted';
      color = const Color(0xFF6C5CE7);
      bg = const Color(0xFFF0EEFF);
      icon = Icons.replay;
    } else if (item.isCompleted) {
      label = 'Submitted';
      color = const Color(0xFF10B981);
      bg = const Color(0xFFD1FAE5);
      icon = Icons.check_circle;
    } else {
      label = 'Not Submitted';
      color = const Color(0xFF9CA3AF);
      bg = const Color(0xFFF9FAFB);
      icon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline step card ─────────────────────────────────────────────────────

class _TimelineStepCard extends StatelessWidget {
  final String type;
  final String? by;
  final String? at;
  final String? comment;
  final List<String> photoUrls;
  final bool isLast;

  const _TimelineStepCard({
    required this.type,
    this.by,
    this.at,
    this.comment,
    this.photoUrls = const [],
    this.isLast = false,
  });

  static const _submitColor = Color(0xFF3B82F6);
  static const _submitBg = Color(0xFFEFF6FF);
  static const _changeReqColor = Color(0xFFF59E0B);
  static const _changeReqBg = Color(0xFFFFFBEB);
  static const _resubmitColor = Color(0xFF6C5CE7);
  static const _resubmitBg = Color(0xFFF0EEFF);
  static const _approvedColor = Color(0xFF10B981);
  static const _approvedBg = Color(0xFFD1FAE5);
  static const _pendingColor = Color(0xFF9CA3AF);
  static const _pendingBg = Color(0xFFF9FAFB);

  Color get _dotColor {
    switch (type) {
      case 'completed':
        return _submitColor;
      case 'rejected':
        return _changeReqColor;
      case 'responded':
        return _resubmitColor;
      case 'approved':
        return _approvedColor;
      case 'pending':
        return _pendingColor;
      default:
        return _pendingColor;
    }
  }

  Color get _cardBg {
    switch (type) {
      case 'completed':
        return _submitBg;
      case 'rejected':
        return _changeReqBg;
      case 'responded':
        return _resubmitBg;
      case 'approved':
        return _approvedBg;
      case 'pending':
        return _pendingBg;
      default:
        return _pendingBg;
    }
  }

  String get _label {
    switch (type) {
      case 'completed':
        return 'Submitted';
      case 'rejected':
        return 'Revision Requested';
      case 'responded':
        return 'Resubmitted';
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      default:
        return type;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'completed':
        return Icons.upload_file;
      case 'rejected':
        return Icons.edit_note;
      case 'responded':
        return Icons.replay;
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.only(top: 4),
                      color: AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dotColor.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _dotColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_icon, size: 12, color: _dotColor),
                            const SizedBox(width: 4),
                            Text(
                              _label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _dotColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      if (at != null)
                        Text(
                          at!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  if (by != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          by!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (comment != null && comment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        comment!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.text,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  if (photoUrls.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PhotoCarousel(photoUrls: photoUrls),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Photo carousel ─────────────────────────────────────────────────────────

class _PhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;

  const _PhotoCarousel({required this.photoUrls});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.length == 1) {
      return _buildSinglePhoto(context, widget.photoUrls[0]);
    }
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            itemCount: widget.photoUrls.length,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _buildPhoto(context, widget.photoUrls[index], index),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.photoUrls.length,
            (i) => Container(
              width: i == _currentPage ? 16 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color:
                    i == _currentPage ? AppColors.accent : AppColors.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePhoto(BuildContext context, String url) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, widget.photoUrls, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoErrorWidget(),
          loadingBuilder: _photoLoadingBuilder,
        ),
      ),
    );
  }

  Widget _buildPhoto(BuildContext context, String url, int index) {
    return GestureDetector(
      onTap: () => _openFullScreen(context, widget.photoUrls, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: double.infinity,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _photoErrorWidget(),
          loadingBuilder: _photoLoadingBuilder,
        ),
      ),
    );
  }

  void _openFullScreen(
      BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (_, __, ___) => _FullScreenPhotoViewer(
          photoUrls: urls,
          initialIndex: initialIndex,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Widget _photoErrorWidget() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined,
              size: 28, color: AppColors.textMuted),
          SizedBox(height: 4),
          Text('Failed to load image',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _photoLoadingBuilder(
      BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
    if (loadingProgress == null) return child;
    return Container(
      width: double.infinity,
      height: 160,
      color: AppColors.bg,
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ─── Full screen photo viewer ───────────────────────────────────────────────

class _FullScreenPhotoViewer extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const _FullScreenPhotoViewer({
    required this.photoUrls,
    this.initialIndex = 0,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.photoUrls.length;
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      widget.photoUrls[index],
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              size: 48, color: Colors.white54),
                          SizedBox(height: 8),
                          Text('Failed to load image',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white54)),
                        ],
                      ),
                      loadingBuilder: (_, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(18),
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
          if (total > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / $total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
