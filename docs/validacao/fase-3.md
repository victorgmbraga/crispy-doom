# Fase 3 — Health regeneration e HUD mínimo

Data: 2026-10-14.
Base: `93c3263b` + Fase 2.
Escopo entregue: F3.1–F3.4.

## Arquivos

- Novos: `src/doom/cr_hud.c`, `src/doom/cr_hud.h`.
- Alterados: `src/doom/cr_player.[ch]` (regen, `CR_PlayerLevelStart`),
  `src/doom/cr_game.c` (limpeza de timers na entrada de nível),
  `src/doom/st_stuff.c` (hook do HUD), `src/doom/CMakeLists.txt`.
- Testes: `scripts/f3-regen-test.c`, `scripts/test-f3.ps1`.

## Regras implementadas

| Regra | Valor / ponto |
|---|---|
| Delay de regeneração | 5 s (175 tics) desde o último dano |
| Passo de regeneração | 1 HP a cada 4 tics |
| Teto | 100, sem reduzir vida acima do teto |
| Morto não regenera | `playerstate != PST_LIVE` sai do caminho |
| Sincronia | `player->health` e `player->mo->health` sempre juntos |
| Transição de nível | `last_damage_tic`/acumulador zerados em `CR_LevelStart` |
| HUD | HP (verde/amarelo/vermelho), energia (azul/vermelho), modo da suit |

O HUD substitui visualmente a barra de status: desenha uma faixa opaca e
sobrepõe o texto, preservando mensagens, menu e automap do upstream.

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f3.ps1
```

- `logic`: regeneração bloqueada antes do delay, passo correto, reinício por
  dano, teto, morto e gate vanilla.
- `engine-regen-hud`: no motor, HP 60→65 após 195 tics, `mo->health` igual,
  pausa congela a regeneração, HUD desenha, captura `DOOM0000.pcx` gerada.
- `vanilla-hud-isolated`: 60 tics vanilla sem `CR_HUDDraw`/`CR_PlayerThink`.

Captura de evidência: `docs/validacao/logs/fase3/engine-regen-hud/DOOM0000.pcx`.

## Limitações

- A captura prova que o desenho ocorreu; legibilidade em todos os modos de tela
  (widescreen, tamanhos de fonte) não foi revisada visualmente a fundo.
- Teste headless (SDL dummy, `-nosound`).
