# Fase 0 — infraestrutura implementada e validação automatizada

Data: 2026-10-05. Plataforma: Windows x64.

O Crispy Doom compila e executa com e sem `-crysis`. A ativação imprime
`[CRYSIS] mode enabled` uma única vez, e os callbacks mínimos de ciclo de vida
estão integrados. Os testes automatizados passaram; os playtests visuais, de
áudio e de entrada por teclado/mouse ainda não foram executados.

O recorte segue a seção 11 do [plano](../../PLANO_IMPLEMENTACAO_CRYSIS_CRISPY_DOOM.md)
e a seção 36 da [especificação](../../CODEX_IMPLEMENTACAO_CRYSIS_CRISPY_DOOM.md):
**“Execute somente a Fase 0.”** O demake completo permanece nas Fases 1–10.
Esta entrega executa mapas do Freedoom, sem Nanosuit, armas Crysis, HUD próprio,
IA nova, objetivos, jammer ou mapa Contact.

## Origem e baseline

- Upstream oficial: https://github.com/fabiangreffrath/crispy-doom
- Tag: `crispy-doom-7.1` (versão 7.1.0).
- SHA-base: `0a022e0ee6c74d9bab173ed9ee5212312e90ce3a`.
- Revisão testada do fork: esse SHA mais as alterações locais descritas abaixo;
  nenhum commit de implementação foi criado.
- O upstream foi clonado em `.upstream-baseline`, e cada entrada foi movida
  para a raiz somente após verificar a ausência de colisões. Os dois documentos
  existentes foram preservados. Não havia código, Git, IWAD ou AGENTS.md local.
- `git diff` dos arquivos upstream estava vazio na compilação e no smoke do
  baseline, antes da aplicação dos módulos e hooks Crysis.

O terminal isolado não conseguia criar processos neste ambiente. Os comandos
de preparação, build e testes foram executados com a permissão de execução
externa do ambiente, mantendo arquivos e ferramentas dentro do projeto.

## Toolchain e dependências

| Componente | Versão / configuração |
|---|---|
| Linguagem | C99, conforme CMake upstream |
| GCC x64 | 16.2.0, w64devkit 2.10.0 |
| GDB | 17.2, mesmo pacote portátil |
| CMake | 3.31.12 |
| Gerador | MinGW Makefiles, 4 jobs |
| Build | RelWithDebInfo, renderer por software, truecolor desativado |
| SDL2 | 2.32.10 |
| SDL2_mixer | 2.8.2, habilitado |
| SDL2_net | 2.4.0, habilitado |
| Opcionais ausentes | SampleRate, PNG/ZLIB e FluidSynth |

`scripts/setup-build.ps1` fixa URLs oficiais e SHA256 dos cinco pacotes,
instala em `.tools`/`.deps`, restaura o PATH ao terminar e copia as três DLLs
SDL para junto do executável. Não instala software globalmente.

A primeira compilação original falhou em `src/i_video.c:989`: `pow()` era
usado sem declaração. Para compilar esse upstream com GCC 16 sem alterar seu
fonte, o script passa `-DCMAKE_C_FLAGS=-include math.h`. Baseline e fork usam
o mesmo ajuste. A falha inicial está preservada em
`logs/baseline-initial-failed-build.log`.

A configuração inicial também encontrou um escape inválido em caminho Windows
de `windres`. Os caminhos passados nas definições CMake agora usam `/`. A captura
de stderr foi verificada no PowerShell 5.1: warning com exit 0 não interrompe o
build; exit 7 produz falha; a preferência de erro é restaurada nos dois casos.

Os dois builds finais passaram e emitiram os mesmos **14 warnings**:
6 em `r_plane.c` (`%td`), 2 em `i_system.c` (`%zu`), 2 em `m_misc.c` (`%zu`)
e 4 em `v_video.c` (declarações após comandos). Nenhum warning novo do fork.
O aviso CMake sobre compatibilidade anterior a 3.10 também vem do upstream.

## Arquivos e decisões de integração

