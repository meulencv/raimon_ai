import 'package:flutter/material.dart';
import 'package:flutter_web_qrcode_scanner/flutter_web_qrcode_scanner.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  String? _scannedUserId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear QR'),
        backgroundColor: const Color(0xFF2A9D8F),
      ),
      body: Column(
        children: [
          if (_scannedUserId != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A9D8F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2A9D8F),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  const Text(
                    '¡Usuario detectado!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A9D8F),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: $_scannedUserId',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, _scannedUserId);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A9D8F),
                    ),
                    child: const Text('Añadir al equipo'),
                  ),
                ],
              ),
            ),
          ],
          Expanded(
            child: FlutterWebQrcodeScanner(
              onGetResult: (result) {
                setState(() {
                  _scannedUserId = result;
                });
              },
              stopOnFirstResult: true,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.7,
              onError: (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${error.message}')),
                );
              },
              onPermissionDeniedError: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Permiso de cámara denegado'),
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