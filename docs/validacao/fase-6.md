# Fase 6 — Ruído e percepção

Data: 2026-10-14.
Base: `eb42e3c7` + Fase 5. As Fases 6 e 7 foram implementadas em conjunto
(percepção e soldado compartilham o registro e o tick); a Fase 7 tem relatório
próprio.

## Arquivos

- Novos: `src/doom/cr_ai.c`, `src/doom/cr_ai.h`.
- Alterados: `src/doom/cr_sound.[ch]` (dispatch imediato de eventos),
  `src/doom/p_mobj.c` (registro de spawn/remoção), `src/doom/cr_game.c`
  (lifecycle do registro), `src/doom/CMakeLists.txt`.
- Testes: `scripts/test-f6.ps1` (probes de motor via GDB).

## Regras implementadas

| Regra | Detalhe |
|---|---|
| Eventos de ruído | `CR_EmitNoise` captura posição/raio/tipo e despacha na hora |
| Alcance | distância ao evento ≤ raio declarado; ganho cai perto da borda |
| Supressor | raio ×0.3 e ganho auditivo menor (`SUPPRESSED_GUNSHOT`) |
| Percepção visual | cone (45°/90° alertado), distância ≤ 1100, `P_CheckSight` |
| Suspeita | acumulador fixo 0..100; fatores fracionários não truncam |
| Cloak | ganho multiplicado por `CR_SuitVisibilityFactor` |
| Frequência | LOS a cada 2 tics alertado / 4 tics calmo |
| Instrumentação | contadores de registrados/vivos/combate + logs de transição |

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f6.ps1
```

- `noise-unsuppressed`: tiro a 600 unidades leva KPA de PATROL a INVESTIGATE.
- `noise-suppressed`: com supressor (raio ~300) o mesmo tiro não gera reação.
- `cloak-delays-detection`: 195 tics de visão direta sob Cloak ficam abaixo do
  limiar de investigação e sem dano, contra COMBAT rápido sem Cloak.
- `vanilla-ai-isolated`: sem `-crysis`, zero registros/thinks.

## Limitações

- Ruído de passos/impactos/explosões ainda não conectado (só tiros).
- Atores criados por GDB porque o mapa técnico (F2.8/F9) ainda não existe.
