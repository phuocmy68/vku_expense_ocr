import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense_model.dart';
import '../providers/expense_provider.dart';
import '../services/ocr_parser_service.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/expense_summary_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  final OcrParserService _ocrService = OcrParserService();

  final List<String> _categories = [
    'Học phí',
    'Ăn uống',
    'Mua sắm',
    'Hóa đơn / Tiện ích',
    'Giải trí',
    'Khác'
  ];

  Future<void> _processImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
    }

    final (recipient, amount, date) =
    await _ocrService.processReceiptImage(image.path);

    if (mounted) {
      Navigator.pop(context);
      _showReviewDialog(recipient, amount, date, image.path);
    }
  }

  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Thêm hóa đơn giao dịch",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2C4570)),
              title: const Text("Chụp ảnh trực tiếp"),
              onTap: () {
                Navigator.pop(ctx);
                _processImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2C4570)),
              title: const Text("Tải ảnh từ thư viện"),
              onTap: () {
                Navigator.pop(ctx);
                _processImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewDialog(
      String recipient, double amount, DateTime date, String imagePath) {
    final recipientController = TextEditingController(text: recipient);
    final amountController =
    TextEditingController(text: amount > 0 ? amount.toStringAsFixed(0) : "");

    String selectedCategory = _categories.first;
    DateTime selectedDate = date;
    final dateController = TextEditingController(
        text: "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}");

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Xác nhận thông tin Hóa đơn"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: recipientController,
                  decoration: const InputDecoration(
                    labelText: "Người nhận / Cửa hàng",
                    prefixIcon: Icon(Icons.storefront),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Số tiền giao dịch (VNĐ)",
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: "Danh mục chi tiêu",
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: _categories.map((cat) {
                    return DropdownMenuItem(
                      value: cat,
                      child: Text(cat),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setStateDialog(() => selectedCategory = val);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Ngày giao dịch",
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setStateDialog(() {
                        selectedDate = picked;
                        dateController.text =
                        "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Hủy"),
            ),
            ElevatedButton(
              onPressed: () {
                final newExpense = ExpenseItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  merchant: recipientController.text.isEmpty
                      ? "Cửa hàng / Người nhận"
                      : recipientController.text,
                  amount: double.tryParse(amountController.text) ?? 0.0,
                  category: selectedCategory,
                  timestamp: selectedDate,
                  imagePath: imagePath,
                );

                ref.read(expenseProvider.notifier).addExpense(newExpense);
                Navigator.pop(ctx);
              },
              child: const Text("Lưu Chi Tiêu"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expenseProvider);

    Map<String, double> categoryData = {};
    for (var exp in expenses) {
      categoryData[exp.category] =
          (categoryData[exp.category] ?? 0) + exp.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("VKU Expense OCR Tracker"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            CategoryPieChart(categoryData: categoryData),
            const Divider(),
            Expanded(
              child: expenses.isEmpty
                  ? const Center(child: Text("Chưa có hóa đơn nào"))
                  : ListView.builder(
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final item = expenses[index];
                  return Dismissible(
                    key: ValueKey(item.id),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) {
                      ref
                          .read(expenseProvider.notifier)
                          .removeExpense(item.id);
                    },
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child:
                      const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: ExpenseSummaryCard(
                      merchant: item.merchant,
                      amount: item.amount,
                      date: item.timestamp,
                      onTap: () {},
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showImageSourceOptions,
        icon: const Icon(Icons.add_a_photo),
        label: const Text("Thêm Hóa Đơn"),
      ),
    );
  }
}