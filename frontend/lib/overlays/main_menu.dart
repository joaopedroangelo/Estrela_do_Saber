import 'package:flutter/material.dart';
import '../ember_quest.dart';

// ignore: must_be_immutable
class MainMenu extends StatelessWidget {
  final EmberQuestGame game;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  String selectedGrade = '1º Ano';

  MainMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    // Preenche os campos se já existirem dados
    if (game.playerName.isNotEmpty) {
      nameController.text = game.playerName;
    }
    if (game.parentEmail.isNotEmpty) {
      emailController.text = game.parentEmail;
    }
    if (game.playerGrade.isNotEmpty) {
      selectedGrade = game.playerGrade;
    }

    return Scaffold(
      backgroundColor: Color(0xFFE1F5FE), // Azul claro mais suave
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
                offset: Offset(0, 8),
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
                  fontFamily: 'ComicNeue', // Fonte mais infantil
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 25),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: '👶 Nome da Criança',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: selectedGrade,
                decoration: InputDecoration(
                  labelText: '📚 Ano do Ensino Fundamental',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    selectedGrade = newValue;
                  }
                },
              ),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: '📧 Email do Responsável',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 25),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      emailController.text.isNotEmpty) {
                    game.savePlayerData(
                      name: nameController.text,
                      grade: selectedGrade,
                      parentEmail: emailController.text,
                    );
                    game.overlays.remove('MainMenu');
                    game.resumeEngine();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Por favor, preencha todos os campos'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                },
                child: Text(
                  '🎮 Começar Jogo',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 35, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 5,
                  shadowColor: Colors.greenAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
