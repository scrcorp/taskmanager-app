/// 경고 공문(PDF) 뷰 — "Employee Warning Notice Form".
///
/// 경고를 공식 한 장짜리 문서로 렌더한다. 앱의 핑크/파랑 테마와 독립적으로
/// 종이-흰색 위 거의-검정 잉크 + 얇은 셀 테두리 + 굵은 외곽 프레임의 고정 색을 쓴다.
/// 읽기 전용. 고정 폭 시트를 화면 폭에 맞춰 축소(FittedBox)하고 세로 스크롤.
///
/// 서명된 경고면 employee 서명 stroke 를 Employee Signature 박스에 그린다
/// (manager 라인은 비워둠 — 매니저는 다른 곳에서 서명).
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/warning.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';
import '../../widgets/signature_strokes_view.dart';
import 'warning_detail_screen.dart' show warningTypeLabel;

// 고정 잉크-온-페이퍼 색 (테마 독립).
const _ink = Color(0xFF1A1C22);
const _inkSoft = Color(0xFF3C4049);
const _label = Color(0xFF6B7280);
const _muted = Color(0xFF9AA0AD);
const _rule = Color(0xFFC7CBD4);
const _fill = Color(0xFFF4F5F7);

// 시트는 이 고정 폭으로 그린 뒤 화면 폭에 맞춰 축소.
const _sheetWidth = 720.0;

