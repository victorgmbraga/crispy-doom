# Fase 4 — Armas, munição, reload e recoil

Data: 2026-10-14.
Base: `098638d5` + Fase 3.
Escopo entregue: F4.1–F4.8 (F4.7 no formato de loadout completo, sem mapa técnico).

## Arquivos

- Novos: `src/doom/cr_weapon.c`, `src/doom/cr_weapon.h`,
  `src/doom/cr_sound.c`, `src/doom/cr_sound.h` (base do ruído; consumo pela IA na Fase 6).
- Alterados: `src/doom/cr_player.[ch]` (estado de arma, espelho `reloading`),
  `src/doom/p_pspr.c` (P_FireWeapon/P_CheckAmmo, despacho pula ações vanilla de tiro),
  `src/doom/p_inter.c` (pickups), `src/doom/p_user.c` (`CR_WeaponTick`),
  `src/doom/cr_hud.c` (linha de arma), `src/doom/cr_game.c` (reset de ruído),
  `src/doom/CMakeLists.txt`.
- Testes: `scripts/f4-weapon-test.c`, `scripts/test-f4.ps1`; fixtures
  F1–F3 ganharam stubs de fronteira do módulo de armas.

## Regras implementadas

| Regra | Detalhe |
|---|---|
| Transporte | fist/pistol/chaingun/plasma → MELEE/SOCOM/SCAR/FY71 |
| Loadout | as três armas e a melee desde a nova partida; carregadores cheios |
| Magazine/reserve | fonte de verdade; pickups adaptados a reservas |
| Cadência | RPM nominal convertido em tics; teto também pela animação |
| Semi/auto | semi exige borda nova; auto segue o botão mantido |
| Reload | temporizado, transferência única `min(necessário, reserva)`, cancelado por troca/morte |
| Spread | hip/ADS e penalidade de sprint alteram a direção real do tiro |
| Recoil | `recoilpitch` funcional, escalado por ADS e Strength |
| Cloak | disparo real quebra o Cloak via `CR_SuitOnWeaponFired` |
| Ruído | `CR_EmitNoise` com posição capturada; suppressor já reduz o raio |
| HUD | nome, carregador, reserva, modo de tiro e indicador de reload |
| Vanilla | `P_FireWeapon`/`P_CheckAmmo` intactos sem `-crysis`; ações de tiro vanilla não coexistem no modo Crysis |

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f4.ps1
```

- `logic`: 75 asserções em `cr_weapon.c` real (semi/auto, reload, cancelamento,
  reservas independentes, pickups, spread, ruído, fallback de arma vazia).
- `engine-weapon`: dois tiros automáticos reais com cadência limitada pela
  animação, munição vanilla intacta, exatamente 2 `P_LineAttack` (sem tiros
  vanilla extras), reload completo pelo teclado R.
- `vanilla-weapon-isolated`: nenhuma chamada Crysis de arma no modo vanilla e a
  pistola vanilla continua consumindo munição.

## Limitações e pendências

- Cadência efetiva do SCAR medida em ~8 tics por tiro (≈262 RPM) porque a
  animação transportada a limita; nominal 600 RPM. Ajuste de animação/tuning
  fica para a Fase 10.
- F4.7 sem mapa técnico: o loadout cobre todas as armas sem cheats.
- Spread e recoil não foram medidos em alvos reais neste harness.
