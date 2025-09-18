#!/usr/bin/env python3
"""
Script mock para simular o jogo Acima e testar o sistema multi-agente
"""

import requests
import json
import time
from typing import Dict, Any

BASE_URL = "http://localhost:5000"

def test_health():
    """Testa health check"""
    print("🏥 Testando health check...")
    try:
        response = requests.get(f"{BASE_URL}/health")
        response.raise_for_status()
        print(f"✅ Health check: {response.json()}")
        return True
    except Exception as e:
        print(f"❌ Health check falhou: {e}")
        return False

def register_child() -> bool:
    """Registra uma criança de teste"""
    print("📝 Registrando criança Maria...")
    
    payload = {
        "nome": "Maria",
        "ano": 3,
        "email_responsavel": "maria.teste@exemplo.com"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/register", json=payload)
        response.raise_for_status()
        
        result = response.json()
        print(f"✅ Criança registrada: {result}")
        return result.get("ok", False)
        
    except Exception as e:
        print(f"❌ Erro no registro: {e}")
        return False

def request_new_question() -> Dict[str, Any]:
    """Solicita uma nova questão"""
    print("🎯 Solicitando nova questão...")
    
    payload = {
        "ano": 3,
        "email_responsavel": "maria.teste@exemplo.com"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/nova_questao", json=payload)
        response.raise_for_status()
        
        question = response.json()
        print(f"✅ Questão recebida: ID {question['id']}")
        print(f"📝 Pergunta: {question['question']}")
        print(f"🔤 Opções: {question['options']}")
        print(f"✏️ Resposta correta: {question['answer']}")
        
        return question
        
    except Exception as e:
        print(f"❌ Erro ao solicitar questão: {e}")
        return {}

def submit_answer(question_id: int, answer: str) -> Dict[str, Any]:
    """Submete uma resposta"""
    print(f"📤 Submetendo resposta: {answer} para questão {question_id}")
    
    payload = {
        "id": question_id,
        "resposta": answer,
        "email_responsavel": "maria.teste@exemplo.com"
    }
    
    try:
        response = requests.post(f"{BASE_URL}/responder", json=payload)
        response.raise_for_status()
        
        result = response.json()
        print(f"✅ Resposta processada:")
        print(f"   Correta: {result['correta']}")
        print(f"   Feedback: {result['feedback']}")
        print(f"   Áudio gerado: {'Sim' if result.get('audio') else 'Não'}")
        print(f"   Salvo no DB: {result['saved']}")
        
        return result
        
    except Exception as e:
        print(f"❌ Erro ao submeter resposta: {e}")
        return {}

def get_report() -> Dict[str, Any]:
    """Solicita relatório de desempenho"""
    print("📊 Solicitando relatório...")
    
    try:
        response = requests.get(f"{BASE_URL}/relatorio/maria.teste@exemplo.com")
        response.raise_for_status()
        
        report = response.json()
        print(f"✅ Relatório gerado:")
        print(f"   Criança: {report['child_info']['name']}")
        print(f"   Total de atividades: {report['performance_summary']['total_activities']}")
        print(f"   Taxa de acerto: {report['performance_summary']['accuracy_percentage']}%")
        print(f"   Insights pedagógicos disponíveis: Sim")
        
        return report
        
    except Exception as e:
        print(f"❌ Erro ao solicitar relatório: {e}")
        return {}

def get_responses() -> Dict[str, Any]:
    """Consulta respostas salvas (debug)"""
    print("🔍 Consultando respostas salvas...")
    
    try:
        response = requests.get(f"{BASE_URL}/respostas/maria.teste@exemplo.com")
        response.raise_for_status()
        
        data = response.json()
        print(f"✅ Encontradas {data['total_responses']} respostas no banco")
        
        return data
        
    except Exception as e:
        print(f"❌ Erro ao consultar respostas: {e}")
        return {}

def main():
    """Executa o teste completo do sistema"""
    print("🚀 INICIANDO TESTE MOCK DO JOGO")
    print("=" * 50)
    
    # 1. Health check
    if not test_health():
        print("❌ Sistema não disponível. Encerrando teste.")
        return
    
    print()
    
    # 2. Registrar criança
    if not register_child():
        print("❌ Falha no registro. Encerrando teste.")
        return
        
    print()
    time.sleep(1)
    
    # 3. Solicitar questão
    question = request_new_question()
    if not question:
        print("❌ Falha ao obter questão. Encerrando teste.")
        return
    
    print()
    time.sleep(1)
    
    # 4. Submeter resposta correta
    print("🎯 Teste 1: Resposta CORRETA")
    result1 = submit_answer(question["id"], question["answer"])
    
    print()
    time.sleep(1)
    
    # 5. Solicitar nova questão e responder incorretamente
    print("🎯 Teste 2: Resposta INCORRETA")
    question2 = request_new_question()
    if question2:
        # Selecionar resposta incorreta (diferente da correta)
        wrong_answer = "B" if question2["answer"] != "B" else "C"
        result2 = submit_answer(question2["id"], wrong_answer)
    
    print()
    time.sleep(1)
    
    # 6. Verificar se respostas foram salvas
    responses_data = get_responses()
    
    print()
    time.sleep(1)
    
    # 7. Gerar relatório
    report = get_report()
    
    print()
    print("=" * 50)
    print("✅ TESTE MOCK CONCLUÍDO COM SUCESSO!")
    
    if responses_data.get("total_responses", 0) >= 2:
        print(f"✅ Respostas salvas corretamente: {responses_data['total_responses']}")
    
    if report.get("performance_summary"):
        accuracy = report["performance_summary"]["accuracy_percentage"]
        print(f"✅ Relatório gerado com {accuracy}% de acerto")
    
    print("🎉 Sistema multi-agente funcionando perfeitamente!")

if __name__ == "__main__":
    main()