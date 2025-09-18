#  ⭐ Estrela do Saber

🎮 Estrela do Saber é um jogo educacional para Android que se integra a um backend baseado em um sistema multi-agente.

---
## Sobre o Jogo

> Demo: https://www.youtube.com/shorts/RXsXKLENw0Y

![alt text](assets/image.png)

![alt text](assets/image02.png)

---
## Arquitetura

```mermaid
flowchart LR
    %% Frontend fora do backend
    FE[Frontend]

    %% Backend com todos os componentes internos
    subgraph Backend
        direction TB
        O[Orchestrator]
        DB[(Database)]

        %% Agentes abaixo do Orchestrator
        subgraph Agents
            direction TB
            Q[Question Agent]
            R[Report Agent]
            T[TTS Audio Agent]
        end
    end

    %% Conexões bidirecionais
    FE <--> O
    O <--> Q
    O <--> R
    O <--> T
    O --> DB

```

---
## Backend

> Confira o backend em: [backend](backend/README.md)

---
## Frontend

> Confira o frontend em: [frontend](frontend/README.md)
