import 'package:EscreveAI/actors/prof_dora.dart';
import 'package:EscreveAI/managers/player_data_manager.dart';
import 'package:EscreveAI/managers/questions_manager.dart';
import 'package:EscreveAI/overlays/dora_overlay.dart';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/parallax.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';

import 'actors/ember.dart';
import 'actors/water_enemy.dart';
import 'managers/segment_manager.dart';
import 'objects/ground_block.dart';
import 'objects/platform_block.dart';
import 'objects/star.dart';
import 'overlays/hud.dart';

class EmberQuestGame extends FlameGame
    with HasCollisionDetection, HasKeyboardHandlerComponents {
  EmberQuestGame();

  // Mantemos os campos do jogo para não quebrar outros arquivos
  late EmberPlayer _ember;
  DateTime? lastDoraDialogTime;
  double lastBlockXPosition = 0.0;
  UniqueKey? lastBlockKey;
  double objectSpeed = 0.0;

  int starsCollected = 0;
  int health = 3;
  double cloudSpeed = 0.0;
  String playerName = '';
  String playerGrade = '';
  String parentEmail = '';

  // Gerenciamento de perguntas
  late QuestionsManager questionsManager;
  bool isQuestionActive = false;

  // Joystick
  late JoystickComponent joystick;

  @override
  Future<void> onLoad() async {
    await images.loadAll([
      'block.png',
      'lapis.png',
      'ember.png',
      'borracha.png',
      'ground.png',
      'heart_half.png',
      'heart.png',
      'star.png',
      'water_enemy.png',
      'prof.png',
      'background05.png'
    ]);

    await FlameAudio.audioCache.loadAll([
      'dora_voices/presentations/dora_apresentacao_1.mp3',
      'dora_voices/presentations/dora_apresentacao_2.mp3',
      'dora_voices/presentations/dora_apresentacao_3.mp3',
      'dora_voices/presentations/dora_apresentacao_4.mp3',
      'dora_voices/presentations/dora_apresentacao_5.mp3',
    ]);
    camera.viewfinder.anchor = Anchor.topLeft;
    // 🔹 Adiciona Parallax de fundo
    final parallax = await loadParallaxComponent(
      [
        ParallaxImageData('background05.png'),
      ],
      baseVelocity: Vector2(10, 0), // velocidade horizontal
      velocityMultiplierDelta: Vector2(1.8, 1.0),
    );
    add(parallax);

    // Inicializa QuestionsManager (passando referência do game)
    questionsManager = QuestionsManager(this);
    await questionsManager.loadQuestions();

    await _loadPlayerData();

    // Inicializa joystick (posicionamento básico)
    joystick = JoystickComponent(
      knob: CircleComponent(
          radius: 20, paint: Paint()..color = Colors.blueAccent),
      background: CircleComponent(
          radius: 50, paint: Paint()..color = Colors.blue.withOpacity(0.5)),
      margin: EdgeInsets.only(right: 60, bottom: canvasSize.y / 2 - 60),
    );
    add(joystick);

    overlays.addEntry('doraDialog', (context, game) {
      return DoraDialogOverlay(
        game: this,
        message: 'Olá, eu sou a professora Dora!',
        onClose: () {
          overlays.remove('doraDialog');
          resumeEngine();
        },
      );
    });

    initializeGame(loadHud: true);
  }

  @override
  void update(double dt) {
    if (health <= 0 && !overlays.isActive('GameOver')) {
      overlays.add('GameOver');
    }

    // Atualiza movimento do EmberPlayer usando joystick
    _ember.move(joystick.relativeDelta);

    super.update(dt);
  }

  @override
  Color backgroundColor() => const Color.fromARGB(255, 173, 223, 247);

  void loadGameSegments(int segmentIndex, double xPositionOffset) {
    for (final block in segments[segmentIndex]) {
      final component = switch (block.blockType) {
        const (GroundBlock) => GroundBlock(
            gridPosition: block.gridPosition, xOffset: xPositionOffset),
        const (PlatformBlock) => PlatformBlock(
            gridPosition: block.gridPosition, xOffset: xPositionOffset),
        const (Star) =>
          Star(gridPosition: block.gridPosition, xOffset: xPositionOffset),
        const (WaterEnemy) => WaterEnemy(
            gridPosition: block.gridPosition, xOffset: xPositionOffset),
        const (TeacherDora) => TeacherDora(
            gridPosition: block.gridPosition, xOffset: xPositionOffset),
        _ => throw UnimplementedError(),
      };
      world.add(component);
    }
  }

  void initializeGame({required bool loadHud}) {
    final segmentsToLoad = (size.x / 640).ceil();
    for (var i = 0; i <= segmentsToLoad; i++) {
      loadGameSegments(i, (640 * i).toDouble());
    }

    _ember = EmberPlayer(position: Vector2(128, canvasSize.y - 128));
    world.add(_ember);
    if (loadHud) camera.viewport.add(Hud());
  }

  void reset() {
    starsCollected = 0;
    health = 3;
    isQuestionActive = false;
    questionsManager.resetQuestions();
    initializeGame(loadHud: false);
  }

  /// Chamado por Star quando coletada
  void onStarCollected() {
    starsCollected++;
    questionsManager.maybeAskQuestion();
  }

  /// Aplica somente o efeito da resposta (pontua/penaliza) — sem fechar overlay.
  void applyAnswerResult(String selectedAnswer, bool isCorrect) {
    if (isCorrect) {
      starsCollected += 2;
    } else {
      health--;
    }
  }

  bool get canShowDoraDialog {
    if (lastDoraDialogTime == null) return true;
    return DateTime.now().difference(lastDoraDialogTime!).inMinutes >= 1;
  }

  /// Compatibilidade: retorna a questão atual (caso algum código a use)
  Map<String, dynamic>? getCurrentQuestion() =>
      questionsManager.currentQuestion;

  Future<void> _loadPlayerData() async {
    try {
      final playerData = await PlayerPreferences.getPlayerData();
      playerName = playerData['name'];
      playerGrade = playerData['grade'];
      parentEmail = playerData['parentEmail'];
    } catch (e) {
      print('Erro ao carregar dados do jogador: $e');
    }
  }

  Future<void> savePlayerData({
    required String name,
    required String grade,
    required String parentEmail,
  }) async {
    try {
      final initials = _getInitials(name);

      await PlayerPreferences.savePlayerData(
        name: name,
        grade: grade,
        parentEmail: parentEmail,
        initials: initials,
      );

      // Atualiza os dados locais
      this.playerName = name;
      this.playerGrade = grade;
      this.parentEmail = parentEmail;
    } catch (e) {
      print('Erro ao salvar dados do jogador: $e');
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '🙂';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    } else {
      final a = parts.first.substring(0, 1);
      final b = parts.last.substring(0, 1);
      return (a + b).toUpperCase();
    }
  }
}
