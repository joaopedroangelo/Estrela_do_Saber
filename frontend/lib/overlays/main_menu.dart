// lib/overlays/main_menu.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

import '../ember_quest.dart';
import '../api/api.dart';

class MainMenu extends StatefulWidget {
  final EmberQuestGame game;

  const MainMenu({super.key, required this.game});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  // campos do usuário
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  // audio
  final AudioPlayer _audioPlayer = AudioPlayer();

  // URLs pré-definidas
  final List<String> _predefinedUrls = [
    'http://192.168.48.41:5000',
    'http://192.168.1.8:5000',
    'http://192.168.166.89:5000'
  ];

  // estado para baseUrl (usado para montar URIs)
  late String _selectedBaseUrl;
  // valor exibido no Dropdown (pode ser uma das URLs pré ou 'Outro')
  late String _dropdownValue;
  // controller para edição manual da baseUrl
  final TextEditingController _baseUrlController = TextEditingController();

  // ApiService (re-criado quando a baseUrl muda)
  late ApiService _api;

  // demais estados
  String selectedGrade = '1º Ano';
  bool _loading = false;

  @override
  void initState() {
    super.initState();

    // popula campos a partir do game (se já existir)
    if (widget.game.playerName.isNotEmpty) {
      nameController.text = widget.game.playerName;
    }
    if (widget.game.parentEmail.isNotEmpty) {
      emailController.text = widget.game.parentEmail;
    }
    if (widget.game.playerGrade.isNotEmpty) {
      selectedGrade = widget.game.playerGrade;
    }

    // inicializa baseUrl com a primeira pré-definida ou com o valor salvo no game (se você tiver)
    _selectedBaseUrl = _predefinedUrls[0];
    _baseUrlController.text = _selectedBaseUrl;

    // define o valor do dropdown conforme a URL inicial
    _dropdownValue =
        _predefinedUrls.contains(_selectedBaseUrl) ? _selectedBaseUrl : 'Outro';

    // cria o ApiService com a base inicial
    _api = ApiService(baseUrl: _selectedBaseUrl);
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    _baseUrlController.dispose();

    // tenta dispensar o serviço de API e o player de áudio
    try {
      _api.dispose();
    } catch (_) {}
    try {
      _audioPlayer.dispose();
    } catch (_) {}

    super.dispose();
  }

  int _gradeStringToInt(String gradeStr) {
    final reg = RegExp(r'^(\d+)');
    final m = reg.firstMatch(gradeStr);
    final v = int.tryParse(m?.group(1) ?? '1') ?? 1;
    return v.clamp(1, 9);
  }

  /// Atualiza a base URL: recria o ApiService e ajusta estados
  void _updateApiBaseUrl(String url) {
    final sanitized = url.trim();
    if (sanitized.isEmpty) return;

    setState(() {
      _selectedBaseUrl = sanitized;
      _baseUrlController.text = sanitized;
      _dropdownValue =
          _predefinedUrls.contains(sanitized) ? sanitized : 'Outro';

      // recria o ApiService com a nova base (dispose do antigo)
      try {
        _api.dispose();
      } catch (_) {}
      _api = ApiService(baseUrl: sanitized);
    });
  }

  // Baixa o áudio remoto e toca com AudioPlayer (bytes)
  Future<void> _playRemoteAudio(String childName) async {
    try {
      final uri = Uri.parse(
          '$_selectedBaseUrl/audio/welcomes/${Uri.encodeComponent(childName)}.mp3');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
      } else {
        debugPrint('Não foi possível obter áudio: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Erro ao tocar áudio de boas-vindas: $e');
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

    bool registered = false;

    try {
      final res = await _api.registerChild(
        nome: nome,
        ano: gradeInt,
        emailResponsavel: email,
      );

      if (res['ok'] == true) {
        registered = true;
        widget.game.savePlayerData(
          name: nome,
          grade: selectedGrade,
          parentEmail: email,
        );
      }
    } catch (e) {
      debugPrint('Erro ao registrar usuário: $e');
    }

    // Toca o áudio de boas-vindas do servidor (usa _selectedBaseUrl)
    await _playRemoteAudio(nome);

    // Entrar no jogo independentemente do registro
    widget.game.overlays.remove('MainMenu');
    widget.game.resumeEngine();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(registered
              ? 'Registro realizado com sucesso!'
              : 'Usuário não cadastrado'),
          backgroundColor: registered ? Colors.green : Colors.orange,
        ),
      );

      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // lista de itens do dropdown (mostra as pré-definidas + opção 'Outro')
    final dropdownItems = [
      ..._predefinedUrls,
      'Outro',
    ];

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
              const SizedBox(height: 20),

              // Dropdown para escolher servidor API
              DropdownButtonFormField<String>(
                value: _dropdownValue,
                decoration: InputDecoration(
                  labelText: '🌐 Servidor API',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                items: dropdownItems
                    .map((value) =>
                        DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (newValue) {
                  if (newValue == null) return;
                  if (newValue == 'Outro') {
                    // define o dropdown como 'Outro' e mantém a URL manual atual no controller
                    setState(() => _dropdownValue = 'Outro');
                    // se o campo manual estiver vazio, coloca a primeira pré-definida como ponto de partida
                    if (_baseUrlController.text.trim().isEmpty) {
                      _baseUrlController.text = _predefinedUrls[0];
                      _updateApiBaseUrl(_baseUrlController.text.trim());
                    } else {
                      _updateApiBaseUrl(_baseUrlController.text.trim());
                    }
                  } else {
                    // selecionou uma URL pré-definida
                    _updateApiBaseUrl(newValue);
                  }
                },
              ),
              const SizedBox(height: 12),

              // Campo para editar/colocar a base URL manualmente
              TextField(
                controller: _baseUrlController,
                onChanged: (val) {
                  // atualiza API conforme o usuário digita (com debounce simples opcional)
                  _updateApiBaseUrl(val);
                },
                decoration: InputDecoration(
                  labelText: '🔧 Base URL manual',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 18),

              const SizedBox(height: 7),
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
                    .map((value) =>
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
