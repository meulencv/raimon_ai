import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/straico_api.dart';
import 'dart:convert';
import 'menu_screen.dart';

class UserInfo {
  Map<String, dynamic> data = {};
  Set<String> pendingFields = {
    'experiencia_tecnica',
    'lenguajes',
    'creatividad',
    'productividad',
    'trabajo_equipo',
    'objetivo',
    'personalidad'
  };

  // Añadimos configuración estática para cada campo
  static final Map<String, Map<String, dynamic>> fieldSpecs = {
    'experiencia_tecnica': {
      'type': 'text',
      'description': 'Descripción detallada de la experiencia'
    },
    'lenguajes': {
      'type': 'list',
      'format': 'array of strings',
      'description': 'Lista de lenguajes de programación conocidos'
    },
    'creatividad': {
      'type': 'numeric',
      'range': '1-5',
      'description': 'Valoración de capacidad creativa'
    },
    'productividad': {
      'type': 'numeric',
      'range': '1-5',
      'description': 'Valoración de productividad'
    },
    'trabajo_equipo': {
      'type': 'numeric',
      'range': '1-5',
      'description': 'Valoración de trabajo en equipo'
    },
    'objetivo': {
      'type': 'enum',
      'values': ['ganar', 'no ganar'],
      'description': 'Objetivo principal de participación'
    },
    'personalidad': {
      'type': 'list',
      'format': 'array of traits',
      'description': 'Lista de rasgos de personalidad e intereses'
    }
  };

