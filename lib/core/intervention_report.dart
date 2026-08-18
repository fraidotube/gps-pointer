import 'dart:convert';

enum InterventionReportStatus { draft, completed, pendingUpload, uploaded }

final class InterventionReport {
  const InterventionReport({
    required this.id,
    required this.clientName,
    required this.customerUser,
    required this.address,
    required this.phone,
    required this.diagnoses,
    required this.diagnosisOther,
    required this.description,
    required this.deliveredMaterial,
    required this.collectedMaterial,
    required this.outcome,
    required this.testResult,
    required this.notes,
    required this.technicianName,
    required this.interventionDate,
    required this.startTime,
    required this.endTime,
    required this.reservedNotes,
    required this.customerSignaturePngBase64,
    required this.technicianSignaturePngBase64,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.uploadedAtUtc,
  });

  final String id;
  final String clientName;
  final String customerUser;
  final String address;
  final String phone;
  final List<String> diagnoses;
  final String diagnosisOther;
  final String description;
  final String deliveredMaterial;
  final String collectedMaterial;
  final String outcome;
  final String testResult;
  final String notes;
  final String technicianName;
  final String interventionDate;
  final String startTime;
  final String endTime;
  final String reservedNotes;
  final String? customerSignaturePngBase64;
  final String? technicianSignaturePngBase64;
  final InterventionReportStatus status;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final DateTime? uploadedAtUtc;

  bool get customerSignaturePresent =>
      customerSignaturePngBase64 != null &&
      customerSignaturePngBase64!.isNotEmpty;
  bool get technicianSignaturePresent =>
      technicianSignaturePngBase64 != null &&
      technicianSignaturePngBase64!.isNotEmpty;

  InterventionReport copyWith({
    InterventionReportStatus? status,
    DateTime? updatedAtUtc,
    DateTime? uploadedAtUtc,
  }) => InterventionReport(
    id: id,
    clientName: clientName,
    customerUser: customerUser,
    address: address,
    phone: phone,
    diagnoses: diagnoses,
    diagnosisOther: diagnosisOther,
    description: description,
    deliveredMaterial: deliveredMaterial,
    collectedMaterial: collectedMaterial,
    outcome: outcome,
    testResult: testResult,
    notes: notes,
    technicianName: technicianName,
    interventionDate: interventionDate,
    startTime: startTime,
    endTime: endTime,
    reservedNotes: reservedNotes,
    customerSignaturePngBase64: customerSignaturePngBase64,
    technicianSignaturePngBase64: technicianSignaturePngBase64,
    status: status ?? this.status,
    createdAtUtc: createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    uploadedAtUtc: uploadedAtUtc ?? this.uploadedAtUtc,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'client_name': clientName,
    'customer_user': customerUser,
    'address': address,
    'phone': phone,
    'diagnoses': diagnoses,
    'diagnosis_other': diagnosisOther,
    'description': description,
    'delivered_material': deliveredMaterial,
    'collected_material': collectedMaterial,
    'outcome': outcome,
    'test_result': testResult,
    'notes': notes,
    'reserved_notes': reservedNotes,
    'technician_name': technicianName,
    'intervention_date': interventionDate,
    'start_time': startTime,
    'end_time': endTime,
    'customer_signature_png_base64': customerSignaturePngBase64,
    'technician_signature_png_base64': technicianSignaturePngBase64,
    'status': status.name,
    'created_at_utc': createdAtUtc.toUtc().toIso8601String(),
    'updated_at_utc': updatedAtUtc.toUtc().toIso8601String(),
    'uploaded_at_utc': uploadedAtUtc?.toUtc().toIso8601String(),
  };

  Map<String, Object?> toServerMetadata() => {
    'report_id': id,
    'client_name': clientName,
    'customer_user': customerUser,
    'address': address,
    'phone': phone,
    'diagnoses': diagnoses,
    'diagnosis_other': diagnosisOther,
    'description': description,
    'delivered_material': deliveredMaterial,
    'collected_material': collectedMaterial,
    'outcome': outcome,
    'test_result': testResult,
    'notes': notes,
    'reserved_notes': reservedNotes,
    'technician_name': technicianName,
    'intervention_date': interventionDate,
    'start_time': startTime,
    'end_time': endTime,
    'customer_signature_present': customerSignaturePresent,
    'technician_signature_present': technicianSignaturePresent,
  };

  factory InterventionReport.fromJson(Map<String, dynamic> json) {
    final statusRaw = json['status']?.toString() ?? 'draft';
    return InterventionReport(
      id: json['id'] as String,
      clientName: json['client_name'] as String? ?? '',
      customerUser: json['customer_user'] as String? ?? '',
      address: json['address'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      diagnoses: (json['diagnoses'] as List<dynamic>? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
      diagnosisOther: json['diagnosis_other'] as String? ?? '',
      description: json['description'] as String? ?? '',
      deliveredMaterial: json['delivered_material'] as String? ?? '',
      collectedMaterial: json['collected_material'] as String? ?? '',
      outcome: json['outcome'] as String? ?? '',
      testResult: json['test_result'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      technicianName: json['technician_name'] as String? ?? '',
      interventionDate: json['intervention_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      reservedNotes: json['reserved_notes'] as String? ?? '',
      customerSignaturePngBase64:
          json['customer_signature_png_base64'] as String?,
      technicianSignaturePngBase64:
          json['technician_signature_png_base64'] as String?,
      status: InterventionReportStatus.values.firstWhere(
        (value) => value.name == statusRaw,
        orElse: () => InterventionReportStatus.draft,
      ),
      createdAtUtc: DateTime.parse(json['created_at_utc'] as String).toUtc(),
      updatedAtUtc: DateTime.parse(json['updated_at_utc'] as String).toUtc(),
      uploadedAtUtc: json['uploaded_at_utc'] == null
          ? null
          : DateTime.parse(json['uploaded_at_utc'] as String).toUtc(),
    );
  }

  static String encodeSignature(List<int> pngBytes) => base64Encode(pngBytes);
  static List<int>? decodeSignature(String? value) =>
      value == null || value.isEmpty ? null : base64Decode(value);
}

abstract interface class InterventionReportRepository {
  Future<List<InterventionReport>> loadAll();
  Future<void> save(InterventionReport report);
  Future<void> delete(String id);
}
