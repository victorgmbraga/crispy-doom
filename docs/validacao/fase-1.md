# Validacao — Fase 1

Data: 2026-10-05. Plataforma: Windows x64.
Base upstream: Crispy Doom 7.1.0, tag crispy-doom-7.1,
commit 0a022e0ee6c74d9bab173ed9ee5212312e90ce3a.

## Escopo entregue

- Estado paralelo cr_players[MAXPLAYERS], com acesso por igualdade de enderecos,
  reset, held/pressed/released e estados continuos de sprint/ADS/crouch reservado.
- Oito bits de buttons2, sem alterar ticcmd_t (20 bytes no toolchain testado).
- Dezesseis bindings configuraveis de teclado/mouse; transicoes de Q/R/E/B/X
  consumidas uma vez por tic, suporte a pressionamentos rapidos e roda do mouse.
- Input adaptado a partir dos eventos existentes. Gameplay le apenas ticcmd.
- Base de caminhada no modo Crysis, com sprint separado do run/autorun original.
- Reserva dos botoes Crysis contra movimento/strafe/double-click/ciclo de arma;
  tiro/uso compartilhados deliberados continuam disponiveis. E usa portas vanilla.
- Resets em nova partida, respawn, troca de nivel, menu e perda de foco; descarte
  de comandos anteriores ao reset e limpeza do cache upstream do mouse.
- Notificacoes genericas ev_focus no SDL e filtro de eventos de controles em
  background somente no modo Crysis. Vanilla ignora a notificacao nova.
- -crdebug mostra apenas transicoes de comandos, sem log continuo por tic.
- CLI, menus, atalhos, comandos especiais e funcoes publicas/deferred de
  save/load e demos bloqueados; opcoes de rede rejeitadas antes de IO/rede.
- Titulo Crysis alterna paginas e permite menu sem iniciar demos automaticas.

Nanosuit, regeneracao/HUD, mecanicas de armas, ADS visual, attachments, IA,
objetivos e PWAD Contact nao integram a F1. O mapa continua Freedoom MAP01.

## Arquivos e integracao

Novos modulos: src/doom/cr_input.[ch] e cr_player.[ch].
cr_defs.h define os bits; cr_game.[ch] coordena resets, diagnostico e rejeicoes.
Hooks em d_main.c, g_game.[ch], p_user.c e CMakeLists.txt do Doom.
m_config.c registra bindings na configuracao extra. d_event.h/i_video.c
notificam foco; i_input.[ch] oferecem limpeza de mouse chamada apenas em Crysis.
m_menu.c bloqueia save/load preservando o fluxo normal do menu.
Os hooks de lifecycle da F0 em p_setup.c/p_tick.c permanecem.

scripts/test-f1.ps1 e f1-state-test.c sao a suite atual; test-vanilla-storage.ps1
cobre IO de persistencia e demos no modo original. O launcher aceita -DebugInput;
Zed/VS Code e README_CRYSIS.md foram atualizados. Os documentos originais do
plano/especificacao e os relatorios F0 foram preservados.

## Build e artefatos

    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-build.ps1 -Build -LogPrefix fase-1-final

Build inicial e incremental final: passaram, exit 0. Toolchain igual ao baseline:
w64devkit 2.10.0/GCC 16.2.0, CMake 3.31.12, SDL2 2.32.10, mixer 2.8.2, net 2.4.0.
Nao houve warnings novos nos arquivos F1. O build inicial recompilado teve os
14 warnings upstream ja registrados; o ultimo incremental mostrou os quatro
warnings C90 de v_video.c. Depreciacao do CMake e bibliotecas opcionais ausentes
permanecem conforme F0. Logs: logs/fase-1-build.log e logs/fase-1-final-build.log,
com respectivos logs de configure.

Executavel: build/src/crispy-doom.exe.
SHA256: 85da6c1e416a6425bc682a576eb72346b281c8e85430a10d5d2cec6fc02f9b71.
IWAD: Freedoom Phase 2 0.13.0 em content/iwad/freedoom2.wad.
SHA256 IWAD: a8772e088847032510d97ba2312406a6998f21cbab44d4ff10696faa9c0ecd4b.

