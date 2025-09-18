import 'package:flame/components.dart';

import '../actors/water_enemy.dart';
import '../objects/ground_block.dart';
import '../objects/platform_block.dart';
import '../objects/star.dart';
import '../actors/prof_dora.dart';

class Block {
  // gridPosition position is always segment based X,Y.
  // 0,0 is the bottom left corner.
  // 10,10 is the upper right corner.
  final Vector2 gridPosition;
  final Type blockType;
  Block(this.gridPosition, this.blockType);
}

final segments = [
  segment0,
  segment1,
  segment2,
  segment3,
  segment4,
  segment5,
];

final segment0 = [
  // Introdução + primeiro "vale" (buraco). Buraco: X=6..7 (sem GroundBlock).
  Block(Vector2(0, 0), GroundBlock),
  Block(Vector2(1, 0), GroundBlock),
  Block(Vector2(2, 0), GroundBlock),
  Block(Vector2(3, 0), GroundBlock),
  Block(Vector2(4, 0), GroundBlock),
  Block(Vector2(5, 0), GroundBlock),
  // <-- buraco: não há GroundBlock em 6 e 7 (se o personagem cair aqui, perde)
  Block(Vector2(8, 0), GroundBlock),
  Block(Vector2(9, 0), GroundBlock),

  // NPC professor (perto do início)
  Block(Vector2(3, 2), TeacherDora),

  // Montanha pequena (degraus fáceis para crianças)
  Block(Vector2(3, 1), PlatformBlock),
  Block(Vector2(4, 2), PlatformBlock),
  Block(Vector2(4, 3), PlatformBlock),
  Block(Vector2(4, 4), PlatformBlock),

  // Estrelas poucas e espaçadas
  Block(Vector2(4, 1), Star),
  Block(Vector2(4, 9), Star),

  // Água no fundo do buraco (alerta visual + perigo)
];

final segment1 = [
  // Montanha mais longa em "rampa" suave (degrau por degrau, com plataformas)
  Block(Vector2(0, 0), GroundBlock),
  Block(Vector2(1, 0), GroundBlock),
  Block(Vector2(2, 0), GroundBlock),
  Block(Vector2(3, 0), GroundBlock),
  Block(Vector2(4, 0), GroundBlock),
  Block(Vector2(5, 0), GroundBlock),
  Block(Vector2(6, 0), GroundBlock),
  Block(Vector2(7, 0), GroundBlock),
  Block(Vector2(8, 0), GroundBlock),
  Block(Vector2(9, 0), GroundBlock),

  // Rampa (subida fácil): plataformas em Y crescente
  Block(Vector2(2, 1), PlatformBlock),
  Block(Vector2(3, 2), PlatformBlock),
  Block(Vector2(4, 3), PlatformBlock),
  Block(Vector2(5, 4), PlatformBlock), // topo da montanha

  // Estrelas espaçadas ao longo da subida (não adjacentes)
  Block(Vector2(2, 2), Star),
  Block(Vector2(4, 4), Star),

  // Inimigo discreto no final
  Block(Vector2(9, 1), WaterEnemy),
];

final segment2 = [
  // Plano com um pequeno "vale" no centro (buraco estreito)
  Block(Vector2(0, 0), GroundBlock),
  Block(Vector2(1, 0), GroundBlock),
  Block(Vector2(2, 0), GroundBlock),
  Block(Vector2(3, 0), GroundBlock),
  // Buraco em X=4 (sem GroundBlock) — cuidado!
  Block(Vector2(5, 0), GroundBlock),
  Block(Vector2(6, 0), GroundBlock),
  Block(Vector2(7, 0), GroundBlock),
  Block(Vector2(8, 0), GroundBlock),
  Block(Vector2(9, 0), GroundBlock),

  // Plataforma / pequeno pico ao lado do buraco (para saltar)
  Block(Vector2(3, 1), PlatformBlock),
  Block(Vector2(5, 1), PlatformBlock),

  // Estrelas reduzidas e espaçadas
  Block(Vector2(1, 1), Star),
  Block(Vector2(7, 2), Star),

  // Água no fundo do vale (sinal de perigo)
];

final segment3 = [
  // Grande montanha / coroa: subida e descida em degraus largos
  Block(Vector2(0, 0), GroundBlock),
  Block(Vector2(1, 0), GroundBlock),
  Block(Vector2(2, 0), GroundBlock),
  Block(Vector2(3, 0), GroundBlock),
  Block(Vector2(4, 0), GroundBlock),
  Block(Vector2(5, 0), GroundBlock),
  Block(Vector2(6, 0), GroundBlock),
  Block(Vector2(7, 0), GroundBlock),
  Block(Vector2(8, 0), GroundBlock),
  Block(Vector2(9, 0), GroundBlock),

  // Montanha em degraus — fácil de subir (espaços largos)
  Block(Vector2(3, 1), PlatformBlock),
  Block(Vector2(4, 2), PlatformBlock),
  Block(Vector2(5, 3), PlatformBlock), // pico
  Block(Vector2(6, 2), PlatformBlock),
  Block(Vector2(7, 1), PlatformBlock),

  // Estrela de recompensa no pico (mais alta)
  Block(Vector2(5, 4), Star),

  // Um inimigo no final do segmento (mantido)
  Block(Vector2(9, 1), WaterEnemy),
];

final segment4 = [
  // Zona de descanso — sem buracos, plataformas para brincar
  Block(Vector2(0, 0), GroundBlock),
  Block(Vector2(1, 0), GroundBlock),
  Block(Vector2(2, 0), GroundBlock),
  Block(Vector2(3, 0), GroundBlock),
  Block(Vector2(4, 0), GroundBlock),
  Block(Vector2(5, 0), GroundBlock),
  Block(Vector2(6, 0), GroundBlock),
  Block(Vector2(7, 0), GroundBlock),
  Block(Vector2(8, 0), GroundBlock),
  Block(Vector2(9, 0), GroundBlock),

  // Plataformas seguras e estrelas espaciais
  Block(Vector2(2, 2), PlatformBlock),
  Block(Vector2(5, 2), PlatformBlock),
  Block(Vector2(8, 2), PlatformBlock),

  Block(Vector2(1, 1), Star),
  Block(Vector2(6, 1), Star),
];

final segment5 = [
  // Final com corredor, um pequeno buraco à esquerda e montanha à direita
  Block(Vector2(0, 0), GroundBlock),
  Block(Vector2(1, 0), GroundBlock),
  // Buraco em X=2 (sem GroundBlock) — armadilha simples antes do corredor
  Block(Vector2(3, 0), GroundBlock),
  Block(Vector2(4, 0), GroundBlock),
  Block(Vector2(5, 0), GroundBlock),
  Block(Vector2(6, 0), GroundBlock),
  Block(Vector2(7, 0), GroundBlock),
  Block(Vector2(8, 0), GroundBlock),
  Block(Vector2(9, 0), GroundBlock),

  // Pequena montanha final (degrau)
  Block(Vector2(6, 1), PlatformBlock),
  Block(Vector2(7, 2), PlatformBlock),

  // Estrelas espaçadas como recompensa
  Block(Vector2(1, 1), Star),
  Block(Vector2(4, 2), Star),
  Block(Vector2(9, 4), Star),

  // Inimigo no fundo do buraco inicial e um inimigo extra no corredor
  Block(Vector2(9, 1), WaterEnemy),
];
