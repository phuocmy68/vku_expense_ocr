import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrParserService {
  final TextRecognizer _textRecognizer =
  TextRecognizer(script: TextRecognitionScript.latin);

  /// Xử lý ảnh hóa đơn và trả về: (Người nhận, Số tiền, Ngày)
  Future<(String, double, DateTime)> processReceiptImage(
      String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText =
    await _textRecognizer.processImage(inputImage);

    // 1. Tái cấu trúc văn bản theo tọa độ thực tế trên ảnh
    final List<String> sortedLines = _reconstructVisualLines(recognizedText);
    final String fullText = sortedLines.join('\n');

    // 2. Trích xuất chính xác các trường thông tin
    final String recipient = _extractRecipient(sortedLines);
    final double amount = _extractAmount(sortedLines, recognizedText);
    final DateTime date = _extractDate(fullText, recognizedText.text);

    return (recipient, amount, date);
  }

  /// Sắp xếp văn bản theo vị trí thực tế (Y từ trên xuống, X từ trái sang)
  List<String> _reconstructVisualLines(RecognizedText recognizedText) {
    List<TextLine> allLines = [];
    for (final block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    if (allLines.isEmpty) return [];

    allLines.sort((a, b) {
      double diffY = a.boundingBox.top - b.boundingBox.top;
      if (diffY.abs() < 18) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return diffY.compareTo(0);
    });

    List<String> reconstructed = [];
    String currentLineText = "";
    double currentTop = -1;

    for (final line in allLines) {
      if (currentTop == -1 || (line.boundingBox.top - currentTop).abs() < 18) {
        currentLineText +=
            (currentLineText.isEmpty ? "" : " ") + line.text.trim();
        if (currentTop == -1) currentTop = line.boundingBox.top;
      } else {
        if (currentLineText.isNotEmpty) reconstructed.add(currentLineText);
        currentLineText = line.text.trim();
        currentTop = line.boundingBox.top;
      }
    }
    if (currentLineText.isNotEmpty) reconstructed.add(currentLineText);

    return reconstructed;
  }

  /// 1. Trích xuất Người nhận / Đơn vị thụ hưởng (Tự động gộp các dòng bị rớt)
  String _extractRecipient(List<String> lines) {
    final keywords = [
      'tên người nhận',
      'người nhận',
      'đơn vị thụ hưởng',
      'người thụ hưởng',
      'tên cửa hàng',
      'thụ hưởng'
    ];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      for (final kw in keywords) {
        if (lower.contains(kw)) {
          List<String> nameParts = [];

          // Lấy đoạn văn bản sau từ khóa
          int index = lower.indexOf(kw);
          String afterKw = line
              .substring(index + kw.length)
              .replaceAll(RegExp(r'^[:\-\t]+'), '')
              .trim();

          if (afterKw.isNotEmpty) {
            String cleaned = _cleanRecipientChunk(afterKw);
            if (cleaned.isNotEmpty) nameParts.add(cleaned);
          }

          // Quét tiếp tối đa 3 dòng bên dưới để nối đủ tên đầy đủ
          for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
            String nextLine = lines[j].trim();
            final nextLower = nextLine.toLowerCase();

            if (nextLower.contains('ngân hàng') ||
                nextLower.contains('nội dung') ||
                nextLower.contains('mã tham chiếu') ||
                nextLower.contains('phí chuyển tiền')) {
              break;
            }

            String cleaned = _cleanRecipientChunk(nextLine);
            if (cleaned.isNotEmpty) {
              nameParts.add(cleaned);
            }
          }

          if (nameParts.isNotEmpty) {
            return nameParts.join(' ');
          }
        }
      }
    }

    // Dự phòng: Tìm tên viết in hoa
    List<String> upperLines = [];
    for (final line in lines) {
      final trimmed = line.trim();
      final upper = trimmed.toUpperCase();

      if (upper.contains('VCBDIGIBANK') ||
          upper.contains('GIAO DỊCH THÀNH CÔNG') ||
          upper.contains('SACOMBANK') ||
          upper.contains('VIETCOMBANK') ||
          upper.contains('MBBANK') ||
          upper.contains('NGÂN HÀNG')) {
        continue;
      }

      String cleaned = _cleanRecipientChunk(trimmed);
      if (cleaned.length >= 3 &&
          cleaned == cleaned.toUpperCase() &&
          !cleaned.contains(RegExp(r'\d'))) {
        upperLines.add(cleaned);
      }
    }

    if (upperLines.isNotEmpty) {
      return upperLines.join(' ');
    }

    return "Cửa hàng / Người nhận";
  }

  /// Lọc mã phụ VNEDU/VNPT
  String _cleanRecipientChunk(String raw) {
    String cleaned = raw.trim();

    if (RegExp(r'^(VNEDU\d*|VNPT\d*|[A-Z0-9_-]{10,})$', caseSensitive: false)
        .hasMatch(cleaned)) {
      return "";
    }

    cleaned = cleaned
        .replaceAll(
        RegExp(r'^(VNEDU\d*|VNPT\d*|[A-Z0-9_-]{8,})\s+', caseSensitive: false),
        '')
        .trim();

    cleaned = cleaned.replaceAll(RegExp(r'\s+\d+$'), '').trim();
    return cleaned;
  }

  /// 2. Trích xuất Số tiền giao dịch chính xác (833,100)
  double _extractAmount(List<String> lines, RecognizedText recognizedText) {
    // ƯU TIÊN 1: Quét khối chứa chữ VND / VNĐ / đ hoặc dòng dưới "Giao dịch thành công"
    for (final block in recognizedText.blocks) {
      final text = block.text.replaceAll('\n', ' ');
      final lower = text.toLowerCase();

      if (lower.contains('vnd') ||
          lower.contains('vnđ') ||
          lower.contains('đ') ||
          lower.contains('giao dịch thành công')) {
        final regExp = RegExp(r'(\d{1,3}(?:[\.,\s]\d{3})+|\d{4,8})');
        for (final match in regExp.allMatches(text)) {
          String rawStr = match.group(1)!;
          String cleanDigits = rawStr.replaceAll(RegExp(r'[^\d]'), '');
          double? val = double.tryParse(cleanDigits);

          if (val != null && val >= 1000 && val <= 500000000) {
            if (val >= 2020 && val <= 2030 && !rawStr.contains(RegExp(r'[\.,]'))) {
              continue;
            }
            return val;
          }
        }
      }
    }

    // ƯU TIÊN 2: Quét các dòng ngay dưới chữ "Giao dịch thành công"
    for (int i = 0; i < lines.length; i++) {
      final lower = lines[i].toLowerCase();
      if (lower.contains('giao dịch thành công') || lower.contains('thành công')) {
        for (int j = i + 1; j < lines.length && j <= i + 3; j++) {
          final lineText = lines[j];
          if (lineText.contains(RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{4}'))) continue;

          final match = RegExp(r'(\d{1,3}(?:[\.,\s]\d{3})+|\d{4,8})').firstMatch(lineText);
          if (match != null) {
            String cleanDigits = match.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
            double? val = double.tryParse(cleanDigits);
            if (val != null && val >= 1000 && val <= 500000000) {
              return val;
            }
          }
        }
      }
    }

    // ƯU TIÊN 3: Tìm chuỗi có dấu phân cách hàng nghìn
    final fullText = lines.join(' ');
    final cleanFullText = fullText.replaceAll(
      RegExp(r'\d{1,2}[/.-]\d{1,2}[/.-]\d{4}|\d{4}[/.-]\d{1,2}[/.-]\d{1,2}'),
      '',
    );

    final moneyRegex = RegExp(r'(\d{1,3}(?:[\.,]\d{3})+)');
    for (final match in moneyRegex.allMatches(cleanFullText)) {
      String cleanDigits = match.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
      double? val = double.tryParse(cleanDigits);
      if (val != null && val >= 1000 && val <= 500000000) {
        return val;
      }
    }

    return 0.0;
  }

  /// 3. Trích xuất Ngày giao dịch
  DateTime _extractDate(String fullText, String rawText) {
    final text = "$fullText\n$rawText";
    final RegExp dateRegex = RegExp(r'(\d{1,2})[/.-](\d{1,2})[/.-](\d{4})');
    final match = dateRegex.firstMatch(text);

    if (match != null) {
      int day = int.parse(match.group(1)!);
      int month = int.parse(match.group(2)!);
      int year = int.parse(match.group(3)!);
      return DateTime(year, month, day);
    }

    return DateTime.now();
  }

  void dispose() {
    _textRecognizer.close();
  }
}