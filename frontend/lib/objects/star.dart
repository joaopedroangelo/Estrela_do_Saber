import 'package:EscreveAI/actors/ember.dart';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

import '../ember_quest.dart';

class Star extends SpriteComponent
    with HasGameReference<EmberQuestGame>, CollisionCallbacks {
  final Vector2 gridPosition;
  double xOffset;

  final Vector2 velocity = Vector2.zero();

  Star({
    required this.gridPosition,
    required this.xOffset,
  }) : super(size: Vector2.all(64), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    final starImage = game.images.fromCache('star.png');
    sprite = Sprite(starImage);
    position = Vector2(
      (gridPosition.x * size.x) + xOffset + (size.x / 2),
      game.size.y - (gridPosition.y * size.y) - (size.y / 2),
    );

    // Adicione um hitbox para detectar colisões
    add(RectangleHitbox(
      collisionType: CollisionType.passive,
      isSolid: true,
    ));

    add(
      SizeEffect.by(
        Vector2.all(-24),
        EffectController(
          duration: 0.75,
          reverseDuration: 0.5,
          infinite: true,
          curve: Curves.easeOut,
        ),
      ),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    // Verifique se colidiu com o jogador
    if (other is EmberPlayer) {
      // Notifique o jogo que uma estrela foi coletada
      game.onStarCollected();

      // Remova a estrela do jogo
      removeFromParent();
    }
  }

  @override
  void update(double dt) {
    velocity.x = game.objectSpeed;
    position += velocity * dt;
    if (position.x < -size.x || game.health <= 0) {
      removeFromParent();
    }
    super.update(dt);
  }
}
