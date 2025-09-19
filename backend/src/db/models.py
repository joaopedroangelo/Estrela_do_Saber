from datetime import datetime
import random
from typing import Optional, Dict, Any
from sqlmodel import SQLModel, Field, create_engine, Session, JSON, Column
from sqlalchemy import create_engine as sqlalchemy_create_engine

class Child(SQLModel, table=True):
    """Modelo para armazenar dados das crianças"""
    id: Optional[int] = Field(default=None, primary_key=True)
    nome: str
    ano: int  # Ano do ensino fundamental
    email_responsavel: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    audio_path: Optional[str] = Field(default=None, nullable=True)


class Question(SQLModel, table=True):
    """Modelo para armazenar questões (opcional - pode ser gerada on-the-fly)"""
    id: Optional[int] = Field(default=None, primary_key=True)  # <-- autoincrement do DB
    question: str
    options: Dict[str, Any] = Field(sa_column=Column(JSON))  # Lista de opções em JSON
    answer: str  # Gabarito correto
    ano_ideal: int  # Ano escolar ideal para esta questão
    audio_path: Optional[str] = Field(default="Sem áudio")
    created_at: datetime = Field(default_factory=datetime.utcnow)


class Response(SQLModel, table=True):
    """Modelo para armazenar respostas das crianças - fonte única de verdade para relatórios"""
    id: Optional[int] = Field(default=None, primary_key=True)
    question_id: int
    child_email: str = Field(index=True)  # FK via email do responsável
    selected: str  # Resposta selecionada pela criança
    correct: bool  # Se a resposta estava correta
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    feedback_text: str  # Feedback gerado para a criança
    audio_path: Optional[str] = None  # Caminho para o arquivo de áudio
    audio_base64: Optional[str] = None  # Áudio em base64 (opcional)

# Configuração do banco SQLite
DATABASE_URL = "sqlite:///./db.sqlite"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}  # Para SQLite threading
)

def create_db_and_tables():
    """Criar tabelas do banco de dados"""
    SQLModel.metadata.create_all(engine)

def get_session():
    """Obter sessão do banco de dados"""
    with Session(engine) as session:
        yield session