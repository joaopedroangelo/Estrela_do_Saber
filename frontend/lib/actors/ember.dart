import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/services.dart';

import '../ember_quest.dart';
import '../objects/ground_block.dart';
import '../objects/platform_block.dart';
import '../objects/star.dart';
import 'water_enemy.dart';

class EmberPlayer extends SpriteComponent
    with KeyboardHandler, CollisionCallbacks, HasGameReference<EmberQuestGame> {
  EmberPlayer({
    required super.position,
  }) : super(size: Vector2.all(64), anchor: Anchor.center);

  final Vector2 velocity = Vector2.zero();
  final Vector2 fromAbove = Vector2(0, -1);
  final double gravity = 30;
  final double jumpSpeed = 1000;
  final double fallMultiplier = 10; // aceleração extra na queda
  final double moveSpeed = 200;
  final double terminalVelocity = 150;
  int horizontalDirection = 0;

  bool hasJumped = false;
  bool isOnGround = false;
  bool hitByEnemy = false;

  @override
  Future<void> onLoad() async {
    sprite = await game.loadSprite('lapis.png'); // imagem estática do lápis

    add(
      CircleHitbox(),
    );
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    horizontalDirection = 0;
    horizontalDirection += (keysPressed.contains(LogicalKeyboardKey.keyA) ||
            keysPressed.contains(LogicalKeyboardKey.arrowLeft))
        ? -1
        : 0;
    horizontalDirection += (keysPressed.contains(LogicalKeyboardKey.keyD) ||
            keysPressed.contains(LogicalKeyboardKey.arrowRight))
        ? 1
        : 0;

    hasJumped = keysPressed.contains(LogicalKeyboardKey.space);
    return true;
  }

  @override
  void update(double dt) {
    velocity.x = horizontalDirection * moveSpeed;
    game.objectSpeed = 0;

    if (position.x - 36 <= 0 && horizontalDirection < 0) {
      velocity.x = 0;
    }

    if (position.x + 64 >= game.size.x / 2 && horizontalDirection > 0) {
      velocity.x = 0;
      game.objectSpeed = -moveSpeed;
    }

    // Aplica gravidade normal sempre
    velocity.y += gravity;

    // Aplica multiplicador de queda apenas durante a queda
    if (velocity.y > 0) {
      velocity.y += gravity * (fallMultiplier - 1);
    }

    // Controle do pulo (mantido original)
    if (hasJumped) {
      if (isOnGround) {
        velocity.y = -jumpSpeed;
        isOnGround = false;
      }
      hasJumped = false;
    }

    velocity.y = velocity.y.clamp(-jumpSpeed, terminalVelocity);
    position += velocity * dt;

    // Remove o acréscimo excessivo anterior
    // (o trecho abaixo foi removido pois já tratamos a queda acima)
    // if (velocity.y > 0) {
    //   velocity.y += 1000;
    // }

    // Restante do código mantido...
    if (position.y > game.size.y + size.y) {
      game.health = 0;
    }

    if (game.health <= 0) {
      removeFromParent();
    }

    if (horizontalDirection < 0 && scale.x > 0) {
      flipHorizontally();
    } else if (horizontalDirection > 0 && scale.x < 0) {
      flipHorizontally();
    }

    super.update(dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is GroundBlock || other is PlatformBlock) {
      if (intersectionPoints.length == 2) {
        final mid = (intersectionPoints.elementAt(0) +
                intersectionPoints.elementAt(1)) /
            2;

        final collisionNormal = absoluteCenter - mid;
        final separationDistance = (size.x / 2) - collisionNormal.length;
        collisionNormal.normalize();

        if (fromAbove.dot(collisionNormal) > 0.9) {
          isOnGround = true;
        }

        position += collisionNormal.scaled(separationDistance);
      }
    }

    if (other is Star) {
      other.removeFromParent();
      game.starsCollected++;
    }

    if (other is WaterEnemy) {
      hit();
    }
    super.onCollision(intersectionPoints, other);
  }

  void hit() {
    if (!hitByEnemy) {
      game.health--;
      hitByEnemy = true;
    }
    add(
      OpacityEffect.fadeOut(
        EffectController(
          alternate: true,
          duration: 0.1,
          repeatCount: 5,
        ),
      )..onComplete = () {
          hitByEnemy = false;
        },
    );
  }

  /// --- MÉTODO PARA JOYSTICK ---
  void move(Vector2 delta) {
    horizontalDirection = delta.x.sign.toInt();

    if (delta.y < -0.5 && isOnGround) {
      hasJumped = true;
    }
  }
}
