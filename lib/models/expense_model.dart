class ExpenseItem {
  final String id;
  final String merchant;
  final double amount;
  final DateTime timestamp;
  final String category;
  final String? imagePath;

  const ExpenseItem({
    required this.id,
    required this.merchant,
    required this.amount,
    required this.timestamp,
    this.category = 'Chung',
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'merchant': merchant,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'category': category,
      'imagePath': imagePath,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'],
      merchant: map['merchant'],
      amount: map['amount'],
      timestamp: DateTime.parse(map['timestamp']),
      category: map['category'] ?? 'Chung',
      imagePath: map['imagePath'],
    );
  }
}
