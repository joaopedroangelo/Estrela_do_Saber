import json
from datetime import datetime, timedelta
from typing import Dict, List, Any
from collections import defaultdict
from sqlmodel import Session, select
from db.models import Response, Child
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage
import os
from dotenv import load_dotenv

load_dotenv()  # isso carrega o arquivo .env

class ReportGeneratorAgent:
    """Agente responsável por gerar relatórios de desempenho para responsáveis"""
    
    def __init__(self):
        # the newest OpenAI model is "gpt-5" which was released August 7, 2025.
        # do not change this unless explicitly requested by the user
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable is required")
        self.llm = ChatOpenAI(
            model="gpt-5",
            api_key=api_key
        )
    
    def generate_report(self, child_email: str, session: Session) -> Dict[str, Any]:
        """
        Gera relatório técnico de desempenho para os responsáveis
        
        Args:
            child_email: Email do responsável pela criança
            session: Sessão do banco de dados
            
        Returns:
            Dict com o relatório completo em JSON
        """
        
        print(f"📊 Gerando relatório para {child_email}...")
        
        # Buscar dados da criança
        child = session.exec(select(Child).where(Child.email_responsavel == child_email)).first()
        if not child:
            return {"error": "Criança não encontrada"}
        
        # Buscar todas as respostas da criança
        responses = session.exec(
            select(Response).where(Response.child_email == child_email)
        ).all()
        
        if not responses:
            return {
                "child_name": child.nome,
                "child_grade": child.ano,
                "total_responses": 0,
                "message": "Ainda não há atividades realizadas para gerar relatório."
            }
        
        # Calcular métricas básicas
        total_responses = len(responses)
        correct_responses = sum(1 for r in responses if r.correct)
        accuracy_percentage = round((correct_responses / total_responses) * 100, 1)
        
        # Análise temporal (últimas 2 semanas vs anteriores)
        now = datetime.utcnow()
        two_weeks_ago = now - timedelta(weeks=2)
        
        recent_responses = [r for r in responses if r.timestamp >= two_weeks_ago]
        older_responses = [r for r in responses if r.timestamp < two_weeks_ago]
        
        recent_accuracy = 0
        if recent_responses:
            recent_correct = sum(1 for r in recent_responses if r.correct)
            recent_accuracy = round((recent_correct / len(recent_responses)) * 100, 1)
        
        # Evolução por dia da semana
        daily_performance = defaultdict(lambda: {"total": 0, "correct": 0})
        for response in responses:
            day_name = response.timestamp.strftime("%A")
            daily_performance[day_name]["total"] += 1
            if response.correct:
                daily_performance[day_name]["correct"] += 1
        
        # Preparar dados para análise pedagógica com IA
        performance_data = {
            "child_name": child.nome,
            "grade": child.ano,
            "total_activities": total_responses,
            "correct_answers": correct_responses,
            "accuracy": accuracy_percentage,
            "recent_accuracy": recent_accuracy,
            "improvement_trend": recent_accuracy - (accuracy_percentage if len(older_responses) > 0 else recent_accuracy)
        }
        
        # Gerar insights pedagógicos usando IA
        pedagogical_insights = self._generate_pedagogical_insights(performance_data)
        
        # Construir relatório final
        report = {
            "generated_at": now.isoformat(),
            "child_info": {
                "name": child.nome,
                "grade": f"{child.ano}º ano",
                "email_responsavel": child_email
            },
            "performance_summary": {
                "total_activities": total_responses,
                "correct_answers": correct_responses,
                "incorrect_answers": total_responses - correct_responses,
                "accuracy_percentage": accuracy_percentage,
                "recent_accuracy": recent_accuracy
            },
            "temporal_analysis": {
                "total_recent_activities": len(recent_responses),
                "total_older_activities": len(older_responses),
                "performance_trend": "improvement" if recent_accuracy > accuracy_percentage else "stable" if recent_accuracy == accuracy_percentage else "needs_attention"
            },
            "daily_patterns": {
                day: {
                    "total": data["total"],
                    "accuracy": round((data["correct"] / data["total"]) * 100, 1) if data["total"] > 0 else 0
                }
                for day, data in daily_performance.items()
            },
            "pedagogical_insights": pedagogical_insights,
            "recommendations": self._generate_recommendations(performance_data)
        }
        
        # Simular envio de email
        self._simulate_email_send(child_email, report)
        
        print(f"✅ Relatório gerado para {child.nome}")
        print(f"📈 Performance: {accuracy_percentage}% de acerto em {total_responses} atividades")
        
        return report
    
    def _generate_pedagogical_insights(self, performance_data: Dict[str, Any]) -> str:
        """Gera insights pedagógicos usando IA"""
        
        system_prompt = """Você é um especialista em pedagogia e alfabetização infantil.
        Analise os dados de desempenho da criança e forneça insights técnicos para os pais/responsáveis.

        DIRETRIZES:
        1. Use linguagem técnica mas acessível para pais
        2. Foque em aspectos pedagógicos do desenvolvimento
        3. Seja construtivo e encorajador
        4. Mencione marcos esperados para a idade/série
        5. Limite a 3-4 parágrafos
        """
        
        human_prompt = f"""Analise os dados de desempenho:
        
        Criança: {performance_data['child_name']} - {performance_data['grade']}º ano
        Total de atividades: {performance_data['total_activities']}
        Acertos: {performance_data['correct_answers']}
        Taxa de acerto: {performance_data['accuracy']}%
        Performance recente: {performance_data['recent_accuracy']}%
        Tendência: {performance_data['improvement_trend']:+.1f} pontos percentuais
        
        Forneça insights pedagógicos para os responsáveis."""
        
        try:
            messages = [
                SystemMessage(content=system_prompt),
                HumanMessage(content=human_prompt)
            ]
            
            response = self.llm.invoke(messages)
            return str(response.content)
            
        except Exception as e:
            print(f"❌ Erro ao gerar insights: {e}")
            return f"Análise pedagógica: {performance_data['child_name']} demonstra {performance_data['accuracy']}% de acerto nas atividades, indicando desenvolvimento adequado para o {performance_data['grade']}º ano."
    
    def _generate_recommendations(self, performance_data: Dict[str, Any]) -> List[str]:
        """Gera recomendações baseadas na performance"""
        
        recommendations = []
        accuracy = performance_data['accuracy']
        grade = performance_data['grade']
        
        if accuracy >= 80:
            recommendations.extend([
                "Excelente desempenho! Continue estimulando com atividades diversificadas.",
                "Considere introduzir desafios um pouco mais avançados.",
                "Elogie o progresso e mantenha a motivação alta."
            ])
        elif accuracy >= 60:
            recommendations.extend([
                "Desempenho satisfatório. Continue praticando regularmente.",
                "Foque em reforçar conceitos com mais dificuldade.",
                "Considere sessões de estudo mais frequentes e curtas."
            ])
        else:
            recommendations.extend([
                "Recomenda-se atenção especial ao desenvolvimento da alfabetização.",
                "Considere atividades lúdicas complementares em casa.",
                "Pode ser útil conversar com o professor para alinhamento pedagógico."
            ])
        
        return recommendations
    
    def _simulate_email_send(self, email: str, report: Dict[str, Any]) -> None:
        """Simula envio de email (log no console conforme especificado)"""
        
        child_name = report["child_info"]["name"]
        accuracy = report["performance_summary"]["accuracy_percentage"]
        total = report["performance_summary"]["total_activities"]
        
        email_content = f"""
        Relatório de Progresso - {child_name}
        
        📊 Resumo de Performance:
        • Total de atividades: {total}
        • Taxa de acerto: {accuracy}%
        
        📈 Insights Pedagógicos:
        {report["pedagogical_insights"][:100]}...
        
        [Relatório completo disponível no aplicativo]
        """
        
        print(f"📧 Enviando relatório para {email} — conteúdo: {email_content.strip()}")