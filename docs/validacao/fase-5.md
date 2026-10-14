# Fase 5 — ADS e attachments

Data: 2026-10-14.
Base: `d2fc1473` + Fase 4.
Escopo entregue: F5.1–F5.5 (Etapa A do plano: sem FOV real).

## Arquivos

- Alterados: `src/doom/cr_weapon.[ch]` (overlay, compatibilidade, psprite de ADS,
  som suprimido), `src/doom/cr_input.c` (overlay consome navegação/tiro),
  `src/doom/cr_nanosuit.c` (sprint bloqueado no reload),
  `src/doom/p_pspr.c` (hook de psprite em A_WeaponReady),
  `src/doom/cr_hud.c` (lista de attachments e marcador ADS),
  `src/doom/hu_stuff.c` (overlay desenhado após o render do mundo),
  `src/doom/s_sound.[ch]` (`S_StartSoundAtVolume` para tiro suprimido).
- Testes: `scripts/f5-ads-test.c`, `scripts/test-f5.ps1`.

## Regras implementadas

| Regra | Detalhe |
|---|---|
| ADS | spread reduzido (já na F4), movimento ×0.5, psprite centrado sem bob, recoil ×2/3 |
| Overlay | X abre/fecha; setas (via comando) navegam; E instala/remove |
| Comando | overlay aberto zera movimento, giro e gatilho/uso do ticcmd |
| Compatibilidade | máscara por arma; SOCOM/SCAR/FY71 têm listas próprias |
| Reflex × scope | mutuamente exclusivos |
| Suppressor | raio de ruído ×0.3, tipo `SUPPRESSED_GUNSHOT`, som em volume reduzido |
| Precedência | ADS suspende sprint; reload bloqueia tiro e sprint; morte/transição fecha overlay |
| HUD | linha de arma com ADS e lista de attachments após o render |

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f5.ps1
```

- `logic`: abertura/fechamento, navegação com wrap, consumo de comando,
  compatibilidade por arma, exclusividade reflex/scope, raio suprimido,
  fechamento por morte, psprite de ADS e bloqueio de sprint no reload.
- `engine-ads-overlay`: overlay aberto pelo X real, suppressor instalado pelo E,
  ADS ativo com `psp->sx=FRACUNIT`/`sy=WEAPONTOP`, captura `DOOM0002.pcx`.
- `vanilla-ads-isolated`: nenhum `CR_WeaponTick` e overlay inerte no vanilla.

Captura: `docs/validacao/logs/fase5/engine-ads-overlay/DOOM0002.pcx`.

## Limitações

- FOV real (Etapa B) e overlay de scope ficam para a Fase 10, como o plano permite.
- Suppressor usa volume reduzido como placeholder de som; sem assets próprios.
- Sensibilidade de mouse por ADS permanece opcional e não foi alterada.
