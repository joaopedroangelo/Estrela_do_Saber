from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Dict, Any
from sqlmodel import Session, select
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from db.models import Child, Response, get_session, create_db_and_tables
from agents.orchestrator import MultiAgentOrchestrator
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Sistema Multi-Agente para Jogo Infantil",
    description="Backend educacional com LangGraph, LangChain e OpenAI",
    version="1.0.0"
)

# Instanciar orquestrador
orchestrator = MultiAgentOrchestrator()

# Modelos Pydantic para requests
class RegisterRequest(BaseModel):
    nome: str
    ano: int
    email_responsavel: str

class NewQuestionRequest(BaseModel):
    ano: int
    email_responsavel: str

class AnswerRequest(BaseModel):
    id: int
    resposta: str
    email_responsavel: str

@app.on_event("startup")
async def startup():
    """Inicializar banco de dados na inicialização"""
    create_db_and_tables()
    logger.info("🚀 Sistema Multi-Agente iniciado!")
    logger.info("📚 Banco de dados SQLite configurado")
    logger.info("🤖 Agentes OpenAI prontos")

@app.post("/register")
async def register_child(
    request: RegisterRequest,
    session: Session = Depends(get_session)
) -> Dict[str, Any]:
    """
    Registra ou atualiza uma criança no sistema
    
    Body: {"nome": "Maria", "ano": 3, "email_responsavel": "resp@exemplo.com"}
    Returns: {"ok": true, "child": {...}}
    """
    
    logger.info(f"📝 Registrando criança: {request.nome}, {request.ano}º ano")
    
    try:
        # Verificar se criança já existe
        existing_child = session.exec(
            select(Child).where(Child.email_responsavel == request.email_responsavel)
        ).first()
        
        if existing_child:
            # Atualizar dados existentes
            existing_child.nome = request.nome
            existing_child.ano = request.ano
            session.commit()
            session.refresh(existing_child)
            child_data = existing_child
            logger.info(f"✅ Criança atualizada: {request.nome}")
        else:
            # Criar nova criança
            new_child = Child(
                nome=request.nome,
                ano=request.ano,
                email_responsavel=request.email_responsavel
            )
            session.add(new_child)
            session.commit()
            session.refresh(new_child)
            child_data = new_child
            logger.info(f"✅ Nova criança registrada: {request.nome}")
        
        return {
            "ok": True,
            "child": {
                "id": child_data.id,
                "nome": child_data.nome,
                "ano": child_data.ano,
                "email_responsavel": child_data.email_responsavel,
                "created_at": child_data.created_at.isoformat()
            }
        }
        
    except Exception as e:
        logger.error(f"❌ Erro ao registrar criança: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")

@app.post("/nova_questao")
async def new_question(
    request: NewQuestionRequest,
    session: Session = Depends(get_session)
) -> Dict[str, Any]:
    """
    Gera nova questão usando o sistema multi-agente
    
    Body: {"ano": 2, "email_responsavel": "resp@exemplo.com"}
    Returns: {"id": 1, "disponivel": true, "question": "...", "options": [...], "answer": "A"}
    """
    
    logger.info(f"🎯 Nova questão solicitada: {request.ano}º ano, email: {request.email_responsavel}")
    
    try:
        # Verificar se criança existe
        child = session.exec(
            select(Child).where(Child.email_responsavel == request.email_responsavel)
        ).first()
        
        if not child:
            raise HTTPException(
                status_code=404, 
                detail="Criança não encontrada. Faça o registro primeiro."
            )
        
        # Processar via LangGraph
        question_data = orchestrator.process_new_question(
            ano=request.ano,
            child_email=request.email_responsavel
        )
        
        logger.info(f"✅ Questão gerada: ID {question_data['id']}")
        
        return question_data
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erro ao gerar questão: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")

@app.post("/responder")
async def answer_question(
    request: AnswerRequest,
    session: Session = Depends(get_session)
) -> Dict[str, Any]:
    """
    Processa resposta da criança usando sistema multi-agente
    
    Body: {"id": 1, "resposta": "A", "email_responsavel": "resp@exemplo.com"}
    Returns: {"correta": true, "feedback": "Muito bem!", "audio": "<base64>", "saved": true}
    """
    
    logger.info(f"📤 Resposta recebida: questão {request.id}, resposta {request.resposta}")
    
    try:
        # Verificar se criança existe
        child = session.exec(
            select(Child).where(Child.email_responsavel == request.email_responsavel)
        ).first()
        
        if not child:
            raise HTTPException(
                status_code=404, 
                detail="Criança não encontrada. Faça o registro primeiro."
            )
        
        # Processar resposta via LangGraph
        result = orchestrator.process_answer(
            question_id=request.id,
            user_answer=request.resposta,
            child_email=request.email_responsavel,
            ano=child.ano
        )
        
        logger.info(f"✅ Resposta processada: {'Correta' if result['correta'] else 'Incorreta'}")
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erro ao processar resposta: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")

@app.get("/relatorio/{email}")
async def get_report(email: str) -> Dict[str, Any]:
    """
    Gera relatório técnico de desempenho
    
    Returns: JSON com relatório completo e simula envio por email
    """
    
    logger.info(f"📊 Relatório solicitado para: {email}")
    
    try:
        # Gerar relatório via agente especializado
        report = orchestrator.generate_report(email)
        
        if "error" in report:
            raise HTTPException(status_code=404, detail=report["error"])
        
        logger.info(f"✅ Relatório gerado para {report.get('child_info', {}).get('name', 'criança')}")
        
        return report
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Erro ao gerar relatório: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")

@app.get("/respostas/{email}")
async def get_responses(
    email: str,
    session: Session = Depends(get_session)
) -> Dict[str, Any]:
    """
    Endpoint opcional para debug - lista respostas salvas
    
    Returns: Lista de respostas para o email especificado
    """
    
    logger.info(f"🔍 Consultando respostas para: {email}")
    
    try:
        responses = session.exec(
            select(Response).where(Response.child_email == email)
        ).all()
        
        response_list = [
            {
                "id": r.id,
                "question_id": r.question_id,
                "selected": r.selected,
                "correct": r.correct,
                "timestamp": r.timestamp.isoformat(),
                "feedback_text": r.feedback_text,
                "audio_path": r.audio_path
            }
            for r in responses
        ]
        
        logger.info(f"✅ Encontradas {len(response_list)} respostas")
        
        return {
            "email": email,
            "total_responses": len(response_list),
            "responses": response_list
        }
        
    except Exception as e:
        logger.error(f"❌ Erro ao consultar respostas: {e}")
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "message": "Sistema Multi-Agente funcionando!"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "api.main:app",
        host="0.0.0.0",
        port=5000,
        reload=True,
        log_level="info"
    )