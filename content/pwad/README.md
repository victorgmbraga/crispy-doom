# Mapa tecnico Crysis (PWAD derivado)

Arquivos:

- `crysis-technical.wad` — PWAD com a substituicao de `MAP01`.
- `crysis-technical.info` — indices das linhas de projeto (gerado junto).

## Procedencia

- Base: `content/iwad/freedoom2.wad` (Freedoom Phase 2 0.13.0), hashes e
  licenca registrados em `content/iwad/ORIGEM.md` e `COPYING-FREEDOOM.txt`.
- Gerador: `scripts/make-technical-pwad.py` (somente biblioteca padrao).
- Nenhum asset comercial de Crysis foi usado.

## Modificacoes em relacao ao MAP01 original

- Geometria intacta: VERTEXES, SIDEDEFS, SEGS, SSECTORS, NODES, SECTORS,
  REJECT e BLOCKMAP sao copiados byte a byte; os NODES originais seguem validos.
- THINGS: os dez monstros mais proximos do inicio viram soldados KPA
  (DoomEd 30001), mantendo posicao e flags de spawn.
- LINEDEFS: quatro linhas sem uso proximas ao inicio recebem os specials do
  projeto (os indices ficam em `crysis-technical.info`):
  - `301` tag 1 e tag 2 — objetivos principais (usar com E);
  - `303` — jammer opcional (usar com E);
  - `302` — saida da missao (usar com E, liberada apos os objetivos).
- As saidas originais do mapa continuam valendo, mas ficam condicionadas aos
  objetivos no modo Crysis (specials 11/51/52).

## Execucao

```powershell
& .\build\src\crispy-doom.exe -crysis -iwad .\content\iwad\freedoom2.wad -file .\content\pwad\crysis-technical.wad -warp 1 -window
```

Regeneracao (o IWAD precisa conferir com o hash fixado):

```powershell
python scripts/make-technical-pwad.py content/iwad/freedoom2.wad content/pwad/crysis-technical.wad
```

## Limites

Este e o mapa **tecnico** de validacao (F2.8 e base da F9). O slice completo
praia → vila → jammer → saida, com greybox proprio, ainda depende de editor de
mapas e permanece pendente.
