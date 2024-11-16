import 'package:flutter/material.dart';

class IntroductionScreen extends StatefulWidget {
  const IntroductionScreen({super.key});

  @override
  State<IntroductionScreen> createState() => _IntroductionScreenState();
}

class _IntroductionScreenState extends State<IntroductionScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.group,
      'title': '¡Bienvenido a la experiencia Raimon!',
      'description': 'Nuestra IA te ayudará a encontrar el grupo perfecto para ti. 🚀',
      'hashtag': '#EncuentraTuEquipo'
    },
    {
      'icon': Icons.chat_bubble_outline,
      'title': 'Conversación Inteligente',
      'description': 'Charla con nuestra IA para que podamos conocerte mejor. 💭',
      'hashtag': '#IAConversacional'
    },
    {
      'icon': Icons.people_outline,
      'title': 'Encuentra tu Equipo',
      'description': 'Te conectaremos con personas que comparten tus intereses y objetivos. 🤝',
      'hashtag': '#EquipoPerfecto'
    },
    {
      'icon': Icons.handshake_outlined,
      'title': 'Política de Privacidad',
      'description': 'Al utilizar esta aplicación, aceptas nuestra política de privacidad. Tus datos están seguros con nosotros. 🔒',
      'hashtag': '#Privacidad'
    },
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth > 600 ? 400.0 : screenWidth * 0.85;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return Center(
                      child: SingleChildScrollView(
                        child: Container(
                          width: buttonWidth,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _pages[index]['icon'],
                                size: 100,
                                color: const Color(0xFF2A9D8F),
                              ),
                              const SizedBox(height: 40),
                              Text(
                                _pages[index]['title'],
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 18,
                                    color: Colors.black87,
                                    height: 1.4,
                                  ),
                                  children: [
                                    TextSpan(text: _pages[index]['description']),
                                    const TextSpan(text: '\n\n'),
                                    TextSpan(
                                      text: _pages[index]['hashtag'],
                                      style: const TextStyle(
                                        color: Color(0xFF2A9D8F),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? const Color(0xFF2A9D8F)
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: buttonWidth,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_currentPage == _pages.length - 1) {
                            Navigator.pushNamed(context, '/chat');
                          } else {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A9D8F),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'Comenzar' : 'Siguiente',
                          style: const TextStyle(
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
            ],
          ),
        ),
      ),
    );
  }
}