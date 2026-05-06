/// 공지사항 상세 화면
///
/// 공지 제목, 본문, 작성자, 날짜, scope(매장/전체) 표시.
/// 하단 섹션: 확인(Acknowledge) 토글 + 댓글 목록 + 댓글 입력.
/// 확인 버튼 누르면 읽음 상태가 토글되고 확인한 사용자 목록이 표시됨.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/notice.dart';
import '../../providers/notice_provider.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_modal.dart';

/// 공지사항 상세 화면 위젯
class NoticeDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const NoticeDetailScreen({super.key, required this.id});

  @override
  ConsumerState<NoticeDetailScreen> createState() =>
      _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  final _commentController = TextEditingController();
  final _commentFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(noticeProvider.notifier).loadNotice(widget.id));
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  void _submitComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    _commentController.clear();
    _commentFocus.unfocus();
    ref.read(noticeProvider.notifier).addComment(widget.id, text: text);
  }

  Future<void> _toggleAcknowledge() async {
    final current = ref.read(noticeProvider).selected;
    ref.read(noticeProvider.notifier).toggleAcknowledge(widget.id);
    if (current != null && !current.isAcknowledged) {
      await AppModal.show(
        context,
        title: 'Acknowledged',
        message: 'Acknowledged',
        type: ModalType.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noticeProvider);
    final notice = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: 'Notice', isDetail: true, onBack: () => context.pop()),
          if (state.isLoading && notice == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (notice == null)
            Expanded(
              child: Center(
                child: Text(state.error ?? 'Notice not found',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            )
          else ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: title + meta ──
                    _buildHeader(notice),
                    const SizedBox(height: 8),
                    // ── Content body ──
                    _buildBody(notice),
                    const SizedBox(height: 8),
                    // ── Acknowledgment section ──
                    _AcknowledgmentSection(
                      notice: notice,
                      onToggle: _toggleAcknowledge,
                    ),
                    const SizedBox(height: 8),
                    // ── Comments section ──
                    _buildCommentsSection(notice),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // ── Comment input bar ──
            _buildCommentInput(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(Notice notice) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notice.title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: notice.store != null
                      ? AppColors.accentBg
                      : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: notice.store != null
                        ? AppColors.accent.withValues(alpha: 0.3)
                        : AppColors.border,
                  ),
                ),
                child: Text(notice.scope,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: notice.store != null
                            ? AppColors.accent
                            : AppColors.textSecondary)),
              ),
              if (notice.createdByName != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline,
                        size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(notice.createdByName ?? 'Unknown',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              if (notice.createdAt != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(formatDate(notice.createdAt!),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Notice notice) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Text(notice.content,
          style: const TextStyle(
              fontSize: 14, height: 1.6, color: AppColors.text)),
    );
  }

  Widget _buildCommentsSection(Notice notice) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments (${notice.comments.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          if (notice.comments.isEmpty) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 32,
                      color: AppColors.textMuted.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  const Text(
                    'No comments yet',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Be the first to leave a comment',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const SizedBox(height: 16),
            ...notice.comments
                .map((comment) => _NoticeCommentTile(comment: comment)),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accentBg,
              child: Icon(Icons.person, size: 16, color: AppColors.accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                decoration: InputDecoration(
                  hintText: 'Write a comment...',
                  hintStyle: const TextStyle(
                      fontSize: 14, color: AppColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  filled: true,
                  fillColor: AppColors.bg,
                ),
                style: const TextStyle(fontSize: 14),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submitComment(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: AppColors.accent),
              onPressed: _submitComment,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Acknowledgment Section ─────────────────────────────────────────────────

class _AcknowledgmentSection extends StatelessWidget {
  final Notice notice;
  final VoidCallback onToggle;

  const _AcknowledgmentSection({
    required this.notice,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final acks = notice.acknowledgments;
    final isAcked = notice.isAcknowledged;

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Acknowledge button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isAcked ? AppColors.successBg : AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isAcked
                      ? AppColors.success.withValues(alpha: 0.4)
                      : AppColors.border,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAcked
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    size: 20,
                    color: isAcked ? AppColors.success : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAcked ? 'Acknowledged' : 'Mark as read',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isAcked ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                  if (acks.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isAcked
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.border.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${acks.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAcked ? AppColors.success : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Acknowledgment avatars
          if (acks.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: acks.map((ack) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.textMuted,
                        child: Text(
                          (ack.userName?.isNotEmpty ?? false)
                              ? ack.userName![0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ack.userName ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Notice Comment Tile ────────────────────────────────────────────────────

class _NoticeCommentTile extends StatelessWidget {
  final NoticeComment comment;

  const _NoticeCommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.bg,
            child: Text(
              (comment.userName?.isNotEmpty ?? false)
                  ? comment.userName![0].toUpperCase()
                  : '?',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgo(comment.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      comment.isLiked ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: comment.isLiked ? AppColors.danger : AppColors.textMuted,
                    ),
                    if (comment.likes > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '${comment.likes}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
