import 'package:flutter/material.dart';
import '../services/straico_api.dart';
import 'dart:convert';

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
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final StraicoApi _api = StraicoApi();
  bool _isLoading = false;
  late final UserInfo _userInfo;

  String? _extractJsonFromText(String text) {
    // Buscar contenido entre llaves, manejando anidación básica
    final regExp = RegExp(r'\{(?:[^{}]|\{[^{}]*\})*\}');
    final match = regExp.firstMatch(text);
    return match?.group(0);
  }

  Future<String> _generateQuestion() async {
    if (_userInfo.pendingFields.isEmpty) return '';

    final prompt = """
    Actúa como un psicólogo experto con experiencia en perfiles tecnológicos.
    
    CONTEXTO ACTUAL:
    - Campos pendientes: ${_userInfo.pendingFields.join(', ')}
    - Información obtenida: ${json.encode(_userInfo.data)}

    TÉCNICAS DE ENTREVISTA PSICOLÓGICA A UTILIZAR:
    1. Preguntas abiertas reflexivas
    2. Técnica del embudo (de lo general a lo específico)
    3. Escucha activa y seguimiento
    4. Exploración de patrones de comportamiento

    GUÍA DE PROFUNDIZACIÓN PSICOLÓGICA:
    - Para experiencia_tecnica/lenguajes: Explora la conexión emocional con la tecnología
    - Para creatividad/productividad: Analiza patrones de resolución de problemas
    - Para trabajo_equipo: Investiga dinámicas sociales y roles preferidos
    - Para objetivo/personalidad: Examina motivaciones profundas y valores

    INSTRUCCIONES ESPECIALES:
    1. Formula entre 2 y 4 preguntas interrelacionadas que:
       - Sean abiertas y reflexivas
       - Generen introspección
       - Eviten respuestas simples sí/no
       - Inviten a compartir experiencias personales
    2. Las preguntas deben seguir un orden lógico y estar conectadas temáticamente
    3. Formato de respuesta:
       • Primera pregunta
       • Segunda pregunta
       [etc.]

    IMPORTANTE: Máximo 4 preguntas, mínimo 2.
    Las preguntas deben estar relacionadas entre sí y fluir naturalmente.
    
    Responde SOLO con las preguntas en formato de lista con viñetas (•).
    """;

    final questions = await _api.getCompletion(prompt);

    // Dar formato al texto para que se vea mejor en el chat
    return questions.trim().replaceAll('•', '\n•');
  }

  Future<Map<String, dynamic>> _analyzeResponse(String response) async {
    final userMessages = _messages
        .where((msg) => msg['isUser'] == true)
        .map((msg) => msg['text'])
        .join('\n');

    final prompt = """
    Como psicólogo experto, analiza profundamente el discurso del usuario.
    
    CONTEXTO COMPLETO:
    $userMessages

    ÚLTIMA RESPUESTA:
    $response

    CAMPOS PENDIENTES: ${_userInfo.pendingFields.join(', ')}

    ANÁLISIS REQUERIDO:
    1. Interpretación profunda del lenguaje utilizado
    2. Patrones de comportamiento implícitos
    3. Indicadores de personalidad y estilo de trabajo
    4. Motivaciones subyacentes

    Si algún campo queda sin información clara, no lo rellenes, no lo añadas en el json:
    - experiencia_tecnica: "Desarrollador con interés en crecimiento profesional"
    - lenguajes: ["separados", "por", "comas"] (si no hay pregunta explicitamente)
    - creatividad: "3"
    - productividad: "3"
    - trabajo_equipo: "3"
    - objetivo: "SOLO PUEDE SER no ganar o ganar, una de las dos palabras"
    - personalidad: ["adaptable", "analítico", "curioso"]

    Responde con JSON en formato <json> </json>
    """;

    final aiResponse = await _api.getCompletion(prompt);
    try {
      // Intentar extraer JSON de la respuesta
      final jsonMatch = RegExp(r'<json>(.*?)</json>', dotAll: true)
          .firstMatch(aiResponse)
          ?.group(1);

      if (jsonMatch != null) {
        print('JSON extraído de la respuesta: $jsonMatch');
        return json.decode(jsonMatch);
      }

      // Si no hay tags, buscar cualquier JSON en el texto
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

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() {
      _messages.add({'text': message, 'isUser': true});
      _isLoading = true;
    });
    _messageController.clear();

    try {
      if (!_userInfo.isComplete()) {
        final analysis = await _analyzeResponse(message);
        print('Analizando respuesta: ${json.encode(analysis)}');
        analysis.forEach(_userInfo.updateField);

        if (_userInfo.isComplete()) {
          print(
              '✅ Información completa del usuario: ${json.encode(_userInfo.data)}');
          setState(() {
            _messages.add({
              'text': 'Gracias por toda la información proporcionada.',
              'isUser': false
            });
          });
        } else {
          final nextQuestion = await _generateQuestion();
          setState(() {
            _messages.add({
              'text':
                  'Para conocerte mejor, me gustaría que respondas a lo siguiente:\n\n$nextQuestion',
              'isUser': false
            });
          });
        }
      } else {
        // Normal chat flow when all info is collected
        final promptWithContext = _buildPromptWithContext(message);
        final response = await _api.getCompletion(promptWithContext);
        setState(() {
          _messages.add({'text': response, 'isUser': false});
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar mensaje')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message['isUser']
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: message['isUser'] ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      message['text'],
                      style: TextStyle(
                        color: message['isUser'] ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
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
}
