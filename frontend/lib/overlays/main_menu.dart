// lib/overlays/main_menu.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
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
    if (widget.game.playerName.isNotEmpty)
      nameController.text = widget.game.playerName;
    if (widget.game.parentEmail.isNotEmpty)
      emailController.text = widget.game.parentEmail;
    if (widget.game.playerGrade.isNotEmpty)
      selectedGrade = widget.game.playerGrade;
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
    final v = int.tryParse(m?.group(1) ?? '1') ?? 1;
    return v.clamp(1, 5);
  }

  /// Baixa o áudio do servidor apenas se não existir no cache temporário
  Future<File> _getAudioFile(String url, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    if (!await file.exists()) {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('Falha ao baixar áudio');
      await file.writeAsBytes(response.bodyBytes);
    }
    return file;
  }

  /// Toca o áudio em paralelo (não bloqueia a UI)
  Future<void> _playWelcomeAudio(String url, String fileName) async {
    try {
      final file = await _getAudioFile(url, fileName);
      await audioPlayer.stop();
      await audioPlayer.play(DeviceFileSource(file.path));
      audioPlayer.onPlayerStateChanged.listen((state) {
        print('🎵 Estado do player: $state');
      });
    } catch (e) {
      print("❌ Erro ao tocar áudio: $e");
    }
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

        // Toca o áudio em paralelo, sem esperar terminar
        unawaited(_playWelcomeAudio(
          'http://192.168.1.8:5000/audio/welcomes/maria_silva.mp3',
          'welcome.mp3',
        ));

        // Entrar no jogo imediatamente
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
                ]
                    .map<DropdownMenuItem<String>>((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (newValue) {
                  if (newValue != null)
                    setState(() => selectedGrade = newValue);
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
                      : const Text('🎮 Começar Jogo',
                          style: TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 35, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
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