class WarningPdfView extends StatelessWidget {
  final Warning warning;
  const WarningPdfView({super.key, required this.warning});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF3A3D42),
      body: Column(
        children: [
          AppHeader(
            title: t.warningDocumentTitle(warning.refNo),
            isDetail: true,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // 고정 폭 시트를 화면 폭에 맞게 축소.
                  return Center(
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: _sheetWidth,
                          child: _Sheet(warning: warning),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  final Warning warning;
  const _Sheet({required this.warning});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final reasonSet = warning.categories.toSet();
    final sig = warning.employeeSignature;
    final signedStrokes = warning.isSigned ? sig?.signatureStrokes : null;
    // 매니저 서명 — 콘솔에서 지정 매니저가 서명하면 함께 렌더(있을 때만).
    final mgr = warning.managerSignature;
    final mgrStrokes = mgr?.signatureStrokes;
    final warningDate = warning.warningDate ?? warning.createdAt;

    // 사유 3열 (라벨은 서버 제공 매핑 사용, categories 순서 유지).
    final reasonCols = _splitColumns(warning.categories, 3);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── banner ──
          Container(
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: _ink, width: 2.5),
                top: BorderSide(color: _ink, width: 2.5),
                right: BorderSide(color: _ink, width: 2.5),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Employee Warning Notice Form '),
                            TextSpan(
                              text: '(${warning.refNo})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, color: _inkSoft),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: _ink),
                      ),
                      const SizedBox(height: 5),
                      const Text('HUMAN RESOURCES · DISCIPLINARY RECORD',
                          style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w600,
                              color: _label)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 레터헤드 = 발행 매장(브랜드)명 + 발행일. (회사/조직명 아님 — 멀티브랜드)
                    Text(warning.storeName ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _ink)),
                    const SizedBox(height: 3),
                    if (warningDate != null)
                      Text('${t.warningDocDate} · ${formatFixedDate(warningDate)}',
                          style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w600,
                              color: _muted)),
                  ],
                ),
              ],
            ),
          ),

          // ── grid body (굵은 외곽 프레임) ──
          Container(
            decoration: Border.all(color: _ink, width: 2.5).toBoxDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // EMP ID / NAME / MANAGER
                _Row(children: [
                  _Cell(flex: 3, fill: true, label: t.warningDocEmpId, value: warning.employeeNo),
                  _Cell(flex: 5, label: t.warningDocEmployeeName, value: warning.subjectName),
                  _Cell(flex: 4, edgeRight: true, label: t.warningDocManagerName, value: warning.issuedByName),
                ]),
                // STORE / DATE 행 제거 — 매장명·날짜는 우상단 레터헤드로 이동(중복 제거).
                // WARNING TYPE
                _Row(children: [
                  _Cell(
                    flex: 12,
                    edgeRight: true,
                    label: t.warningDocWarningType,
                    child: Text(warningTypeLabel(t, warning.ordinal),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                  ),
                ]),
                // SECTION 1 — reasons band
                _SectionBand(text: t.warningDocReasonsTitle),
                _Row(children: [
                  _Cell(
                    flex: 12,
                    edgeRight: true,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: reasonCols
                          .map((col) => Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: col
                                      .map((c) => _ReasonItem(
                                            label: warning.labelFor(c),
                                            on: reasonSet.contains(c),
                                          ))
                                      .toList(),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ]),
                // Details
                _Row(children: [
                  _Cell(
                    flex: 12,
                    edgeRight: true,
                    label: t.warningDocDetailsLabel,
                    child: Text(
                      (warning.details ?? '').isNotEmpty ? warning.details! : t.warningDocNone,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: (warning.details ?? '').isNotEmpty ? _ink : _muted),
                    ),
                  ),
                ]),
                // SECTION 2 — corrective
                _SectionBand(text: t.warningDocCorrectiveTitle),
                _Row(children: [
                  _Cell(
                    flex: 12,
                    edgeRight: true,
                    child: Text(
                      (warning.correctiveAction ?? '').isNotEmpty
                          ? warning.correctiveAction!
                          : t.warningDocNone,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: (warning.correctiveAction ?? '').isNotEmpty ? _ink : _muted),
                    ),
                  ),
                ]),
                // Deadline / Follow-up date / time
                _Row(children: [
                  _Cell(
                    flex: 4,
                    label: t.warningDocDeadline,
                    value: warning.deadline != null ? formatFixedDate(warning.deadline!) : t.warningDocNone,
                  ),
                  _Cell(
                    flex: 4,
                    label: t.warningDocFollowUpDate,
                    value: warning.followUpDate != null
                        ? formatFixedDate(warning.followUpDate!)
                        : t.warningDocNone,
                  ),
                  _Cell(
                    flex: 4,
                    edgeRight: true,
                    label: t.warningDocFollowUpTime,
                    value: (warning.followUpTime ?? '').isNotEmpty
                        ? warning.followUpTime!
                        : t.warningDocNone,
                  ),
                ]),
                // Signatures
                _Row(children: [
                  _SignatureCell(
                    flex: 6,
                    label: t.warningDocEmployeeSignature,
                    strokes: signedStrokes,
                    name: warning.subjectName,
                    dateText: (warning.isSigned && sig?.signedAt != null)
                        ? formatDate(sig!.signedAt!)
                        : t.warningDocDate,
                  ),
                  _SignatureCell(
                    flex: 6,
                    edgeRight: true,
                    label: t.warningDocManagerSignature,
                    strokes: mgrStrokes,
                    name: mgr?.signerName ?? warning.issuedByName,
                    dateText: mgr?.signedAt != null
                        ? formatDate(mgr!.signedAt!)
                        : t.warningDocDate,
                  ),
                ]),
                // cc
                _Row(
                  edgeBottom: true,
                  children: [
                    _Cell(
                      flex: 12,
                      edgeRight: true,
                      edgeBottom: true,
                      label: t.warningDocCc,
                      child: Text(t.warningDocCcValue,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 항목을 [cols] 개 열로 분배 (col-major, 첫 열이 가장 많이).
  List<List<String>> _splitColumns(List<String> items, int cols) {
    final result = List.generate(cols, (_) => <String>[]);
    final per = (items.length / cols).ceil();
    for (var i = 0; i < items.length; i++) {
      final col = (i ~/ per).clamp(0, cols - 1);
      result[col].add(items[i]);
    }
    return result;
  }
}

extension _BorderToDeco on Border {
  BoxDecoration toBoxDecoration() => BoxDecoration(border: this);
}

class _Row extends StatelessWidget {
  final List<Widget> children;
  final bool edgeBottom;
  const _Row({required this.children, this.edgeBottom = false});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final int flex;
  final String? label;
  final String? value;
  final Widget? child;
  final bool fill;
  final bool edgeRight;
  final bool edgeBottom;

  const _Cell({
    required this.flex,
    this.label,
    this.value,
    this.child,
    this.fill = false,
    this.edgeRight = false,
    this.edgeBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: fill ? _fill : Colors.white,
          border: Border(
            right: edgeRight ? BorderSide.none : const BorderSide(color: _rule, width: 1),
            bottom: edgeBottom ? BorderSide.none : const BorderSide(color: _rule, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null) ...[
              Text(label!.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: _label)),
              const SizedBox(height: 5),
            ],
            if (child != null)
              child!
            else
              Text(
                (value ?? '').isNotEmpty ? value! : '—',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: (value ?? '').isNotEmpty ? _ink : _muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionBand extends StatelessWidget {
  final String text;
  const _SectionBand({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _fill,
        border: Border(bottom: BorderSide(color: _rule, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _ink)),
    );
  }
}

class _ReasonItem extends StatelessWidget {
  final String label;
  final bool on;
  const _ReasonItem({required this.label, required this.on});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16, height: 16,
            margin: const EdgeInsets.only(top: 1, right: 8),
            decoration: BoxDecoration(
              color: on ? _ink : Colors.white,
              border: Border.all(color: _ink, width: 1.6),
            ),
            child: on
                ? const Icon(Icons.check, size: 11, color: Colors.white)
                : null,
          ),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                    color: on ? _ink : _inkSoft)),
          ),
        ],
      ),
    );
  }
}

class _SignatureCell extends StatelessWidget {
  final int flex;
  final String label;
  final SignatureStrokes? strokes;
  final String? name;
  final String dateText;
  final bool edgeRight;

  const _SignatureCell({
    required this.flex,
    required this.label,
    required this.strokes,
    required this.name,
    required this.dateText,
    this.edgeRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            right: edgeRight ? BorderSide.none : const BorderSide(color: _rule, width: 1),
            bottom: const BorderSide(color: _rule, width: 1),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(13, 9, 13, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: _label)),
            // 서명 라인 + 잉크.
            Container(
              height: 46,
              margin: const EdgeInsets.fromLTRB(0, 6, 0, 4),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _ink, width: 1)),
              ),
              child: strokes != null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SignatureStrokesView(
                          signature: strokes!, color: _ink, strokeWidth: 2.6),
                    )
                  : null,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text((name ?? '').isNotEmpty ? name! : '',
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600, color: _label),
                      overflow: TextOverflow.ellipsis),
                ),
                Text(dateText,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600, color: _label)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
