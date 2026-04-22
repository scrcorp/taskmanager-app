/// 체크리스트 항목 채팅 화면
///
/// 특정 체크리스트 항목의 상세 이력(타임라인) 및 관리자와의 채팅을 표시.
/// 미완료/반려 항목은 제출 카드(ResubmitCard)를 상단에 표시.
///
/// 레이아웃:
///   AppBar (← 항목 제목, 상태 뱃지)
///   ──────────────────────────────────
///   [제출 카드] (미완료 or 반려 상태)
///     - 사진 요구사항, 썸네일, 메모 입력, 제출 버튼
///   ──────────────────────────────────
///   [타임라인] (스크롤 가능)
///     - 시스템 이벤트 (완료, 리뷰, 재제출)
///     - 채팅 말풍선 (직원/관리자)
///   ──────────────────────────────────
///   [입력 바] (📎 + 텍스트 입력 + 전송)
///
/// 네비게이션: Navigator.push / AppBar 뒤로가기
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../models/checklist.dart';
import '../../providers/auth_provider.dart';
import '../../providers/my_schedule_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/toast_manager.dart';

/// 체크리스트 항목 채팅 전체 화면 위젯
class ChecklistChatScreen extends ConsumerStatefulWidget {
  final String scheduleId;
  final ChecklistItem item;
  /// true면 조회 전용 (모바일) — 입력바/제출카드 숨김, 타임라인만 표시
  final bool readOnly;

  const ChecklistChatScreen({
    super.key,
    required this.scheduleId,
    required this.item,
    this.readOnly = false,
  });

  @override
  ConsumerState<ChecklistChatScreen> createState() =>
      _ChecklistChatScreenState();
}

class _ChecklistChatScreenState extends ConsumerState<ChecklistChatScreen> {
  final _chatController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSubmitting = false;
  bool _isUploading = false;

  // 제출 카드 상태
  List<String> _pendingPhotoUrls = [];
  final _memoController = TextEditingController();
  bool _submitCardExpanded = true;
  Timer? _draftSaveTimer;

  String get _draftKey =>
      'checklist_draft_${widget.scheduleId}_${widget.item.index}';

  ChecklistItem get _item {
    // 최신 상태 가져오기 (provider에서 업데이트된 경우 반영)
    final schedule = ref.read(myScheduleProvider).selected;
    if (schedule != null && schedule.checklistSnapshot != null) {
      final idx = widget.item.index;
      final items = schedule.checklistSnapshot!.items;
      if (idx < items.length) return items[idx];
    }
    return widget.item;
  }

  bool get _showResubmitCard {
    final item = _item;
    // reviewResult is the source of truth — if null, item is unreviewed (not pending_re_review)
    return !item.isCompleted || (item.isRejected && !item.isResolved && !item.isPendingReReview);
  }

