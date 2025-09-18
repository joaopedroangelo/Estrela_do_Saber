import 'package:flutter/material.dart';
import '../ember_quest.dart';

// ---------------------------
// Overlay Widget (Flutter) - Design Infantil
// ---------------------------
class DoraDialogOverlay extends StatelessWidget {
  final EmberQuestGame game;
  final String message;
  final VoidCallback onClose;

  const DoraDialogOverlay({
    Key? key,
    required this.game,
    required this.message,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Backdrop semitransparente
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),
        ),

        // Conteúdo centralizado com design infantil
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFFF0F9FF), // Azul claro muito suave
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Color(0xFFB3E5FC),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue[100]!.withOpacity(0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho com foto da professora Dora
                  Row(
                    children: [
                      // Foto da professora Dora
                      CircleAvatar(
                        backgroundImage: AssetImage('assets/images/prof.png'),
                        radius: 22,
                        backgroundColor: Colors.yellow[100],
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Professora Dora', // Emoji de professora
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 15),

                  // Mensagem com emojis
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(0xFFB3E5FC),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💬 ', // Emoji de balão de fala
                          style: TextStyle(fontSize: 16),
                        ),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1976D2),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 15),

                  // Botão com emoji
                  Align(
                    alignment: Alignment.center,
                    child: ElevatedButton.icon(
                      onPressed: onClose,
                      icon: Text('🎮'), // Emoji de controle de jogo
                      label: Text(
                        'Vamos jogar!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CAF50), // Verde amigável
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        elevation: 5,
                        shadowColor: Colors.green[200],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
