import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/form_data_service.dart';

class InitialFormScreen extends StatefulWidget {
  const InitialFormScreen({super.key});

  @override
  State<InitialFormScreen> createState() => _InitialFormScreenState();
}

class _InitialFormScreenState extends State<InitialFormScreen> {
  String? _yearOfStudy;
  String? _shirtSize;
  String? _dietaryRestrictions;
  String? _preferredTeamSize;

  bool _isLoading = false;

  // Definir las opciones para cada dropdown
  final Map<String, List<String>> _options = {
    'year_of_study': ['1er año', '2do año', '3er año', '4to año', 'Maestría', 'Doctorado'],
    'shirt_size': ['S', 'M', 'L', 'XL'],
    'dietary_restrictions': ['Ninguna', 'Vegetariano', 'Vegano', 'Sin gluten', 'Otra'],
    'preferred_team_size': ['1', '2', '3', '4'],
  };

  bool _isFormValid() {
    return _yearOfStudy != null && 
           _shirtSize != null && 
           _dietaryRestrictions != null && 
           _preferredTeamSize != null;
  }

  Future<void> _continueToChat() async {
    if (!_isFormValid()) return;

    final formData = {
      'initial_form_data': {
        'year_of_study': _yearOfStudy,
        'shirt_size': _shirtSize,
        'dietary_restrictions': _dietaryRestrictions,
        'preferred_team_size': _preferredTeamSize
      }
    };

    FormDataService.setFormData(formData);
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/chat');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Información Adicional'),
        backgroundColor: const Color(0xFF2A9D8F),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDropdownSection(
                'Año de Estudios',
                'year_of_study',
                _yearOfStudy,
                (value) => setState(() => _yearOfStudy = value),
              ),
              const SizedBox(height: 24),
              
              _buildDropdownSection(
                'Talla de Camiseta',
                'shirt_size',
                _shirtSize,
                (value) => setState(() => _shirtSize = value),
              ),
              const SizedBox(height: 24),
              
              _buildDropdownSection(
                'Restricciones Alimentarias',
                'dietary_restrictions',
                _dietaryRestrictions,
                (value) => setState(() => _dietaryRestrictions = value),
              ),
              const SizedBox(height: 24),
              
              _buildDropdownSection(
                'Tamaño de Equipo Preferido',
                'preferred_team_size',
                _preferredTeamSize,
                (value) => setState(() => _preferredTeamSize = value),
              ),
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isFormValid() && !_isLoading 
                    ? _continueToChat
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A9D8F),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continuar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownSection(
    String label, 
    String optionKey, 
    String? value, 
    void Function(String?) onChanged
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              border: InputBorder.none,
            ),
            items: _options[optionKey]!.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option),
              );
            }).toList(),
            onChanged: onChanged,
            hint: Text('Selecciona $label'),
          ),
        ),
      ],
    );
  }
}
