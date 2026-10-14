# Fase 2 — Nanosuit e movimento

Data: 2026-10-14.
Base: `93c3263b` (Fase 1 integrada no fork).
Escopo entregue: F2.1–F2.7 do plano; F2.8 (mapa técnico) pendente.

## Arquivos

- Novos: `src/doom/cr_nanosuit.c`, `src/doom/cr_nanosuit.h`.
- Alterados: `src/doom/cr_player.[ch]` (suit no estado paralelo, `CR_PlayerNoteDamage`),
  `src/doom/p_user.c` (fator de movimento, salto, tick da suit),
  `src/doom/p_inter.c` (absorção de dano),
  `src/doom/p_pspr.c` (dano melee, recoil, tiro revela cloak),
  `src/doom/CMakeLists.txt`.
- Testes: `scripts/f2-suit-test.c`, `scripts/test-f2.ps1`; `scripts/test-f1.ps1`
  passou a compilar `cr_nanosuit.c` e `m_fixed.c`.

## Regras implementadas

| Regra | Onde |
|---|---|
| Quatro modos, Q cicla por borda | `cr_nanosuit.c`, hook em `P_PlayerThink` |
| Energia 0..100, recarga 1/tic após 35 tics | `CR_SuitTick`, `CR_SuitConsume`, `DrainRate` |
| Drenos por contador de tics (8/3/2) | `CR_SUIT_*_DRAIN_TICS` |
| Armor absorve dano integral ou parcial, delay reinicia | `CR_SuitAbsorbDamage` em `P_DamageMobj` |
| Energia zero → modo volta a Armor | `CR_SuitConsume`/`DrainRate` |
| Sprint Factor, Speed ×1.5, ADS ×0.5 | `CR_SuitMoveFactor` em `P_MovePlayer` |
| Strength: salto ×1.5, melee ×2, recoil ×0.5 | `CR_SuitJumpMomentum`, `CR_SuitMeleeDamage`, `CR_SuitRecoilScale` |
| Cloak: visibilidade 0.05/0.15/0.35, tiro quebra | `CR_SuitVisibilityFactor`, `CR_SuitOnWeaponFired` |
| Vanilla intacto | todas as APIs retornam sem efeito sem `-crysis` |

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f2.ps1
```

- `logic`: 70 asserções em `cr_nanosuit.c`/`cr_player.c` reais com stubs de motor.
- `engine-suit`: GDB observa dreno de cloak, quebra por disparo real, dreno de
  Speed, recarga após 35 tics e salto Strength na execução do motor.
- `vanilla-suit-isolated`: 60 tics sem qualquer chamada `CR_SuitTick`/`CR_PlayerThink`.
- `vanilla-snapshot`: demo F0 mantém o snapshot do baseline.

## Limitações

- Sem mapa técnico dedicado (F2.8): os cenários usam MAP01 do Freedoom.
- Teste headless (SDL dummy, `-nosound`); sem playtest humano.
- Valores de balanceamento são os iniciais do plano, sujeitos a tuning.