  @override
  void initState() {
    super.initState();
    _loadDraft();
    // 초기 로드 후 맨 아래로 스크롤
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
    });
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _chatController.dispose();
    _scrollController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_draftKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final photos = (data['photoUrls'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final memo = data['memo'] as String? ?? '';
      if (mounted) {
        setState(() {
          _pendingPhotoUrls = photos;
          _memoController.text = memo;
        });
      }
    } catch (_) {}
  }

  void _saveDraft() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final data = jsonEncode({
          'photoUrls': _pendingPhotoUrls,
          'memo': _memoController.text,
        });
        await prefs.setString(_draftKey, data);
      } catch (_) {}
    });
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _addPhotoFromCamera() => _addPhoto(ImageSource.camera);

  Future<void> _addPhotoFromGallery() => _addPhoto(ImageSource.gallery);

  Future<void> _addPhoto(ImageSource source) async {
    final picker = ImagePicker();

    // Gallery → 여러 장 선택, Camera → 1장
    final List<XFile> pickedList;
    if (source == ImageSource.gallery) {
      pickedList = await picker.pickMultiImage(imageQuality: 80);
    } else {
      final single = await picker.pickImage(source: source, imageQuality: 80);
      pickedList = single != null ? [single] : [];
    }
    if (pickedList.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final storage = ref.read(storageServiceProvider);
      for (final picked in pickedList) {
        final bytes = await picked.readAsBytes();
        final filename = 'checklist_${DateTime.now().millisecondsSinceEpoch}.jpg';
        const contentType = 'image/jpeg';
        final urls = await storage.getPresignedUrl(filename, contentType);
        await storage.uploadFile(urls['upload_url']!, bytes, contentType);
        final fileUrl = urls['file_url']!;
        if (mounted) {
          setState(() => _pendingPhotoUrls = [..._pendingPhotoUrls, fileUrl]);
        }
      }
      _saveDraft();
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Photo upload failed');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _removePhoto(int index) {
    setState(() {
      final list = List<String>.from(_pendingPhotoUrls);
      list.removeAt(index);
      _pendingPhotoUrls = list;
    });
    _saveDraft();
  }

  Future<void> _submit() async {
    final item = _item;
    // 사진 필요한데 없으면 안내
    if (item.requiresPhoto && _pendingPhotoUrls.isEmpty) {
      ToastManager().error(context, 'Please attach a photo.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (!item.isCompleted) {
        // 미완료 → 완료 처리
        await ref.read(myScheduleProvider.notifier).toggleChecklistItem(
              widget.scheduleId,
              item.index,
              true,
              photoUrls: _pendingPhotoUrls.isEmpty ? null : _pendingPhotoUrls,
              note: _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
            );
      } else if (item.isRejected && !item.isResolved) {
        // 반려 → 재응답
        await ref.read(myScheduleProvider.notifier).respondToRejection(
              widget.scheduleId,
              item.index,
              responseComment: _memoController.text.trim().isEmpty
                  ? null
                  : _memoController.text.trim(),
              photoUrls: _pendingPhotoUrls.isEmpty ? null : _pendingPhotoUrls,
            );
      }
      // 제출 성공: 상태 초기화 + 드래프트 삭제
      setState(() {
        _pendingPhotoUrls = [];
        _memoController.clear();
      });
      await _clearDraft();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Failed to submit. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendChatMessage() async {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    try {
      final schedule = ref.read(myScheduleProvider).selected;
      final instanceId = schedule?.checklistInstanceId;
      if (instanceId == null) throw Exception('No checklist instance');
      await ref.read(myScheduleProvider.notifier).addReviewContent(
            instanceId,
            widget.item.index,
            type: 'text',
            content: text,
          );
      _chatController.clear();
      await ref.read(myScheduleProvider.notifier).loadSchedule(widget.scheduleId);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Send failed');
      }
    }
  }

  Future<void> _sendChatPhoto() async {
    final source = await _showPhotoSourceSheet();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = source == ImageSource.camera
        ? await picker.pickImage(source: ImageSource.camera, imageQuality: 80)
        : await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final filename = 'chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      const contentType = 'image/jpeg';
      final storage = ref.read(storageServiceProvider);
      final urls = await storage.getPresignedUrl(filename, contentType, folder: 'chat');
      await storage.uploadFile(urls['upload_url']!, bytes, contentType);
      final schedule = ref.read(myScheduleProvider).selected;
      final instanceId = schedule?.checklistInstanceId;
      if (instanceId == null) throw Exception('No checklist instance');
      await ref.read(myScheduleProvider.notifier).addReviewContent(
            instanceId,
            widget.item.index,
            type: 'photo',
            content: urls['file_url']!,
          );
      await ref.read(myScheduleProvider.notifier).loadSchedule(widget.scheduleId);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ToastManager().error(context, 'Photo send failed');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
    // provider 상태 변경 시 리빌드 트리거
    ref.watch(myScheduleProvider);
    final item = _item;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _buildAppBar(item),
      body: Stack(
        children: [
          Column(
            children: [
              // Scrollable timeline (full height)
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.only(
                        // 헤더 상태바 높이만큼 상단 패딩
                        top: 40,
                        bottom: 8,
                      ),
                      children: [
                        _buildTimeline(item),
                      ],
                    ),
                    // 헤더: 위에 떠있음 (overlay)
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: _buildUnifiedHeader(item),
                    ),
                  ],
                ),
              ),
              // Chat input bar (읽기전용에서는 숨김)
              if (!widget.readOnly) _buildChatInputBar(),
            ],
          ),
          if (_isUploading || _isSubmitting)
            Container(
              color: Colors.black26,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 12),
                    Text(
                      _isSubmitting ? 'Submitting...' : 'Uploading photo...',
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(ChecklistItem item) {
    return AppBar(
      backgroundColor: AppColors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.text),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        children: [
          Text(
            item.title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          _StatusBadge(reviewResult: item.reviewResult, isCompleted: item.isCompleted),
        ],
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: AppColors.border),
      ),
    );
  }

  /// 통합 헤더: 상태바 + 접기/펼치기 submit/resubmit 폼
  Widget _buildUnifiedHeader(ChecklistItem item) {
    String statusText;
    Color statusColor;

    if (item.isRejected && !item.isResolved) {
      statusText = 'Rejected — Resubmission required';
      statusColor = AppColors.danger;
    } else if (item.isPendingReReview) {
      statusText = 'Pending re-review';
      statusColor = AppColors.warning;
    } else if (item.isApproved) {
      statusText = 'Approved';
      statusColor = AppColors.success;
    } else if (item.isCompleted) {
      statusText = 'Completed — Awaiting review';
      statusColor = AppColors.accent;
    } else {
      statusText = 'Not completed — Submit below';
      statusColor = AppColors.textSecondary;
    }

    final showForm = _showResubmitCard && !widget.readOnly;

    return Container(
      color: showForm
          ? (item.isRejected ? const Color(0xFFFFF5F5) : AppColors.accentBg)
          : AppColors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status row + toggle arrow
          GestureDetector(
            onTap: showForm ? () => setState(() => _submitCardExpanded = !_submitCardExpanded) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statusColor),
                    ),
                  ),
                  if (showForm)
                    Icon(
                      _submitCardExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: statusColor,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
          // Collapsible form
          if (showForm && _submitCardExpanded)
            _buildSubmitCard(item),
          // Divider
          Container(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ChecklistItem item) {
    String statusText;
    Color statusColor;

    if (item.isRejected && !item.isResolved) {
      statusText = 'Rejected — Resubmission required';
      statusColor = AppColors.danger;
    } else if (item.isPendingReReview) {
      statusText = 'Pending re-review';
      statusColor = AppColors.warning;
    } else if (item.isApproved) {
      statusText = 'Approved';
      statusColor = AppColors.success;
    } else if (item.isCompleted) {
      statusText = 'Completed — Awaiting review';
      statusColor = AppColors.accent;
    } else {
      statusText = 'Not completed — Submit below';
      statusColor = AppColors.textSecondary;
    }

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            statusText,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: statusColor),
          ),
        ],
      ),
    );
  }

  /// 제출/재제출 카드 (mockup 5C 기반)
  Widget _buildSubmitCard(ChecklistItem item) {
    final isResubmit = item.isCompleted && item.isRejected;
    final accentColor = isResubmit ? AppColors.danger : AppColors.accent;
    final minPhotos = item.minPhotos ?? 1;
    final photosFulfilled = !item.requiresPhoto ||
        _pendingPhotoUrls.length >= minPhotos;
    final canSubmit = photosFulfilled && !_isSubmitting && !_isUploading;

    // 접힌 상태 요약 텍스트
    String collapsedHint = '';
    if (item.requiresPhoto) {
      collapsedHint = '${_pendingPhotoUrls.length}/$minPhotos photos';
    }
    if (item.requiresComment && _memoController.text.isNotEmpty) {
      collapsedHint += collapsedHint.isEmpty ? 'note added' : ', note added';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      decoration: BoxDecoration(
        color: isResubmit
            ? const Color(0xFFFFF7F7)
            : const Color(0xFFF0F6FF),
        border: Border(
          bottom: BorderSide(
            color: accentColor.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Body (접기/펼치기는 상단 상태바 화살표로 제어)
          ...[
            const SizedBox(height: 10),
            // Requirements checklist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.requiresPhoto)
                    _RequirementRow(
                      label: 'Photos (required, min $minPhotos)',
                      isDone: _pendingPhotoUrls.length >= minPhotos,
                    ),
                  if (item.requiresComment)
                    _RequirementRow(
                      label: 'Text (required)',
                      isDone: _memoController.text.isNotEmpty,
                    ),
                ],
              ),
            ),
            if (item.requiresPhoto) ...[
              const SizedBox(height: 8),
              // Photo action buttons: Take Photo | Gallery
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _addPhotoFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined, size: 15),
                        label: const Text('Take Photo'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          backgroundColor: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isUploading ? null : _addPhotoFromGallery,
                        icon: const Icon(Icons.photo_library_outlined, size: 15),
                        label: const Text('Gallery'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.text,
                          side: const BorderSide(color: AppColors.border),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          backgroundColor: AppColors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Photo counter
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt_rounded,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Photos: ${_pendingPhotoUrls.length}/$minPhotos required',
                      style: TextStyle(
                        fontSize: 12,
                        color: _pendingPhotoUrls.length >= minPhotos
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Photo strip
              if (_pendingPhotoUrls.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _pendingPhotoUrls.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) => _PhotoThumb(
                      url: _pendingPhotoUrls[i],
                      onRemove: () => _removePhoto(i),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 10),
            // Memo input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _memoController,
                maxLines: 2,
                onChanged: (_) {
                  setState(() {});
                  _saveDraft();
                },
                decoration: InputDecoration(
                  hintText: isResubmit
                      ? 'Reason for resubmission...'
                      : 'Text (optional) — e.g. task completed',
                  hintStyle: const TextStyle(
                      color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: accentColor, width: 1),
                  ),
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ),
            const SizedBox(height: 10),
            // Submit button (full width)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: const Color(0xFFEDE6E9),
                    disabledForegroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(isResubmit ? 'Resubmit' : 'Submit'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 타임라인 이벤트 목록
  Widget _buildTimeline(ChecklistItem item) {
    final events = item.fullHistory;
    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: events.map((event) => _buildTimelineEvent(event)).toList(),
      ),
    );
  }

  Widget _buildTimelineEvent(ChecklistItemEvent event) {
    switch (event.type) {
      case 'submitted':
        return Column(
          children: [
            _SystemEventDivider(
              label: 'Submitted',
              icon: Icons.check_circle_rounded,
              color: AppColors.accent,
              time: event.atDisplay,
            ),
            if (event.photoUrls.isNotEmpty || event.comment != null)
              Align(
                alignment: Alignment.centerRight,
                child: _SubmissionCard(event: event, isStaff: true),
              ),
          ],
        );
      case 'resubmitted':
        return Column(
          children: [
            _SystemEventDivider(
              label: 'Resubmitted',
              icon: Icons.redo_rounded,
              color: AppColors.warning,
              time: event.atDisplay,
            ),
            if (event.photoUrls.isNotEmpty || event.comment != null)
              Align(
                alignment: Alignment.centerRight,
                child: _SubmissionCard(event: event, isStaff: true),
              ),
          ],
        );
      case 'rejected':
        return Column(
          children: [
            _SystemEventDivider(
              label: 'Rejected',
              icon: Icons.cancel_rounded,
              color: AppColors.danger,
              time: event.atDisplay,
            ),
            if (event.comment != null || event.photoUrls.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: _ManagerBubble(event: event),
              ),
          ],
        );
      case 'approved':
        return Column(
          children: [
            _SystemEventDivider(
              label: 'Approved',
              icon: Icons.verified_rounded,
              color: AppColors.success,
              time: event.atDisplay,
            ),
            if (event.comment != null || event.photoUrls.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: _ManagerBubble(event: event),
              ),
          ],
        );
      case 'pending_re_review':
        return _SystemEventDivider(
          label: 'Pending Re-review',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warning,
          time: event.atDisplay,
        );
      case 'pending':
        return _SystemEventDivider(
          label: 'Pending',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.textMuted,
          time: null,
        );
      case 'message':
        // 채팅 텍스트 메시지 — 현재 사용자 ID와 비교해 본인/상대방 구분
        final myId = ref.read(authProvider).user?.id;
        final isMine = event.by == myId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: _ChatBubble(
            message: event.comment ?? '',
            isStaff: !isMine,
            byName: event.byName,
            time: event.atDisplay,
          ),
        );
      case 'message_photo':
        final myIdPhoto = ref.read(authProvider).user?.id;
        final isMinePhoto = event.by == myIdPhoto;
        return Align(
          alignment: isMinePhoto ? Alignment.centerRight : Alignment.centerLeft,
          child: _ChatPhotoBubble(
            event: event,
            isMine: isMinePhoto,
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildChatInputBar() {
    return SafeArea(
      child: Container(
        color: AppColors.white,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach button
            GestureDetector(
              onTap: _sendChatPhoto,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF5F7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.attach_file_rounded,
                    size: 18, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            // Text input
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 100),
                child: TextField(
                  controller: _chatController,
                  maxLines: null,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: const TextStyle(
                        color: AppColors.textMuted, fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFFAF5F7),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.accent, width: 1),
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, color: AppColors.text),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            GestureDetector(
              onTap: _sendChatMessage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.send_rounded,
                    size: 18, color: AppColors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

/// 항목 상태 뱃지 (AppBar 제목 아래)
class _StatusBadge extends StatelessWidget {
  final String? reviewResult;
  final bool isCompleted;

  const _StatusBadge({this.reviewResult, required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bgColor;
    Color textColor;

    if (reviewResult == 'fail') {
      label = 'Rejected';
      bgColor = AppColors.dangerBg;
      textColor = AppColors.danger;
    } else if (reviewResult == 'pass') {
      label = 'Approved';
      bgColor = AppColors.successBg;
      textColor = const Color(0xFF008F76);
    } else if (reviewResult == 'pending_re_review') {
      label = 'Re-review';
      bgColor = AppColors.warningBg;
      textColor = const Color(0xFFC07C00);
    } else if (isCompleted) {
      label = 'Done';
      bgColor = AppColors.accentBg;
      textColor = AppColors.accent;
    } else {
      label = 'Pending';
      bgColor = AppColors.border;
      textColor = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }
}

/// 요구사항 행 (사진/메모 필요 여부)
class _RequirementRow extends StatelessWidget {
  final String label;
  final bool isDone;

  const _RequirementRow({required this.label, required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 15,
            color: isDone ? AppColors.success : AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDone ? AppColors.success : AppColors.textSecondary,
              fontWeight: isDone ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 사진 썸네일 (제거 버튼 포함)
class _PhotoThumb extends StatelessWidget {
  final String url;
  final VoidCallback onRemove;

  const _PhotoThumb({required this.url, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withOpacity(0.4)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.accentBg,
              child: const Icon(Icons.image_rounded,
                  color: AppColors.accent, size: 24),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 12, color: AppColors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// 시스템 이벤트 구분선
class _SystemEventDivider extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final String? time;

  const _SystemEventDivider({
    required this.label,
    required this.icon,
    required this.color,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.border, height: 1)),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          if (time != null) ...[
            const SizedBox(width: 4),
            Text(
              time!,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(width: 8),
          Expanded(child: Divider(color: AppColors.border, height: 1)),
        ],
      ),
    );
  }
}

/// 제출 카드 (완료/재제출 이벤트)
class _SubmissionCard extends StatelessWidget {
  final ChecklistItemEvent event;
  final bool isStaff;

  const _SubmissionCard({required this.event, required this.isStaff});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxWidth: 240),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First photo (full-width preview)
                  Image.network(
                    event.photoUrls.first,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 120,
                      color: AppColors.accentBg,
                      child: const Icon(Icons.image_rounded,
                          color: AppColors.accent, size: 32),
                    ),
                  ),
                  // Additional photos (horizontal strip)
                  if (event.photoUrls.length > 1)
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(6),
                        itemCount: event.photoUrls.length - 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 4),
                        itemBuilder: (ctx, i) => ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.network(
                            event.photoUrls[i + 1],
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 44,
                              height: 44,
                              color: AppColors.accentBg,
                              child: const Icon(Icons.image_rounded,
                                  color: AppColors.accent, size: 18),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (event.comment != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                event.comment!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: Text(
              event.atDisplay ?? '',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// 관리자 말풍선 (오른쪽)
class _ManagerBubble extends StatelessWidget {
  final ChecklistItemEvent event;

  const _ManagerBubble({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (event.atDisplay != null)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              child: Text(
                event.atDisplay!,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
                border: Border.all(
                    color: AppColors.accent.withOpacity(0.15)),
              ),
              child: Text(
                event.comment ?? '',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.text,
                    height: 1.45),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.successBg,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (event.byName?.isNotEmpty == true)
                    ? event.byName![0].toUpperCase()
                    : (event.by?.isNotEmpty == true)
                        ? event.by![0].toUpperCase()
                        : 'M',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF008F76)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 채팅 사진 말풍선 — 사진이 말풍선 안에 렌더링됨
class _ChatPhotoBubble extends StatelessWidget {
  final ChecklistItemEvent event;
  final bool isMine;

  const _ChatPhotoBubble({required this.event, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other person avatar
          if (!isMine) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: AppColors.accentBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  (event.byName?.isNotEmpty == true)
                      ? event.byName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Timestamp (left of mine, right of other)
          if (isMine && event.atDisplay != null)
            Padding(
              padding: const EdgeInsets.only(right: 4, bottom: 2),
              child: Text(
                event.atDisplay!,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          // Photo bubble
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
              child: event.photoUrls.isNotEmpty
                  ? Image.network(
                      event.photoUrls.first,
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 200,
                        height: 120,
                        color: AppColors.accentBg,
                        child: const Icon(Icons.broken_image_rounded,
                            color: AppColors.accent, size: 32),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Timestamp (right of other)
          if (!isMine && event.atDisplay != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                event.atDisplay!,
                style:
                    const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// 일반 채팅 말풍선
/// isMine=true: 본인 메시지 (오른쪽, 프로필 없음, 시간 왼쪽)
/// isMine=false: 상대방 메시지 (왼쪽, 프로필 아이콘, 시간 오른쪽)
class _ChatBubble extends StatelessWidget {
  final String message;
  final bool isStaff; // false = 본인(isMine)
  final String? byName;
  final String? time;

  const _ChatBubble({
    required this.message,
    required this.isStaff,
    this.byName,
    this.time,
  });

  bool get _isMine => !isStaff;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment:
            _isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 상대방 이름 (본인이면 표시 안 함)
          if (!_isMine && byName != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, bottom: 2),
              child: Text(
                byName!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          Row(
            mainAxisAlignment:
                _isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 상대방 프로필 아이콘
              if (!_isMine) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (byName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // 본인 메시지: 시간 왼쪽
              if (_isMine && time != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  child: Text(
                    time!,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
              // 말풍선
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isMine
                        ? AppColors.accentBg
                        : const Color(0xFFF0F1F5),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(_isMine ? 16 : 4),
                      bottomRight: Radius.circular(_isMine ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.text, height: 1.45),
                  ),
                ),
              ),
              // 상대방 메시지: 시간 오른쪽
              if (!_isMine && time != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 2),
                  child: Text(
                    time!,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
