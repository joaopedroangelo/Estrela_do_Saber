from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field, EmailStr
from typing import Dict, Any, List, Optional
from sqlmodel import Column, Session, String, select
import sys
import os
from fastapi.staticfiles import StaticFiles

# Adicione esta linha após criar a instância do app
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from agents.tts_agent import ChildFeedbackAgent
from db.models import Child, Response, Question, get_session, create_db_and_tables
from agents.orchestrator import MultiAgentOrchestrator
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Sistema Multi-Agente para Alfabetização Infantil",
    description="API para geração de questões educativas, avaliação de respostas e relatórios de desempenho",
    version="1.0.0"
)
app.mount("/audios", StaticFiles(directory="audios"), name="audios")


from fastapi.middleware.cors import CORSMiddleware

# Adicione isso após criar a instância do app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite todas as origens (apenas para desenvolvimento)
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos os métodos
    allow_headers=["*"],  # Permite todos os headers
)

# Instanciar orquestrador
orchestrator = MultiAgentOrchestrator()

# Modelos Pydantic para requests
class RegisterRequest(BaseModel):
    nome: str = Field(..., min_length=2, max_length=100, example="Maria Silva")
    ano: int = Field(..., ge=1, le=5, example=3)
    email_responsavel: EmailStr = Field(..., example="responsavel@exemplo.com")

# Adicione esta classe para a resposta
class RegisterResponse(BaseModel):
    ok: bool
    child: dict

class NewQuestionRequest(BaseModel):
    ano: int = Field(..., ge=1, le=5, example=3)
    email_responsavel: EmailStr = Field(..., example="responsavel@exemplo.com")

class AnswerRequest(BaseModel):
    id: int = Field(..., ge=1, example=1)
    resposta: str = Field(..., min_length=1, max_length=1, example="A")
    email_responsavel: EmailStr = Field(..., example="responsavel@exemplo.com")

class ResponseItem(BaseModel):
    id: int
    question_id: int
    selected: str
    correct: bool
    timestamp: str
    feedback_text: str
    audio_path: str

class ResponsesResponse(BaseModel):
    email: str
    total_responses: int
    responses: List[ResponseItem]

@app.on_event("startup")
async def startup():
    """Inicializar banco de dados na inicialização"""
    create_db_and_tables()
    logger.info("🚀 Sistema Multi-Agente iniciado!")
    logger.info("📚 Banco de dados SQLite configurado")
    logger.info("🤖 Agentes OpenAI prontos")

from fastapi import BackgroundTasks

@app.post("/register", status_code=status.HTTP_201_CREATED)
async def register_child(
    request: RegisterRequest,
    session: Session = Depends(get_session)
) -> Dict[str, Any]:
    logger.info(f"Registrando criança: {request.nome}, {request.ano}º ano")

    new_child = Child(
        nome=request.nome,
        ano=request.ano,
        email_responsavel=request.email_responsavel
    )
    session.add(new_child)
    session.commit()
    session.refresh(new_child)

    audio_filename = f"{request.nome.lower().replace(' ', '_')}.mp3"
    audio_dir = os.path.join("audios", "welcomes")
    os.makedirs(audio_dir, exist_ok=True)
    audio_path = os.path.join(audio_dir, audio_filename)
    new_child.audio_path = audio_path
    session.commit()

    welcome_text = f"Olá {request.nome}! Seja muito bem-vinda ao jogo do saber... O melhooooor jogo do muuundo!"

    # Gerar o áudio aqui de forma BLOQUEANTE
    tts_agent = ChildFeedbackAgent()
    tts_agent.generate_audio(welcome_text, audio_path)
    logger.info(f"Áudio gerado em {audio_path}")

    # Agora sim retorna
    return {
        "ok": True,
        "child": {
            "id": new_child.id,
            "nome": new_child.nome,
            "ano": new_child.ano,
            "email_responsavel": new_child.email_responsavel,
            "audio_path": new_child.audio_path,
            "created_at": new_child.created_at.isoformat()
        }
    }



from fastapi.responses import FileResponse
import os

@app.api_route("/audio/{file_path:path}", methods=["GET", "HEAD"])
async def get_audio(file_path: str):
    audio_path = os.path.join("audios", file_path)

    if not os.path.exists(audio_path):
        raise HTTPException(status_code=404, detail="Arquivo não encontrado")

    if not audio_path.endswith(".mp3"):
        raise HTTPException(status_code=400, detail="Apenas MP3 são suportados")

    file_size = os.path.getsize(audio_path)

    headers = {
        "Accept-Ranges": "bytes",
        "Content-Length": str(file_size),
        "Content-Type": "audio/mpeg",
    }

    # Se for só HEAD → devolve só os headers
    if file_path and "HEAD" in str(file_path):
        return Response(status_code=200, headers=headers)

    # Se for GET → devolve o arquivo
    return FileResponse(
        audio_path,
        media_type="audio/mpeg",
        filename=os.path.basename(audio_path),
        content_disposition_type="inline",  # 👈 força inline
        headers={"Accept-Ranges": "bytes"}  # 👈 garante suporte a Range
    )


@app.get("/respostas/{email}", response_model=ResponsesResponse)
async def get_responses(
    email: str,
    session: Session = Depends(get_session)
) -> Dict[str, Any]:
    """
    Endpoint para consultar respostas salvas (útil para debug)
    """
    
    logger.info(f"Consultando respostas para: {email}")
    
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
                "audio_path": r.audio_path or ""
            }
            for r in responses
        ]
        
        logger.info(f"Encontradas {len(response_list)} respostas")
        
        return {
            "email": email,
            "total_responses": len(response_list),
            "responses": response_list
        }
        
    except Exception as e:
        logger.error(f"Erro ao consultar respostas: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro interno: {str(e)}"
        )

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy", 
        "message": "Sistema Multi-Agente funcionando!",
        "version": "1.0.0"
    }

@app.get("/criancas")
async def get_all_children(session: Session = Depends(get_session)) -> Dict[str, Any]:
    """
    Retorna todas as crianças registradas no sistema
    """
    try:
        children = session.exec(select(Child)).all()
        children_list = [
            {
                "id": c.id,
                "nome": c.nome,
                "ano": c.ano,
                "email_responsavel": c.email_responsavel,
                "created_at": c.created_at.isoformat()
            }
            for c in children
        ]
        return {"total": len(children_list), "children": children_list}
    except Exception as e:
        logger.error(f"Erro ao consultar crianças: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro interno: {str(e)}"
        )


@app.get("/questoes")
async def get_all_questions(session: Session = Depends(get_session)) -> Dict[str, Any]:
    """
    Retorna todas as questões geradas no sistema
    """
    try:
        questions = session.exec(select(Question)).all()
        questions_list = [
            {
                "id": q.id,
                "ano": q.ano,
                "pergunta": q.pergunta,
                "opcoes": q.opcoes,  # Assumindo que seja um campo JSON ou lista
                "resposta_correta": q.resposta_correta,
                "created_at": q.created_at.isoformat()
            }
            for q in questions
        ]
        return {"total": len(questions_list), "questions": questions_list}
    except Exception as e:
        logger.error(f"Erro ao consultar questões: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro interno: {str(e)}"
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=5000,
        reload=True,
        log_level="info"
    )