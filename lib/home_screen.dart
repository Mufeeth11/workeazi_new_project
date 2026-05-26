import 'package:flutter/material.dart';
import 'services/google_sheets_service.dart';
import 'record_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final String loginId;
  final String permissions;
  final String accessPermissions;

  const HomeScreen({
    super.key,
    required this.loginId,
    required this.permissions,
    required this.accessPermissions,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  List<Map<String, String>> _dataList = [];
  List<String> _permittedColumns = [];
  String _accessPermissions = '';

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSortDescending = true;

  bool get _canRead => _accessPermissions.toLowerCase().contains('read');
  bool get _canWrite => _accessPermissions.toLowerCase().contains('write');
  bool get _canDelete => _accessPermissions.toLowerCase().contains('delete');

  @override
  void initState() {
    super.initState();
    _accessPermissions = widget.accessPermissions;
    _permittedColumns = widget.permissions
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'dashboard')
        .toList();
    _fetchSheetData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSheetData() async {
    if (mounted && _dataList.isEmpty) {
      setState(() => _isLoading = true);
    }

    try {
      final parsedData = await GoogleSheetsService.fetchSheetData();

      if (parsedData != null) {
        if (mounted) {
          setState(() {
            _dataList = parsedData;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── EDIT ACTION ────────────────────────────────────────────────────────────

  void _showEditSheet(Map<String, String> item) {
    final editColumns = List<String>.from(_permittedColumns);
    final hasDate = editColumns.any((c) => c.toLowerCase() == 'date');
    if (!hasDate) {
      editColumns.insert(0, 'Date');
    }

    final controllers = {
      for (final col in editColumns)
        col: TextEditingController(
          text:
              item[item.keys.firstWhere(
                (k) => k.toLowerCase() == col.toLowerCase(),
                orElse: () => col,
              )] ??
              '',
        ),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'Edit Record',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final updatedData = <String, String>{};
                              controllers.forEach((key, controller) {
                                updatedData[key] = controller.text.trim();
                              });
                              Navigator.pop(context);
                              await _saveEditAndRefresh(item, updatedData);
                            },
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Form fields
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: editColumns.map((col) {
                          final isDate = col.toLowerCase() == 'date';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: controllers[col],
                              readOnly: isDate,
                              onTap: isDate
                                  ? () => _showDatePicker(
                                        context,
                                        controllers[col]!,
                                      )
                                  : null,
                              decoration: InputDecoration(
                                labelText: col,
                                labelStyle: const TextStyle(color: Colors.grey),
                                suffixIcon: isDate
                                    ? const Icon(
                                        Icons.calendar_today_outlined,
                                        color: Color(0xFF667EEA),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF667EEA),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveEditAndRefresh(
    Map<String, String> originalItem,
    Map<String, String> updatedData,
  ) async {
    final originalList = List<Map<String, String>>.from(_dataList);

    // Identify row key identifier (IV NO)
    final ivKey = originalItem.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    if (ivKey.isEmpty) {
      _showErrorDialog('Missing Key: Could not locate IV NO column identifier.');
      return;
    }

    final targetIvValue = originalItem[ivKey] ?? '';

    // Align all fields perfectly
    final alignedRecord = <String, String>{};
    originalItem.forEach((key, val) {
      alignedRecord[key] = val;
    });

    updatedData.forEach((key, val) {
      final actualKey = alignedRecord.keys.firstWhere(
        (k) => k.toLowerCase() == key.toLowerCase(),
        orElse: () => key,
      );
      alignedRecord[actualKey] = val;
    });

    final targetIndex = _dataList.indexWhere(
      (item) => (item[ivKey] ?? '') == targetIvValue,
    );

    if (targetIndex != -1) {
      setState(() {
        _dataList[targetIndex] = alignedRecord;
      });
    }

    try {
      final error = await GoogleSheetsService.editRow(
        ivNo: targetIvValue,
        updates: alignedRecord,
      );

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
    } catch (e) {
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to save changes: $e');
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Sort Records By',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.arrow_downward, color: Color(0xFF667EEA)),
              title: const Text('Updated Time: Newest First'),
              trailing: _isSortDescending
                  ? const Icon(Icons.check, color: Color(0xFF667EEA))
                  : null,
              onTap: () {
                setState(() {
                  _isSortDescending = true;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward, color: Color(0xFF667EEA)),
              title: const Text('Updated Time: Oldest First'),
              trailing: !_isSortDescending
                  ? const Icon(Icons.check, color: Color(0xFF667EEA))
                  : null,
              onTap: () {
                setState(() {
                  _isSortDescending = false;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  DateTime _parseDateString(String dateStr) {
    try {
      if (dateStr.isEmpty) return DateTime.now();

      final cleaned = dateStr.trim();

      final parts = cleaned.split('-');
      if (parts.length >= 2) {
        final day = int.tryParse(parts[0]);
        if (day != null) {
          final months = [
            'jan', 'feb', 'mar', 'apr', 'may', 'jun',
            'jul', 'aug', 'sep', 'oct', 'nov', 'dec'
          ];
          final monthIndex = months.indexOf(parts[1].toLowerCase());
          if (monthIndex != -1) {
            int year = DateTime.now().year;
            if (parts.length >= 3) {
              year = int.tryParse(parts[2]) ?? year;
            }
            return DateTime(year, monthIndex + 1, day);
          }
        }
      }

      return DateTime.parse(cleaned);
    } catch (_) {
      return DateTime.now();
    }
  }

  String _formatDateToString(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final monthStr = months[dt.month - 1];
    return '$day-$monthStr';
  }

  Future<void> _showDatePicker(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final parsedInitial = _parseDateString(controller.text);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: parsedInitial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF667EEA),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      controller.text = _formatDateToString(picked);
    }
  }

  // ─── ADD NEW RECORD ACTION ──────────────────────────────────────────────────

  void _showAddSheet() {
    final addColumns = List<String>.from(_permittedColumns);
    final hasDate = addColumns.any((c) => c.toLowerCase() == 'date');
    if (!hasDate) {
      addColumns.insert(0, 'Date');
    }

    final controllers = {
      for (final col in addColumns)
        col: TextEditingController(
          text: col.toLowerCase() == 'date'
              ? _formatDateToString(DateTime.now())
              : '',
        ),
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Text(
                            'Add New Record',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final newRecord = <String, String>{};
                              controllers.forEach((key, controller) {
                                newRecord[key] = controller.text.trim();
                              });
                              Navigator.pop(context);
                              await _saveAddAndRefresh(newRecord);
                            },
                            child: const Text(
                              'Save',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Form fields
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: addColumns.map((col) {
                          final isDate = col.toLowerCase() == 'date';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: controllers[col],
                              readOnly: isDate,
                              onTap: isDate
                                  ? () => _showDatePicker(
                                        context,
                                        controllers[col]!,
                                      )
                                  : null,
                              decoration: InputDecoration(
                                labelText: col,
                                labelStyle: const TextStyle(color: Colors.grey),
                                suffixIcon: isDate
                                    ? const Icon(
                                        Icons.calendar_today_outlined,
                                        color: Color(0xFF667EEA),
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF667EEA),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveAddAndRefresh(Map<String, String> newRecord) async {
    final originalList = List<Map<String, String>>.from(_dataList);

    final alignedRecord = <String, String>{};
    if (_dataList.isNotEmpty) {
      for (final key in _dataList.first.keys) {
        alignedRecord[key] = '';
      }
    }

    newRecord.forEach((key, val) {
      final actualKey = alignedRecord.keys.firstWhere(
        (k) => k.toLowerCase() == key.toLowerCase(),
        orElse: () => key,
      );
      alignedRecord[actualKey] = val;
    });

    setState(() {
      _dataList.add(alignedRecord);
    });

    try {
      final error = await GoogleSheetsService.addRow(rowData: alignedRecord);

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
    } catch (e) {
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to save changes: $e');
    }
  }

  // ─── DELETE ACTION ──────────────────────────────────────────────────────────

  void _confirmDelete(Map<String, String> item) {
    final ivKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    final recordId = ivKey.isNotEmpty ? (item[ivKey] ?? '') : '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Record'),
        content: Text('Are you sure you want to delete this record ($recordId)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performDelete(item);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDelete(Map<String, String> item) async {
    final originalList = List<Map<String, String>>.from(_dataList);

    final ivKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    if (ivKey.isEmpty) {
      _showErrorDialog('Missing Identifier: Could not locate IV NO column identifier.');
      return;
    }

    final targetIvValue = item[ivKey] ?? '';

    setState(() {
      _dataList.removeWhere((rec) => (rec[ivKey] ?? '') == targetIvValue);
    });

    try {
      final error = await GoogleSheetsService.clearRowToNil(
        ivNo: targetIvValue,
        permittedColumns: _permittedColumns,
      );

      if (error != null) {
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
      _showSuccessDialog('Record deleted successfully.');
    } catch (e) {
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to delete record: $e');
    }
  }

  // ─── DIALOGS & WIDGET BUILDERS ──────────────────────────────────────────────

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, String> item) {
    final ivKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => '',
    );
    final title = ivKey.isNotEmpty ? (item[ivKey] ?? '-') : '-';

    final dateKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'date',
      orElse: () => '',
    );
    final dateVal = dateKey.isNotEmpty ? (item[dateKey] ?? '-') : '-';

    final displayFields = _permittedColumns
        .where((col) => col.toLowerCase() != 'iv no' && col.toLowerCase() != 'date')
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecordDetailsScreen(
                  record: item,
                  permittedColumns: _permittedColumns,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateVal,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 12),

                // Properties layout
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: displayFields.map((col) {
                    final actualKey = item.keys.firstWhere(
                      (k) => k.toLowerCase() == col.toLowerCase(),
                      orElse: () => col,
                    );
                    final rawVal = item[actualKey] ?? '-';
                    final val = rawVal.isEmpty ? '-' : rawVal;

                    return SizedBox(
                      width: 140,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            col,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            val,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade100),
                const SizedBox(height: 10),

                // Lower actions bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 15,
                          color: Color(0xFF667EEA),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'View Details',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667EEA),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_canWrite) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                            iconSize: 20,
                            onPressed: () => _showEditSheet(item),
                          ),
                        ],
                        if (_canDelete) ...[
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            iconSize: 20,
                            onPressed: () => _confirmDelete(item),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _dataList.where((item) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();

      final matchesAnyValue = item.values.any(
        (val) => val.toLowerCase().contains(q),
      );
      if (matchesAnyValue) return true;

      final dateKey = item.keys.firstWhere(
        (k) => k.toLowerCase() == 'date',
        orElse: () => '',
      );
      if (dateKey.isNotEmpty) {
        final dateVal = (item[dateKey] ?? '').toLowerCase();
        final normalizedQuery = q.replaceAll('/', '-').replaceAll('.', '-');
        final normalizedDate = dateVal
            .replaceAll('/', '-')
            .replaceAll('.', '-');
        if (normalizedDate.contains(normalizedQuery)) {
          return true;
        }
      }
      return false;
    }).toList();

    final displayList = _isSortDescending
        ? filteredList.reversed.toList()
        : filteredList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey.shade200,
            height: 1.0,
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF667EEA)))
            : RefreshIndicator(
                color: const Color(0xFF667EEA),
                onRefresh: _fetchSheetData,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    if (_permittedColumns.isEmpty)
                      _buildEmptyState(
                        Icons.person_off_outlined,
                        'No Permissions',
                        'You have no column permissions assigned.\nPlease contact your administrator.',
                      )
                    else if (!_canRead)
                      _buildEmptyState(
                        Icons.lock_outline,
                        'Access Restricted',
                        'You do not have read access to view this data.\nPlease contact your administrator.',
                      )
                    else ...[
                      // Search & Sort Bar Row
                      if (_dataList.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Search records...',
                                        hintStyle: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 15,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search,
                                          size: 20,
                                          color: Color(0xFF667EEA),
                                        ),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 18),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = '';
                                                  });
                                                },
                                              )
                                            : null,
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _searchQuery = val.trim();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                InkWell(
                                  onTap: _showSortSheet,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _isSortDescending
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color: const Color(0xFF667EEA),
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Add New Record Button
                      if (_canWrite)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 12,
                              bottom: 4,
                            ),
                            child: ElevatedButton(
                              onPressed: _showAddSheet,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667EEA),
                                foregroundColor: Colors.white,
                                shadowColor: const Color(0xFF667EEA).withValues(alpha: 0.25),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add New Record',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      if (_dataList.isEmpty)
                        _buildEmptyState(
                          Icons.inbox_outlined,
                          'No Data',
                          'No records were found in the sheet.',
                        )
                      else if (displayList.isEmpty)
                        _buildEmptyState(
                          Icons.search_off_outlined,
                          'No Results Found',
                          'We couldn\'t find any records matching "$_searchQuery".',
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildCard(displayList[index]),
                              childCount: displayList.length,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
