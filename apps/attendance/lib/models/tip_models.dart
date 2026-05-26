/// Tip entry 관련 모델 — Phase 5 Stage F.
///
/// TipReceiver: GET /attendance/tip-entry/eligible-receivers 응답 row 매핑.
/// TipDistribution / TipPayload: TipEntryDialog 의 onSubmit 콜백 payload.

class TipReceiver {
  final String userId;
  final String userName;
  final String? role; // 'Server' / 'Barista' / 'Kitchen' 등
  final double workedHours;

  const TipReceiver({
    required this.userId,
    required this.userName,
    required this.role,
    required this.workedHours,
  });

  factory TipReceiver.fromJson(Map<String, dynamic> json) {
    // server eligible-receivers 응답은 {id, full_name} 형식. user_id/user_name 은
    // 다른 endpoint 호환용 alias.
    return TipReceiver(
      userId: (json['user_id'] ?? json['id'])?.toString() ?? '',
      userName: (json['user_name'] ?? json['full_name'])?.toString() ?? '',
      role: json['role']?.toString() ?? json['work_role']?.toString(),
      workedHours: (json['worked_hours'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TipDistribution {
  final String receiverId;
  final double amount;
  const TipDistribution({required this.receiverId, required this.amount});

  Map<String, dynamic> toJson() => {'receiver_id': receiverId, 'amount': amount};
}

class TipPayload {
  final double cardTips;
  final double cashTipsKept;
  final List<TipDistribution> distributions;

  const TipPayload({
    required this.cardTips,
    required this.cashTipsKept,
    required this.distributions,
  });

  Map<String, dynamic> toJson() => {
        'card_tips': cardTips.toStringAsFixed(2),
        'cash_tips_kept': cashTipsKept.toStringAsFixed(2),
        'distributions': distributions.map((d) => d.toJson()).toList(),
      };
}