| Arquivo | Alteração |
|---|---|
| `src/doom/cr_defs.h` | Constantes de argumento e prefixo de log |
| `src/doom/cr_game.h` | API mínima `CR_IsActive/Init/NewGame/LevelStart/LevelEnd/Ticker` |
| `src/doom/cr_game.c` | Ativação e estado privado de inicialização/nível, sem gameplay |
| `src/doom/CMakeLists.txt` | Registro dos três novos arquivos |
| `src/doom/d_main.c` | Init após banner; limpeza no título e na troca da sequência de demos |
| `src/doom/g_game.c` | NewGame em `G_InitNew`; LevelEnd em `G_DoCompleted` |
| `src/doom/p_setup.c` | LevelEnd antes de `Z_FreeTags`; LevelStart após spawn/precache |
| `src/doom/p_tick.c` | Ticker após guards de pausa/menu e antes de PlayerThink |
| `.gitignore` | Exclusão das ferramentas portáteis; inclusão dos três JSON de VS Code |

Arquivos de suporte criados:

- `scripts/setup-build.ps1`, `setup-iwad.ps1` e `prepare-run.ps1`.
- `scripts/smoke-test.ps1`, `trace-snapshot.ps1` e `trace-lifecycle.ps1`.
- `.vscode/launch.json`, `tasks.json` e `extensions.json`.
- `README_CRYSIS.md`.
- `content/iwad/.gitignore`, `ORIGEM.md`, `COPYING-FREEDOOM.txt`,
  `CREDITS-FREEDOOM.txt` e `CREDITS-MUSIC-FREEDOOM.txt`.
- Este relatório e evidências em `docs/validacao/logs`.

`CR_Init()` é idempotente e centraliza a única consulta ao argumento. Sem o
modo ativo, os hooks não chamam os callbacks de gameplay e nenhum callback de
saída novo é registrado. Em Crysis, `I_AtExit(CR_LevelEnd, true)` cobre saída
normal e erro. O boolean privado de nível torna a limpeza idempotente.

`G_InitNew()` também atende demos e a base de carregamento de saves. Por isso
esta fase não retém referências a atores: o unarchive do save pode substituí-los
depois de `P_SetupLevel()`. Na Fase 1, bloquear saves/demos/rede antes de criar
estado incompatível e adaptar os testes que hoje usam demos vanilla.

O ticker pertence à simulação, antes dos jogadores e thinkers, e não avança
durante pausa/menu. Nesta fase ele reserva o ponto de coordenação dos módulos
futuros; não altera jogador, física, armas, HUD, RNG ou estado do mundo.

## Comandos de build e testes

Executados na raiz `C:\Users\victor.braga\crysis-crispy-doom`:

```powershell
git status --short
git rev-parse HEAD
& .\scripts\setup-iwad.ps1
& .\scripts\setup-build.ps1 -Build -BuildDirectory build-baseline -LogPrefix baseline
& .\scripts\smoke-test.ps1 -Mode Baseline -Executable build-baseline/src/crispy-doom.exe -LogDirectory docs/validacao/logs/baseline-smoke
& .\scripts\trace-snapshot.ps1 -Mode Baseline -Executable build-baseline/src/crispy-doom.exe -DemoPath docs/validacao/logs/baseline-smoke/fase0-smoke.lmp -LogDirectory docs/validacao/logs/baseline-snapshot
& .\scripts\setup-build.ps1 -Build -BuildDirectory build -LogPrefix fase-0
& .\scripts\smoke-test.ps1
& .\scripts\trace-snapshot.ps1
& .\scripts\trace-lifecycle.ps1
& .\scripts\prepare-run.ps1
git diff --check
```

Os argumentos CMake efetivos estão definidos em `scripts/setup-build.ps1`;
os logs registram a saída de configuração e compilação. O script configura
`-G "MinGW Makefiles"`, `-DCMAKE_BUILD_TYPE=RelWithDebInfo`, o cabeçalho forçado
e caminhos absolutos para GCC, make, windres e os prefixos SDL locais. Compila
`--target crispy-doom --parallel 4`.

## Resultados observados

