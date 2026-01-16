import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/employee_document.dart';
import '../utils/responsive_helper.dart';

/// Dialog for managing employee documents (training, medical, etc.)
class DocumentManagementDialog extends StatefulWidget {
  final String employeeName;
  final List<EmployeeDocument> documents;
  final Function(List<EmployeeDocument>) onDocumentsChanged;

  const DocumentManagementDialog({
    super.key,
    required this.employeeName,
    required this.documents,
    required this.onDocumentsChanged,
  });

  @override
  State<DocumentManagementDialog> createState() => _DocumentManagementDialogState();
}

class _DocumentManagementDialogState extends State<DocumentManagementDialog> {
  late List<EmployeeDocument> _documents;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _documents = List.from(widget.documents);
  }

  Future<void> _uploadDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        print('📁 File picker cancelled or no file selected');
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        _showError('Failed to read file data');
        return;
      }

      print('✅ File selected: ${file.name}, size: ${file.size} bytes');

      // Show category selection dialog
      if (!mounted) return;
      final category = await _showCategoryDialog();
      if (category == null) {
        print('❌ No category selected');
        return;
      }
      
      print('✅ Category selected: $category');

      // Optional notes
      if (!mounted) return;
      final notes = await _showNotesDialog();

      setState(() => _isUploading = true);

      final encoded = base64Encode(file.bytes!);
      final document = EmployeeDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.name,
        category: category,
        uploadDate: DateTime.now(),
        fileBase64: encoded,
        fileSizeBytes: file.size,
        notes: notes,
      );

      setState(() {
        _documents.add(document);
        _isUploading = false;
      });

      widget.onDocumentsChanged(_documents);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${file.name} (${(file.size / 1024).toStringAsFixed(0)}KB)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('❌ Error uploading document: $e');
      setState(() => _isUploading = false);
      _showError('Failed to upload document: $e');
    }
  }

  Future<String?> _showCategoryDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 400,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Select Document Category',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Divider(height: 1),
                Expanded(
                  child: ListView(
                    shrinkWrap: true,
                    children: DocumentCategory.all.map((category) {
                      final iconData = _getCategoryIcon(category);
                      final color = _getCategoryColor(category);
                      
                      return ListTile(
                        leading: Icon(iconData, color: color),
                        title: Text(category),
                        onTap: () => Navigator.of(context).pop(category),
                      );
                    }).toList(),
                  ),
                ),
                Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String?> _showNotesDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Notes (Optional)'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'e.g., Valid until 2026, Renewal required...',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    return (result == true && controller.text.trim().isNotEmpty) ? controller.text.trim() : null;
  }

  Future<void> _deleteDocument(EmployeeDocument document) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _documents.removeWhere((doc) => doc.id == document.id);
      });
      widget.onDocumentsChanged(_documents);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _viewDocument(EmployeeDocument document) async {
    // Show document info
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${document.category}'),
            const SizedBox(height: 8),
            Text('Size: ${document.fileSizeKB.toStringAsFixed(1)} KB'),
            const SizedBox(height: 8),
            Text('Uploaded: ${_formatDate(document.uploadDate)}'),
            if (document.notes?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text('Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(document.notes!),
            ],
            const SizedBox(height: 16),
            const Text(
              'Document is stored and can be downloaded when needed.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(EmployeeDocument document) async {
    // For now, just show that document is stored
    _showInfo('Document "${document.name}" is stored in the employee profile (${document.fileSizeKB.toStringAsFixed(0)}KB)');
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case DocumentCategory.training:
        return Icons.school;
      case DocumentCategory.medical:
        return Icons.medical_services;
      case DocumentCategory.contract:
        return Icons.description;
      case DocumentCategory.identification:
        return Icons.badge;
      case DocumentCategory.certification:
        return Icons.verified;
      case DocumentCategory.rightToWork:
        return Icons.verified_user;
      case DocumentCategory.ppsNumber:
        return Icons.numbers;
      case DocumentCategory.taxDeclaration:
        return Icons.receipt;
      case DocumentCategory.healthSafety:
        return Icons.security;
      case DocumentCategory.induction:
        return Icons.assignment;
      case DocumentCategory.sickLeave:
        return Icons.sick;
      case DocumentCategory.parentalLeave:
        return Icons.child_care;
      case DocumentCategory.vaccinationRecords:
        return Icons.favorite;
      case DocumentCategory.garda:
        return Icons.verified_user;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case DocumentCategory.training:
        return Colors.blue;
      case DocumentCategory.medical:
        return Colors.red;
      case DocumentCategory.contract:
        return Colors.green;
      case DocumentCategory.identification:
        return Colors.purple;
      case DocumentCategory.certification:
        return Colors.orange;
      case DocumentCategory.rightToWork:
        return Colors.teal;
      case DocumentCategory.ppsNumber:
        return Colors.indigo;
      case DocumentCategory.taxDeclaration:
        return Colors.amber;
      case DocumentCategory.healthSafety:
        return Colors.pink;
      case DocumentCategory.induction:
        return Colors.cyan;
      case DocumentCategory.sickLeave:
        return Colors.red;
      case DocumentCategory.parentalLeave:
        return Colors.lime;
      case DocumentCategory.vaccinationRecords:
        return Colors.deepOrange;
      case DocumentCategory.garda:
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.all(isMobile ? 12 : 40),
      child: Container(
        width: isMobile ? screenWidth * 0.95 : 900,
        height: isMobile ? screenHeight * 0.85 : 700,
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.folder_open, color: Colors.blue, size: isMobile ? 24 : 28),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Personal Documents',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.employeeName,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: isMobile ? 22 : 24),
                ),
              ],
            ),

            SizedBox(height: isMobile ? 16 : 24),

            // Category grid
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isMobile ? 6 : 10,
                  crossAxisSpacing: isMobile ? 6 : 8,
                  mainAxisSpacing: isMobile ? 6 : 8,
                  childAspectRatio: 1,
                ),
                itemCount: DocumentCategory.all.length,
                itemBuilder: (context, index) {
                  final category = DocumentCategory.all[index];
                  return _buildCategoryIconTile(category, isMobile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIconTile(String category, bool isMobile) {
    final icon = _getCategoryIcon(category);
    final color = _getCategoryColor(category);
    final docsInCategory = _documents.where((doc) => doc.category == category).toList();
    final hasDocument = docsInCategory.isNotEmpty;

    return Tooltip(
      message: category,
      child: GestureDetector(
        onTap: () => _showCategoryDetails(category, isMobile),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: isMobile ? 40 : 48, color: color.withOpacity(0.8)),
            // Status indicator badge
            Positioned(
              top: isMobile ? -4 : -2,
              right: isMobile ? -4 : -2,
              child: Container(
                padding: EdgeInsets.all(isMobile ? 2 : 3),
                decoration: BoxDecoration(
                  color: hasDocument ? Colors.green : Colors.grey[400],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasDocument ? Icons.check : Icons.add,
                  color: Colors.white,
                  size: isMobile ? 10 : 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(String category, bool isMobile) {
    final icon = _getCategoryIcon(category);
    final color = _getCategoryColor(category);
    final docsInCategory = _documents.where((doc) => doc.category == category).toList();
    final hasDocument = docsInCategory.isNotEmpty;

    return GestureDetector(
      onTap: () => _showCategoryDetails(category, isMobile),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: isMobile ? 32 : 40, color: color),
                SizedBox(height: isMobile ? 6 : 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 6),
                  child: Text(
                    category,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            // Status indicator badge
            Positioned(
              top: isMobile ? 4 : 6,
              right: isMobile ? 4 : 6,
              child: Container(
                padding: EdgeInsets.all(isMobile ? 3 : 4),
                decoration: BoxDecoration(
                  color: hasDocument ? Colors.green : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasDocument ? Icons.check : Icons.add,
                  color: hasDocument ? Colors.white : Colors.grey[600],
                  size: isMobile ? 12 : 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryDetails(String category, bool isMobile) async {
    final docsInCategory = _documents.where((doc) => doc.category == category).toList();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: isMobile ? 350 : 500,
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_getCategoryIcon(category), color: _getCategoryColor(category), size: isMobile ? 24 : 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category,
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                if (docsInCategory.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 16 : 20),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.insert_drive_file, size: isMobile ? 40 : 48, color: Colors.grey[300]),
                          SizedBox(height: isMobile ? 8 : 12),
                          Text(
                            'No document uploaded',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${docsInCategory.length} document${docsInCategory.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: isMobile ? 8 : 12),
                      ...docsInCategory.map((doc) => _buildDocumentListItem(doc, isMobile)),
                    ],
                  ),
                SizedBox(height: isMobile ? 16 : 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _uploadForCategory(category);
                  },
                  icon: Icon(Icons.upload_file, size: isMobile ? 16 : 18),
                  label: Text(
                    docsInCategory.isEmpty ? 'Upload Document' : 'Upload Another / Replace',
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getCategoryColor(category),
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, isMobile ? 40 : 48),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentListItem(EmployeeDocument doc, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.name,
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isMobile ? 2 : 4),
                    Text(
                      '${doc.fileSizeKB.toStringAsFixed(0)}KB • ${_formatDate(doc.uploadDate)}',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _deleteDocument(doc);
                  } else if (value == 'view') {
                    _viewDocument(doc);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: const [
                        Icon(Icons.visibility, size: 18),
                        SizedBox(width: 8),
                        Text('View'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (doc.notes?.isNotEmpty == true) ...[
            SizedBox(height: isMobile ? 6 : 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                doc.notes!,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: Colors.amber[900],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadForCategory(String category) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        _showError('Failed to read file data');
        return;
      }

      // Optional notes
      if (!mounted) return;
      final notes = await _showNotesDialog();

      setState(() => _isUploading = true);

      final encoded = base64Encode(file.bytes!);
      final document = EmployeeDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: file.name,
        category: category,
        uploadDate: DateTime.now(),
        fileBase64: encoded,
        fileSizeBytes: file.size,
        notes: notes,
      );

      setState(() {
        _documents.add(document);
        _isUploading = false;
      });

      widget.onDocumentsChanged(_documents);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${file.name} (${(file.size / 1024).toStringAsFixed(0)}KB)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      _showError('Failed to upload document: $e');
    }
  }

  Widget _buildEmptyState() {
    final isMobile = ResponsiveHelper.isMobile(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off, size: isMobile ? 60 : 80, color: Colors.grey[300]),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'No documents yet',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            'Click on a category above to upload documents',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(EmployeeDocument document, bool isMobile) {
    final categoryColor = _getCategoryColor(document.category);
    final categoryIcon = _getCategoryIcon(document.category);

    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isMobile ? 8 : 10),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(categoryIcon, color: categoryColor, size: isMobile ? 20 : 24),
                ),
                SizedBox(width: isMobile ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              document.category,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12,
                                color: categoryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: isMobile ? 6 : 8),
                          Text(
                            '${document.fileSizeKB.toStringAsFixed(0)}KB',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteDocument(document);
                    } else if (value == 'view') {
                      _viewDocument(document);
                    } else if (value == 'download') {
                      _downloadDocument(document);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: const [
                          Icon(Icons.visibility, size: 18),
                          SizedBox(width: 8),
                          Text('View'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'download',
                      child: Row(
                        children: const [
                          Icon(Icons.download, size: 18),
                          SizedBox(width: 8),
                          Text('Download'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: const [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (document.notes?.isNotEmpty == true) ...[
              SizedBox(height: isMobile ? 8 : 10),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  document.notes!,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'Uploaded: ${_formatDate(document.uploadDate)}',
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
