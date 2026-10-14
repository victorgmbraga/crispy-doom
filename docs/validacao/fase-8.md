# Fase 8 — Objetivos, interação e jammer

Data: 2026-10-14.
Base: `2f5346fb` + Fases 6–7.

## Arquivos

- Novos: `src/doom/cr_objective.[ch]`, `src/doom/cr_interact.[ch]`.
- Alterados: `src/doom/p_spec.c` (precedência no cruzamento),
  `src/doom/p_switch.c` (precedência no uso),
  `src/doom/cr_game.c` (reset da missão), `src/doom/cr_hud.c`
  (objetivo atual), `src/doom/CMakeLists.txt`.
- Testes: `scripts/f8-objective-test.c`, `scripts/test-f8.ps1`.

## Contrato de mapa (specials privados)

| Special | Uso | Tag | Efeito |
|---|---|---|---|
| 300 | Cruzar | id do objetivo | LOCKED→ACTIVE→COMPLETE, uma vez por linha |
| 301 | Usar | id do objetivo | idem, via E |
| 302 | Usar | — | sai se todos os objetivos principais exceto a saída estiverem completos; repetível |
| 303 | Usar | — | completa o jammer (opcional), som + troca de switch |

Faixa 300–303 auditada acima dos specials do motor (máximo 272).
Os exemplos 220–222 da especificação não foram usados.

## Regras

- IDs estáveis 1–4; tabela fixa; `LOCKED/ACTIVE/COMPLETE/FAILED`.
- Eventos repetidos são idempotentes; objetivo completo nunca reabre.
- Explicitar `Activate` também reativa um objetivo falho.
- Saída antecipada mostra mensagem e não troca de nível.
- Jammer opcional nunca bloqueia a saída.
- IDs desconhecidos são rejeitados sem tocar a tabela.
- Vanilla: dispatch original intacto quando `-crysis` está ausente.

## Verificação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f8.ps1
```

- `logic`: 29 asserções de transições, idempotência, falha/reativação,
  IDs inválidos, `Current` e `CanExit`.
- `mission-objectives`: linhas reais mutadas para 301/303/302 pelo caminho
  `P_UseSpecialLine`; recusa de saída antecipada; jammer completo; saída
  completa o objetivo 4, passa pela intermission e carrega MAP02.
- `vanilla-objectives-isolated`: specials 300–303 inertes no modo vanilla.

Captura: `docs/validacao/logs/fase8/mission-objectives/DOOM0000.pcx`
(objetivo no topo, mensagem JAMMER DISABLED).

## Limitações

- O mapa técnico com essas linhas ainda não existe; o teste reutiliza linhas
  reais do IWAD mutadas em memória.