| Verificação | Resultado e evidência |
|---|---|
| Build original | Passou; `logs/baseline-build.log` |
| Build fork | Passou; `logs/fase-0-build.log` |
| Warnings comparados | Idênticos, 14 em cada build; `logs/regression-comparison.json` |
| Smoke original | Exit 0, sem log CR; `logs/baseline-smoke/result.json` |
| Smoke vanilla do fork | Exit 0, sem log CR; `logs/smoke/result.json` |
| Smoke Crysis | Exit 0, uma mensagem de ativação |
| `-crysis` repetido | Exit 0, uma mensagem de ativação |
| Simulação comparada | Três snapshots do fork iguais ao original; `logs/snapshot/result.json` e `logs/baseline-snapshot/result.json` |
| Nova partida/reload/transição | Passou nos dois modos por GDB; `logs/lifecycle/result.json` |
| Pausa/menu | Timers e chamadas CR congelados por GDB nos dois modos |
| Cleanup final | Crysis terminou com nível inativo, após callbacks de saída |
| Ordem de cleanup antes de liberar atores | Confirmada na inspeção de `p_setup.c`; não medida pelo trace |
| Sintaxe PowerShell e JSON de VS Code | Passou |
| Diff/whitespace | `git diff --check` passou |

O smoke usa uma demo Doom 1.9 própria com 175 comandos de movimento, giro,
tiro, uso e pausa. O processo encerra naturalmente. O GDB lê o estado final
sem alterá-lo; baseline, vanilla, Crysis e argumento repetido produziram:

```text
map=1 gametic=175 leveltime=170
x=8718787 y=-12575414 z=-2097152 angle=1342177280
health=100 mobjhealth=100 bullets=46 rng=34 paused=0
```

A munição inicial 50 terminou em 46, e os cinco tics de pausa explicam
`175 - 170`. A comparação demonstra equivalência nesta sequência controlada,
sem constituir uma regressão completa de todos os recursos vanilla.

O diagnóstico de lifecycle abre MAP01 com `-warp 1 -nomonsters`, injeta apenas
estados/ações existentes no processo e testa nova partida, recarga do nível,
conclusão, avanço para MAP02, pausa/menu e saída. Crysis registrou 2 NewGame,
4 LevelStart, 4 limpezas efetivas e 124 tics CR em 150 chamadas a G_Ticker.
Vanilla registrou zero chamadas CR. Os dois terminaram normalmente com exit 0,
`menu_frozen=1`, `pause_frozen=1` e `level_active=0`.

O primeiro harness de lifecycle parou em um breakpoint durante `call I_Quit()`
pelo GDB e corretamente reportou falha. O harness foi corrigido para redirecionar
a execução na entrada de G_Ticker ao encerramento normal; os dois casos passaram
com exit 0 estrito. Não foi necessário alterar o motor.

## Conteúdo e hashes

IWAD: `content/iwad/freedoom2.wad`, Freedoom Phase 2 0.13.0, compatível com MAPxx.
Origem, licença e créditos estão em [ORIGEM.md](../../content/iwad/ORIGEM.md).
Nenhum conteúdo comercial de Doom ou Crysis foi incorporado.

| Artefato | SHA256 |
|---|---|
| IWAD Freedoom2 | `a8772e088847032510d97ba2312406a6998f21cbab44d4ff10696faa9c0ecd4b` |
| Demo de smoke | `7200bae8be45a224666fd7173a0c0e41aabde372b3182ca49975e1dc7b2cf5ce` |
| Executável baseline | `c21b894fdf2a1e0de2db757d9d2710ae901f285ddc39d017c7ba0f3606576047` |
| Executável fork | `f486b90831b74f5622ebd2280c57c635f027f41dbdf7a1284d10dd5d9eaf3edb` |
| Plano preservado | `2e75297d5e52e45e2bd284ff9096283a313516caf0e4cbadfd32a626affdfa6f` |
| Especificação preservada | `f834880610b18728a28fd2583b695e5cd950c2a4e4edbe26d677de8a51cdfcba` |

## Execução e pendências de aceite

O executável final é `build/src/crispy-doom.exe`. No VS Code, instalar a extensão
C/C++ recomendada, escolher **Crysis: Fase 0 (MAP01)** e usar F5. O perfil vanilla
permite a comparação. As instruções completas estão no
[README_CRYSIS.md](../../README_CRYSIS.md).

Não executados: playtest de imagem/áudio perceptíveis, teclado/mouse, menu e
restart por controles reais, save/load interativo, netplay e regressão ampla de
IA/HUD. Os testes automatizados usam SDL dummy e `-nosound`; o diagnóstico GDB
comprova os caminhos de lifecycle, sem testar a navegação do menu por entrada
real. O aceite interativo da Fase 0 permanece pendente.

Antes da Fase 1, revisar este código e completar esse aceite. Não foram criados
estado paralelo do jogador, bindings Crysis, Nanosuit, armas, mapa técnico ou
PWAD final nesta execução.
