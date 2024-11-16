import 'package:flutter/material.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú Principal'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Text(
          '¡Hola!',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}