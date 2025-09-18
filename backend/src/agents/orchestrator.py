from typing import Dict, Any, TypedDict
from sqlmodel import Session, select
from db.models import get_session, Response, Question, Child, create_db_and_tables
from .question_agent import QuestionGeneratorAgent
from .report_agent import ReportGeneratorAgent
from .tts_agent import ChildFeedbackAgent
from datetime import datetime
import logging
from dotenv import load_dotenv
import os
import base64
from pathlib import Path
from contextlib import contextmanager

# Configurar logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

load_dotenv()

class AgentState(TypedDict):
    child_email: str
    ano: int
    question_data: Dict[str, Any]
    question_id: int
    user_response: str
    evaluation_result: Dict[str, Any]
    feedback_text: str
    audio_data: Dict[str, str]
    saved: bool
    response_id: int
    child_name: str

@contextmanager
def get_db_session():
    """Context manager para sessões do banco"""
    session = next(get_session())
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

class MultiAgentOrchestrator:
    def __init__(self):
        logger.info("🤖 Inicializando sistema multi-agente...")
        self.question_agent = QuestionGeneratorAgent()
        self.report_agent = ReportGeneratorAgent()
        self.tts_agent = ChildFeedbackAgent()
        
        create_db_and_tables()
        logger.info("✅ Sistema multi-agente pronto!")

    def _get_child_info(self, session: Session, child_email: str) -> Dict[str, Any]:
        """Obtém informações da criança do banco"""
        child = session.exec(
            select(Child).where(Child.email_responsavel == child_email)
        ).first()
        if not child:
            raise ValueError(f"Criança com email {child_email} não encontrada")
        return {"nome": child.nome, "ano": child.ano}

    def _initialize_state(self, child_email: str, ano: int = None) -> AgentState:
        """Inicializa o estado com informações da criança"""
        with get_db_session() as session:
            child_info = self._get_child_info(session, child_email)
            
            return {
                "child_email": child_email,
                "ano": ano or child_info["ano"],
                "question_data": {},
                "question_id": 0,
                "user_response": "",
                "evaluation_result": {},
                "feedback_text": "",
                "audio_data": {},
                "saved": False,
                "response_id": 0,
                "child_name": child_info["nome"]
            }

    def _execute_with_error_handling(self, func, state: AgentState, operation_name: str) -> AgentState:
        """Executa uma função com tratamento de erro consistente"""
        try:
            logger.info(f"🔄 Executando: {operation_name}")
            return func(state)
        except Exception as e:
            logger.error(f"❌ Erro em {operation_name}: {e}")
            raise

    def process_new_question(self, ano: int, child_email: str) -> Dict[str, Any]:
        """Processa a geração de uma nova questão"""
        logger.info(f"🚀 Iniciando fluxo para nova questão (ano: {ano})")
        
        state = self._initialize_state(child_email, ano)
        
        try:
            state = self._execute_with_error_handling(
                self._generate_question_node, state, "Geração de questão"
            )
            state = self._execute_with_error_handling(
                self._persist_question_node, state, "Persistência de questão"
            )
            return state["question_data"]
        except Exception as e:
            logger.error(f"Erro ao processar nova questão: {e}")
            raise

    def process_answer(self, question_id: int, user_answer: str, child_email: str) -> Dict[str, Any]:
        """Processa uma resposta do usuário"""
        logger.info(f"🚀 Processando resposta (ID: {question_id})")
        
        state = self._initialize_state(child_email)
        state["question_id"] = question_id
        state["user_response"] = user_answer.upper().strip()

        try:
            operations = [
                (self._fetch_question_node, "Busca de questão"),
                (self._evaluate_answer_node, "Avaliação de resposta"),
                (self._save_response_node, "Salvamento de resposta"),
                (self._generate_feedback_node, "Geração de feedback"),
                (self._generate_audio_node, "Geração de áudio")
            ]
            
            for operation, description in operations:
                state = self._execute_with_error_handling(operation, state, description)
            
            return {
                "correta": state["evaluation_result"]["correct"],
                "feedback": state["feedback_text"],
                "audio": state["audio_data"].get("base64", ""),
                "saved": state["saved"]
            }
        except Exception as e:
            logger.error(f"Erro ao processar resposta: {e}")
            raise

    def generate_report(self, child_email: str) -> Dict[str, Any]:
        """Gera um relatório de desempenho"""
        logger.info(f"📊 Gerando relatório via agente especializado")
        with get_db_session() as session:
            return self.report_agent.generate_report(child_email, session)

    def _generate_question_node(self, state: AgentState) -> AgentState:
        """Gera uma nova questão usando o QuestionAgent"""
        question_data = self.question_agent.generate_question(state["ano"])
        state["question_data"] = question_data
        return state

    def _persist_question_node(self, state: AgentState) -> AgentState:
        logger.info("💾 Persistindo questão no banco")
        question_data = state["question_data"]
        try:
            with get_db_session() as session:
                # Cria e adiciona
                db_question = Question(
                    question=question_data["question"],
                    options=question_data["options"],
                    answer=question_data["answer"],
                    ano_ideal=state["ano"]
                )
                session.add(db_question)

                # flush() garante que db_question.id será populado pelo DB sem commitar ainda
                session.flush()
                question_id = db_question.id  # id já disponível

                # Gerar áudio (chamada síncrona) usando o id gerado
                audio_path = self._generate_question_audio(question_data["question"], question_id)

                # Atualiza o mesmo objeto antes de commitar
                db_question.audio_path = audio_path

                # Commit finaliza tudo de uma vez
                session.commit()

                # Opcional: session.refresh(db_question) se precisar garantir estado fresco
                # session.refresh(db_question)

                # Preenche o estado com dados primitivos
                state["question_data"]["id"] = question_id
                state["question_id"] = question_id
                state["question_data"]["audio_path"] = audio_path

            logger.info("✅ Questão gerada completa (com áudio): Áudio path = %s", audio_path)
            return state

        except Exception as e:
            logger.error(f"Erro ao persistir questão: {e}", exc_info=True)
            # Dependendo da implementação de get_db_session, pode ser necessário dar rollback aqui.
            raise


    def _generate_question_audio(self, question_text: str, question_id: int) -> str:
        """Gera áudio para a questão e retorna o caminho do arquivo"""
        try:
            audios_dir = Path("audios")
            audios_dir.mkdir(exist_ok=True)
            audio_filename = f"questao_{question_id}.mp3"
            audio_path = str(audios_dir / audio_filename)
            
            # Usar o TTS Agent para gerar áudio
            self.tts_agent.generate_audio(question_text, audio_path)
            
            logger.info(f"🎵 Áudio da questão gerado: {audio_path}")
            return audio_path
        except Exception as e:
            logger.error(f"❌ Erro ao gerar áudio da questão: {e}")
            return ""

    def _fetch_question_node(self, state: AgentState) -> AgentState:
        """Busca uma questão do banco de dados"""
        with get_db_session() as session:
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
                fallback_data = self.question_agent._get_fallback_question(state["ano"])
                state["question_data"] = {
                    "id": state["question_id"],
                    "question": fallback_data["question"],
                    "options": fallback_data["options"],
                    "answer": fallback_data["answer"]
                }
        return state

    def _evaluate_answer_node(self, state: AgentState) -> AgentState:
        """Avalia se a resposta do usuário está correta"""
        question_data = state["question_data"]
        user_answer = state["user_response"]
        is_correct = user_answer == question_data.get("answer", "").upper()
        
        state["evaluation_result"] = {
            "correct": is_correct,
            "expected": question_data.get("answer", ""),
            "selected": user_answer
        }
        return state

    def _save_response_node(self, state: AgentState) -> AgentState:
        """Salva a resposta do usuário no banco de dados"""
        with get_db_session() as session:
            response_record = Response(
                question_id=state["question_id"],
                child_email=state["child_email"],
                selected=state["evaluation_result"]["selected"],
                correct=state["evaluation_result"]["correct"],
                timestamp=datetime.utcnow(),
                feedback_text="",
            )
            session.add(response_record)
            session.commit()
            session.refresh(response_record)
            state["saved"] = True
            state["response_id"] = response_record.id
        return state

    def _generate_feedback_node(self, state: AgentState) -> AgentState:
        """Gera feedback usando o ChildFeedbackAgent"""
        # Prepara avaliação para o agente de feedback
        avaliacao = (
            f"A criança {state['child_name']} {'acertou' if state['evaluation_result']['correct'] else 'errou'} "
            f"a questão do {state['ano']}º ano. "
            f"Resposta esperada: {state['evaluation_result']['expected']}, "
            f"Resposta dada: {state['evaluation_result']['selected']}"
        )

        # Gera feedback usando o agente especializado
        feedback_text = self.tts_agent.generate_feedback(
            avaliacao_completa=avaliacao,
            crianca_nome=state["child_name"],
            with_audio=False
        )
        
        state["feedback_text"] = feedback_text
        return state

    def _generate_audio_node(self, state: AgentState) -> AgentState:
        """Gera áudio do feedback usando o TTS Agent"""
        audios_dir = Path("audios")
        audios_dir.mkdir(exist_ok=True)
        
        audio_filename = f"feedback_{state['response_id']}.mp3"
        audio_path = str(audios_dir / audio_filename)
        
        # Gera áudio usando o TTS Agent
        self.tts_agent._generate_audio(state["feedback_text"], audio_path)
        
        # Codifica para base64
        with open(audio_path, "rb") as f:
            audio_b64 = base64.b64encode(f.read()).decode("utf-8")
        
        state["audio_data"] = {
            "path": audio_path,
            "base64": audio_b64
        }
        
        # Atualiza resposta no banco
        with get_db_session() as session:
            response = session.get(Response, state["response_id"])
            if response:
                response.feedback_text = state["feedback_text"]
                response.audio_path = audio_path
                response.audio_base64 = audio_b64
                session.commit()
        
        return state