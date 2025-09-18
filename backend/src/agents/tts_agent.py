from langchain_openai import ChatOpenAI
from langchain_core.prompts import ChatPromptTemplate
from openai import OpenAI
import os
from dotenv import load_dotenv

load_dotenv()  # isso carrega o arquivo .env


class ChildFeedbackPrompt:
    @staticmethod
    def feedback_context(crianca_nome: str) -> str:
        return (
            f"Você é um assistente pedagógico animado e divertido para crianças em fase de alfabetização. "
            f"Seu objetivo é transformar avaliações pedagógicas em mensagens positivas e encorajadoras "
            f"que serão NARRADAS EM ÁUDIO para a criança chamada {crianca_nome}. "
            f"Sempre que possível, chame a criança pelo nome {crianca_nome} para criar proximidade e motivação.\n\n"

            "DIRETRIZES ESPECÍFICAS PARA ÁUDIO:\n"
            "1. LINGUAGEM SONORA: Use palavras com sons expressivos (ex: 'muuuuito bem!', 'éééé isso ai!') \n"
            "2. ENTONAÇÃO ANIMADA: Escreva de forma que a IA possa ler com empolgação e alegria na voz\n"
            "3. FRASES CURTAS: Use frases simples com máximo de 5-6 palavras cada\n"
            "4. REPETIÇÃO RÍTMICA: Crie um padrão sonoro agradável com repetições\n"
            "6. POSITIVIDADE: Foque sempre no que a criança acertou primeiro\n\n"

            "FORMATO DO FEEDBACK (pronto para narração em áudio):\n"
            f"[Saudação animada usando o nome {crianca_nome}]!\n\n"
            "[Explicação animada da atividade e qual resposta correta]\n\n"
            "[Diga se a criança acertou ou errou a atividade, sempre sendo positivo, mesmo nos erros]\n\n"
            "[Mensagem final de incentivo com entonação alegre]\n\n"

            "EXEMPLOS DE FRASES ADEQUADAS:\n"
            f"- 'Uhuuuul, {crianca_nome}! Você acertou a letra L!'\n"
            f"- 'O leão começa com L! L-L-L-Léão, {crianca_nome}!'\n"
            "- 'Vamos brincar de bater palminhas? Pá-pá-pá!'\n"
            "- 'Que deeeelícia de resposta!'\n"
            "- 'Issoooo ai, pequeno explorador!'\n\n"

            "NUNCA USE:\n"
            "- Emojis ou símbolos visuais\n"
            "- Termos técnicos complexos\n"
            "- Frases longas ou complexas\n"
            "- Críticas ou focos excessivos nos erros\n"
            "- Comparações com outras crianças\n\n"
            "- NUNCA USE EMOJIS\n\n"

            "Lembre-se: seu texto será transformado em áudio! Escreva de forma que a IA possa ler com "
            "entonação animada, alegre e encorajadora, como se estivesse BRICANDO com a CRIANÇA!"
        )


class ChildFeedbackAgent:
    def __init__(self, model_name="gpt-4o", temperature=0.7, voice="alloy"):
        api_key = os.environ.get("OPENAI_API_KEY")
        self.llm = ChatOpenAI(model=model_name, temperature=temperature, api_key=api_key)
        self.voice = voice
        self.client = OpenAI(api_key=api_key)

    def _build_chain(self, crianca_nome: str):
        prompt = ChatPromptTemplate.from_messages(
            [
                ("system", ChildFeedbackPrompt.feedback_context(crianca_nome)),
                ("human", "Aqui está a avaliação do professor:\n{avaliacao_completa}"),
            ]
        )
        return prompt | self.llm

    def _generate_audio(self, text: str, output_file: str):
        audio_response = self.client.audio.speech.create(
            model="gpt-4o-mini-tts",
            voice=self.voice,
            input=text,
           instructions=(
            "Leia o texto de forma animada, empolgante, feliz e divertida! "
            "Você está conversando com uma criança."
        ),

        )
        with open(output_file, "wb") as f:
            f.write(audio_response.read())
        print(f"Audio successfully generated in '{output_file}'")

    def generate_audio(self, text: str, output_file: str) -> None:
        """Método público para gerar áudio a partir de texto"""
        self._generate_audio(text, output_file)

    def generate_feedback(
        self,
        avaliacao_completa: str,
        crianca_nome: str,
        with_audio: bool = True,
        audio_file: str = "feedback_crianca.mp3",
    ) -> str:
        chain = self._build_chain(crianca_nome)
        resp = chain.invoke({"avaliacao_completa": avaliacao_completa})
        feedback_text = resp.content
        if with_audio:
            self._generate_audio(feedback_text, audio_file)
        return feedback_text

if __name__ == "__main__":
    # Caminho para salvar dentro da pasta /audios
    audio_output_path = os.path.join("audios", "teste_audio.mp3")

    # Instancia o agente
    agent = ChildFeedbackAgent()

    # Teste rápido do generate audio
    texto_teste = "Oi! Qual é o seu nome? Eu sou a Dora. Vamos brincar com as letras?"
    agent._generate_audio(texto_teste, audio_output_path)
    print(f"Áudio de teste salvo em: {audio_output_path}")
