// lib/overlays/main_menu.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../ember_quest.dart';
import '../api/api.dart';

class MainMenu extends StatefulWidget {
  final EmberQuestGame game;

  const MainMenu({super.key, required this.game});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final AudioPlayer audioPlayer = AudioPlayer();

  String selectedGrade = '1º Ano';
  bool _loading = false;
  final ApiService _api = ApiService(baseUrl: 'http://192.168.1.8:5000');

  @override
  void initState() {
    super.initState();

    if (widget.game.playerName.isNotEmpty) {
      nameController.text = widget.game.playerName;
    }
    if (widget.game.parentEmail.isNotEmpty) {
      emailController.text = widget.game.parentEmail;
    }
    if (widget.game.playerGrade.isNotEmpty) {
      selectedGrade = widget.game.playerGrade;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    audioPlayer.dispose();
    _api.dispose();
    super.dispose();
  }

  int _gradeStringToInt(String gradeStr) {
    final reg = RegExp(r'^(\d+)');
    final m = reg.firstMatch(gradeStr);
    if (m == null) return 1;
    final v = int.tryParse(m.group(1)!) ?? 1;
    if (v < 1) return 1;
    if (v > 5) return 5;
    return v;
  }

  // ignore: unused_element
  Future<void> _playWelcomeAudio(String audioPath) async {
    final base = 'http://192.168.1.8:5000';
    String relativePath =
        audioPath.startsWith('audios/') ? audioPath.substring(7) : audioPath;
    final candidateUrls = [
      '$base/audio/$relativePath', // rota personalizada
      '$base/$audioPath', // rota estática
    ];

    Future<void> _playFromUrl(String url) async {
      try {
        // checar rapidamente se o recurso existe (HEAD preferível; se não suportar, fallback para GET)
        try {
          final headResp = await http
              .head(Uri.parse(url))
              .timeout(const Duration(seconds: 4));
          if (headResp.statusCode != 200) {
            throw Exception('HEAD retornou ${headResp.statusCode}');
          }
        } catch (e) {
          // tenta um GET curto (alguns servidores não respondem a HEAD)
          final getResp = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 6));
          if (getResp.statusCode != 200)
            throw Exception('GET curto retornou ${getResp.statusCode}');
        }

        // Escuta o estado do player para saber quando realmente começou a tocar
        final completer = Completer<void>();
        late StreamSubscription sub;
        sub = audioPlayer.onPlayerStateChanged.listen((state) {
          if (state == PlayerState.playing) {
            if (!completer.isCompleted) completer.complete();
          } else if (state == PlayerState.stopped ||
              state == PlayerState.completed) {
            if (!completer.isCompleted)
              completer.completeError(Exception('player parou antes de tocar'));
          }
        });

        // Inicia o play (não aplicamos timeout diretamente aqui)
        await audioPlayer.play(UrlSource(url));

        // aguardamos até entrar em playing, com timeout razoável
        await completer.future.timeout(const Duration(seconds: 10),
            onTimeout: () {
          throw TimeoutException(
              'Timeout aguardando PlayerState.playing para $url');
        });

        await sub.cancel();
        print('Áudio reproduzido via URL: $url');
      } catch (e) {
        rethrow; // deixa o chamador tratar / tentar fallback
      }
    }

    // Tenta as urls na ordem, depois tenta tocar a partir dos bytes (sem salvar) e por fim salva+toca no disco.
    for (final url in candidateUrls) {
      try {
        print('Tentando reproduzir áudio via URL: $url');
        await _playFromUrl(url);
        return;
      } catch (e) {
        print('Falha ao reproduzir via URL $url: $e');
        // tenta próxima URL
      }
    }

    // Fallback: tenta baixar os bytes e tocar diretamente (sem salvar em disco)
    try {
      final downloadUrl = '$base/$audioPath';
      print('Tentando fallback: download bytes de $downloadUrl');
      final resp = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        // tocar direto dos bytes (BytesSource)
        try {
          await audioPlayer.play(BytesSource(resp.bodyBytes));
          print('Áudio reproduzido diretamente dos bytes (sem salvar).');
          return;
        } catch (e) {
          print('Falha ao reproduzir BytesSource: $e');
        }

        // Se preferir salvar e tocar do arquivo (opcional)
        try {
          final directory = await getTemporaryDirectory();
          final assetsDir = Directory('${directory.path}/downloads_audio');
          await assetsDir.create(recursive: true);
          final fileName = audioPath.split('/').last;
          final file = File('${assetsDir.path}/$fileName');
          await file.writeAsBytes(resp.bodyBytes);
          if (await file.exists() && await file.length() > 0) {
            print('Arquivo salvo temporariamente em: ${file.path}');
            await audioPlayer.play(DeviceFileSource(file.path));
            print('Áudio reproduzido localmente: ${file.path}');
            return;
          } else {
            print('Falha ao salvar arquivo localmente (arquivo vazio).');
          }
        } catch (e) {
          print('Erro ao salvar e reproduzir localmente: $e');
        }
      } else {
        print('Resposta de download inválida: ${resp.statusCode}');
      }
    } catch (e) {
      print('Erro no fallback de download: $e');
    }

    print('Não foi possível reproduzir o áudio em nenhum método.');
  }

  Future<void> _onStartPressed(BuildContext context) async {
    final nome = nameController.text.trim();
    final email = emailController.text.trim();
    final gradeInt = _gradeStringToInt(selectedGrade);

    if (nome.isEmpty || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, preencha todos os campos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final res = await _api.registerChild(
        nome: nome,
        ano: gradeInt,
        emailResponsavel: email,
      );

      if (res['ok'] == true) {
        widget.game.savePlayerData(
          name: nome,
          grade: selectedGrade,
          parentEmail: email,
        );

        // 👉 Entrar direto no jogo (sem áudio)
        widget.game.overlays.remove('MainMenu');
        widget.game.resumeEngine();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registro realizado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final message =
            res['detail'] ?? res['error'] ?? 'Resposta inesperada do servidor';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no registro: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro na API: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro inesperado: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE1F5FE),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Littera',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                  fontFamily: 'ComicNeue',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 25),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '👶 Nome da Criança',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedGrade,
                decoration: InputDecoration(
                  labelText: '📚 Ano do Ensino Fundamental',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: [
                  '1º Ano',
                  '2º Ano',
                  '3º Ano',
                  '4º Ano',
                  '5º Ano',
                  '6º Ano',
                  '7º Ano',
                  '8º Ano',
                  '9º Ano',
                ].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      selectedGrade = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '📧 Email do Responsável',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _onStartPressed(context),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          '🎮 Começar Jogo',
                          style: TextStyle(fontSize: 18),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 35, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    shadowColor: Colors.greenAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
