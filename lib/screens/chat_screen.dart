import 'package:flutter/material.dart';
import '../services/straico_api.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<MessageBubble> _messages = [];
  final StraicoApi _api = StraicoApi();
  bool _isLoading = false;
  String? firstName;
  String? lastName;
  
  final String initialPrompt = "Hola! Soy Raimon, tu asistente personal. Me gustaría conocerte mejor. ¿Cómo te llamas?";

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _messages.add(MessageBubble(
          content: initialPrompt,
          isUser: false,
        ));
      });
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text;
    setState(() {
      _messages.add(MessageBubble(
        content: userMessage,
        isUser: true,
      ));
      _isLoading = true;
    });
    _messageController.clear();

    try {
      String prompt = """
      Eres Raimon, un asistente conversacional experto. Tu misión es obtener el nombre y apellidos del usuario de forma estratégica.

      OBJETIVO PRINCIPAL:
      Obtener nombre y apellidos del usuario siguiendo una estrategia conversacional en 3 pasos:

      PASO 1 - Si no tienes el nombre:
      - Haz preguntas que naturalmente lleven a que el usuario mencione su nombre
      - Ejemplos: "¿Cómo te gusta que te llamen?", "¿Te han puesto algún apodo?"
      - Si detectas un nombre en la respuesta, confírmalo

      PASO 2 - Si tienes el nombre pero no el apellido:
      - Usa el nombre para personalizar y pregunta por la familia
      - Ejemplos: "[nombre], ¿vienes de una familia grande?", "¿Tu apellido tiene alguna historia?"

      PASO 3 - Confirmación:
      - Cuando tengas ambos datos, confírmalos naturalmente
      - Ejemplo: "Entonces eres [nombre] [apellido], ¿verdad?"

      REGLAS IMPORTANTES:
      1. NO AVANCES al siguiente paso hasta confirmar el dato actual
      2. Si el usuario evade, INSISTE de forma amable pero firme
      3. Usa estos marcadores exactos:
         - [NOMBRE:valor] cuando confirmes un nombre
         - [APELLIDO:valor] cuando confirmes un apellido
         - [COMPLETO] cuando tengas ambos confirmados

      ESTADO ACTUAL:
      - Nombre: ${firstName ?? 'pendiente'}
      - Apellido: ${lastName ?? 'pendiente'}

      CONTEXTO PREVIO:
      ${_messages.map((m) => "${m.isUser ? 'Usuario' : 'Raimon'}: ${m.content}").join('\n')}

      NUEVO MENSAJE: $userMessage
      """;

      final response = await _api.getCompletion(prompt);
      
      if (mounted) {
        _processResponseData(response);
        
        String cleanResponse = response
            .replaceAll(RegExp(r'\[NOMBRE:.*?\]'), '')
            .replaceAll(RegExp(r'\[APELLIDO:.*?\]'), '')
            .replaceAll('[COMPLETO]', '')
            .trim();

        setState(() {
          _messages.add(MessageBubble(
            content: cleanResponse,
            isUser: false,
          ));
        });

        if (firstName != null && lastName != null && response.contains('[COMPLETO]')) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/results',
                arguments: <String, String>{  // Especificamos el tipo explícitamente
                  'firstName': firstName ?? '',
                  'lastName': lastName ?? '',
                },
              );
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar mensaje')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _processResponseData(String response) {
    // Extraer nombre
    final nombreMatch = RegExp(r'\[NOMBRE:(.*?)\]').firstMatch(response);
    if (nombreMatch != null && nombreMatch.group(1) != null) {
      firstName = nombreMatch.group(1)!.trim();
    }

    // Extraer apellido
    final apellidoMatch = RegExp(r'\[APELLIDO:(.*?)\]').firstMatch(response);
    if (apellidoMatch != null && apellidoMatch.group(1) != null) {
      lastName = apellidoMatch.group(1)!.trim();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat con Raimon AI'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: _messages,
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blue,
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
}

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isUser;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isUser ? Colors.blue : Colors.grey[300],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
