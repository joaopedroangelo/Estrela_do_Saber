from typing import Dict, Any, TypedDict
from sqlmodel import Session, select
from db.models import get_session, Response, Question, create_db_and_tables
from .question_agent import QuestionGeneratorAgent
from .report_agent import ReportGeneratorAgent
# Ajuste: importe a classe correta do seu tts_agent
from .tts_agent import ChildFeedbackAgent
from datetime import datetime
import logging
from dotenv import load_dotenv
import os
import base64
from pathlib import Path

# Configurar logging para os agentes
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

load_dotenv()  # isso carrega o arquivo .env

class AgentState(TypedDict):
    """Estado compartilhado entre os agentes"""
    child_email: str
    ano: int
    question_data: Dict[str, Any]
    question_id: int
    user_response: str
    evaluation_result: Dict[str, Any]
    feedback_text: str
    audio_data: Dict[str, str]
    saved: bool
    response_id: int  # Adicionar campo para ID da resposta

class MultiAgentOrchestrator:
    """Orquestrador simplificado para coordenar fluxos multi-agente"""
    
    def __init__(self):
        logger.info("🤖 Inicializando sistema multi-agente...")
        self.question_agent = QuestionGeneratorAgent()
        self.report_agent = ReportGeneratorAgent()
        # Instancia o agente TTS baseado na implementação que você mostrou
        self.tts_agent = ChildFeedbackAgent()
        
        # Inicializar banco de dados
        create_db_and_tables()
        logger.info("✅ Sistema multi-agente pronto!")
    
    # Métodos públicos para uso pela API
    def process_new_question(self, ano: int, child_email: str) -> Dict[str, Any]:
        logger.info(f"🚀 Iniciando fluxo multi-agente para nova questão (ano: {ano})")
        state: AgentState = {
            "child_email": child_email,
            "ano": ano,
            "question_data": {},
            "question_id": 0,
            "user_response": "",
            "evaluation_result": {},
            "feedback_text": "",
            "audio_data": {},
            "saved": False,
            "response_id": 0
        }
        state = self._generate_question_node(state)
        state = self._persist_question_node(state)
        state = self._format_question_output_node(state)
        logger.info("✅ Fluxo de questão concluído")
        return state["question_data"]
    
    def process_answer(self, question_id: int, user_answer: str, child_email: str, ano: int) -> Dict[str, Any]:
        logger.info(f"🚀 Iniciando fluxo multi-agente para resposta (ID: {question_id})")
        state: AgentState = {
            "child_email": child_email,
            "ano": ano,
            "question_data": {},
            "question_id": question_id,
            "user_response": user_answer,
            "evaluation_result": {},
            "feedback_text": "",
            "audio_data": {},
            "saved": False,
            "response_id": 0
        }
        state = self._fetch_question_node(state)
        state = self._evaluate_answer_node(state)
        state = self._save_response_node(state)
        state = self._generate_feedback_node(state)
        state = self._generate_audio_node(state)
        state = self._finalize_response_node(state)
        logger.info("✅ Fluxo de resposta concluído")
        return {
            "correta": state["evaluation_result"]["correct"],
            "feedback": state["feedback_text"],
            "audio": state["audio_data"].get("base64", ""),
            "saved": state["saved"]
        }
    
    def generate_report(self, child_email: str) -> Dict[str, Any]:
        logger.info(f"📊 Gerando relatório via agente especializado")
        with next(get_session()) as session:
            return self.report_agent.generate_report(child_email, session)
    
    # ================== NÓS DO FLUXO MULTI-AGENTE ==================
    
    def _generate_question_node(self, state: AgentState) -> AgentState:
        logger.info(f"🎯 Fluxo: Gerando questão para ano {state['ano']}")
        question_data = self.question_agent.generate_question(state["ano"])
        state["question_data"] = question_data
        return state
    
    def _persist_question_node(self, state: AgentState) -> AgentState:
        logger.info("💾 Fluxo: Persistindo questão no banco")
        question_data = state["question_data"]
        with next(get_session()) as session:
            db_question = Question(
                question=question_data["question"],
                options=question_data["options"],
                answer=question_data["answer"],
                ano_ideal=state["ano"]
            )
            session.add(db_question)
            session.commit()
            session.refresh(db_question)
            state["question_data"]["id"] = db_question.id
            state["question_id"] = db_question.id
        return state
    
    def _format_question_output_node(self, state: AgentState) -> AgentState:
        logger.info("📝 Fluxo: Formatando saída da questão")
        return state
    
    def _fetch_question_node(self, state: AgentState) -> AgentState:
        logger.info(f"🔍 Fluxo: Buscando questão ID {state['question_id']}")
        with next(get_session()) as session:
            question = session.get(Question, state["question_id"])
            if question:
                state["question_data"] = {
                    "id": question.id,
                    "question": question.question,
                    "options": question.options,
                    "answer": question.answer
                }
            else:
                logger.warning(f"Questão {state['question_id']} não encontrada, usando fallback")
                state["question_data"] = {
                    "id": state["question_id"],
                    "answer": "A"
                }
        return state
    
    def _evaluate_answer_node(self, state: AgentState) -> AgentState:
        logger.info(f"✅ Fluxo: Avaliando resposta {state['user_response']}")
        question_data = state["question_data"]
        user_answer = state["user_response"]
        is_correct = user_answer == question_data.get("answer")
        state["evaluation_result"] = {
            "correct": is_correct,
            "expected": question_data.get("answer"),
            "selected": user_answer
        }
        return state
    
    def _save_response_node(self, state: AgentState) -> AgentState:
        logger.info("💾 Fluxo: Salvando resposta no banco")
        with next(get_session()) as session:
            response_record = Response(
                question_id=state["question_id"],
                child_email=state["child_email"],
                selected=state["evaluation_result"]["selected"],
                correct=state["evaluation_result"]["correct"],
                timestamp=datetime.utcnow(),
                feedback_text="",  # Será preenchido no próximo nó
            )
            session.add(response_record)
            session.commit()
            session.refresh(response_record)
            state["saved"] = True
            state["response_id"] = response_record.id
        return state
    
    def _generate_feedback_node(self, state: AgentState) -> AgentState:
        logger.info("💬 Fluxo: Gerando feedback personalizado")
        is_correct = state["evaluation_result"]["correct"]
        ano = state["ano"]
        if is_correct:
            if ano <= 2:
                feedback = "Parabéns! Você acertou! Que inteligente você é!"
            elif ano <= 3:
                feedback = "Excelente trabalho! Sua resposta está certinha! Continue assim!"
            else:
                feedback = "Fantástico! Você demonstrou muito conhecimento! Parabéns!"
        else:
            expected = state["evaluation_result"]["expected"]
            if ano <= 2:
                feedback = f"Quase lá! A resposta correta é '{expected}'. Você vai conseguir na próxima!"
            elif ano <= 3:
                feedback = f"Boa tentativa! A resposta certa é '{expected}'. Vamos continuar aprendendo!"
            else:
                feedback = f"Não foi dessa vez! A resposta correta é '{expected}'. Cada erro nos ajuda a aprender mais!"
        state["feedback_text"] = feedback
        return state
    
    def _generate_audio_node(self, state: AgentState) -> AgentState:
        logger.info("🎵 Fluxo: Gerando áudio do feedback")
        feedback_text = state["feedback_text"]
        # Garantir pasta audios
        audios_dir = Path("audios")
        audios_dir.mkdir(parents=True, exist_ok=True)
        # Nome do arquivo baseado no response_id (ou timestamp se não existir)
        response_id = state.get("response_id") or int(datetime.utcnow().timestamp())
        audio_filename = f"feedback_{response_id}.mp3"
        audio_path = str(audios_dir / audio_filename)
        
        # Usar o agente TTS para gerar o arquivo de áudio
        try:
            # Chamada direta ao método de geração de áudio do seu agente
            # Observação: _generate_audio é "privado" no seu agente; dá para expor um método público se preferir
            self.tts_agent._generate_audio(feedback_text, audio_path)
        except Exception as e:
            logger.exception("Erro ao gerar áudio via TTSAgent: %s", e)
            state["audio_data"] = {"path": "", "base64": ""}
            return state
        
        # Ler o arquivo e codificar em base64 para retorno/armazenamento
        try:
            with open(audio_path, "rb") as f:
                audio_bytes = f.read()
            audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")
        except Exception as e:
            logger.exception("Erro ao ler/encodar arquivo de áudio: %s", e)
            audio_b64 = ""
        
        state["audio_data"] = {
            "path": audio_path,
            "base64": audio_b64
        }
        
        # Atualizar registro no banco com dados do áudio e feedback_text
        with next(get_session()) as session:
            response_record = session.get(Response, state["response_id"])
            if response_record:
                response_record.feedback_text = feedback_text
                response_record.audio_path = audio_path
                response_record.audio_base64 = audio_b64
                session.commit()
        
        return state
    
    def _finalize_response_node(self, state: AgentState) -> AgentState:
        logger.info("🏁 Fluxo: Finalizando processamento")
        return state
