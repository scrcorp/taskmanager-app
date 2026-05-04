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
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/clockin_pin_service.dart';
import '../../widgets/app_modal.dart';

/// 서류 유형 정의 (key, 제목, 설명, 아이콘)
class _DocumentType {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _DocumentType({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

const _documentTypes = [
  _DocumentType(key: 'food_handler', title: 'Food Handler Card', subtitle: 'Required food safety certification', icon: Icons.restaurant_menu),
  _DocumentType(key: 'ssn_work_auth', title: 'SSN / Work Authorization', subtitle: 'Social Security Number or Work Permit', icon: Icons.badge_outlined),
  _DocumentType(key: 'id_card', title: 'Government ID', subtitle: 'Driver License / State ID / Passport', icon: Icons.credit_card),
  _DocumentType(key: 'i9_form', title: 'I-9 Form', subtitle: 'Employment Eligibility Verification', icon: Icons.description_outlined),
  _DocumentType(key: 'w4_form', title: 'W-4 Form', subtitle: "Employee's Withholding Certificate", icon: Icons.receipt_long_outlined),
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

  String _languageLabel(String? code) {
    switch (code) {
      case 'es':
        return 'Español';
      case 'ko':
        return '한국어';
      default:
        return 'English';
    }
  }

  Future<void> _showLanguagePicker() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Preferred Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
            ),
            for (final entry in const [
              MapEntry('en', 'English'),
              MapEntry('es', 'Español'),
              MapEntry('ko', '한국어'),
            ])
              ListTile(
                title: Text(entry.value),
                trailing: user.preferredLanguage == entry.key
                    ? const Icon(Icons.check, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null || selected == user.preferredLanguage) return;
    final success = await ref.read(authProvider.notifier).updateProfile({
      'preferred_language': selected,
    });
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Language preference saved'), backgroundColor: AppColors.success),
      );
    } else {
      final error = ref.read(authProvider).error ?? 'Failed to update language';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _showEditUsernameDialog() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    final controller = TextEditingController(text: user.username);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditUsernameDialog(controller: controller),
    );

    if (result != null && result.trim().isNotEmpty && result.trim() != user.username) {
      final success = await ref.read(authProvider.notifier).updateProfile({
        'username': result.trim(),
      });
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username updated successfully'), backgroundColor: AppColors.success),
          );
        } else {
          final error = ref.read(authProvider).error ?? 'Failed to update username';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  Future<void> _pickProfileImage() async {
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
              const Text('Change Profile Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt, color: AppColors.accent, size: 20),
                ),
                title: const Text('Take Photo', style: TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getImage(ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library, color: AppColors.accent, size: 20),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getImage(ImageSource.gallery); },
              ),
              if (_profileImage != null)
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  ),
                  title: const Text('Remove Photo', style: TextStyle(fontSize: 15, color: AppColors.danger)),
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
              Text(hasDoc ? 'Replace Document' : 'Upload Document', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt, color: AppColors.accent, size: 20),
                ),
                title: const Text('Take Photo', style: TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getDocumentImage(key, ImageSource.camera); },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library, color: AppColors.accent, size: 20),
                ),
                title: const Text('Choose from Gallery', style: TextStyle(fontSize: 15)),
                onTap: () { Navigator.pop(ctx); _getDocumentImage(key, ImageSource.gallery); },
              ),
              if (hasDoc)
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: AppColors.dangerBg, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                  ),
                  title: const Text('Remove', style: TextStyle(fontSize: 15, color: AppColors.danger)),
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
    final user = ref.watch(authProvider).user;
    final unread = ref.watch(notificationProvider).unreadCount;
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
        title: const Text('My Page'),
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
                      Text(user?.fullName ?? 'Staff', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                      const SizedBox(height: 2),
                      Text('@${user?.username ?? ''}', style: const TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(user?.roleName ?? 'staff', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      if (user?.email != null && user!.email!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(user.email!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                      const SizedBox(height: 2),
                      const _ProfilePinRow(),
                    ],
                  ),
                ),
              ],
            ),
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
                        const Text('Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                          child: Text('0/${_documentTypes.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.accent)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Upload required documents for employment verification', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
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
                          const Text('Coming Soon', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                          const SizedBox(height: 4),
                          const Text('This feature is under development', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
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
                  label: 'Alerts',
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
                  label: 'Edit Username',
                  onTap: _showEditUsernameDialog,
                ),
                const Divider(height: 1),
                _MenuItem(
                  label: 'Preferred Language',
                  trailing: Text(
                    _languageLabel(ref.watch(authProvider).user?.preferredLanguage),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  onTap: _showLanguagePicker,
                ),
                const Divider(height: 1),
                _MenuItem(
                  label: 'Change Password',
                  onTap: () => context.push('/my/change-password'),
                ),
                const Divider(height: 1),
                _MenuItem(
                  label: 'Logout',
                  isDestructive: true,
                  onTap: () async {
                    final confirmed = await AppModal.show(context, title: 'Logout', message: 'Are you sure you want to log out?', type: ModalType.confirm, confirmText: 'Logout');
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

/// Profile 정보 한 줄 PIN row — masked 기본, 눈 아이콘 토글로 노출.
///
/// profile info 영역에 한 줄로 표시 ("PIN: ●●●●●● [eye]"). Regenerate 는 제거됨.
class _ProfilePinRow extends ConsumerStatefulWidget {
  const _ProfilePinRow();

  @override
  ConsumerState<_ProfilePinRow> createState() => _ProfilePinRowState();
}

class _ProfilePinRowState extends ConsumerState<_ProfilePinRow> {
  String? _pin;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ref.read(clockinPinServiceProvider).getPin();
      if (!mounted) return;
      setState(() {
        _pin = data['clockin_pin']?.toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = _loading ? '…' : (_pin ?? '—');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('PIN: ',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.text)),
        Text(
          display,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.text,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
                      Text(docType.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 2),
                      if (isUploaded && uploadedAt != null)
                        Text('Uploaded ${_formatDate(uploadedAt!)}', style: const TextStyle(fontSize: 12, color: AppColors.success))
                      else
                        Text(docType.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
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
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.upload_file, size: 16, color: Colors.white),
                        SizedBox(width: 4),
                        Text('Upload', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
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

class _EditUsernameDialog extends StatefulWidget {
  final TextEditingController controller;
  const _EditUsernameDialog({required this.controller});

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late String _initial;

  @override
  void initState() {
    super.initState();
    _initial = widget.controller.text;
    widget.controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  bool get _canSave {
    final val = widget.controller.text.trim();
    return val.isNotEmpty && val != _initial;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Username', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 16),
            TextField(
              controller: widget.controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Enter new username',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.accent)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _canSave ? () => Navigator.pop(context, widget.controller.text) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
