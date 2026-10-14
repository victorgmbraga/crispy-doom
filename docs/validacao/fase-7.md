# Fase 7 — Soldado KPA e combate

Data: 2026-10-14.
Base: `eb42e3c7` + Fase 5 (implementada junto com a Fase 6).

## Arquivos

- `src/doom/info.[ch]`: tipo `MT_CR_KPA` (DoomEd 3001) e estados
  `S_CR_KPA_*` na faixa reservada 3900–3915 (`S_CR_STATES_*`).
- `src/doom/deh_ptr.c`: a faixa reservada sobrevive a `DEH_PointerInit`.
- `src/doom/deh_thing.c`: drop de clip como o zombieman.
- `src/doom/cr_ai.[ch]`: máquina de estados, combate e ações.
- `src/doom/p_mobj.c`: registro no spawn e remoção.

## Máquina de estados

```text
PATROL → SUSPICIOUS → INVESTIGATE → SEARCH → RETURN
   └────────────→ ALERT → COMBAT ──┘
```

| Estado | Comportamento |
|---|---|
| PATROL | âncora no spawn; sem busca global de alvo |
| SUSPICIOUS | para e encara o último estímulo; timeout volta/segue |
| INVESTIGATE | caminha até a última posição vista/ouvida |
| ALERT | reação de 12 tics antes do combate |
| COMBAT | encara, avança se longe, rajada de 3 hitscans a cada 35 tics |
| SEARCH | varre o último local conhecido por ~3 s |
| RETURN | volta ao spawn e zera suspeita |

- Alvo (`actor->target`) só é atribuído após visual válido; nunca através de
  parede. Perda de contato após 70 tics sai de COMBAT.
- Movimento reutiliza `P_Move`/`P_TryWalk`/`P_NewChaseDir`.
- Rifle: 8 de dano por projétil, spread por distância; rajada emite ruído.
- Registro externo (`cr_ai_actors`), máximo 64, criado no spawn e removido
  antes de liberar o mobj; sem heap por tic.

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f6.ps1
```

- `perception-combat`: PATROL→SUSPICIOUS (tic 13)→ALERT (43)→COMBAT (63),
  dano real absorvido pelo Armor (energia < 100).
- `kill-and-remove`: morte + remoção limpam o registro sem crash.
- `loss-of-contact`: após COMBAT, afastar o jogador para além da visão termina
  em SEARCH/RETURN, sem perseguição permanente.

## Limitações

- Sprites/sons reutilizados do zombieman (placeholder), como o plano permite.
- Rotas de patrulha por marcadores de mapa (F7.3) dependem do mapa técnico.
- Sem navegação global; destino inalcançável cai no timeout existente.
- Criação de atores nos testes via GDB; o mapa técnico ainda não existe.
