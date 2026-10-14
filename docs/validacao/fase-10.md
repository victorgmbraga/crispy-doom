# Fase 10 (parcial) — FOV real e overlay de scope

Data: 2026-10-14.
Base: `c883d52c` + Fase 8.
Escopo entregue: F10.4 e F10.6 (parcial). Performance, tuning e playtest
seguem pendentes de hardware/uso humano.

## Arquivos

- Novos: `src/doom/cr_render.[ch]`.
- Alterados: `src/doom/r_main.c` (FOV variável em `R_InitTextureMapping`),
  `src/doom/cr_weapon.c` (atualização por tic), `src/doom/cr_hud.c`
  (moldura do scope), `src/doom/CMakeLists.txt`.
- Testes: `scripts/test-f10-fov.ps1`.

## Regras

| Situação | FOV |
|---|---|
| Padrão / ADS desligado | 2048 (igual ao `FIELDOFVIEW` original) |
| ADS | 1024 |
| ADS com scope instalado | 768 |

- As tabelas de projeção só são reconstruídas quando o FOV muda.
- Transição instantânea, como o plano permite.
- Overlay de scope: moldura preta com centro livre, desenhada após o render.
- O tiro usa o mesmo ângulo real; o FOV afeta apenas a projeção.

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f10-fov.ps1
```

- `ads-fov`: sequência 1024 → 768 → 2048 observada no motor; captura com
  scope visível (`DOOM0007.pcx`).
- `vanilla-fov-isolated`: projeção fixa 2048 no modo vanilla.

## Pendências da Fase 10

- Perfil de performance em hardware de referência e p95/p99 (F10.1–F10.3).
- Ajustes de áudio, animações e balanceamento por playtest (F10.7).
- Pacote reproduzível e limitações conhecidas (F10.8).