  bool isComplete() => pendingFields.isEmpty;
  void updateField(String field, dynamic value) {
    if (value != null && value.toString().isNotEmpty) {
      data[field] = value;
      pendingFields.remove(field);
      // Imprimir el nuevo elemento obtenido
      print('Nuevo elemento obtenido - $field: ${json.encode(value)}');
    }
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final StraicoApi _api = StraicoApi();
  bool _isLoading = false;
  late final UserInfo _userInfo;
  int _wordCount = 0;

  String? _extractJsonFromText(String text) {
    // Buscar contenido entre llaves, manejando anidación básica
    final regExp = RegExp(r'\{(?:[^{}]|\{[^{}]*\})*\}');
    final match = regExp.firstMatch(text);
    return match?.group(0);
  }

  Future<String> _generateQuestion() async {
    if (_userInfo.pendingFields.isEmpty) return '';

    final prompt = """
    Actúa como un psicólogo experto en perfiles tecnológicos que está realizando una entrevista inicial.
    
    CONTEXTO ACTUAL:
    - Campos pendientes: ${_userInfo.pendingFields.join(', ')}
    - Información obtenida: ${json.encode(_userInfo.data)}

    SI ES LA PRIMERA PREGUNTA (no hay información previa), USA EXACTAMENTE ESTE FORMATO:
    ¡Hola! 👋 Me gustaría conocerte mejor para formar el equipo perfecto para el hackathon. Cuéntame sobre ti:

    • ¿Cuál es tu experiencia en programación? Menciona tus proyectos favoritos, los lenguajes que dominas, y cualquier hackathon o evento tech en el que hayas participado.
    
    • Cuando te enfrentas a desafíos técnicos, ¿cómo los abordas? Cuéntame sobre algún problema complejo que hayas resuelto y cómo gestionas tu tiempo y energía en proyectos intensivos.
    
    • ¿Qué te motiva a participar en este hackathon? ¿Buscas principalmente ganar o es más importante para ti la experiencia? Háblame también sobre cómo te desenvuelves trabajando en equipo.

    PARA PREGUNTAS POSTERIORES:
    1. Formula 1-2 preguntas basadas en la información faltante
    2. Usa un tono amigable y motivador
    3. Evita preguntas sí/no
    4. Relaciona las preguntas con temas tecnológicos

    IMPORTANTE: Si es la primera pregunta, usa EXACTAMENTE el formato proporcionado arriba.
    Para preguntas posteriores, máximo 2 preguntas, mínimo 1.
    """;

    final questions = await _api.getCompletion(prompt);
    return questions.trim();
  }

  Future<Map<String, dynamic>> _analyzeResponse(String response) async {
    final userMessages = _messages
        .where((msg) => msg['isUser'] == true)
        .map((msg) => msg['text'])
        .join('\n');

    final prompt = """
    Como psicólogo experto y analista de perfiles tecnológicos, analiza el discurso del usuario y:
    1. Extrae información explícita mencionada
    2. Predice/infiere los campos faltantes basándote en patrones, estilo de comunicación y contexto

    RESPUESTA DEL USUARIO:
    $response

    IMPORTANTE:
    - Devuelve TODOS los campos, usando predicción para los no mencionados explícitamente
    - Usa el contexto y patrones para hacer predicciones realistas

    REQUERIDO (usa predicción si no hay información explícita):
    1. experiencia_tecnica: Experiencia en programación, descripción detallada
    2. lenguajes: Lista de lenguajes de programación
    3. creatividad: Valor 1-5
    4. productividad: Valor 1-5
    5. trabajo_equipo: Valor 1-5
    6. objetivo: "ganar" o "no ganar"
    7. personalidad: Lista de rasgos e intereses

    CONTEXTO COMPLETO:
    $userMessages

    Responde con JSON en formato <json> </json>
    Incluye TODOS los campos, usando predicción cuando sea necesario.
    """;

    final aiResponse = await _api.getCompletion(prompt);
    try {
      final jsonMatch = RegExp(r'<json>(.*?)</json>', dotAll: true)
          .firstMatch(aiResponse)
          ?.group(1);

      if (jsonMatch != null) {
        final Map<String, dynamic> data = json.decode(jsonMatch);
        // Normalizar valores numéricos
        ['creatividad', 'productividad', 'trabajo_equipo'].forEach((field) {
          if (data.containsKey(field)) {
            final value = int.tryParse(
                    '${data[field]}'.replaceAll(RegExp(r'[^\d]'), '')) ??
                3;
            data[field] = value.clamp(1, 5).toString();
          }
        });
        _userInfo.pendingFields
            .clear(); // Limpiar campos pendientes ya que predecimos todo
        return data;
      }

      final jsonInText = _extractJsonFromText(aiResponse);
      if (jsonInText != null) {
        print('JSON encontrado en el texto: $jsonInText');
        return json.decode(jsonInText);
      }

      print(
          'No se encontró JSON en la respuesta. Respuesta completa: $aiResponse');
      return {};
    } catch (e) {
      print('Error procesando JSON: $e');
      return {};
    }
  }

  Future<void> _saveUserDataToSupabase() async {
    try {
      final userId = supabase.auth.currentUser!.id;

      // Guardar directamente en users_info
      await supabase.from('users_info').upsert({
        'user_id': userId,
        'scores': _userInfo.data,
        'looking_for_team': false
      });

      print('✅ Datos guardados en Supabase exitosamente');
    } catch (e) {
      print('Error guardando datos en Supabase: $e');
      throw e;
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'text': message, 'isUser': true});
      _isLoading = true;
    });
    _messageController.clear();

    try {
      final analysis = await _analyzeResponse(message);
      print('Analizando respuesta: ${json.encode(analysis)}');
      analysis.forEach(_userInfo.updateField);

      if (_userInfo.isComplete()) {
        await _saveUserDataToSupabase();
        setState(() {
          _messages.add({
            'text':
                'Gracias por compartir tu información. ¡Te dirijo al menú principal!',
            'isUser': false
          });
        });
        Future.delayed(Duration(seconds: 2), () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MenuScreen()),
          );
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _userInfo = UserInfo();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final question = await _generateQuestion();
      setState(() {
        _messages.add({'text': question, 'isUser': false});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxBubbleWidth = screenWidth * 0.8;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RAIMON',
          style: TextStyle(
            color: Color(0xFF2A9D8F),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2A9D8F)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message['isUser']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxBubbleWidth),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: message['isUser']
                          ? const Color(0xFF2A9D8F)
                          : const Color(0xFF2A9D8F).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      message['text'],
                      style: TextStyle(
                        color:
                            message['isUser'] ? Colors.white : Colors.black87,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const LinearProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2A9D8F)),
              backgroundColor: Color(0xFFE8F5E9),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A9D8F).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: 'Escribe un mensaje...',
                            hintStyle: TextStyle(color: Colors.black54),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                          onChanged: (text) {
                            setState(() {
                              _wordCount = text
                                  .trim()
                                  .split(RegExp(r'\s+'))
                                  .where((word) => word.isNotEmpty)
                                  .length;
                            });
                          },
                        ),
                      ),
                      Container(
                        height: 3,
                        width: MediaQuery.of(context).size.width - 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getProgressColor(_wordCount),
                              _getProgressColor(_wordCount).withOpacity(0.3),
                            ],
                            stops: [
                              _wordCount < 150 ? _wordCount / 150 : 1.0,
                              1.0,
                            ],
                          ),
                        ),
                      ),
                      Text(
                        '$_wordCount palabras',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getProgressColor(_wordCount),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2A9D8F),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  int _clampValue(int value) {
    return value.clamp(1, 5);
  }

  String _buildPromptWithContext(String userMessage) {
    final lastMessages = _messages.length > 5
        ? _messages.sublist(_messages.length - 5)
        : _messages;

    String context = lastMessages.map((msg) {
      return "${msg['isUser'] ? 'Usuario' : 'Asistente'}: ${msg['text']}";
    }).join('\n');

    return """
    Ten en cuenta la información ya recopilada del usuario: ${json.encode(_userInfo.data)}
    
    Contexto de la conversación:
    $context
    
    Usuario: $userMessage
    
    Asistente:""";
  }

  Color _getProgressColor(int wordCount) {
    if (wordCount < 50) {
      // Interpolar entre rojo y amarillo
      double t = wordCount / 50.0;
      return Color.lerp(Colors.red, Colors.yellow, t) ?? Colors.red;
    } else if (wordCount < 150) {
      // Interpolar entre amarillo y verde
      double t = (wordCount - 50) / 100.0;
      return Color.lerp(Colors.yellow, Colors.green, t) ?? Colors.yellow;
    }
    return Colors.green;
  }
}
