# 📱 DCGO Android Developer Kit (Kit para Desenvolvedores)
### Correções, Shaders, Scripts Defensivos e Automação para Suporte Oficial ao Android

---

## 🎯 Objetivo deste Pacote

Este kit reúne **todas as soluções técnicas e correções** desenvolvidas e testadas para fazer o **DCGO (Digimon Card Game Online)** rodar de forma nativa, estável e livre de bugs em dispositivos **Android (celulares e tablets)**.

Ele foi organizado de forma limpa e modular para você **enviar diretamente aos desenvolvedores oficiais do DCGO** (seja via Pull Request no GitHub, arquivo zip no Discord da comunidade ou e-mail).

---

## 🧩 O Que Está Sendo Entregue aos Desenvolvedores

### 1. `01_Shaders_Mali_Bugfix/` (Correção Gráfica para GPU Mali)
* **O Problema:** Em tablets e celulares com processadores MediaTek, Exynos ou Unisoc (GPUs Mali-G52, G57, G72, etc.), os efeitos de partículas do jogo ficavam rosa, telas pretas ou formavam caixas amarelas opacas na arena de batalha.
* **A Solução:** 6 shaders HLSL modernos e otimizados para Unity URP mobile prontos para serem colocados em `Assets/Shader_Material/Shader/`.

### 2. `02_Scripts_CSharp_Fixes/` (Proteção de Código e Decks Persistentes)
* **O Problema:** No Android, o Unity empacota os arquivos dentro do arquivo `.apk` (`jar:file://`), impedindo a gravação comum de decks. Além disso, se um jogador importava uma lista de deck sem o cabeçalho exato ou sem `_` no nome do arquivo, o jogo travava com erro `FormatException`.
* **A Solução:**
  * `StreamingAssetsUtility.cs`: Redireciona a pasta de Decks para `Application.persistentDataPath` no Android.
  * `ContinuousController.cs`: Substitui `int.Parse` por `int.TryParse` seguro e proteção no split de nomes de arquivo.
  * `csharp_patches.patch`: Arquivo padrão do Git (`git apply`) para aplicar essas alterações com 1 comando.

### 3. `03_Editor_Automated_Build/` (Script de Compilação Automática)
* **A Solução:** `ProductionBuild.cs` permite que a equipe compile o APK de forma 100% automatizada em servidores de integração contínua (CI/CD) ou via linha de comando:
  * Arquitetura ARM64 pura.
  * Modo Release limpo (sem lentidão de debug).
  * API Gráfica OpenGL ES 3.0.

### 4. `04_ProjectSettings_Orientation/` (Orientação Paisagem Dupla)
* **O Problema:** Bloquear a rotação em apenas um lado impede o jogador de virar o aparelho para carregar. Permitir o modo retrato deforma toda a interface.
* **A Solução:** Configuração oficial de autorrotação restrita exclusivamente entre `Landscape Left` e `Landscape Right`.

### 5. `05_Standalone_Converter_Tool/` (Programa Conversor 1-Clique)
* Cópia completa da ferramenta **DCGO-Converter** (com scripts `.bat` e `.ps1`) que qualquer usuário ou desenvolvedor no Windows pode usar para compilar novas versões do DCGO com 1 clique.

---

## 💡 Mensagem Sugerida para Enviar aos Desenvolvedores (em Inglês)

Você pode copiar e colar o seguinte texto ao entrar em contato com os desenvolvedores no Discord ou GitHub:

```text
Hi DCGO Team! 👋

I've put together a complete Android compatibility package that fixes all known Android issues (Mali GPU black screens/yellow boxes, dual-landscape orientation, and persistent deck storage with safe parsing), along with a headless automated Release build script.

Everything has been tested and verified on physical Android hardware (ARM64, Android 13/14, Mali GPU).

You can find all modular patches, replacement shaders, C# git diffs, and the build orchestrator organized in this repository / zip archive:
- Shaders: 6 replacement URP mobile shaders (drop-in to Assets/Shader_Material/Shader/)
- C# Scripts: safe int.TryParse deck loading & persistentDataPath routing
- PlayerSettings: dual-landscape autorotation guide
- ProductionBuild.cs: automated CI/CD headless release build

Let me know if you would like me to submit this as a Pull Request on GitHub or if you want to test the included converter tool. Thank you for this awesome project!
```
