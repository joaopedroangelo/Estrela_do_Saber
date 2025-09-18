import json
import os
from typing import Dict, Any
from langchain_openai import ChatOpenAI
from langchain_core.messages import SystemMessage, HumanMessage
from langchain_core.output_parsers import JsonOutputParser
from dotenv import load_dotenv
import os

load_dotenv()  # isso carrega o arquivo .env

class QuestionGeneratorAgent:
    """Agente responsável por gerar questões de múltipla escolha para alfabetização"""
    
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
        self.parser = JsonOutputParser()
        self._question_counter = 100
    
    def generate_question(self, ano: int) -> Dict[str, Any]:
        """
        Gera uma questão de múltipla escolha adaptada ao ano escolar
        
        Args:
            ano: Ano do ensino fundamental (1-5)
            
        Returns:
            Dict com formato exato: {"id": int, "disponivel": true, "question": str, "options": list, "answer": str}
        """
        
        # Adaptar conteúdo ao ano escolar
        if ano <= 2:
            focus = "reconhecimento de letras, sílabas simples, palavras básicas do cotidiano"
            complexity = "muito simples, com palavras de 2-4 letras"
        elif ano <= 4:
            focus = "formação de palavras, rimas, separação silábica, interpretação de frases curtas"
            complexity = "simples, com palavras familiares de até 6 letras"
        else:
            focus = "interpretação de textos curtos, sinônimos, antônimos, classificação de palavras"
            complexity = "moderado, com vocabulário mais amplo"
        
        system_prompt = f"""Você é um especialista em educação infantil e alfabetização.
        Crie uma questão de múltipla escolha para crianças do {ano}º ano do ensino fundamental.

        FOCO: {focus}
        COMPLEXIDADE: {complexity}

        REGRAS OBRIGATÓRIAS:
        1. Use linguagem adequada para a idade (simples, clara, amigável)
        2. Crie exatamente 4 opções de resposta
        3. As opções devem ser rotuladas como A, B, C, D
        4. Apenas UMA opção deve estar correta
        5. As outras 3 opções devem ser plausíveis mas incorretas
        6. Use contextos lúdicos e divertidos (animais, brinquedos, natureza)
        
        RESPONDA APENAS EM JSON no formato EXATO:
        {{
            "question": "texto da pergunta aqui",
            "options": ["opção A", "opção B", "opção C", "opção D"],
            "answer": "A"
        }}"""
        
        human_prompt = f"Gere uma questão de alfabetização para o {ano}º ano."
        
        try:
            messages = [
                SystemMessage(content=system_prompt),
                HumanMessage(content=human_prompt)
            ]
            
            print(f"🎯 Gerando questão para {ano}º ano...")
            response = self.llm.invoke(
                messages,
                response_format={"type": "json_object"}
            )
            
            # Parse da resposta JSON
            question_data = json.loads(str(response.content))
            
            # Adicionar campos obrigatórios
            formatted_question = {
                "id": self._question_counter,
                "disponivel": True,
                "question": question_data["question"],
                "options": question_data["options"],
                "answer": question_data["answer"]
            }
            
            self._question_counter += 1
            
            print("✅ Questão gerada completa:")
            print(json.dumps(formatted_question, indent=2, ensure_ascii=False))
            print("Gerando áudio...")
            
            return formatted_question
            
        except Exception as e:
            print(f"❌ Erro ao gerar questão: {e}")
            # Questão fallback para garantir funcionamento
            return self._get_fallback_question(ano)
    
    def _get_fallback_question(self, ano: int) -> Dict[str, Any]:
        """Questão de fallback caso a API falhe"""
        fallback_questions = {
            1: {
                "question": "Qual é a primeira letra da palavra 'CASA'?",
                "options": ["C", "A", "S", "H"],
                "answer": "C"
            },
            2: {
                "question": "Quantas sílabas tem a palavra 'GATO'?",
                "options": ["1", "2", "3", "4"],
                "answer": "2"
            },
            3: {
                "question": "Qual palavra rima com 'FLOR'?",
                "options": ["Amor", "Casa", "Livro", "Carro"],
                "answer": "Amor"
            }
        }
        
        base_question = fallback_questions.get(ano, fallback_questions[2])
        
        return {
            "id": self._question_counter,
            "disponivel": True,
            "question": base_question["question"],
            "options": base_question["options"],
            "answer": base_question["answer"]
        }