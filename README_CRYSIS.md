# Crysis: Contact Demake — vertical slice (Fases 0–10, parcial)

Fork do Crispy Doom 7.1 com um modo Crysis ativado por `-crysis`: estado
paralelo do jogador, Nanosuit com quatro modos, armas com carregador/reload,
ADS com FOV real, attachments, ruído e percepção, soldado KPA com combate,
objetivos, jammer e saída. Sem o parâmetro, o motor permanece vanilla.

Estado: **sistemas implementados e execução no mapa técnico**, ainda sem
aceite final. O mapa Contact completo (praia → vila), as três abordagens e
correções de IA, mira e projeção continuam pendentes. Veja a
[revisão de 2026-10-15](docs/validacao/revisao-2026-10-15.md), com prioridades,
testes executados e limites. Relatórios históricos por fase em
`docs/validacao/fase-N.md`.

## Executar no Windows x64

### Zed

Abra a paleta de comandos e execute **task: spawn**. As tarefas locais estão
em `.zed/tasks.json`:

- **Crysis: preparar e executar (mapa tecnico)**: prepara IWAD/toolchain,
  compila e abre o PWAD com KPA, objetivos, jammer e saída.
- **Crysis: executar sem recompilar (mapa tecnico)**: reutiliza o executável.
- **Crysis: preparar e executar (MAP01)**: modo Crysis no Freedoom original,
  sem o PWAD técnico.
- **Vanilla: preparar e executar (MAP01)**: comparação sem `-crysis` e sem PWAD.
- **Crysis: diagnosticar controles (mapa tecnico)**: execução com `-crdebug`.
- Tarefas **validar F1**, **validar IA e combate (F6-F7)**,
  **validar mapa tecnico (F9 parcial)** e **validar ADS e FOV (F10 parcial)**:
  usam o build existente; execute **Crysis: compilar** antes se necessário.
  Os resultados ficam em `build/zed-f*`, sem substituir evidências históricas.

Na primeira preparação podem ocorrer downloads do GitHub, com versões e
hashes fixados nos scripts. O PWAD técnico já é versionado; Python 3 só é
necessário para regenerá-lo. As tarefas usam Windows PowerShell sem perfil e
limpam `PSModulePath` no processo filho para não herdar módulos incompatíveis
do PowerShell 7. Não alteram a configuração global do editor ou do sistema.

### VS Code

Aceite a extensão recomendada **C/C++** e use **F5** com o perfil
**Crysis: mapa tecnico (PWAD)**, **Crysis: modo Crysis (Freedoom MAP01)** ou
**Vanilla: Freedoom MAP01**.

### PowerShell

Na raiz do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-game.ps1 -Mode Crysis -Scenario Technical -Build
# Comparação vanilla, reutilizando o build:
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-game.ps1 -Mode Vanilla
```

`-Scenario` usa `Freedoom` por padrão para preservar o fluxo anterior.
`Technical` exige `-Mode Crysis` e recusa o lançamento com mensagem clara
se o PWAD estiver ausente. Para preparação manual e regeneração opcional:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-iwad.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-build.ps1 -Build
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/prepare-run.ps1

# Mapa tecnico com soldados, objetivos, jammer e saida:
python scripts/make-technical-pwad.py content/iwad/freedoom2.wad content/pwad/crysis-technical.wad
& .\build\src\crispy-doom.exe -crysis -iwad .\content\iwad\freedoom2.wad `
    -file .\content\pwad\crysis-technical.wad -warp 1 -window `
    -config .\build\run\default.cfg -extraconfig .\build\run\crispy-doom.cfg -savedir .\build\run
```

Sem `-file`, o modo roda no **MAP01 do Freedoom Phase 2**. Remova `-crysis`
para comparar com o vanilla. O IWAD necessário é o Freedoom Phase 2 0.13.0 já
fixado em `content/iwad`; um IWAD comercial de Doom II também funciona.

## Controles Crysis

| Controle | Comando | Comportamento |
|---|---|---|
| Shift | Sprint | Contínuo; corrida normal, e bônus de Speed com energia |
| Botão direito | ADS | Contínuo; spread menor, movimento reduzido, FOV real |
| R | Reload | Recarrega o carregador a partir da reserva |
| E | Interact | Usa linhas do projeto e portas/switches vanilla |
| Q | Suit next | Cicla Armor → Strength → Speed → Cloak |
| B | Fire mode | Alterna semi/auto quando a arma suporta |
| X | Attachments | Abre/fecha a lista; setas escolhem; E instala/remove |
| C | Crouch | Reservado; postura/collision seguem pendentes |

Bindings `key_cr_*`/`mouseb_cr_*` ficam em `build/run/crispy-doom.cfg`
(scancodes, não ASCII). Só `mouseb_cr_ads=1` vem habilitado. Feche o jogo antes
de editar a configuração.

## Sistemas

- **Nanosuit (F2):** energia 0–100, recarga com atraso; Armor absorve dano;
  Strength aumenta salto/melee e reduz recoil; Speed acelera o sprint; Cloak
  reduz a percepção e quebra ao atirar.
- **Saúde (F3):** regeneração após 5 s sem dano, 1 HP a cada 4 tics, teto 100.
- **Armas (F4):** SOCOM (semi), SCAR e FY71 (semi/auto), carregadores de 12/30,
  reservas independentes, reload temporizado e cancelável, recoil funcional.
- **ADS/attachments (F5):** Reflex e Scope (exclusivos), Suppressor com menor
  raio de ruído e som abafado; overlay em X.
- **Percepção (F6):** suspeita 0–100 por visão (cone, LOS, distância, Cloak) e
  audição (raio por arma e supressor); eventos de ruído com posição capturada.
- **KPA (F7):** patrulha → suspeita → investigação → alerta → combate → busca →
  retorno; rifle hitscan em rajadas; perde o contato após quebra de LOS.
- **Objetivos (F8):** IDs 1–2 principais, 3 jammer opcional, 4 saída; specials
  privados 300 (cruzar), 301 (usar), 302 (saída), 303 (jammer); saídas vanilla
  11/51/52 exigem os objetivos principais.
- **HUD:** vida, energia, modo da suit, arma/carregador/reserva/modo de tiro,
  objetivo atual, lista de attachments e overlay de scope.

## Bloqueios e limites

- Save/load, demos e rede permanecem bloqueados no modo Crysis; no vanilla
  seguem normais.
- O mapa técnico deriva do MAP01 do Freedoom (geometria intacta; veja
  `content/pwad/README.md`). O slice Contact detalhado (praia/floresta/vila)
  ainda não existe.
- Performance em hardware de referência, tuning por playtest e as três
  abordagens (combate, stealth, jammer) continuam pendentes.
- Crouch, radar, granadas, objetos arremessáveis e menus radiais estão fora do
  escopo, como no plano.

## Validação

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f2.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f3.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f4.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f5.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f6.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f8.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-map.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f10-fov.ps1
```

Fontes das suites em `scripts/`; resultados e capturas em
`docs/validacao/logs/`. Os testes usam SDL dummy e `-nosound`; não substituem
teclado/mouse/áudio reais nem playtest.
