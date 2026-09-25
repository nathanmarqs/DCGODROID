# 🎮 DCGO Android Converter & Builder

Uma ferramenta automatizada e autossuficiente para transformar qualquer versão (atual ou futura) do projeto **DCGO (Digimon Card Game Online)** em um **APK Android 100% funcional**, corrigindo automaticamente todos os problemas conhecidos de compatibilidade gráfica (Mali GPU), orientação de tela e carregamento de decks.

---

## ⚡ Início Rápido (1-Clique)

1. Dê um duplo-clique no arquivo **`Converter-DCGO.bat`** (ou no atalho **`CONVERTER-DCGO.bat`** na raiz).
2. O menu interativo abrirá no seu terminal:

```text
============================================================
             DCGO ANDROID CONVERTER & BUILDER               
   Automacao completa: Clone -> Patches Mali/Deck -> APK    
============================================================

 Escolha uma opcao:
  [1] Converter Versao Direto do GitHub (Clonar + Patch + Build)
  [2] Converter Pasta Local do DCGO (Patch + Build)
  [3] Instalar Ultimo APK + Deck no Tablet (ADB USB)
  [4] Verificar Ambiente e Dispositivos Conectados
  [0] Sair
```

---

## 🛠️ Modos de Uso

### Opção 1: Converter Direto do GitHub
- Você pode colar qualquer repositório (ex: `https://github.com/DCGO2/DCGO.git`) e selecionar a branch ou tag desejada.
- O conversor baixa a versão mais recente em um workspace isolado, aplica todos os patches, compila o APK e pergunta se você já quer instalar no seu tablet via USB.

### Opção 2: Converter Pasta Local do DCGO
- Se você já tem uma pasta com o código-fonte do DCGO baixada no seu computador (por exemplo: `C:\Users\Administrator\Desktop\dcgo android\PROD\DCGO`), escolha essa opção.
- O conversor valida a pasta, aplica as correções e compila o APK.

### Opção 3: Instalar Último APK + Deck no Tablet
- Instala o APK mais recente gerado na pasta `output/` diretamente no tablet conectado via USB (`adb install -r`).
- Copia automaticamente o Deck Inicial para a pasta do jogo no Android (`/sdcard/Android/data/com.DCGO.DCGO/files/Decks/StarterDeck_01.txt`).
- Acorda a tela e inicia o jogo automaticamente.

### Opção 4: Verificar Ambiente
- Realiza um diagnóstico rápido do seu sistema:
  - Localização do Unity Editor (2021.3.x)
  - Presença do suporte de compilação Android (Unity Android Player)
  - Versão do Git
  - Status do ADB e detecção de aparelhos Android conectados.

---

## 🧩 Patches Automáticos Aplicados

O conversor resolve automaticamente todos os bugs que impediam o DCGO de rodar em tablets e celulares Android:

1. **Correção de Shaders Mali GPU (Telas pretas / texturas rosas):**
   - Substitui shaders de partículas depreciados e incompatíveis do URP por shaders HLSL nativos compilados especificamente para GPUs Mali (`MaliMaskedAdditive`, `Legacy-Particle-Add`, etc.).
2. **Orientação Dual-Landscape:**
   - Habilita autorotação contínua entre `Landscape Left` e `Landscape Right` no `ProjectSettings.asset`, permitindo virar o tablet para qualquer um dos dois lados sem cair em modo retrato.
3. **Persistência de Decks no Android:**
   - Corrige o `StreamingAssetsUtility.cs` e `ContinuousController.cs` para carregar listas de cartas a partir de `Application.persistentDataPath` (onde o Android permite leitura e escrita livre).
   - Inclui proteção com `int.TryParse` contra travamentos ao ler arquivos de deck sem cabeçalho padrão.
4. **Perfil de Compilação Release:**
   - Configura IL2CPP, arquitetura ARM64 pura (otimizada para processadores modernos), API Gráfica OpenGLES3, remoção de símbolos de debug para tamanho reduzido e desempenho máximo.

---

## 📁 Estrutura de Arquivos

```text
DCGO-Converter/
├── Converter-DCGO.bat          # Launcher de duplo clique
├── DCGO-Converter.ps1          # Menu orquestrador interativo
├── Engine-Patch.ps1            # Motor de aplicação de patches
├── Engine-Build.ps1            # Motor de build headless via Unity Batchmode
├── Engine-Deploy.ps1           # Motor de instalação e envio de decks via ADB
├── README.md                   # Este manual
├── patches/                    # Arquivos e códigos dos patches
│   ├── Shaders/                # Shaders corrigidos para GPU Mali
│   ├── Editor/                 # ProductionBuild.cs automatizado
│   └── Decks/                  # Deck inicial legal para o jogo
├── output/                     # APKs compilados finais
│   ├── DCGO_Release_latest.apk # Atalho sempre para o APK mais novo
│   └── DCGO_Release_<data>.apk # Histórico de versões compiladas
└── logs/                       # Logs detalhados de build do Unity
```

---

## 🃏 Como Adicionar Outros Decks no Jogo

Para que novos decks apareçam automaticamente no jogo:
1. Crie ou edite um arquivo de texto no formato DigimonCard.io (com quantidade e código da carta, ex: `4 Coronamon BT25-008`).
2. Adicione o cabeçalho obrigatório no início do arquivo:
   ```text
   Key Card: 0
   Deck Name: NomeDoSeuDeck
   Deck Color: Red
   ```
3. Salve na pasta `patches/Decks/` ou transfira diretamente para a pasta do tablet:
   `/sdcard/Android/data/com.DCGO.DCGO/files/Decks/`
