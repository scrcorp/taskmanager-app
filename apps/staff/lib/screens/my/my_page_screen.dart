/// 마이 페이지 화면
///
/// 프로필 정보 표시 (이름, 역할, 이메일) + 프로필 사진 변경.
/// 서류 업로드 섹션 (Food Handler, SSN, ID 등) — 현재 "Coming Soon" 상태.
/// 메뉴: 알림 (미읽음 배지) + 로그아웃.
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/alert_provider.dart';
import '../../providers/warnings_provider.dart';
import '../../widgets/profile_pin_row.dart';

/// 서류 유형 정의 — title/subtitle은 ARB에서 동적으로 가져옴
class _DocumentType {
  final String key;
  final IconData icon;
  final String Function(AppL10n t) title;
  final String Function(AppL10n t) subtitle;

  const _DocumentType({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

final _documentTypes = <_DocumentType>[
  _DocumentType(
    key: 'food_handler',
    icon: Icons.restaurant_menu,
    title: (t) => t.myDocFoodHandlerTitle,
    subtitle: (t) => t.myDocFoodHandlerSubtitle,
  ),
  _DocumentType(
    key: 'ssn_work_auth',
    icon: Icons.badge_outlined,
    title: (t) => t.myDocSsnTitle,
    subtitle: (t) => t.myDocSsnSubtitle,
  ),
  _DocumentType(
    key: 'id_card',
    icon: Icons.credit_card,
    title: (t) => t.myDocIdTitle,
    subtitle: (t) => t.myDocIdSubtitle,
  ),
  _DocumentType(
    key: 'i9_form',
    icon: Icons.description_outlined,
    title: (t) => t.myDocI9Title,
    subtitle: (t) => t.myDocI9Subtitle,
  ),
  _DocumentType(
    key: 'w4_form',
    icon: Icons.receipt_long_outlined,
    title: (t) => t.myDocW4Title,
    subtitle: (t) => t.myDocW4Subtitle,
  ),
];

/// 마이 페이지 화면 위젯
class MyPageScreen extends ConsumerStatefulWidget {
  final String? returnTo;
  const MyPageScreen({super.key, this.returnTo});

  @override
  ConsumerState<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends ConsumerState<MyPageScreen> {
  Uint8List? _profileImage;
  final _picker = ImagePicker();
  final Map<String, Uint8List> _documents = {};
  final Map<String, DateTime> _uploadedAt = {};

  @override
  void initState() {
    super.initState();
    // Warnings 카드 배지용 — 미서명 수를 가볍게 조회.
    Future.microtask(() => ref.read(warningsProvider.notifier).refreshUnsignedCount());
  }

  Future<void> _pickProfileImage() async {
    final t = AppL10n.of(context);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Text(t.myChangePhoto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt, color: AppColors.accent, size: 20),
                ),
                title: Text(t.myTakePhoto, style: const TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getImage(ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library, color: AppColors.accent, size: 20),
                ),
                title: Text(t.myChooseGallery, style: const TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getImage(ImageSource.gallery); },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  ),
                  title: Text(t.myRemovePhoto, style: const TextStyle(fontSize: 15, color: AppColors.danger)),
                  onTap: () { Navigator.pop(ctx); setState(() => _profileImage = null); },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() => _profileImage = bytes);
      }
    } catch (_) {}
  }

  Future<void> _pickDocument(String key) async {
    final t = AppL10n.of(context);
    final hasDoc = _documents.containsKey(key);
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
              ),
              Text(hasDoc ? t.myReplaceDocument : t.myUploadDocument, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt, color: AppColors.accent, size: 20),
                ),
                title: Text(t.myTakePhoto, style: const TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getDocumentImage(key, ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library, color: AppColors.accent, size: 20),
                ),
                title: Text(t.myChooseGallery, style: const TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getDocumentImage(key, ImageSource.gallery); },
              ),
              if (hasDoc)
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  ),
                  title: Text(t.actionRemove, style: const TextStyle(fontSize: 15, color: AppColors.danger)),
                  onTap: () { Navigator.pop(ctx); setState(() { _documents.remove(key); _uploadedAt.remove(key); }); },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _getDocumentImage(String key, ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() { _documents[key] = bytes; _uploadedAt[key] = DateTime.now(); });
      }
    } catch (_) {}
  }

  void _previewDocument(String key, String title) {
    final bytes = _documents[key];
    if (bytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text))),
                  IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            ClipRRect(
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(alertProvider).unreadCount;
    final unsignedWarnings = ref.watch(warningsProvider).unsignedCount;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () {
            final returnTo = widget.returnTo;
            if (returnTo != null) {
              context.go(returnTo);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(t.myPageHeader),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile header ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.accentBg,
                        backgroundImage: _profileImage != null ? MemoryImage(_profileImage!) : null,
                        child: _profileImage == null
                            ? Text(user?.initials ?? '??', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.accent))
                            : null,
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle, border: Border.all(color: AppColors.white, width: 2)),
                          child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.fullName ?? t.commonStaff, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text('@${user?.username ?? ''}', style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(user?.roleName ?? 'staff', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      if (user?.email != null && user!.email!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(user.email!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Clock-in PIN ──
          const ProfilePinRow(),
          const SizedBox(height: 16),

          // ── Warnings ──
          _WarningsCard(
            unsignedCount: unsignedWarnings,
            onTap: () => context.push('/my/warnings'),
          ),
          const SizedBox(height: 24),

          // ── Documents Section (Coming Soon) ──
          Stack(
            children: [
              IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(t.myDocumentsHeader, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                          child: Text('0/${_documentTypes.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(t.myDocumentsSubtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    const SizedBox(height: 12),
                    ...List.generate(_documentTypes.length, (i) {
                      final doc = _documentTypes[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DocumentCard(
                          docType: doc, isUploaded: false,
                          onUpload: () {},
                          onPreview: () {},
                        ),
                      );
                    }),
                  ],
                ),
              ),
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 52, height: 52,
                            decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.construction_rounded, size: 26, color: AppColors.accent),
                          ),
                          const SizedBox(height: 10),
                          Text(t.commonComingSoonTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                          const SizedBox(height: 4),
                          Text(t.myDocumentsUnderDev, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Menu ──
          Container(
            decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                _MenuItem(
                  label: t.alertsHeader,
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                          child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        )
                      : null,
                  onTap: () => context.push('/alerts'),
                ),
                const Divider(height: 1),
                _MenuItem(
                  label: t.settingsHeader,
                  onTap: () => context.push('/my/settings'),
                ),
                const Divider(height: 1),
                _MenuItem(
                  label: t.actionLogoutConfirm,
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await AppModal.show(context, title: t.myLogoutConfirmTitle, message: t.myLogoutConfirmMessage, type: ModalType.confirm, confirmText: t.actionLogoutConfirm);
                    if (confirmed == true) {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) context.go('/login');
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// My Page 의 Warnings 진입 카드 (PIN 아래). 미서명 수 배지를 표시.
class _WarningsCard extends StatelessWidget {
  final int unsignedCount;
  final VoidCallback onTap;
  const _WarningsCard({required this.unsignedCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final hasUnsigned = unsignedCount > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: hasUnsigned ? AppColors.dangerBg : AppColors.accentBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_amber_rounded,
                  size: 22, color: hasUnsigned ? AppColors.danger : AppColors.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.warningsCardTitle,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(
                    hasUnsigned
                        ? t.warningsCardNeedSignature(unsignedCount)
                        : t.warningsCardAllSigned,
                    style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            if (hasUnsigned) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 22),
                height: 22,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                    color: AppColors.danger, borderRadius: BorderRadius.circular(11)),
                child: Text('$unsignedCount',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final _DocumentType docType;
  final bool isUploaded;
  final DateTime? uploadedAt;
  final Uint8List? imageBytes;
  final VoidCallback onUpload;
  final VoidCallback onPreview;

  const _DocumentCard({required this.docType, required this.isUploaded, this.uploadedAt, this.imageBytes, required this.onUpload, required this.onPreview});

  String _formatDate(DateTime dt) {
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}.$m.$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isUploaded ? AppColors.success.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: isUploaded ? AppColors.successBg : AppColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(isUploaded ? Icons.check_circle : docType.icon, size: 22, color: isUploaded ? AppColors.success : AppColors.textMuted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(docType.title(t), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 2),
                      if (isUploaded && uploadedAt != null)
                        Text(t.myUploadedAt(_formatDate(uploadedAt!)), style: const TextStyle(fontSize: 12, color: AppColors.success))
                      else
                        Text(docType.subtitle(t), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isUploaded)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    GestureDetector(
                      onTap: onPreview,
                      child: Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.visibility_outlined, size: 18, color: AppColors.accent)),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onUpload,
                      child: Container(width: 34, height: 34, decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.more_horiz, size: 18, color: AppColors.textSecondary)),
                    ),
                  ])
                else
                  GestureDetector(
                    onTap: onUpload,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(10)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.upload_file, size: 16, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(t.actionUpload, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          if (isUploaded && imageBytes != null)
            GestureDetector(
              onTap: onPreview,
              child: Container(
                height: 80, width: double.infinity,
                decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border.withValues(alpha: 0.5)))),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(13), bottomRight: Radius.circular(13)),
                  child: Image.memory(imageBytes!, fit: BoxFit.cover, width: double.infinity),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final Widget? trailing;
  final bool isDestructive;
  final VoidCallback onTap;
  const _MenuItem({required this.label, this.trailing, this.isDestructive = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: isDestructive ? AppColors.danger : AppColors.text))),
            if (trailing != null) ...[trailing!, const SizedBox(width: 8)],
            if (!isDestructive) const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
