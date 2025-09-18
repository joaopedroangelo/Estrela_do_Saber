import 'package:EscreveAI/actors/ember.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame_audio/flame_audio.dart';
import 'dart:math';

import '../ember_quest.dart';

class TeacherDora extends SpriteComponent
    with HasGameReference<EmberQuestGame>, CollisionCallbacks {
  final Vector2 gridPosition;
  final double xOffset;
  final double moveDistance;

  // Variáveis para controlar a direção e movimento
  bool movingLeft = true;
  final double movementDuration = 0;
  late double initialX;
  late double leftBound;
  late double rightBound;

  // Variáveis para controlar o delay do diálogo
  bool canShowDialog = true;
  DateTime? lastDialogTime;

  // Lista de áudios de apresentação
  final List<String> presentationAudios = [
    'dora_voices/presentations/dora_apresentacao_1.mp3',
    'dora_voices/presentations/dora_apresentacao_2.mp3',
    'dora_voices/presentations/dora_apresentacao_3.mp3',
    'dora_voices/presentations/dora_apresentacao_4.mp3',
    'dora_voices/presentations/dora_apresentacao_5.mp3',
  ];

  TeacherDora({
    required this.gridPosition,
    required this.xOffset,
    this.moveDistance = 0,
  }) : super(size: Vector2.all(64), anchor: Anchor.bottomLeft);

  @override
  Future<void> onLoad() async {
    // Evita duplicatas: se já existir outra TeacherDora no game, remove esta
    final existing =
        game.children.whereType<TeacherDora>().where((d) => d != this);
    if (existing.isNotEmpty) {
      removeFromParent();
      return;
    }

    sprite = await game.loadSprite('prof.png');
    position = Vector2(
      (gridPosition.x * size.x) + xOffset,
      game.size.y - (gridPosition.y * size.y),
    );

    // Define os limites de movimento
    initialX = position.x;
    leftBound = initialX - moveDistance / 2;
    rightBound = initialX + moveDistance / 2;

    add(RectangleHitbox(
      collisionType: CollisionType.passive,
      size: Vector2(50, 50),
    ));
  }

  @override
  void onCollisionStart(
      Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollisionStart(intersectionPoints, other);

    // Verificar se colidiu com o jogador e se pode mostrar o diálogo
    if (other is EmberPlayer && canShowDialog) {
      // Tocar áudio de apresentação aleatório
      _playRandomPresentationAudio();

      // Mostrar o overlay da Dora
      game.overlays.add('doraDialog');
      game.pauseEngine();

      // Atualizar o tempo do último diálogo e desativar temporariamente
      lastDialogTime = DateTime.now();
      canShowDialog = false;

      // Temporariamente desativar a colisão para não bloquear o jogador
      final hitbox = children.whereType<RectangleHitbox>().first;
      hitbox.collisionType = CollisionType.inactive;

      // Reativar a colisão após um breve período
      Future.delayed(Duration(seconds: 2), () {
        if (isMounted) {
          hitbox.collisionType = CollisionType.passive;
        }
      });

      // Reativar a possibilidade de mostrar diálogo após 10 segundos
      Future.delayed(Duration(seconds: 10), () {
        if (isMounted) {
          canShowDialog = true;
        }
      });
    }
  }

  // Método para tocar um áudio de apresentação aleatório
  void _playRandomPresentationAudio() {
    final random = Random();
    int randomIndex = random.nextInt(presentationAudios.length);
    FlameAudio.play(presentationAudios[randomIndex]);
  }

  @override
  void update(double dt) {
    super.update(dt);

    // pequenas constantes para estabilidade
    const double epsilon = 1e-6;

    // 1. Acompanha o movimento do cenário ANTES de mover a Dora
    double scenarioShift = game.objectSpeed * dt;
    position.x += scenarioShift;
    leftBound += scenarioShift;
    rightBound += scenarioShift;

    // 2. Se moveDistance <= 0, não tenta oscilar entre limites (fica "parada" relativa ao cenário)
    if (moveDistance <= epsilon) {
      // apenas garante que não esteja fora dos limites (clamp entre bounds)
      position.x = position.x.clamp(leftBound, rightBound);
      // Remove se sair da tela ou se o jogo terminar
      if (position.x < -size.x || game.health <= 0) {
        removeFromParent();
      }
      return;
    }

    // 3. Move Dora dentro dos limites
    double moveSpeed = (moveDistance / movementDuration) * dt;

    if (moveSpeed > epsilon) {
      if (movingLeft) {
        position.x -= moveSpeed;
      } else {
        position.x += moveSpeed;
      }

      // Evita overshoot usando clamp e detecta se atingiu o bound
      final double clampedX = position.x.clamp(leftBound, rightBound);
      final bool reachedLeft = position.x <= leftBound + epsilon;
      final bool reachedRight = position.x >= rightBound - epsilon;

      position.x = clampedX;

      // Troca de direção — só se o movimento foi efetivo e realmente alcançou o bound
      if (movingLeft && reachedLeft) {
        movingLeft = false;
        flipHorizontally();
      } else if (!movingLeft && reachedRight) {
        movingLeft = true;
        flipHorizontally();
      }
    }

    // 4. Remove se sair da tela ou se o jogo terminar
    if (position.x < -size.x || game.health <= 0) {
      removeFromParent();
    }
  }
}