## Testes executados

    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f1.ps1
    powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-vanilla-storage.ps1

Suite F1 executada no PowerShell 7 e Windows PowerShell 5.1: 31 casos passaram
em cada ambiente, exit 0. Relatorios logs/fase1/result.json e
logs/fase1-windows-powershell/result.json, com logs por caso. O runner captura
o handle do processo antes de esperar, preservando ExitCode no PowerShell 5.1.

| Verificacao | Resultado observado |
|---|---|
| Logica dos modulos reais | 221 assertions; compilacao C99 com -Wall -Wextra -Werror passou |
| Protocolo | Oito bits; sizeof(ticcmd_t)=20, canais arti/look/movimento preservados |
| Bordas | Hold, release/repress, repeat, taps rapidos e roda; sem repeticao enquanto segurado |
| Bindings | Teclado/mouse remapeados; indices invalidos e ponteiros NULL/estranhos rejeitados |
| CLI | 23 opcoes rejeitadas; -record sem valor e response file tambem; sem IO/save/demo/rede |
| Compositor real | Forward 25 com e sem autorun; ADS nao causa strafe/use; salto 128 e look preservados |
| Menu/foco | Cache do mouse e teclas limpos; retorno do menu sem movimento ou comandos antigos |
| Atalhos de persistencia | F2/F3/F6/F9 rejeitados; nenhum save criado nem entrada de descricao |
| Lifecycle | 150 tics; duas novas partidas, quatro niveis, tres resets, transicao para MAP02 |
| Pausa/menu | Timers e input da simulacao congelados |
| Debug | Quatro logs nas quatro transicoes provocadas; sem spam durante hold |
| Titulo | Vinte advances, menu acessivel, zero tentativas de demo |
| Vanilla | Snapshot da demo original identico ao baseline F0 |

Snapshot vanilla controlado:

    SNAPSHOT map=1 gametic=175 leveltime=170 x=8718787 y=-12575414 z=-2097152 angle=1342177280 health=100 mobjhealth=100 bullets=46 rng=34 paused=0

Storage vanilla: tres casos passaram, exit 0 no runner. Foi criado um save
isolado com HP 77; apos alterar HP para 17, o load restaurou player e mobj para
77. Foi gravada uma demo de 69 comandos; a reproducao encerrou naturalmente
e gerou o mesmo snapshot de posicao, angulo, saude, municao, RNG e tempos.
O motor original finaliza gravacao pelo caminho I_Error com mensagem de
sucesso; a verificacao aceita esse comportamento somente com arquivo valido,
mensagem de gravacao e reproducao correspondente.
Relatorios: logs/fase1-storage/run-20261005-151358-177/result.json (PowerShell 7)
e logs/fase1-storage/run-20261005-151937-409/result.json (Windows PowerShell 5.1).
Os tres casos passaram tambem no ambiente 5.1 usado pelas tasks.

Launcher executado via Windows PowerShell: passou. Com -Mode Crysis -DebugInput
e um -playdemo de teste, encaminhou o modo e retornou a rejeicao esperada ao
chamador, sem abrir mapa ou janela. Logs em build/f1-launcher-check.
Os sete tasks Zed, JSON VS Code e sintaxe dos scripts PowerShell passaram;
git diff --check passou.

## Limites da evidencia

O harness usa stubs nas fronteiras; GDB injeta eventos, comandos e gameactions
somente nos processos de teste. Isso exercita os caminhos reais, sem comprovar
teclado/mouse fisicos, alt-tab real, imagem, audio ou uso do editor pela interface.
SDL dummy, renderer software e -nosound foram usados. Nao foi executada uma
partida multiplayer vanilla nem uma bateria completa de todas as demos/saves.
A F1 nao afirma completar o slice Crysis; a F2 e a proxima etapa de gameplay.
