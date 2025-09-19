// flutter_api_service.dart
// Serviço HTTP para consumir a API FastAPI do Sistema Multi-Agente

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => 'ApiException(${statusCode ?? "?"}): $message';
}

class ApiService {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  ApiService({required this.baseUrl, http.Client? client, Duration? timeout})
      : _client = client ?? http.Client(),
        timeout = timeout ?? const Duration(seconds: 10);

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  void dispose() {
    _client.close();
  }

  // Helpers
  Future<dynamic> _post(String path, Map<String, dynamic> body) async {
    final uri = _uri(path);
    final resp = await _client
        .post(uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(timeout);

    return _handleResponse(resp);
  }

  Future<dynamic> _get(String path) async {
    final uri = _uri(path);
    final resp = await _client.get(uri).timeout(timeout);
    return _handleResponse(resp);
  }

  dynamic _handleResponse(http.Response resp) {
    final status = resp.statusCode;
    if (status >= 200 && status < 300) {
      if (resp.body.isEmpty) return null;
      try {
        return jsonDecode(resp.body);
      } catch (e) {
        // resposta não JSON
        return resp.body;
      }
    }

    // tentar decodificar corpo com erro
    String message = resp.body;
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['detail'] != null) {
        message = body['detail'].toString();
      } else if (body is Map && body['error'] != null) {
        message = body['error'].toString();
      } else {
        message = resp.body.toString();
      }
    } catch (e) {
      // manter body raw
      message = resp.body;
    }

    throw ApiException(message, statusCode: status);
  }

  // ENDPOINTS

  /// Registra ou atualiza criança
  /// Retorna o JSON do FastAPI (map)
  Future<Map<String, dynamic>> registerChild({
    required String nome,
    required int ano,
    required String emailResponsavel,
  }) async {
    final body = {
      'nome': nome,
      'ano': ano,
      'email_responsavel': emailResponsavel,
    };

    final res = await _post('/register', body);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Solicita uma nova questão
  Future<Map<String, dynamic>> newQuestion({
    required int ano,
    required String emailResponsavel,
  }) async {
    final body = {'ano': ano, 'email_responsavel': emailResponsavel};
    final res = await _post('/nova_questao', body);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Envia resposta para avaliação
  Future<Map<String, dynamic>> answerQuestion({
    required int id,
    required String resposta,
    required String emailResponsavel,
  }) async {
    final body = {
      'id': id,
      'resposta': resposta,
      'email_responsavel': emailResponsavel
    };
    final res = await _post('/responder', body);
    return Map<String, dynamic>.from(res as Map);
  }

  /// Pega relatório técnico de desempenho
  Future<Map<String, dynamic>> getReport(String email) async {
    final res = await _get('/relatorio/$email');
    return Map<String, dynamic>.from(res as Map);
  }

  /// Consulta respostas salvas
  Future<ResponsesResponse> getResponses(String email) async {
    final res = await _get('/respostas/$email');
    return ResponsesResponse.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Health check
  Future<Map<String, dynamic>> healthCheck() async {
    final res = await _get('/health');
    return Map<String, dynamic>.from(res as Map);
  }

  /// Listar todas as crianças
  Future<List<Map<String, dynamic>>> getAllChildren() async {
    final res = await _get('/criancas');
    final map = Map<String, dynamic>.from(res as Map);
    final list = List.from(map['children'] ?? []);
    return list.cast<Map<String, dynamic>>();
  }

  /// Listar todas as questões
  Future<List<Map<String, dynamic>>> getAllQuestions() async {
    final res = await _get('/questoes');
    final map = Map<String, dynamic>.from(res as Map);
    final list = List.from(map['questions'] ?? []);
    return list.cast<Map<String, dynamic>>();
  }
}

// MODELS SIMPLES
class ResponseItem {
  final int id;
  final int questionId;
  final String selected;
  final bool correct;
  final DateTime timestamp;
  final String feedbackText;
  final String audioPath;

  ResponseItem({
    required this.id,
    required this.questionId,
    required this.selected,
    required this.correct,
    required this.timestamp,
    required this.feedbackText,
    required this.audioPath,
  });

  factory ResponseItem.fromJson(Map<String, dynamic> json) => ResponseItem(
        id: json['id'],
        questionId: json['question_id'],
        selected: json['selected'],
        correct: json['correct'],
        timestamp: DateTime.parse(json['timestamp']),
        feedbackText: json['feedback_text'] ?? '',
        audioPath: json['audio_path'] ?? '',
      );
}

class ResponsesResponse {
  final String email;
  final int totalResponses;
  final List<ResponseItem> responses;

  ResponsesResponse({
    required this.email,
    required this.totalResponses,
    required this.responses,
  });

  factory ResponsesResponse.fromJson(Map<String, dynamic> json) {
    final respList = (json['responses'] as List? ?? [])
        .map((e) => ResponseItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ResponsesResponse(
      email: json['email'] ?? '',
      totalResponses: json['total_responses'] ?? respList.length,
      responses: respList,
    );
  }
}

// USAGE RÁPIDO (não duplicado no código):
// - Crie ApiService(baseUrl: 'http://10.0.2.2:5000') para emulador Android
// - Para iOS simulator use 'http://127.0.0.1:5000' ou para device real use IP da máquina
// - Exemplo de chamadas: registerChild(...), newQuestion(...), answerQuestion(...), getResponses(...)

// PUBSPEC (adicione):
// dependencies:
//   http: ^0.13.6
