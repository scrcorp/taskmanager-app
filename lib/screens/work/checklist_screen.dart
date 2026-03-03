import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/assignment.dart';
import '../../models/checklist.dart';
import '../../providers/assignment_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  final String id;
  const ChecklistScreen({super.key, required this.id});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  bool _celebrationShown = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(assignmentProvider.notifier).loadAssignment(widget.id));
  }

  void _showCompletionToast() {
    if (_celebrationShown) return;
    _celebrationShown = true;
    ToastManager().success(context, 'All tasks completed! Great work!');
  }

  bool _isUploading = false;

  void _onItemTap(ChecklistItem item) async {
    if (item.isCompleted || _isUploading) return;

    String? photoUrl;
    String? note;

    // Handle photo requirement
    if (item.requiresPhoto) {
      photoUrl = await _handlePhotoCapture();
      if (photoUrl == null) return; // User cancelled
    }

    // Handle text/comment requirement
    if (item.requiresComment) {
      note = await _showNoteDialog();
      if (note == null) return; // User cancelled
    }

    ref.read(assignmentProvider.notifier).toggleChecklistItem(
      widget.id, item.index, true,
      photoUrl: photoUrl,
      note: note,
    );
  }

  Future<String?> _handlePhotoCapture() async {
    final source = await _showPhotoSourceSheet();
    if (source == null) return null;

    final picker = ImagePicker();
    final XFile? picked;
    if (source == ImageSource.camera) {
      picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    } else {
      picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    }
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
      debugPrint('[ChecklistScreen] Photo upload error: $e');
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.accent),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppColors.accent),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<String?> _showNoteDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Add Note', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter verification note...',
            hintStyle: TextStyle(color: AppColors.textMuted),
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assignmentProvider);
    final assignment = state.selected;

    // Show toast when all completed
    if (assignment != null &&
        assignment.checklistSnapshot != null &&
        assignment.checklistSnapshot!.isAllCompleted &&
        !_celebrationShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCompletionToast();
      });
    }

    return Stack(
      children: [
        Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: assignment?.store.name ?? 'Checklist',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          if (state.isLoading && assignment == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (state.error != null && assignment == null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Failed to load assignment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () {
                          ref.read(assignmentProvider.notifier).loadAssignment(widget.id);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (assignment == null)
            const Expanded(child: Center(child: Text('Assignment not found')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  await ref.read(assignmentProvider.notifier).loadAssignment(widget.id);
                },
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Assignment header card
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
                            assignment.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatFixedDateWithDay(assignment.workDate),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildProgressSection(assignment),
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
                        if (assignment.checklistSnapshot != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${assignment.checklistSnapshot!.totalItems}',
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
                    if (assignment.checklistSnapshot == null ||
                        assignment.checklistSnapshot!.items.isEmpty)
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
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
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
                            assignment.checklistSnapshot!.items.length,
                            (index) {
                              final item = assignment.checklistSnapshot!.items[index];
                              return Column(
                                children: [
                                  if (index > 0)
                                    const Divider(height: 1, color: AppColors.border),
                                  _ChecklistItemTile(
                                    item: item,
                                    onTap: () => _onItemTap(item),
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
                    style: TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProgressSection(Assignment assignment) {
    final snapshot = assignment.checklistSnapshot;
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

class _ChecklistItemTile extends StatelessWidget {
  final ChecklistItem item;
  final VoidCallback onTap;

  const _ChecklistItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: item.isCompleted ? AppColors.success : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isCompleted ? AppColors.success : AppColors.border,
                    width: 2,
                  ),
                ),
                child: item.isCompleted
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: item.isCompleted ? AppColors.textMuted : AppColors.text,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  if (item.description != null && item.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                  if (item.isCompleted && item.completedAtDisplay != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Done ${item.completedAtDisplay}${item.completedBy != null ? ' · ${item.completedBy}' : ''}',
                      style: const TextStyle(fontSize: 11, color: AppColors.success),
                    ),
                  ],
                ],
              ),
            ),
            // Verification type icons
            if (item.requiresVerification && !item.isCompleted) ...[
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.requiresPhoto)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.accent.withValues(alpha: 0.7)),
                    ),
                  if (item.requiresComment)
                    Icon(Icons.edit_note, size: 18, color: AppColors.accent.withValues(alpha: 0.7)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
