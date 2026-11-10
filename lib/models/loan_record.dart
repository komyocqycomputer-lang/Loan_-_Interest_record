class LoanRecord {
  final String id;
  final String codeNo;
  final String name;
  final String address;
  final String phone1;
  final String phone2;
  final double loanAmount;
  final double monthlyInterestRate;
  final String startDate; // dd/MM/yyyy
  final String endDate; // dd/MM/yyyy
  final String durationText;
  final double durationMonths;
  final double totalInterest;
  final double totalAmountDue;
  final String? photoPath;
  final String? guarantee;
  final String? notes;
  final int createdAt;
  final int updatedAt;

  LoanRecord({
    required this.id,
    required this.codeNo,
    required this.name,
    required this.address,
    required this.phone1,
    required this.phone2,
    required this.loanAmount,
    required this.monthlyInterestRate,
    required this.startDate,
    required this.endDate,
    required this.durationText,
    required this.durationMonths,
    required this.totalInterest,
    required this.totalAmountDue,
    this.photoPath,
    this.guarantee,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'codeNo': codeNo,
      'name': name,
      'address': address,
      'phone1': phone1,
      'phone2': phone2,
      'loanAmount': loanAmount,
      'monthlyInterestRate': monthlyInterestRate,
      'startDate': startDate,
      'endDate': endDate,
      'durationText': durationText,
      'durationMonths': durationMonths,
      'totalInterest': totalInterest,
      'totalAmountDue': totalAmountDue,
      'photoPath': photoPath,
      'guarantee': guarantee,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory LoanRecord.fromJson(Map<String, dynamic> json) {
    return LoanRecord(
      id: json['id'] as String? ?? '',
      codeNo: json['codeNo'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone1: json['phone1'] as String? ?? '',
      phone2: json['phone2'] as String? ?? '',
      loanAmount: (json['loanAmount'] as num?)?.toDouble() ?? 0.0,
      monthlyInterestRate: (json['monthlyInterestRate'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      durationText: json['durationText'] as String? ?? '',
      durationMonths: (json['durationMonths'] as num?)?.toDouble() ?? 0.0,
      totalInterest: (json['totalInterest'] as num?)?.toDouble() ?? 0.0,
      totalAmountDue: (json['totalAmountDue'] as num?)?.toDouble() ?? 0.0,
      photoPath: json['photoPath'] as String?,
      guarantee: json['guarantee'] as String? ?? json['notes'] as String?,
      notes: json['notes'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
    );
  }

  LoanRecord copyWith({
    String? id,
    String? codeNo,
    String? name,
    String? address,
    String? phone1,
    String? phone2,
    double? loanAmount,
    double? monthlyInterestRate,
    String? startDate,
    String? endDate,
    String? durationText,
    double? durationMonths,
    double? totalInterest,
    double? totalAmountDue,
    String? photoPath,
    String? guarantee,
    String? notes,
    int? createdAt,
    int? updatedAt,
  }) {
    return LoanRecord(
      id: id ?? this.id,
      codeNo: codeNo ?? this.codeNo,
      name: name ?? this.name,
      address: address ?? this.address,
      phone1: phone1 ?? this.phone1,
      phone2: phone2 ?? this.phone2,
      loanAmount: loanAmount ?? this.loanAmount,
      monthlyInterestRate: monthlyInterestRate ?? this.monthlyInterestRate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      durationText: durationText ?? this.durationText,
      durationMonths: durationMonths ?? this.durationMonths,
      totalInterest: totalInterest ?? this.totalInterest,
      totalAmountDue: totalAmountDue ?? this.totalAmountDue,
      photoPath: photoPath ?? this.photoPath,
      guarantee: guarantee ?? this.guarantee,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
