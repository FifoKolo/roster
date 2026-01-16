import 'dart:convert';

/// Represents a document attached to an employee profile
/// Used for storing training certificates, sick notes, doctor's letters, etc.
class EmployeeDocument {
  final String id; // Unique identifier
  final String name; // Original filename
  final String category; // e.g., 'Training', 'Medical', 'Contract', 'Other'
  final DateTime uploadDate;
  final String fileBase64; // Base64-encoded file content
  final int fileSizeBytes;
  final String? notes; // Optional notes about the document

  EmployeeDocument({
    required this.id,
    required this.name,
    required this.category,
    required this.uploadDate,
    required this.fileBase64,
    required this.fileSizeBytes,
    this.notes,
  });

  /// Get file size in KB
  double get fileSizeKB => fileSizeBytes / 1024;

  /// Get file extension
  String get fileExtension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  /// Decode the base64 content to bytes
  List<int> get fileBytes => base64Decode(fileBase64);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'uploadDate': uploadDate.millisecondsSinceEpoch,
        'fileBase64': fileBase64,
        'fileSizeBytes': fileSizeBytes,
        'notes': notes,
      };

  static EmployeeDocument fromJson(Map<String, dynamic> json) {
    return EmployeeDocument(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      uploadDate: DateTime.fromMillisecondsSinceEpoch(json['uploadDate'] as int),
      fileBase64: json['fileBase64'] as String,
      fileSizeBytes: json['fileSizeBytes'] as int,
      notes: json['notes'] as String?,
    );
  }

  EmployeeDocument copyWith({
    String? id,
    String? name,
    String? category,
    DateTime? uploadDate,
    String? fileBase64,
    int? fileSizeBytes,
    String? notes,
  }) {
    return EmployeeDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      uploadDate: uploadDate ?? this.uploadDate,
      fileBase64: fileBase64 ?? this.fileBase64,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      notes: notes ?? this.notes,
    );
  }
}

/// Predefined document categories
class DocumentCategory {
  static const String training = 'Training';
  static const String medical = 'Medical';
  static const String contract = 'Contract';
  static const String identification = 'Identification';
  static const String certification = 'Certification';
  
  // Irish Employment Specific
  static const String rightToWork = 'Right to Work';
  static const String ppsNumber = 'PPS Number';
  static const String taxDeclaration = 'Tax Declaration';
  static const String healthSafety = 'Health & Safety';
  static const String induction = 'Induction';
  static const String sickLeave = 'Sick Leave';
  static const String parentalLeave = 'Parental Leave';
  static const String vaccinationRecords = 'Vaccination Records';
  static const String garda = 'Garda Vetting';
  static const String other = 'Other';

  static List<String> get all => [
        rightToWork,
        ppsNumber,
        contract,
        taxDeclaration,
        identification,
        training,
        certification,
        healthSafety,
        induction,
        medical,
        sickLeave,
        parentalLeave,
        vaccinationRecords,
        garda,
        other,
      ];
}
