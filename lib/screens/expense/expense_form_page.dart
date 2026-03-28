import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:gap/gap.dart';
import '../../models/enums.dart';
import '../../models/expense.dart';
import '../../models/split_detail.dart';
import '../../models/family_member.dart';
import '../../providers/member_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/image_storage_service.dart';

class ExpenseFormPage extends ConsumerStatefulWidget {
  final Expense? existingExpense;
  const ExpenseFormPage({super.key, this.existingExpense});
  @override
  ConsumerState<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends ConsumerState<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = '餐飲';
  bool _isShared = true;
  SplitMethod _splitMethod = SplitMethod.equal;
  String? _payerId;
  Set<String> _participantIds = {};
  Map<String, double> _percentages = {};
  Map<String, double> _customAmounts = {};
  Map<String, TextEditingController> _pctCtrl = {};
  Map<String, TextEditingController> _customCtrl = {};
  String? _receiptPath;
  TextEditingController? _descAutoController;

  String get _descText => (_descAutoController ?? _descController).text;
  bool get _isEditing => widget.existingExpense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingExpense;
    if (e != null) {
      _descController.text = e.description;
      _amountController.text = e.amount.toStringAsFixed(0);
      _noteController.text = e.note ?? '';
      _selectedDate = e.date;
      _selectedCategory = e.category;
      _isShared = e.isShared;
      _splitMethod = e.splitMethod;
      _payerId = e.payerId;
      _receiptPath = e.receiptPath;
      _participantIds = e.splits.where((s) => s.isParticipant).map((s) => s.memberId).toSet();
      if (_splitMethod == SplitMethod.percentage) {
        final total = e.amount;
        for (final s in e.splits.where((s) => s.isParticipant)) {
          final pct = total > 0 ? s.shareAmount / total * 100 : 0.0;
          _percentages[s.memberId] = pct;
          _pctCtrl[s.memberId] = TextEditingController(text: pct.toStringAsFixed(0));
        }
      }
      if (_splitMethod == SplitMethod.custom) {
        for (final s in e.splits.where((s) => s.isParticipant)) {
          _customAmounts[s.memberId] = s.shareAmount;
          _customCtrl[s.memberId] = TextEditingController(text: s.shareAmount.toStringAsFixed(0));
        }
      }
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _pctCtrl.values.forEach((c) => c.dispose());
    _customCtrl.values.forEach((c) => c.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider);
    final categories = ref.watch(categoriesProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '編輯支出' : '新增支出')),
      body: members.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('錯誤：$e')),
        data: (memberList) {
          if (memberList.isEmpty) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.people_outline, size: 64, color: theme.colorScheme.primary.withValues(alpha:0.3)),
                const Gap(16),
                Text('尚未建立家庭成員', style: theme.textTheme.titleMedium),
                const Gap(8),
                const Text('請先到「設定」頁新增家庭成員'),
                const Gap(24),
                FilledButton.icon(onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back), label: const Text('返回')),
              ]),
            ));
          }
          _payerId ??= currentUser.valueOrNull?.id ?? memberList.first.id;
          if (_participantIds.isEmpty) _participantIds = memberList.map((m) => m.id).toSet();
          final catList = categories.valueOrNull ?? [];
          return Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              // 日期
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate,
                      firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '日期', prefixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                  child: Text(DateFormat('yyyy/MM/dd (E)', 'zh_TW').format(_selectedDate)),
                ),
              ),
              const Gap(16),
              // 描述（自動提示最近輸入）
              LayoutBuilder(builder: (context, constraints) {
                final recentDescs = ref.watch(recentDescriptionsProvider).valueOrNull ?? [];
                return Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return recentDescs.take(5);
                    final query = textEditingValue.text.toLowerCase();
                    return recentDescs.where((d) => d.toLowerCase().contains(query)).take(8);
                  },
                  onSelected: (value) {
                    _descAutoController?.text = value;
                    _descAutoController?.selection = TextSelection.collapsed(offset: value.length);
                  },
                  initialValue: TextEditingValue(text: _descController.text),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    _descAutoController = controller;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: '描述',
                        hintText: '例如：晚餐、加油、水費...',
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '請輸入描述' : null,
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: 200, maxWidth: constraints.maxWidth),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option),
                                leading: const Icon(Icons.history, size: 18),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              const Gap(16),
              // 金額
              TextFormField(controller: _amountController,
                  decoration: const InputDecoration(labelText: '金額', prefixText: 'NT\$ ',
                      prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '請輸入金額';
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return '請輸入有效金額';
                    return null;
                  }),
              const Gap(16),
              // 類別
              DropdownButtonFormField<String>(
                value: catList.any((c) => c.name == _selectedCategory) ? _selectedCategory
                    : (catList.isNotEmpty ? catList.first.name : '其他'),
                decoration: const InputDecoration(labelText: '類別', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                items: (catList.isNotEmpty ? catList.map((c) => c.name).toList()
                    : ['餐飲', '交通', '購物', '其他']).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const Gap(16),
              // 支出類型
              Text('支出類型', style: theme.textTheme.labelLarge),
              const Gap(8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('個人支出'), icon: Icon(Icons.person)),
                  ButtonSegment(value: true, label: Text('共同支出'), icon: Icon(Icons.people)),
                ],
                selected: {_isShared},
                onSelectionChanged: (v) => setState(() => _isShared = v.first),
              ),
              const Gap(16),
              // 付款人
              DropdownButtonFormField<String>(
                value: _payerId,
                decoration: const InputDecoration(labelText: '付款人（誰先付的）',
                    prefixIcon: Icon(Icons.payment), border: OutlineInputBorder()),
                items: memberList.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                onChanged: (v) => setState(() => _payerId = v),
              ),
              const Gap(16),
              // 拆帳設定
              if (_isShared) ...[
                Text('分帳方式', style: theme.textTheme.labelLarge),
                const Gap(8),
                SegmentedButton<SplitMethod>(
                  segments: const [
                    ButtonSegment(value: SplitMethod.equal, label: Text('均分')),
                    ButtonSegment(value: SplitMethod.percentage, label: Text('比例')),
                    ButtonSegment(value: SplitMethod.custom, label: Text('自訂')),
                  ],
                  selected: {_splitMethod},
                  onSelectionChanged: (v) => setState(() => _splitMethod = v.first),
                ),
                const Gap(12),
                // 參與者
                Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.people_outline, size: 20, color: theme.colorScheme.primary),
                      const Gap(8),
                      Text('參與拆帳的成員', style: theme.textTheme.titleSmall),
                    ]),
                    const Gap(8),
                    Wrap(spacing: 8, children: memberList.map((m) {
                      final sel = _participantIds.contains(m.id);
                      return FilterChip(label: Text(m.name), selected: sel,
                          onSelected: (v) => setState(() {
                            if (v) { _participantIds.add(m.id); }
                            else if (_participantIds.length > 1) { _participantIds.remove(m.id); }
                          }));
                    }).toList()),
                    if (_splitMethod == SplitMethod.percentage) ...[
                      const Gap(12),
                      ...memberList.where((m) => _participantIds.contains(m.id)).map((m) {
                        _pctCtrl.putIfAbsent(m.id, () => TextEditingController());
                        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                          SizedBox(width: 80, child: Text(m.name)),
                          Expanded(child: TextFormField(controller: _pctCtrl[m.id],
                              decoration: const InputDecoration(suffixText: '%', isDense: true, border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => _percentages[m.id] = double.tryParse(v) ?? 0))),
                        ]));
                      }),
                    ],
                    if (_splitMethod == SplitMethod.custom) ...[
                      const Gap(12),
                      ...memberList.where((m) => _participantIds.contains(m.id)).map((m) {
                        _customCtrl.putIfAbsent(m.id, () => TextEditingController());
                        return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                          SizedBox(width: 80, child: Text(m.name)),
                          Expanded(child: TextFormField(controller: _customCtrl[m.id],
                              decoration: const InputDecoration(prefixText: 'NT\$ ', isDense: true, border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                              onChanged: (v) => setState(() => _customAmounts[m.id] = double.tryParse(v) ?? 0))),
                        ]));
                      }),
                    ],
                  ],
                ))),
                const Gap(12),
                // 拆帳預覽
                Builder(builder: (context) {
                  final amount = double.tryParse(_amountController.text) ?? 0;
                  if (amount <= 0) return const SizedBox.shrink();
                  final pCount = _participantIds.length;
                  return Card(
                    color: theme.colorScheme.primaryContainer.withValues(alpha:0.3),
                    child: Padding(padding: const EdgeInsets.all(12), child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(Icons.calculate_outlined, size: 20, color: theme.colorScheme.primary),
                          const Gap(8),
                          Text('拆帳預覽', style: theme.textTheme.titleSmall),
                        ]),
                        const Gap(8),
                        if (_splitMethod == SplitMethod.equal)
                          Text('每人 NT\$ ${(amount / pCount).toStringAsFixed(0)}（共 $pCount 人）'),
                        if (_splitMethod == SplitMethod.percentage)
                          ...memberList.where((m) => _participantIds.contains(m.id)).map((m) {
                            final pct = _percentages[m.id] ?? 0;
                            return Text('${m.name}：${pct.toStringAsFixed(0)}% = NT\$ ${(amount * pct / 100).toStringAsFixed(0)}');
                          }),
                        if (_splitMethod == SplitMethod.custom)
                          ...memberList.where((m) => _participantIds.contains(m.id)).map((m) {
                            final share = _customAmounts[m.id] ?? 0;
                            return Text('${m.name}：NT\$ ${share.toStringAsFixed(0)}');
                          }),
                      ],
                    )),
                  );
                }),
                const Gap(16),
              ],
              // 備註
              TextFormField(controller: _noteController,
                  decoration: const InputDecoration(labelText: '備註（可選）',
                      prefixIcon: Icon(Icons.note_outlined), border: OutlineInputBorder()),
                  maxLines: 2),
              const Gap(16),
              // 收據照片
              Text('收據 / 發票照片', style: theme.textTheme.labelLarge),
              const Gap(8),
              if (_receiptPath != null) ...[
                Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_receiptPath!),
                        height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(top: 8, right: 8, child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _CircleIconButton(
                      icon: Icons.fullscreen,
                      onTap: () => _viewReceiptFullScreen(_receiptPath!),
                    ),
                    const Gap(8),
                    _CircleIconButton(
                      icon: Icons.close,
                      onTap: () {
                        final old = _receiptPath;
                        setState(() => _receiptPath = null);
                        if (old != null) ImageStorageService.deleteReceipt(old);
                      },
                    ),
                  ])),
                ]),
                const Gap(8),
                OutlinedButton.icon(
                  onPressed: _pickReceipt,
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('更換照片'),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _pickReceipt,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('拍照或選擇照片'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              const Gap(32),
              // 儲存
              FilledButton.icon(
                onPressed: () => _save(memberList),
                icon: Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(_isEditing ? '儲存變更' : '新增支出'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
              const Gap(32),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt), title: const Text('拍照'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library), title: const Text('從相簿選擇'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ])),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1920, imageQuality: 85);
    if (picked == null) return;
    final old = _receiptPath;
    final saved = await ImageStorageService.saveReceipt(picked.path);
    if (old != null) await ImageStorageService.deleteReceipt(old);
    setState(() => _receiptPath = saved);
  }

  void _viewReceiptFullScreen(String path) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
        body: Center(child: InteractiveViewer(
          child: Image.file(File(path)),
        )),
      ),
    ));
  }

  Future<void> _save(List<FamilyMember> members) async {
    if (!_formKey.currentState!.validate()) return;
    if (_payerId == null) return;
    final amount = double.parse(_amountController.text);
    final currentUser = ref.read(currentUserProvider).valueOrNull;
    final nameMap = {for (final m in members) m.id: m.name};
    List<SplitDetail> splits = [];
    if (_isShared) {
      final participants = members.where((m) => _participantIds.contains(m.id))
          .map((m) => {'id': m.id, 'name': m.name}).toList();
      switch (_splitMethod) {
        case SplitMethod.equal:
          final per = amount / participants.length;
          final rounded = double.parse(per.toStringAsFixed(0));
          final rem = amount - (rounded * participants.length);
          splits = participants.asMap().entries.map((e) {
            final isLast = e.key == participants.length - 1;
            return SplitDetail()
              ..memberId = e.value['id']!
              ..memberName = e.value['name']!
              ..shareAmount = isLast ? rounded + rem : rounded
              ..paidAmount = (e.value['id'] == _payerId) ? amount : 0
              ..isParticipant = true;
          }).toList();
          break;
        case SplitMethod.percentage:
          splits = _percentages.entries.where((e) => _participantIds.contains(e.key)).map((e) {
            return SplitDetail()
              ..memberId = e.key
              ..memberName = nameMap[e.key] ?? ''
              ..shareAmount = double.parse((amount * e.value / 100).toStringAsFixed(0))
              ..paidAmount = (e.key == _payerId) ? amount : 0
              ..isParticipant = true;
          }).toList();
          break;
        case SplitMethod.custom:
          splits = _customAmounts.entries.where((e) => _participantIds.contains(e.key)).map((e) {
            return SplitDetail()
              ..memberId = e.key
              ..memberName = nameMap[e.key] ?? ''
              ..shareAmount = e.value
              ..paidAmount = (e.key == _payerId) ? amount : 0
              ..isParticipant = true;
          }).toList();
          break;
      }
    }
    if (_isEditing) {
      final existing = widget.existingExpense!;
      existing
        ..date = _selectedDate
        ..description = _descText.trim()
        ..amount = amount
        ..category = _selectedCategory
        ..isShared = _isShared
        ..splitMethod = _splitMethod
        ..payerId = _payerId!
        ..payerName = nameMap[_payerId] ?? ''
        ..splits = splits
        ..receiptPath = _receiptPath
        ..note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
      await ref.read(expenseNotifierProvider.notifier).updateExpense(existing);
    } else {
      await ref.read(expenseNotifierProvider.notifier).addExpense(
        date: _selectedDate, description: _descText.trim(),
        amount: amount, category: _selectedCategory, isShared: _isShared,
        splitMethod: _splitMethod, payerId: _payerId!,
        payerName: nameMap[_payerId] ?? '', splits: splits,
        receiptPath: _receiptPath,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
        createdBy: currentUser?.id ?? _payerId!,
      );
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? '已更新支出' : '已新增支出'), behavior: SnackBarBehavior.floating));
      Navigator.pop(context);
    }
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
