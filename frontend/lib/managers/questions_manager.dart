import 'dart:convert';
import 'dart:math';
import 'package:EscreveAI/ember_quest.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// Gerencia carregamento, seleção, áudio e verificação das questões.
class QuestionsManager {
  final EmberQuestGame game;

  QuestionsManager(this.game);

  final AudioPlayer _audioPlayer = AudioPlayer();
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic>? _currentQuestion;
  String? _currentAudioPath;

  // Listas de áudios de feedback
  final List<String> _correctFeedbackAudios = [
    'audio/dora_voices/feedbacks_correct/dora_acerto_3.mp3',
    'audio/dora_voices/feedbacks_correct/dora_acerto_4.mp3',
    'audio/dora_voices/feedbacks_correct/dora_acerto_5.mp3',
    'audio/dora_voices/feedbacks_correct/dora_acerto_6.mp3',
    'audio/dora_voices/feedbacks_correct/dora_acerto_7.mp3',
    'audio/dora_voices/feedbacks_correct/dora_acerto_8.mp3',
    'audio/dora_voices/feedbacks_correct/dora_acerto_9.mp3',
    'audio/dora_voices/feedbacks_correct/dora_acerto_10.mp3',
  ];

  final List<String> _errorFeedbackAudios = [
    'audio/dora_voices/feedbacks_error/dora_erro_1.mp3',
    'audio/dora_voices/feedbacks_error/dora_erro_2.mp3',
    'audio/dora_voices/feedbacks_error/dora_erro_3.mp3',
    'audio/dora_voices/feedbacks_error/dora_erro_6.mp3',
    'audio/dora_voices/feedbacks_error/dora_erro_7.mp3',
    'audio/dora_voices/feedbacks_error/dora_erro_8.mp3',
    'audio/dora_voices/feedbacks_error/dora_erro_9.mp3',
    'audio/dora_voices/feedbacks_error/dora_erro_10.mp3',
  ];

  bool get hasQuestions => _questions.isNotEmpty;
  Map<String, dynamic>? get currentQuestion => _currentQuestion;

  /// Carrega as questões do JSON (com fallback)
  Future<void> loadQuestions() async {
    try {
      final jsonString =
          await rootBundle.loadString('assets/questions/questions.json');
      final List<dynamic> jsonList = json.decode(jsonString);

      _questions = jsonList
          .where((q) => q['disponivel'] == true)
          .toList()
          .cast<Map<String, dynamic>>();

      _questions.sort((a, b) => a['id'].compareTo(b['id']));
      print('${_questions.length} questões carregadas do JSON');
    } catch (e) {
      print('Erro ao carregar questões: $e');
      _questions = [
        {
          "id": 1,
          "disponivel": true,
          "question": "Teste",
          "options": ["A", "B", "C", "D"],
          "answer": "A"
        },
        {
          "id": 2,
          "disponivel": true,
          "question": "Qual é a cor do céu em um dia claro?",
          "options": ["Azul", "Verde", "Amarelo", "Vermelho"],
          "answer": "Azul"
        },
      ];
    }
  }

  /// Reset do estado interno (usado por game.reset())
  void resetQuestions() {
    _currentQuestion = null;
    _currentAudioPath = null;
  }

  /// Seleciona questão aleatória e prepara áudio (interno)
  Map<String, dynamic>? _selectRandomQuestion() {
    if (_questions.isEmpty) return null;
    final random = Random();
    _currentQuestion = _questions[random.nextInt(_questions.length)];

    final questionId = _currentQuestion!['id'];
    final formattedId = questionId.toString().padLeft(2, '0');
    _currentAudioPath = 'voices/questions_voices/$formattedId.mp3';

    return _currentQuestion;
  }

  /// Deve ser chamado quando o jogo decide tentar perguntar (ex: coleta de estrela)
  void maybeAskQuestion() {
    if (game.isQuestionActive || _questions.isEmpty) return;

    final q = _selectRandomQuestion();
    if (q == null) return;

    game.isQuestionActive = true;
    game.pauseEngine();
    game.overlays.add('QuestionOverlay');
    playCurrentQuestionAudio();
  }

  Future<void> playCurrentQuestionAudio() async {
    if (_currentAudioPath == null) return;
    try {
      await _audioPlayer.play(AssetSource(_currentAudioPath!));
    } catch (e) {
      print('Erro ao reproduzir áudio: $e');
    }
  }

  Future<void> stopAudio() async {
    try {
      await _audioPlayer.stop();
    } catch (e) {
      // ignore
    }
  }

  /// Apenas checa se a resposta bate com a resposta correta.
  bool checkAnswer(String selectedAnswer) {
    if (_currentQuestion == null) return false;
    return selectedAnswer == _currentQuestion!['answer'];
  }

  /// Toca áudio de feedback para resposta correta
  Future<void> playCorrectFeedback() async {
    final random = Random();
    final audioIndex = random.nextInt(_correctFeedbackAudios.length);
    try {
      await _audioPlayer.play(AssetSource(_correctFeedbackAudios[audioIndex]));
    } catch (e) {
      print('Erro ao reproduzir áudio de acerto: $e');
    }
  }

  /// Toca áudio de feedback para resposta errada
  Future<void> playErrorFeedback() async {
    final random = Random();
    final audioIndex = random.nextInt(_errorFeedbackAudios.length);
    try {
      await _audioPlayer.play(AssetSource(_errorFeedbackAudios[audioIndex]));
    } catch (e) {
      print('Erro ao reproduzir áudio de erro: $e');
    }
  }

  /// Limpa a questão atual e marca game.isQuestionActive = false
  void clearCurrentQuestion() {
    _currentQuestion = null;
    _currentAudioPath = null;
    game.isQuestionActive = false;
  }
}
