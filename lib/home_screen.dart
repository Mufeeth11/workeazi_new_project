import 'package:flutter/cupertino.dart';
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
      // Fetch Sheet1 data directly from Google Sheets API to bypass caching
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
    final controllers = {
      for (final col in _permittedColumns)
        col: TextEditingController(
          text:
              item[item.keys.firstWhere(
                (k) => k.toLowerCase() == col.toLowerCase(),
                orElse: () => col,
              )] ??
              '',
        ),
    };

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    ),
                    const Text(
                      'Edit Record',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final updates = {
                          for (final col in _permittedColumns)
                            col: controllers[col]!.text.trim(),
                        };
                        Navigator.pop(ctx);
                        _saveEditAndRefresh(item, updates);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 0),

              // Fields
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _permittedColumns.map((col) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CupertinoTextField(
                        controller: controllers[col],
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            '$col: ',
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        placeholder: 'Enter value',
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                        decoration: null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveEditAndRefresh(
    Map<String, String> item,
    Map<String, String> updates,
  ) async {
    // 1. Instantly update the local memory state and rebuild (1 ms response!)
    final originalList = List<Map<String, String>>.from(_dataList);

    final ivNoKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => 'IV NO',
    );
    final targetIvNo = item[ivNoKey] ?? '';

    int targetIndex = -1;
    for (int i = 0; i < _dataList.length; i++) {
      if ((_dataList[i][ivNoKey] ?? '').toLowerCase() ==
          targetIvNo.toLowerCase()) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != -1) {
      setState(() {
        final updatedRecord = Map<String, String>.from(_dataList[targetIndex]);
        updates.forEach((key, val) {
          final actualKey = updatedRecord.keys.firstWhere(
            (k) => k.toLowerCase() == key.toLowerCase(),
            orElse: () => key,
          );
          updatedRecord[actualKey] = val;
        });
        _dataList[targetIndex] = updatedRecord;
      });
    }

    // 2. Perform the API call in the background without blocking the UI
    try {
      if (targetIvNo.isEmpty) {
        _showErrorDialog('Could not find a row identifier (IV NO).');
        return;
      }

      final error = await GoogleSheetsService.editRow(
        ivNo: targetIvNo,
        updates: updates,
      );

      if (error != null) {
        // Rollback to original if API call failed
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      // Quietly fetch fresh data from sheet to ensure full synchronization (without blocking loader)
      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
    } catch (e) {
      // Rollback
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to save changes: $e');
    }
  }

  // ─── ADD ACTION ──────────────────────────────────────────────────────────────

  void _showAddSheet() {
    // Format current date
    final now = DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final defaultDate =
        '${now.day.toString().padLeft(2, '0')}-${months[now.month - 1]}';

    final controllers = {
      for (final col in _permittedColumns)
        col: TextEditingController(
          text: col.toLowerCase() == 'date' ? defaultDate : '',
        ),
    };

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Color(0xFFF2F2F7),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: CupertinoColors.systemGrey),
                      ),
                    ),
                    const Text(
                      'Add New Record',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final newRecord = {
                          for (final col in _permittedColumns)
                            col: controllers[col]!.text.trim(),
                        };
                        Navigator.pop(ctx);
                        _saveAddAndRefresh(newRecord);
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 0),

              // Fields
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: _permittedColumns.map((col) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: CupertinoTextField(
                        controller: controllers[col],
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            '$col: ',
                            style: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        placeholder: 'Enter $col',
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 14,
                        ),
                        decoration: null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveAddAndRefresh(Map<String, String> newRecord) async {
    // 1. Instantly append locally and rebuild (1 ms response!)
    final originalList = List<Map<String, String>>.from(_dataList);

    // Align keys and populate all columns from existing sheet structure to ensure
    // that Edit, Delete, and Details actions work flawlessly on this new record immediately!
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
      _dataList.insert(0, alignedRecord);
    });

    // 2. Perform the API call in the background without blocking the UI
    try {
      final error = await GoogleSheetsService.addRow(rowData: alignedRecord);

      if (error != null) {
        // Rollback
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      // Quietly fetch fresh data from sheet to ensure full synchronization (without blocking loader)
      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
    } catch (e) {
      // Rollback
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to create record: $e');
    }
  }

  // ─── DELETE ACTION ───────────────────────────────────────────────────────────

  void _confirmDelete(Map<String, String> item) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this record? This will set its permitted columns to "nil".',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteRow(item);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRow(Map<String, String> item) async {
    // 1. Instantly update the local memory state to "nil" and rebuild (1 ms response!)
    final originalList = List<Map<String, String>>.from(_dataList);

    final ivNoKey = item.keys.firstWhere(
      (k) => k.toLowerCase() == 'iv no',
      orElse: () => 'IV NO',
    );
    final targetIvNo = item[ivNoKey] ?? '';

    int targetIndex = -1;
    for (int i = 0; i < _dataList.length; i++) {
      if ((_dataList[i][ivNoKey] ?? '').toLowerCase() ==
          targetIvNo.toLowerCase()) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != -1) {
      setState(() {
        final updatedRecord = Map<String, String>.from(_dataList[targetIndex]);
        for (final col in _permittedColumns) {
          final actualKey = updatedRecord.keys.firstWhere(
            (k) => k.toLowerCase() == col.toLowerCase(),
            orElse: () => col,
          );
          updatedRecord[actualKey] = 'nil';
        }
        _dataList[targetIndex] = updatedRecord;
      });
    }

    // 2. Perform the API call in the background without blocking the UI
    try {
      if (targetIvNo.isEmpty) {
        _showErrorDialog('Could not find a row identifier (IV NO).');
        return;
      }

      final error = await GoogleSheetsService.clearRowToNil(
        ivNo: targetIvNo,
        permittedColumns: _permittedColumns,
      );

      if (error != null) {
        // Rollback
        setState(() {
          _dataList = originalList;
        });
        _showErrorDialog(error);
        return;
      }

      // Quietly fetch fresh data from sheet to ensure full synchronization (without blocking loader)
      final parsedData = await GoogleSheetsService.fetchSheetData();
      if (parsedData != null) {
        setState(() {
          _dataList = parsedData;
        });
      }
    } catch (e) {
      // Rollback
      setState(() {
        _dataList = originalList;
      });
      _showErrorDialog('Failed to delete: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  // ─── UI HELPERS ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 52, color: CupertinoColors.systemGrey3),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: CupertinoColors.systemGrey,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCardValue(String col, String val) {
    if (val.isEmpty || val == '-') return val;
    final lowerCol = col.toLowerCase();
    final isMonetary = lowerCol.contains('value') ||
                       lowerCol.contains('amount') ||
                       lowerCol.contains('price') ||
                       lowerCol.contains('total') ||
                       lowerCol.contains('balance') ||
                       lowerCol.contains('paid');
                       
    if (isMonetary) {
      if (!val.contains('\u20B9') && !val.contains('Rs') && !val.contains('\$')) {
        return '\u20B9$val';
      }
    }
    return val;
  }

  Widget _buildCard(Map<String, String> item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => RecordDetailsScreen(
              record: item,
              permittedColumns: _permittedColumns,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CupertinoColors.systemGrey5, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Date (Left) & Actions (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date Display with calendar icon
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.calendar,
                        size: 16,
                        color: CupertinoColors.systemGrey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.entries
                            .firstWhere(
                              (entry) => entry.key.toLowerCase() == 'date',
                              orElse: () => const MapEntry('Date', '-'),
                            )
                            .value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                  // Action buttons (Write + Delete) with icon and text
                  if (_canWrite || _canDelete)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_canWrite)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            color: CupertinoColors.systemBlue.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () => _showEditSheet(item),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.pencil,
                                  size: 14,
                                  color: CupertinoColors.systemBlue,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Edit',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.systemBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            minimumSize: Size(0, 0),
                          ),
                        if (_canWrite && _canDelete) const SizedBox(width: 8),
                        if (_canDelete)
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            color: CupertinoColors.systemRed.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            onPressed: () => _confirmDelete(item),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.trash,
                                  size: 14,
                                  color: CupertinoColors.systemRed,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.systemRed,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            minimumSize: Size(0, 0),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Data rows
              ..._permittedColumns.map((col) {
                final actualHeader = item.keys.firstWhere(
                  (k) => k.toLowerCase() == col.toLowerCase(),
                  orElse: () => col,
                );
                final val = item[actualHeader] ?? '-';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          col,
                          style: const TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          _formatCardValue(col, val.isEmpty ? '-' : val),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.black,
                            fontFamilyFallback: ['Roboto', 'NotoSans'],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Divider + permission badges
              const SizedBox(height: 8),
              Container(height: 0.5, color: CupertinoColors.systemGrey5),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (_canRead)
                    _buildPermissionBadge(
                      icon: CupertinoIcons.eye_fill,
                      label: 'Read',
                      color: CupertinoColors.systemGreen,
                    ),
                  if (_canWrite)
                    _buildPermissionBadge(
                      icon: CupertinoIcons.pencil,
                      label: 'Write',
                      color: CupertinoColors.systemBlue,
                    ),
                  if (_canDelete)
                    _buildPermissionBadge(
                      icon: CupertinoIcons.trash_fill,
                      label: 'Delete',
                      color: CupertinoColors.systemRed,
                    ),
                ],
              ),
            ],
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

      // 1. Direct value checking
      final matchesAnyValue = item.values.any(
        (val) => val.toLowerCase().contains(q),
      );
      if (matchesAnyValue) return true;

      // 2. Ultra-flexible date search (normalize slashes / dots / dashes to match interchangeably)
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

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Dashboard', style: TextStyle(color: Colors.black)),
        backgroundColor: Color(0xFFF2F2F7),
        border: Border(
          bottom: BorderSide(color: Color(0xFFD8D8D8), width: 0.5),
        ),
      ),
      backgroundColor: const Color(0xFFF2F2F7),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CupertinoActivityIndicator(radius: 14))
            : CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _fetchSheetData),

                  if (_permittedColumns.isEmpty)
                    _buildEmptyState(
                      CupertinoIcons.person_badge_minus,
                      'No Permissions',
                      'You have no column permissions assigned.\nPlease contact your administrator.',
                    )
                  else if (!_canRead)
                    _buildEmptyState(
                      CupertinoIcons.lock_fill,
                      'Access Restricted',
                      'You do not have read access to view this data.\nPlease contact your administrator.',
                    )
                  else if (_dataList.isEmpty)
                    _buildEmptyState(
                      CupertinoIcons.tray,
                      'No Data',
                      'No records were found in the sheet.',
                    )
                  else ...[
                    // Smooth, Premium Aesthetic Search Bar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          top: 16,
                          bottom: 4,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemGrey.withValues(
                                  alpha: 0.08,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CupertinoTextField(
                            controller: _searchController,
                            placeholder: 'Search records...',
                            style: const TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.black,
                            ),
                            placeholderStyle: const TextStyle(
                              color: CupertinoColors.systemGrey,
                              fontSize: 15,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: null,
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 14),
                              child: Icon(
                                CupertinoIcons.search,
                                size: 20,
                                color: Color(0xFF667EEA),
                              ),
                            ),
                            suffix: _searchQuery.isNotEmpty
                                ? CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.only(right: 14),
                                      child: Icon(
                                        CupertinoIcons.clear,
                                        size: 18,
                                        color: CupertinoColors.systemGrey3,
                                      ),
                                    ),
                                  )
                                : null,
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val.trim();
                              });
                            },
                          ),
                        ),
                      ),
                    ),

                    // Smooth, Premium Aesthetic Add New Record Button
                    if (_canWrite)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            top: 12,
                            bottom: 4,
                          ),
                          child: GestureDetector(
                            onTap: _showAddSheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF667EEA).withValues(alpha: 0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    CupertinoIcons.add_circled_solid,
                                    color: CupertinoColors.white,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Add New Record',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (filteredList.isEmpty)
                      _buildEmptyState(
                        CupertinoIcons.search,
                        'No Results Found',
                        'We couldn\'t find any records matching "$_searchQuery".',
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildCard(filteredList[index]),
                            childCount: filteredList.length,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}
