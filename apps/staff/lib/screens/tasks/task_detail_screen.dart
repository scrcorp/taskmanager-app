/// Task 상세 화면 — staff (담당자) 시점.
///
/// 게시물 스타일:
///   - Hero (status / priority / title / store(s) / due / assignees / created)
///   - Description + reference attachments (관리자가 첨부)
///   - Activity (system audit + 댓글 + 댓글-첨부)
///   - 입력 폼 (텍스트 + 첨부)
///   - Bottom workflow: Start / Submit / (manager) Confirm·Reject / Reopen
///
/// 워크플로:
///   pending → in_progress (Start)
///   in_progress → under_review (Submit, 텍스트+첨부 모달)
///   under_review → completed (manager Confirm)
///   under_review → in_progress (manager Reject, 사유 필수)
///   completed → in_progress (manager Reopen)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/app_localizations.dart';
import '../../models/task.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/storage_service.dart';
import '../../services/task_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const TaskDetailScreen({super.key, required this.id});

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  final List<TaskAttachmentItem> _commentAttachments = [];
  bool _postingComment = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(taskProvider.notifier).loadTask(widget.id);
    });
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _isManager {
    final user = ref.read(authProvider).user;
    return user != null && user.roleLevel <= 30; // SV+ 까지 review 가능
  }

  bool get _isManagerStrict {
    final user = ref.read(authProvider).user;
    return user != null && user.roleLevel <= 20; // GM+
  }

  bool _isAssignee(AdditionalTask task) {
    final me = ref.read(authProvider).user;
    if (me == null) return false;
    return task.assignees.any((a) => a.userId == me.id);
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'in_progress':
        return AppColors.accent;
      case 'under_review':
        return AppColors.warning;
      case 'completed':
        return AppColors.success;
      default:
        return AppColors.textMuted;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warningBg;
      case 'in_progress':
        return AppColors.accentBg;
      case 'under_review':
        return AppColors.warningBg;
      case 'completed':
        return AppColors.successBg;
      default:
        return AppColors.bg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final state = ref.watch(taskProvider);
    final task = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: t.taskDetailHeader,
            isDetail: true,
            onBack: () => context.pop(),
          ),
          if (state.isLoading && task == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (task == null)
            Expanded(
              child: Center(
                child: Text(
                  state.error ?? t.taskNotFound,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(task),
                    _buildMeta(task),
                    if ((task.description ?? '').trim().isNotEmpty)
                      _buildDescription(task),
                    if (task.attachments.isNotEmpty)
                      _buildReferenceAttachments(task),
                    _buildActivity(task),
                    _buildCommentInput(task),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          if (task != null)
            _buildBottomBar(task, state.isLoading),
        ],
      ),
    );
  }

  // ── Hero — status badge + priority + title + store(s) ────────────────
  Widget _buildHero(AdditionalTask task) {
    final storeNames = task.storeNames.isNotEmpty
        ? task.storeNames.join(' · ')
        : (task.storeName ?? 'Organization-wide');
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (task.priority == 'urgent') ...[
                _chip('Urgent', AppColors.danger, AppColors.dangerBg),
                const SizedBox(width: 6),
              ],
              _chip(task.statusLabel, _statusColor(task.status), _statusBg(task.status)),
              if ((task.category ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                _chip(task.category!, AppColors.textSecondary, AppColors.bg),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            task.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            storeNames,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Meta — due / assigned / created / submitted / reviewed ───────────
  Widget _buildMeta(AdditionalTask task) {
    final rows = <Widget>[];
    if (task.dueDate != null) {
      rows.add(_metaRow(Icons.schedule, 'Due date',
          formatDateTime(task.dueDate!), AppColors.warning));
    }
    if (task.assignees.isNotEmpty) {
      rows.add(_metaRow(
        Icons.people_alt_outlined,
        'Assigned to',
        task.assignees.map((a) => a.fullName ?? '—').join(', '),
        AppColors.text,
      ));
    }
    if ((task.createdByName ?? '').isNotEmpty) {
      rows.add(_metaRow(
        Icons.person_outline,
        'Created by',
        task.createdByName!,
        AppColors.text,
      ));
    }
    if (task.createdAt != null) {
      rows.add(_metaRow(Icons.access_time, 'Created at',
          formatDateTime(task.createdAt!), AppColors.textSecondary));
    }
    if (task.submittedAt != null) {
      rows.add(_metaRow(
        Icons.outbox_outlined,
        'Submitted by',
        '${task.submittedByName ?? "—"} · ${formatDateTime(task.submittedAt!)}',
        AppColors.textSecondary,
      ));
    }
    if (task.reviewedAt != null && task.status == 'completed') {
      rows.add(_metaRow(
        Icons.verified_outlined,
        'Approved by',
        '${task.reviewedByName ?? "—"} · ${formatDateTime(task.reviewedAt!)}',
        AppColors.success,
      ));
    }
    if (task.reviewedAt != null && task.status == 'in_progress') {
      rows.add(_metaRow(
        Icons.undo_outlined,
        'Sent back by',
        '${task.reviewedByName ?? "—"} · ${formatDateTime(task.reviewedAt!)}',
        AppColors.warning,
      ));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: Text(
              label,
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }

  // ── Description ─────────────────────────────────────────────────────
  Widget _buildDescription(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Description',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text),
          ),
          const SizedBox(height: 8),
          Text(
            task.description!,
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
        ],
      ),
    );
  }

  // ── Reference attachments (관리자가 첨부) ────────────────────────────
  Widget _buildReferenceAttachments(AdditionalTask task) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reference',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text),
          ),
          const SizedBox(height: 10),
          _attachmentsGrid(task.attachments, removable: false, onRemove: null),
        ],
      ),
    );
  }

  // ── Activity timeline (system + user comments) ───────────────────────
  Widget _buildActivity(AdditionalTask task) {
    final commentsAsync = ref.watch(taskCommentsProvider(task.id));
    return Container(
      width: double.infinity,
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Activity',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.text),
          ),
          const SizedBox(height: 10),
          commentsAsync.when(
            data: (comments) {
              if (comments.isEmpty) {
                return const Text(
                  'No activity yet.',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic),
                );
              }
              return Column(
                children: comments.map(_commentTile).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (err, _) => Text(
              'Failed to load activity: $err',
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentTile(TaskCommentItem c) {
    final isSystem = c.kind == 'system';
    final timestamp =
        c.createdAt != null ? formatDateTime(c.createdAt!) : '';
    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '${c.userName ?? "—"} · ${c.content} · $timestamp',
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border:
            Border(left: BorderSide(color: AppColors.accent, width: 2)),
        color: AppColors.bg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                '${c.userName ?? "—"} · $timestamp',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
          if (c.content.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(c.content,
                style: const TextStyle(fontSize: 13, color: AppColors.text)),
          ],
          if (c.attachments.isNotEmpty) ...[
            const SizedBox(height: 8),
            _attachmentsGrid(c.attachments, removable: false, onRemove: null),
          ],
        ],
      ),
    );
  }

  // ── Comment input (텍스트 + 첨부 grid) ──────────────────────────────
  Widget _buildCommentInput(AdditionalTask task) {
    if (task.status == 'completed') return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'New message',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.text),
          ),
          const SizedBox(height: 8),
          // Attachment grid + 빈 (+) 박스 — message 칸 위에.
          _attachmentsGrid(
            _commentAttachments,
            removable: true,
            onRemove: (idx) =>
                setState(() => _commentAttachments.removeAt(idx)),
            onAdd: _postingComment
                ? null
                : () async {
                    await _pickAttachment(_commentAttachments);
                    if (mounted) setState(() {});
                  },
          ),
          const SizedBox(height: 10),
          // TextField + 오른쪽 Send 버튼 한 줄.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Write a message…',
                    hintStyle:
                        TextStyle(fontSize: 13, color: AppColors.textMuted),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  onPressed: (_postingComment ||
                          (_commentCtrl.text.trim().isEmpty &&
                              _commentAttachments.isEmpty))
                      ? null
                      : () => _postComment(task.id),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: _postingComment
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Send'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom bar — workflow buttons ───────────────────────────────────
  Widget _buildBottomBar(AdditionalTask task, bool busy) {
    final t = AppL10n.of(context);
    final isAssignee = _isAssignee(task);
    final isManager = _isManager;
    final isManagerStrict = _isManagerStrict;

    Widget? content;
    switch (task.status) {
      case 'pending':
        if (isAssignee || isManager) {
          content = _primaryButton(
            label: 'Start',
            icon: Icons.play_arrow,
            busy: busy,
            onPressed: () => _quickTransition(task.id, 'in_progress'),
          );
        }
        break;
      case 'in_progress':
        if (isAssignee || isManager) {
          content = _primaryButton(
            label: 'Done',
            icon: Icons.check,
            busy: busy,
            onPressed: () => _quickTransition(task.id, 'under_review'),
          );
        }
        break;
      case 'under_review':
        if (isManager) {
          content = Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _quickTransition(task.id, 'completed'),
                  icon: const Icon(Icons.check, size: 18, color: Colors.white),
                  label: const Text('Confirm',
                      style:
                          TextStyle(color: Colors.white, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _quickTransition(task.id, 'in_progress'),
                  icon: const Icon(Icons.undo,
                      size: 18, color: Colors.white),
                  label: const Text('Reject',
                      style:
                          TextStyle(color: Colors.white, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          );
        } else {
          content = const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Waiting for manager review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontStyle: FontStyle.italic),
            ),
          );
        }
        break;
      case 'completed':
        if (isManagerStrict) {
          content = _primaryButton(
            label: 'Reopen',
            icon: Icons.refresh,
            busy: busy,
            onPressed: () => _quickTransition(task.id, 'in_progress'),
          );
        }
        break;
    }

    if (content == null) return const SizedBox.shrink();
    // 사용 안 한 t는 향후 라벨 i18n 변환용.
    if (kDebugMode) {
      // ignore: unnecessary_statements
      t;
    }
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        color: AppColors.white,
        child: content,
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required IconData icon,
    required bool busy,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: Icon(icon, color: Colors.white, size: 18),
        label: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 15)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // ── Transition helper — 단순 status 전이만. 보고/사유는 comment 로. ──
  Future<void> _quickTransition(String id, String status) async {
    try {
      await ref
          .read(taskProvider.notifier)
          .transition(id, status: status);
      ref.invalidate(taskCommentsProvider(id));
    } catch (e) {
      if (mounted) {
        await AppModal.show(context,
            title: 'Failed', message: e.toString(), type: ModalType.error);
      }
    }
  }

  // ── Comment post (text + attachments) ───────────────────────────────
  Future<void> _postComment(String id) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty && _commentAttachments.isEmpty) return;
    setState(() => _postingComment = true);
    try {
      final service = ref.read(taskServiceProvider);
      await service.addComment(
        id,
        content: text,
        attachments: _commentAttachments.map((a) => a.toJson()).toList(),
      );
      _commentCtrl.clear();
      setState(() {
        _commentAttachments.clear();
      });
      ref.invalidate(taskCommentsProvider(id));
    } catch (e) {
      if (mounted) {
        await AppModal.show(context,
            title: 'Failed', message: e.toString(), type: ModalType.error);
      }
    } finally {
      if (mounted) setState(() => _postingComment = false);
    }
  }

  // ── Attachment picker + upload ──────────────────────────────────────
  Future<void> _pickAttachment(List<TaskAttachmentItem> target) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final filename = picked.name;
    final ext = filename.split('.').last.toLowerCase();
    final mime = _guessMime(ext);
    try {
      final storage = ref.read(storageServiceProvider);
      final urls = await storage.getPresignedUrl(filename, mime,
          folder: 'tasks');
      await storage.uploadFile(urls['upload_url']!, bytes, mime);
      final key = urls['file_url']!;
      final kind = mime.startsWith('video/') ? 'video' : 'image';
      setState(() {
        target.add(TaskAttachmentItem(
          key: key,
          url: key,
          mimeType: mime,
          kind: kind,
          name: filename,
          size: bytes.length,
        ));
      });
    } catch (e) {
      if (mounted) {
        await AppModal.show(context,
            title: 'Upload failed',
            message: e.toString(),
            type: ModalType.error);
      }
    }
  }

  // ── Attachments grid widget (reusable) ──────────────────────────────
  /// [onAdd] 가 있으면 마지막에 dashed (+) 박스가 그려져 새 첨부 추가 가능.
  /// [removable] + [onRemove] 가 있으면 각 항목 우상단에 X 버튼.
  /// 이미지 thumbnail 클릭 시 fullscreen viewer.
  Widget _attachmentsGrid(
    List<TaskAttachmentItem> items, {
    required bool removable,
    required void Function(int idx)? onRemove,
    VoidCallback? onAdd,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...items.asMap().entries.map((entry) {
          final idx = entry.key;
          final a = entry.value;
          final isImage = (a.kind == 'image') ||
              (a.mimeType?.startsWith('image/') ?? false);
          final isVideo = (a.kind == 'video') ||
              (a.mimeType?.startsWith('video/') ?? false);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: isImage && (a.url ?? '').isNotEmpty
                    ? () => _openImageViewer(items, idx)
                    : null,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: isImage && (a.url ?? '').isNotEmpty
                      ? Image.network(
                          a.url!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image,
                              color: AppColors.textMuted),
                        )
                      : Center(
                          child: Text(
                            isVideo ? '🎬' : '📄',
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                ),
              ),
              if (removable && onRemove != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: GestureDetector(
                    onTap: () => onRemove(idx),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 12, color: Colors.white),
                    ),
                  ),
                ),
            ],
          );
        }),
        if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.add,
                  color: AppColors.textMuted, size: 28),
            ),
          ),
      ],
    );
  }

  /// Image viewer — pinch zoom + swipe (다중 이미지면 좌/우 인덱스 이동).
  void _openImageViewer(List<TaskAttachmentItem> items, int initialIndex) {
    final imageItems = items.where((a) {
      final isImage = (a.kind == 'image') ||
          (a.mimeType?.startsWith('image/') ?? false);
      return isImage && (a.url ?? '').isNotEmpty;
    }).toList();
    if (imageItems.isEmpty) return;
    // 원본 index 를 image-only index 로 매핑.
    int startIdx = imageItems.indexWhere((a) => a == items[initialIndex]);
    if (startIdx < 0) startIdx = 0;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            _ImageViewerScreen(images: imageItems, initialIndex: startIdx),
      ),
    );
  }

  String _guessMime(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        return 'application/octet-stream';
    }
  }

  Widget _chip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: fg)),
    );
  }
}

// ── Image viewer — pinch zoom + swipe (multi-image) ────────────────────
class _ImageViewerScreen extends StatefulWidget {
  final List<TaskAttachmentItem> images;
  final int initialIndex;
  const _ImageViewerScreen({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.images.length > 1
              ? '${_current + 1} / ${widget.images.length}'
              : (widget.images[_current].name ?? ''),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) {
          final a = widget.images[i];
          return InteractiveViewer(
            minScale: 1.0,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                a.url!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image,
                  color: Colors.white54,
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

