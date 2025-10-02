import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ipay/services/cart_service.dart';
import 'package:ipay/services/product_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({Key? key}) : super(key: key);

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  final CartService _cartService = CartService();
  final ProductService _productService = ProductService();
  
  bool _isScanning = true;
  bool _flashOn = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isDenied || result.isPermanentlyDenied) {
        _showPermissionDialog();
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Permission Required'),
        content: const Text(
          'This app needs camera permission to scan barcodes. Please grant camera permission in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || !_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    
    for (final barcode in barcodes) {
      // Only process barcodes, not QR codes
      if (barcode.rawValue != null && _isBarcode(barcode)) {
        await _processBarcodeData(barcode.rawValue!, barcode);
        break; // Process only the first barcode
      }
    }
  }

  bool _isBarcode(Barcode barcode) {
    // Filter for common barcode formats, exclude QR codes
    final barcodeFormats = [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.codabar,
      BarcodeFormat.itf,
      BarcodeFormat.aztec,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
    ];
    
    return barcodeFormats.contains(barcode.format);
  }

  Future<void> _processBarcodeData(String barcodeData, Barcode barcode) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Haptic feedback
      HapticFeedback.mediumImpact();
      
      // Stop scanning temporarily
      setState(() {
        _isScanning = false;
      });

      print('📱 Scanned barcode: $barcodeData');
      print('📱 Barcode format: ${barcode.format}');

      // Get product information by barcode
      final product = await _productService.getProductByBarcode(barcodeData);
      
      if (product != null) {
        // Add product to cart
        final success = await _cartService.addToCart(product);
        
        if (success) {
          _showSuccessDialog(product);
        } else {
          _showErrorDialog('Failed to add product to cart. Please try again.');
        }
      } else {
        _showProductNotFoundDialog(barcodeData);
      }
    } catch (e) {
      print('Error processing barcode: $e');
      _showErrorDialog('An error occurred while processing the barcode.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showSuccessDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle,
          color: Colors.green,
          size: 48,
        ),
        title: const Text('Product Added!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              product['name'] ?? 'Unknown Product',
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '₹${product['price']?.toStringAsFixed(2) ?? '0.00'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Barcode: ${product['barcode'] ?? 'N/A'}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text('has been added to your cart'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _continuScanning();
            },
            child: const Text('Scan More'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to home
              // TODO: Navigate to cart screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A9B8E),
              foregroundColor: Colors.white,
            ),
            child: const Text('View Cart'),
          ),
        ],
      ),
    );
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.search_off,
          color: Colors.orange,
          size: 48,
        ),
        title: const Text('Product Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Barcode: $barcode'),
            const SizedBox(height: 8),
            const Text(
              'This product is not available in our store. Please try scanning another product.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _continuScanning();
            },
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to home
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.error,
          color: Colors.red,
          size: 48,
        ),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _continuScanning();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _continuScanning() {
    setState(() {
      _isScanning = true;
    });
  }

  void _showManualBarcodeDialog() {
    final TextEditingController barcodeController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A9B8E).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.keyboard,
                              color: Color(0xFF4A9B8E),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Enter Barcode Manually',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1A202C),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFF718096),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        children: [
                          // Barcode input
                          TextField(
                            controller: barcodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 13,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF1A202C),
                            ),
                            decoration: InputDecoration(
                              labelText: 'Barcode',
                              hintText: 'e.g., 8901030611234',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFF4A9B8E),
                                  width: 1,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              labelStyle: const TextStyle(
                                color: Color(0xFF718096),
                                fontWeight: FontWeight.w400,
                              ),
                              hintStyle: const TextStyle(
                                color: Color(0xFFA0AEC0),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Sample barcodes
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A9B8E).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF4A9B8E).withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Sample barcodes to test:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A202C),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildSampleBarcode('8901030611234', 'Maggi Noodles (₹14)'),
                                _buildSampleBarcode('8901030823456', 'Britannia Cookies (₹20)'),
                                _buildSampleBarcode('8901030934567', 'Parle-G Biscuits (₹10)'),
                                _buildSampleBarcode('8901030845678', 'Coca-Cola (₹25)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Actions
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Row(
                        children: [
                          // Cancel button
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF718096),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // Test button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                final barcode = barcodeController.text.trim();
                                if (barcode.isNotEmpty) {
                                  Navigator.pop(context);
                                  _processBarcodeData(barcode, Barcode(
                                    rawValue: barcode,
                                    format: BarcodeFormat.ean13,
                                  ));
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4A9B8E),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Test Barcode',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildSampleBarcode(String barcode, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF4A9B8E),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF718096),
                ),
                children: [
                  TextSpan(
                    text: '$barcode - ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A202C),
                    ),
                  ),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleFlash() {
    cameraController.toggleTorch();
    setState(() {
      _flashOn = !_flashOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // Overlay
          _buildScannerOverlay(),
          
          // Top Controls
          _buildTopControls(),
          
          // Bottom Controls
          _buildBottomControls(),
          
          // Processing Overlay
          if (_isProcessing) _buildProcessingOverlay(),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return Container(
      decoration: ShapeDecoration(
        shape: BarcodeScannerOverlayShape(
          borderColor: const Color(0xFF4A9B8E),
          borderRadius: 16,
          borderLength: 40,
          borderWidth: 4,
          cutOutSize: 300, // Wider for barcodes
        ),
      ),
    );
  }

  Widget _buildTopControls() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back Button
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                ),
              ),
            ),
            
            // Title
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Scan Product Barcode',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            // Flash Toggle
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: _toggleFlash,
                icon: Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_off,
                  color: _flashOn ? Colors.yellow : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: const Text(
                  'Point camera at product barcode\n(Not QR codes)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: Icons.keyboard,
                    label: 'Manual',
                    onTap: () {
                      _showManualBarcodeDialog();
                    },
                  ),
                  _buildControlButton(
                    icon: _isScanning ? Icons.pause : Icons.play_arrow,
                    label: _isScanning ? 'Pause' : 'Resume',
                    onTap: () {
                      setState(() {
                        _isScanning = !_isScanning;
                      });
                    },
                  ),
                  
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A9B8E)),
                ),
                SizedBox(height: 16),
                Text(
                  'Processing barcode...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom overlay shape for barcode scanner
class BarcodeScannerOverlayShape extends ShapeBorder {
  const BarcodeScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 2.0,
    this.borderLength = 40,
    this.borderRadius = 0,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final double borderLength;
  final double borderRadius;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path path = Path()..addRect(rect);
    
    // Calculate center position
    final center = rect.center;
    final cutOutRect = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );
    
    path.addRRect(RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)));
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final center = rect.center;
    final cutOutRect = Rect.fromCenter(
      center: center,
      width: cutOutSize,
      height: cutOutSize,
    );

    final paint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Draw corners
    final cornerSize = borderLength;
    final corners = [
      // Top-left
      [cutOutRect.topLeft, cutOutRect.topLeft + Offset(cornerSize, 0)],
      [cutOutRect.topLeft, cutOutRect.topLeft + Offset(0, cornerSize)],
      
      // Top-right
      [cutOutRect.topRight, cutOutRect.topRight + Offset(-cornerSize, 0)],
      [cutOutRect.topRight, cutOutRect.topRight + Offset(0, cornerSize)],
      
      // Bottom-left
      [cutOutRect.bottomLeft, cutOutRect.bottomLeft + Offset(cornerSize, 0)],
      [cutOutRect.bottomLeft, cutOutRect.bottomLeft + Offset(0, -cornerSize)],
      
      // Bottom-right
      [cutOutRect.bottomRight, cutOutRect.bottomRight + Offset(-cornerSize, 0)],
      [cutOutRect.bottomRight, cutOutRect.bottomRight + Offset(0, -cornerSize)],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint);
    }
  }

  @override
  ShapeBorder scale(double t) => BarcodeScannerOverlayShape(
        borderColor: borderColor,
        borderWidth: borderWidth,
        borderLength: borderLength,
        borderRadius: borderRadius,
        cutOutSize: cutOutSize,
      );
}
