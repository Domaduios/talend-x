import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as math;

class AppIconGeneratorScreen extends StatefulWidget {
  const AppIconGeneratorScreen({super.key});

  @override
  State<AppIconGeneratorScreen> createState() => _AppIconGeneratorScreenState();
}

class _AppIconGeneratorScreenState extends State<AppIconGeneratorScreen> {
  final GlobalKey _iconKey = GlobalKey();
  bool _isGenerating = false;
  String _selectedDesign = 'design1';

  final List<Map<String, dynamic>> _designs = [
    {
      'id': 'design1',
      'name': 'Swap Arrows',
      'description': 'Classic exchange icon with gradient',
    },
    {
      'id': 'design2',
      'name': 'TX Monogram',
      'description': 'TalentX letters design',
    },
    {
      'id': 'design3',
      'name': 'Handshake',
      'description': 'Two hands exchanging',
    },
    {
      'id': 'design4',
      'name': 'Circular Flow',
      'description': 'Continuous learning cycle',
    },
  ];

  Future<void> _generateIcon(int size) async {
    setState(() => _isGenerating = true);
    try {
      // Wait for the widget to render
      await Future.delayed(const Duration(milliseconds: 300));

      if (_iconKey.currentContext == null) {
        throw Exception('Context not available');
      }

      // Find the render object
      RenderRepaintBoundary boundary =
          _iconKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // Convert to image with proper pixel ratio
      // The preview container is 300x300, and the icon inside is 240x240
      final pixelRatio = size / 240.0;
      ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      // Convert to PNG
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Failed to convert image to bytes');
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/app_icon_${size}x$size.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Icon saved: ${size}x$size\n$filePath')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<void> _generateAllSizes() async {
    final sizes = [192, 512, 1024]; // Android sizes

    for (final size in sizes) {
      await _generateIcon(size);
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.download_done, color: Colors.white),
              SizedBox(width: 10),
              Text('All icons generated successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'App Icon Generator',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Design selector
            _buildDesignSelector(),
            const SizedBox(height: 30),
            // Live Preview
            const Text(
              'Live Preview',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            // Icon preview with RepaintBoundary
            Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(30),
                child: RepaintBoundary(
                  key: _iconKey,
                  child: _buildSelectedDesign(240),
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Size previews
            _buildSizePreviews(),
            const SizedBox(height: 30),
            // Generate buttons
            _buildGenerateButtons(),
            const SizedBox(height: 20),
            // Info card
            _buildInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesignSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Design',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        ..._designs.map((design) {
          final isSelected = _selectedDesign == design['id'];
          return InkWell(
            onTap: () => setState(() => _selectedDesign = design['id']),
            borderRadius: BorderRadius.circular(15),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF667eea).withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF667eea)
                      : Colors.grey.shade300,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: _buildSelectedDesign(50, designId: design['id']),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          design['name'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? const Color(0xFF667eea)
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          design['description'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF667eea),
                      size: 28,
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSelectedDesign(double size, {String? designId}) {
    final id = designId ?? _selectedDesign;
    switch (id) {
      case 'design1':
        return _buildDesign1(size);
      case 'design2':
        return _buildDesign2(size);
      case 'design3':
        return _buildDesign3(size);
      case 'design4':
        return _buildDesign4(size);
      default:
        return _buildDesign1(size);
    }
  }

  // Design 1: Swap Arrows (Classic)
  Widget _buildDesign1(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
        boxShadow: size > 100
            ? [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.4),
                  blurRadius: size * 0.1,
                  spreadRadius: size * 0.02,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          // Left arrow
          Positioned(
            left: size * 0.15,
            top: size * 0.42,
            child: CustomPaint(
              size: Size(size * 0.35, size * 0.16),
              painter: _LeftArrowPainter(),
            ),
          ),
          // Right arrow
          Positioned(
            right: size * 0.15,
            top: size * 0.42,
            child: CustomPaint(
              size: Size(size * 0.35, size * 0.16),
              painter: _RightArrowPainter(),
            ),
          ),
        ],
      ),
    );
  }

  // Design 2: TX Monogram
  Widget _buildDesign2(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'T',
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.0,
              ),
            ),
            Text(
              'X',
              style: TextStyle(
                fontSize: size * 0.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -1,
                height: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Design 3: Handshake
  Widget _buildDesign3(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Icon(Icons.handshake, size: size * 0.75, color: Colors.white),
      ),
    );
  }

  // Design 4: Circular Flow
  Widget _buildDesign4(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Stack(
        children: [
          Center(
            child: CustomPaint(
              size: Size(size * 0.6, size * 0.6),
              painter: _CircularFlowPainter(),
            ),
          ),
          Center(
            child: Icon(Icons.sync, size: size * 0.35, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSizePreviews() {
    return Column(
      children: [
        const Text(
          'Size Previews',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSizePreview(48, 'mdpi'),
            _buildSizePreview(72, 'hdpi'),
            _buildSizePreview(96, 'xhdpi'),
            _buildSizePreview(144, 'xxhdpi'),
          ],
        ),
      ],
    );
  }

  Widget _buildSizePreview(double size, String label) {
    return Column(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildSelectedDesign(size),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          '${size.toInt()}px',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateAllSizes,
            icon: _isGenerating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Icon(Icons.download, size: 24),
            label: Text(
              _isGenerating ? 'Generating...' : 'Generate All Sizes',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              disabledBackgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isGenerating ? null : () => _generateIcon(512),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF667eea),
                  side: const BorderSide(color: Color(0xFF667eea)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('512px'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: _isGenerating ? null : () => _generateIcon(1024),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF667eea),
                  side: const BorderSide(color: Color(0xFF667eea)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('1024px'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 10),
              Text(
                'How to Use',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildInfoStep('1', 'Select your preferred design'),
          _buildInfoStep('2', 'Click "Generate All Sizes"'),
          _buildInfoStep('3', 'Find icons in app documents folder'),
          _buildInfoStep('4', 'Use flutter_launcher_icons package to apply'),
        ],
      ),
    );
  }

  Widget _buildInfoStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

// Custom Painters for arrows and shapes
class _LeftArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Arrow body (rectangle)
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.3,
        size.height * 0.3,
        size.width * 0.7,
        size.height * 0.4,
      ),
      paint,
    );

    // Arrow head (triangle pointing left)
    final path = Path();
    path.moveTo(size.width * 0.3, size.height / 2);
    path.lineTo(0, 0);
    path.lineTo(0, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RightArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    // Arrow body (rectangle)
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.3, size.width * 0.7, size.height * 0.4),
      paint,
    );

    // Arrow head (triangle pointing right)
    final path = Path();
    path.moveTo(size.width * 0.7, size.height / 2);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircularFlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw circular arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
