import 'package:flutter/material.dart';
import 'package:EscreveAI/ember_quest.dart';

class QuestionOverlay extends StatefulWidget {
  final EmberQuestGame game;

  const QuestionOverlay({
    super.key,
    required this.game,
  });

  @override
  State<QuestionOverlay> createState() => _QuestionOverlayState();
}

class _QuestionOverlayState extends State<QuestionOverlay>
    with SingleTickerProviderStateMixin {
  String? selectedOption;
  bool? isCorrect;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Configuração da animação
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    // Toca o áudio automaticamente quando a overlay é aberta
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.game.questionsManager.playCurrentQuestionAudio();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _onOptionPressed(String option) async {
    // Verifica se está correta
    final correct = widget.game.questionsManager.checkAnswer(option);

    // Atualiza estado local para mostrar feedback visual
    setState(() {
      selectedOption = option;
      isCorrect = correct;
    });

    // Aplica o efeito no jogo (pontuação/vida)
    widget.game.applyAnswerResult(option, correct);

    // Para o áudio da pergunta
    widget.game.questionsManager.stopAudio();

    // Toca o áudio de feedback apropriado
    if (correct) {
      await widget.game.questionsManager.playCorrectFeedback();
    } else {
      await widget.game.questionsManager.playErrorFeedback();
    }

    // Espera 2 segundos para mostrar o feedback visual
    await Future.delayed(const Duration(seconds: 2));

    // Limpa a questão e fecha a overlay
    widget.game.questionsManager.clearCurrentQuestion();
    widget.game.overlays.remove('QuestionOverlay');

    // Retoma o jogo
    widget.game.resumeEngine();

    // Reset do estado interno da overlay
    if (mounted) {
      setState(() {
        selectedOption = null;
        isCorrect = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQuestion = widget.game.questionsManager.currentQuestion;

    if (currentQuestion == null) {
      return Container();
    }

    return Material(
      color: Colors.black.withOpacity(0.7),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 500,
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabeçalho
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade700,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🎯',
                        style: TextStyle(
                          fontSize: 28,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          widget.game.questionsManager
                              .playCurrentQuestionAudio();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text(
                            '🔊',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Pergunta
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    currentQuestion['question'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Opções
                ...currentQuestion['options'].asMap().entries.map((entry) {
                  final option = entry.value;
                  final correctAnswer = currentQuestion['answer'];

                  Color backgroundColor = Colors.white;
                  Color borderColor = Colors.blue.shade200;
                  String emoji = '';

                  // Define cores e emojis com base na seleção
                  if (selectedOption != null) {
                    if (option == selectedOption) {
                      if (isCorrect == true) {
                        backgroundColor = Colors.green.shade50;
                        borderColor = Colors.green;
                        emoji = '✅';
                      } else {
                        backgroundColor = Colors.red.shade50;
                        borderColor = Colors.red;
                        emoji = '❌';
                      }
                    } else if (option == correctAnswer) {
                      backgroundColor = Colors.green.shade50;
                      borderColor = Colors.green;
                      emoji = '✅';
                    }
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: backgroundColor,
                          foregroundColor: Colors.blue.shade800,
                          minimumSize: const Size(double.infinity, 70),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: borderColor,
                              width: 2.0,
                            ),
                          ),
                          elevation: 2,
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                        ),
                        onPressed: selectedOption == null
                            ? () => _onOptionPressed(option)
                            : null,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (emoji.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                option,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                // Feedback de resultado com emojis
                if (selectedOption != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      isCorrect == true
                          ? "🎉 Parabéns!"
                          : "😢 Tente novamente!",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isCorrect == true ? Colors.green : Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
