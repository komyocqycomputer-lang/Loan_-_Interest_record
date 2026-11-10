import 'dart:io';

import 'package:flutter/material.dart';

import '../models/loan_record.dart';
import '../services/storage_service.dart';
import '../utils/loan_calculator_helper.dart';

class RecordsScreen extends StatefulWidget {
  final Function(LoanRecord)? onEditRecord;
  final Widget Function(BuildContext context, VoidCallback onRefreshRecords)?
  drawerBuilder;

  const RecordsScreen({
    super.key,
    this.onEditRecord,
    this.drawerBuilder,
  });

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<LoanRecord> _allRecords = [];
  List<LoanRecord> _filteredRecords = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  int _compareCodeNo(LoanRecord a, LoanRecord b) {
    final codeA = a.codeNo.trim();
    final codeB = b.codeNo.trim();
    final numA = int.tryParse(codeA.replaceAll(RegExp(r'[^0-9]'), ''));
    final numB = int.tryParse(codeB.replaceAll(RegExp(r'[^0-9]'), ''));
    int cmp;
    if (numA != null && numB != null && numA != numB) {
      cmp = numA.compareTo(numB);
    } else {
      cmp = codeA.toLowerCase().compareTo(codeB.toLowerCase());
    }
    return _sortAscending ? cmp : -cmp;
  }

  void _applyFilterAndSort() {
    final q = _searchController.text.trim().toLowerCase();
    List<LoanRecord> results;
    if (q.isEmpty) {
      results = List<LoanRecord>.from(_allRecords);
    } else {
      results = _allRecords.where((r) {
        return r.codeNo.toLowerCase().contains(q) ||
            r.name.toLowerCase().contains(q) ||
            r.phone1.contains(q) ||
            r.phone2.contains(q) ||
            r.address.toLowerCase().contains(q);
      }).toList();
    }
    results.sort(_compareCodeNo);
    setState(() {
      _filteredRecords = results;
    });
  }

  void _toggleSortOrder() {
    _sortAscending = !_sortAscending;
    _applyFilterAndSort();
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final list = await StorageService.getRecords();
    _allRecords = list;
    _isLoading = false;
    _applyFilterAndSort();
  }

  void _onSearch(String query) {
    _applyFilterAndSort();
  }

  Future<void> _deleteRecord(LoanRecord record) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'ဖျက်ရန် အတည်ပြုပါ',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'ကုတ် [${record.codeNo}] - "${record.name}" ကို ဖျက်ရန် သေချာပါသလား?',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'မဖျက်ပါ',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ဖျက်မည်'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await StorageService.deleteRecord(record.id);
      _loadRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ကုတ် [${record.codeNo}] ကို ဖျက်ပြီးပါပြီ'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1527),
      drawer: widget.drawerBuilder?.call(context, _loadRecords),
      drawerEdgeDragWidth: MediaQuery.of(context).size.width,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1527),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: widget.drawerBuilder != null
                ? () => Scaffold.of(ctx).openDrawer()
                : null,
            child: Container(
              margin: const EdgeInsets.only(left: 12),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.menu_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'သိမ်းထားသောစာရင်း',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
            )
          : Column(
              children: [
                // Search Input + Code No. Sort Toggle Button on far right
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(left: 14, right: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131D30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF202E47)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearch,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Code / အမည် / ဖုန်း ဖြင့်ရှာရန်...',
                              hintStyle: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 13,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                              prefixIconConstraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 20,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.grey,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearch('');
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: const Color(0xFF131D30),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _toggleSortOrder,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _sortAscending
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  color: const Color(0xFFF59E0B),
                                  size: 18,
                                ),
                                const Icon(
                                  Icons.swap_vert_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Records List
                Expanded(
                  child: _filteredRecords.isEmpty
                      ? const Center(
                          child: Text(
                            'မှတ်တမ်း မရှိသေးပါ',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          itemCount: _filteredRecords.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final record = _filteredRecords[index];
                            final hasValidPhoto =
                                record.photoPath != null &&
                                File(record.photoPath!).existsSync();
                            return InkWell(
                              onTap: () {
                                if (widget.onEditRecord != null) {
                                  widget.onEditRecord!(record);
                                  Navigator.of(context).pop();
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF152033),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFF22324D),
                                  ),
                                ),
                                child: IntrinsicHeight(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Left side: Photo & Code Badge
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Photo container (matching home_screen Camera aspect ratio 92:122)
                                          Container(
                                            width: 76,
                                            height: 101,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0B111F),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: const Color(0xFFB45309),
                                              ),
                                            ),
                                            child: hasValidPhoto
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          9,
                                                        ),
                                                    child: Image.file(
                                                      File(record.photoPath!),
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      cacheWidth: 240,
                                                      gaplessPlayback: true,
                                                      errorBuilder:
                                                          (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) => const Center(
                                                            child: Icon(
                                                              Icons.person,
                                                              color: Color(
                                                                0xFF475569,
                                                              ),
                                                              size: 32,
                                                            ),
                                                          ),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Icon(
                                                      Icons.person,
                                                      color: Color(0xFF475569),
                                                      size: 32,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(height: 6),

                                          // Code No Badge below photo
                                          Container(
                                            width: 76,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 3,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFB45309)
                                                  .withValues(alpha: 0.25),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: const Color(0xFFF59E0B)
                                                    .withValues(alpha: 0.7),
                                              ),
                                            ),
                                            child: Text(
                                              record.codeNo,
                                              style: const TextStyle(
                                                color: Color(0xFFF59E0B),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),

                                      // Right side: Info Column
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Row 1: Name, Trash Icon
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    record.name,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 16,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    color: Color(0xFFEF4444),
                                                    size: 20,
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                  onPressed: () =>
                                                      _deleteRecord(record),
                                                ),
                                              ],
                                            ),

                                            // Row 2: နေရပ် (Address - prominent light slate)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.location_on_outlined,
                                                  size: 15,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    record.address.isNotEmpty
                                                        ? record.address
                                                        : '-',
                                                    style: const TextStyle(
                                                      color: Color(0xFFE2E8F0),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Row 3: ဖုန်း (Phone - prominent vibrant sky blue)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.phone_outlined,
                                                  size: 14,
                                                  color: Color(0xFF38BDF8),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    record.phone1.isNotEmpty
                                                        ? record.phone1
                                                        : (record
                                                                  .phone2
                                                                  .isNotEmpty
                                                              ? record.phone2
                                                              : '-'),
                                                    style: const TextStyle(
                                                      color: Color(0xFF38BDF8),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Row 4: ကြာချိန် (Duration - prominent warm amber)
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.schedule_outlined,
                                                  size: 14,
                                                  color: Color(0xFFFBBF24),
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    record.durationText.isNotEmpty
                                                        ? record.durationText
                                                        : '-',
                                                    style: const TextStyle(
                                                      color: Color(0xFFFBBF24),
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // Row 5: Total Due (Green)
                                            Text(
                                              'ကျသင့်ငွေ: ${LoanCalculatorHelper.formatCurrency(record.totalAmountDue)} Ks',
                                              style: const TextStyle(
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13.5,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
