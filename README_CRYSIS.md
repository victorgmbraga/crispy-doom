# Crysis: Contact Demake — Fase 1

Esta entrega acrescenta estado paralelo do jogador, controles Crysis
configuraveis, diagnostico de input e bloqueios de formatos incompativeis.
O mapa continua sendo o **MAP01 do Freedoom Phase 2**. Q/R/B/X registram
comandos nesta fase; Nanosuit, reload, armas, ADS visual, IA, objetivos e mapa
Contact entram depois. E ja funciona como uso de portas e switches do Doom.

## Executar no Windows x64

No VS Code, aceite a extensao recomendada **C/C++**, escolha
**Crysis: Fase 1 (Freedoom MAP01)** em Executar e Depurar e pressione **F5**.
A primeira execucao baixa o toolchain portatil e o IWAD livre, confere seus
hashes e compila o jogo. E necessario acesso a internet nessa preparacao.
O perfil **Vanilla: Freedoom MAP01** abre o mesmo motor sem `-crysis`.
As configuracoes ficam em `build/run`, dentro deste projeto. Save/load esta
disponivel apenas no modo vanilla.

### Executar pelo Zed

Abra a raiz do projeto no Zed e pressione **Ctrl+Shift+R** (ou use
**task: spawn** na paleta de comandos). Escolha
**Crysis: preparar e executar (MAP01)**. Essa task obtem o IWAD livre,
prepara o toolchain portatil, compila e abre o jogo em uma janela.
O Zed carrega as tasks locais de `.zed/tasks.json`, conforme a
[documentacao oficial](https://zed.dev/docs/tasks).

Tambem estao disponiveis **Vanilla: preparar e executar (MAP01)**, as
duas variantes **executar sem recompilar**, **Crysis: compilar** e
**Crysis: validar F1**. Para validar, prepare o projeto
primeiro; seus logs ficam em `build/zed-f1`. A task
**Crysis: diagnosticar controles F1 (MAP01)** prepara e executa com `-crdebug`,
mostrando transicoes no terminal. As tasks usam o PowerShell
do Windows e `scripts/run-game.ps1`, preservando configuracoes e saves
em `build/run`. Encerre a janela do jogo antes de recompilar o executavel.

Tambem e possivel executar pelo PowerShell, na raiz do projeto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-iwad.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/setup-build.ps1 -Build
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/prepare-run.ps1
& .\build\src\crispy-doom.exe -crysis -iwad .\content\iwad\freedoom2.wad -warp 1 -window -config .\build\run\default.cfg -extraconfig .\build\run\crispy-doom.cfg -savedir .\build\run
```

Para comparar o comportamento vanilla, remova `-crysis` do ultimo comando.
Controles originais: setas para mover/girar, Ctrl para atirar, Espaco para
usar, Esc para menu e F10 para sair. Salto e freelook mantem os canais e opcoes
originais; habilite-os em **Crispy Options** conforme desejado.

## Controles Crysis da F1

| Controle | Comando | Comportamento nesta fase |
|---|---|---|
| Shift | Sprint | Estado continuo; base de caminhada, sem bonus de suit ainda |
| Botao direito | ADS | Estado continuo; sem zoom ou animacao ainda |
| R | Reload | Uma borda por pressionamento; sem recarga de arma ainda |
| E | Interact | Uma borda; tambem usa portas/switches originais |
| Q | Suit next | Uma borda; modos ainda nao implementados |
| B | Fire mode | Uma borda; alternancia das armas ainda nao implementada |
| X | Attachments | Uma borda; overlay ainda nao implementado |
| C | Crouch | Comando reservado; sem alterar postura/colisao |

O sprint substitui a selecao run/autorun vanilla no comando Crysis; Shift nao
aplica dois multiplicadores. Botao reservado Crysis nao causa movimento,
strafe, double-click use ou troca de arma por um binding original compartilhado.
Tiro e uso compartilhados continuam permitidos. Menus, reinicios e perda de
foco limpam comandos antigos; o modo vanilla conserva seus controles.

Os bindings `key_cr_sprint`, `key_cr_ads`, `key_cr_reload`, `key_cr_interact`,
`key_cr_suit`, `key_cr_firemode`, `key_cr_attachment` e `key_cr_crouch` ficam
em `build/run/crispy-doom.cfg`. Usam scancodes da configuracao upstream,
nao ASCII: defaults 54, 0, 19, 18, 16, 48, 45 e 46 respectivamente.
Valor 0 desabilita uma tecla. Ha `mouseb_cr_*` para cada comando: -1 desabilita,
0 esquerdo, 1 direito, 2 meio, 3/4 roda e 5/6 botoes extras.
Somente `mouseb_cr_ads=1` vem habilitado por padrao. Feche o jogo antes de editar
a configuracao, pois o motor a salva ao encerrar.

Save/load, quicksave/quickload, demos e rede estao bloqueados em `-crysis`:
os formatos vanilla nao armazenam o novo estado paralelo. Os menus mostram
uma mensagem; opcoes CLI incompativeis encerram com erro antes de ler saves,
demos ou iniciar rede. O titulo alterna paginas sem demos e permite abrir o menu.

Para diagnosticar pelo PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run-game.ps1 -Mode Crysis -Build -DebugInput
```

## Compilacao e conteudo

O script fixa GCC/MinGW x64 via w64devkit 2.10.0, CMake 3.31.12, SDL2
2.32.10, SDL2_mixer 2.8.2 e SDL2_net 2.4.0. Tudo fica em `.tools` e `.deps`,
sem instalacao global nem alteracao permanente do PATH. O executavel fica
em `build/src/crispy-doom.exe`, com as DLLs ao lado.

Para o GCC 16.2.0 dessa distribuicao, o script aplica `-include math.h` na
compilacao: o upstream chama `pow()` sem incluir esse header. O mesmo ajuste
foi aplicado ao baseline e ao fork, sem alterar essa chamada.
As compilacoes mantiveram os 14 warnings preexistentes registrados nos logs
(depreciacao do CMake, formatos MinGW e declaracoes C90); os hooks Crysis
nao introduziram warnings novos.

O IWAD livre Freedoom Phase 2 0.13.0 vem da release oficial. Sua origem,
hash, licenca e creditos acompanham `content/iwad`. Um IWAD comercial de
Doom II pode ser utilizado por seu proprietario, mas nao foi incluido.
Nenhum asset comercial de Crysis foi incluido. O README upstream permanece
em `README.md` e a licenca do motor em `COPYING.md`.

## Validacao

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-f1.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/test-vanilla-storage.ps1
```

`test-f1.ps1` compila os modulos reais com stubs nas fronteiras e verifica bits,
bordas, remapeamento, foco e resets. Sondas GDB exercitam eventos, menus,
composicao de comandos, lifecycle e titulo no executavel. A suite tambem testa
rejeicao CLI e compara uma demo vanilla com o baseline original da Fase 0.
`test-vanilla-storage.ps1` grava/carrega um save isolado e grava/reproduz uma
demo vanilla, comparando o estado final. Cada execucao de storage usa uma pasta
nova. Os testes usam SDL dummy e `-nosound`; nao comprovam teclado/mouse
fisicos, imagem ou audio interativos. Resultados estao em `docs/validacao/fase-1.md`.

## Historico de validacao da Fase 0

Os relatorios/logs da Fase 0 permanecem como historico. Os scripts antigos
`smoke-test.ps1` e `trace-snapshot.ps1` com modos Crysis dependem de demos e
agora sao rejeitados corretamente; use a suite F1 para o modo Crysis atual.

O smoke roda vanilla, Crysis e argumento `-crysis` repetido. Uma demo Doom
1.9 curta, gerada pelo script, fornece 175 comandos de movimento, giro,
tiro, uso e pausa; o processo encerra naturalmente ao fim da demo. O script
verifica a saida e a mensagem de ativacao: zero em vanilla, uma em Crysis,
inclusive com o argumento repetido. Logs e resultados ficam em
`docs/validacao/logs/smoke`. `-Timed` usa o caminho `-timedemo -nodraw` e
aceita o encerramento nao-zero esperado do benchmark upstream somente
quando ha seu resultado de gametics.

Esse teste usa SDL dummy, renderer por software e `-nosound`, sem tomar o
foco do desktop. Ele valida a execucao automatizada, sem comprovar imagem,
audio, entrada por teclado/mouse, menu ou restart interativos. Esses
playtests e os resultados efetivamente observados devem ser consultados
no relatorio `docs/validacao/fase-0.md`. Demos eram permitidas na Fase 0;
a suite F1 substitui esse caminho de teste para Crysis.

Na validacao desta entrega, baseline original e os tres casos do fork
passaram com encerramento natural e contagens de ativacao esperadas.
O trace somente de leitura `scripts/trace-snapshot.ps1` confirmou estado
final identico ao baseline em vanilla, Crysis e argumento repetido:
mesma posicao, angulo, saude, municao, RNG e tempos. Os 175 comandos
resultaram em 170 tics de nivel pela pausa de cinco tics e em 46 balas
apos comecar com 50.

O teste de integracao `scripts/trace-lifecycle.ps1` aciona pelo GDB os
caminhos existentes de nova partida, recarga de nivel, conclusao e
transicao para MAP02. Nos dois modos foram observadas duas inicializacoes
de partida e quatro entradas em nivel, com pausa e menu congelando a
simulacao. Em Crysis foram observados quatro cleanups e 124 chamadas de
tic ativo; em vanilla, nenhuma chamada dos callbacks Crysis. O encerramento
passou por `I_Quit`, limpou o nivel antes de `SDL_Quit` e retornou codigo
zero. O debugger alterou estados somente no processo de teste: isso prova
os caminhos de integracao, sem comprovar acionamento por teclado/menu.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/trace-snapshot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/trace-lifecycle.ps1
```

Os artefatos correspondentes ficam em `docs/validacao/logs/baseline-smoke`,
`baseline-snapshot`, `smoke`, `snapshot` e `lifecycle`.
