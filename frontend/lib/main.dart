import 'package:EscreveAI/overlays/dora_overlay.dart';
import 'package:EscreveAI/overlays/question.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'ember_quest.dart';
import 'overlays/game_over.dart';
import 'overlays/main_menu.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: GameWidget<EmberQuestGame>.controlled(
        gameFactory: EmberQuestGame.new,
        overlayBuilderMap: {
          'MainMenu': (_, game) => MainMenu(game: game),
          'GameOver': (_, game) => GameOver(game: game),
          'QuestionOverlay': (_, game) => QuestionOverlay(game: game),
          'doraDialog': (context, game) {
            final emberQuestGame = game;
            return DoraDialogOverlay(
              game: emberQuestGame,
              message: "Oi! É bom te ver feliz!",
              onClose: () {
                emberQuestGame.overlays.remove('doraDialog');
                emberQuestGame.resumeEngine();
              },
            );
          },
        },
        initialActiveOverlays: const ['MainMenu'],
      ),
    ),
  );
}
