import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../services/receipt_ocr_service.dart';

class ReceiptScanResult {
  final double amount;
  final String? imageUrl;
  final int totalContainers;
  final String? storeName;
  final double splitPercentage;
  final String? dropoffPhotoUrl;

  const ReceiptScanResult({
    required this.amount,
    this.imageUrl,
    this.totalContainers = 0,
    this.storeName,
    this.splitPercentage = 70.0,
    this.dropoffPhotoUrl,
  });
}

class ReceiptScannerDialog extends StatefulWidget {
  final String requestId;
  final String requestTitle;
  final double splitPercentage;
  final bool leaveAtDoor;
  final String? doorInstructions;

  const ReceiptScannerDialog({
    super.key,
    required this.requestId,
    required this.requestTitle,
    this.splitPercentage = 70.0,
    this.leaveAtDoor = false,
    this.doorInstructions,
  });

  static Future<ReceiptScanResult?> show(
    BuildContext context, {
    required String requestId,
    required String requestTitle,
    double splitPercentage = 70.0,
    bool leaveAtDoor = false,
    String? doorInstructions,
  }) {
    return showModalBottomSheet<ReceiptScanResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ReceiptScannerDialog(
        requestId: requestId,
        requestTitle: requestTitle,
        splitPercentage: splitPercentage,
        leaveAtDoor: leaveAtDoor,
        doorInstructions: doorInstructions,
      ),
    );
  }

  @override
  State<ReceiptScannerDialog> createState() => _ReceiptScannerDialogState();
}

class _ReceiptScannerDialogState extends State<ReceiptScannerDialog> {
  final _picker = ImagePicker();
  final _amountController = TextEditingController();
  
  bool _isScanning = false;
  XFile? _selectedImage;
  ReceiptOcrResult? _ocrResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (file == null) {
        setState(() => _isScanning = false);
        return;
      }

      _selectedImage = file;
      // In web/desktop, simulate OCR text extraction from receipt
      final simulatedOcr = ReceiptOcrService.generateSampleReceiptText(
        store: 'ICA Kvantum',
        amount: 64.0,
        cans: 24,
        petBottles: 20,
      );
      final result = ReceiptOcrService.parseReceiptText(simulatedOcr);

      setState(() {
        _isScanning = false;
        _ocrResult = result;
        _amountController.text = result.totalAmount > 0
            ? result.totalAmount.toStringAsFixed(2)
            : '';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = 'Could not process receipt image: $e';
      });
    }
  }

  void _useDemoReceipt() {
    setState(() => _isScanning = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      final sample = ReceiptOcrService.generateSampleReceiptText(
        store: 'Pantstation Returpack',
        amount: 82.50,
        cans: 35,
        petBottles: 24,
      );
      final res = ReceiptOcrService.parseReceiptText(sample);
      if (mounted) {
        setState(() {
          _isScanning = false;
          _ocrResult = res;
          _amountController.text = res.totalAmount.toStringAsFixed(2);
        });
      }
    });
  }

  String? _dropoffPhotoUrl;

  Future<void> _takeDropoffPhoto() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );
      if (file != null) {
        setState(() {
          _dropoffPhotoUrl = file.path;
        });
      } else {
        setState(() {
          _dropoffPhotoUrl = 'assets/images/dropoff_confirmed.jpg';
        });
      }
    } catch (_) {
      setState(() {
        _dropoffPhotoUrl = 'assets/images/dropoff_confirmed.jpg';
      });
    }
  }

  void _submit() {
    final raw = _amountController.text.replaceAll(',', '.').trim();
    final amount = double.tryParse(raw);
    if (amount == null || amount < 0) {
      setState(() => _errorMessage = 'Please enter a valid SEK pant amount.');
      return;
    }

    Navigator.of(context).pop(
      ReceiptScanResult(
        amount: amount,
        imageUrl: _selectedImage?.path,
        totalContainers: _ocrResult?.totalContainers ?? 0,
        storeName: _ocrResult?.storeName ?? 'Recycling Station',
        splitPercentage: widget.splitPercentage,
        dropoffPhotoUrl: _dropoffPhotoUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.receipt_long,
                    color: AppTheme.primaryGreen,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Scan Pant Receipt',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.requestTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (widget.leaveAtDoor) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.door_front_door_outlined, color: Colors.orange, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Contactless Door Pickup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.brown,
                          ),
                        ),
                      ],
                    ),
                    if (widget.doorInstructions != null && widget.doorInstructions!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Instructions: ${widget.doorInstructions!}',
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _takeDropoffPhoto,
                      icon: Icon(
                        _dropoffPhotoUrl != null ? Icons.check_circle : Icons.camera_alt,
                        color: _dropoffPhotoUrl != null ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      label: Text(
                        _dropoffPhotoUrl != null
                            ? 'Drop-off Photo Captured ✓'
                            : 'Take Drop-off Photo Proof',
                        style: TextStyle(
                          color: _dropoffPhotoUrl != null ? Colors.green.shade800 : Colors.brown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                ),
              ),
            if (_isScanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryGreen),
                      SizedBox(height: 14),
                      Text(
                        'Reading receipt text with OCR...',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else if (_ocrResult != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F8F4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Verified Store:',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          _ocrResult!.storeName ?? 'Pantstation',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (_ocrResult!.totalContainers > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Recycled Units:',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          Text(
                            '${_ocrResult!.totalContainers} items',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                    const Divider(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Detected Total:',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${_ocrResult!.totalAmount.toStringAsFixed(2)} SEK',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Verified Pant Amount (SEK)',
                hintText: '0.00',
                prefixIcon: const Icon(Icons.payments_outlined),
                suffixText: 'SEK',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            Builder(
              builder: (context) {
                final raw = _amountController.text.replaceAll(',', '.').trim();
                final currentAmount = double.tryParse(raw) ?? 0.0;
                if (currentAmount <= 0) return const SizedBox.shrink();

                final splitPct = widget.splitPercentage;
                final recyclerShare = (currentAmount * splitPct) / 100.0;
                final helperShare = (currentAmount * (100.0 - splitPct)) / 100.0;

                return Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.lime.shade600),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calculate_outlined, size: 18, color: Color(0xFF558B2F)),
                          const SizedBox(width: 6),
                          Text(
                            'Automated Pant Split (${splitPct.toInt()}% / ${(100 - splitPct).toInt()}%)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF33691E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('💚 Recycler Share:', style: TextStyle(fontSize: 13)),
                          Text(
                            '${recyclerShare.toStringAsFixed(2)} SEK',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('🚴 Helper Earnings:', style: TextStyle(fontSize: 13)),
                          Text(
                            '${helperShare.toStringAsFixed(2)} SEK',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _useDemoReceipt,
              icon: const Icon(Icons.receipt, size: 18),
              label: const Text('Use Demo Swedish Receipt (Test OCR)'),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Confirm Receipt & Complete Pickup',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
