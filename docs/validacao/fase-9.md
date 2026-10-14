# Fase 9 (parcial) — Mapa tecnico

Data: 2026-10-14.
Base: `9a4a6b9e` + Fase 10 (FOV).
Escopo entregue: mapa tecnico jogavel com KPA, objetivos, jammer e saida
(F2.8 e base da F9). O slice Contact completo (praia → vila) permanece pendente.

## Arquivos

- Novos: `scripts/make-technical-pwad.py`, `content/pwad/crysis-technical.wad`,
  `content/pwad/crysis-technical.info`, `content/pwad/README.md`.
- Alterados: `src/doom/cr_interact.c` (saidas vanilla 11/51/52 condicionadas
  aos objetivos; linhas de projeto reutilizaveis; jammer de uso unico),
  `src/doom/p_setup.c` (specials 300–303 reconhecidos sem avisos).
- Testes: `scripts/test-map.ps1`.

## Decisoes

- O mapa tecnico deriva do MAP01 do Freedoom com **geometria intacta**
  (NODES/SEGS/BLOCKMAP originais) e altera somente THINGS e LINEDEFS. Isso
  evita um editor/BSP de mapas nesta fase e usa os spawn points validados do
  IWAD para posicionar os soldados.
- Soldado KPA com DoomEd **30001** (3001 e o imp vanilla; conflito corrigido).
- Saidas vanilla passam a exigir os objetivos principais no modo Crysis.
- Linhas de objetivo sao reutilizaveis: o primeiro uso ativa, o segundo
  completa; o jammer e unico e nao duplica efeitos.

## Verificacao

```powershell
python scripts/make-technical-pwad.py content/iwad/freedoom2.wad content/pwad/crysis-technical.wad
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-map.ps1
```

- `technical-map`: com o PWAD, KPA registrados no inicio; objetivos 1 e 2 e
  jammer completados pelas linhas reais do mapa; saida liberada, passa pela
  intermission e carrega MAP02.
- `technical-map-refuse`: saida antecipada recusada no mapa real.
- Captura: `docs/validacao/logs/fase9/technical-map/DOOM0000.pcx`.

## Limites

- Nao e o slice Contact (praia/floresta/vila/saida); e um mapa tecnico de
  validacao com a geometria do Freedoom.
- Percurso jogavel completo e as tres abordagens (combate/stealth/jammer)
  exigem playtest humano e permanecem pendentes (F9).
