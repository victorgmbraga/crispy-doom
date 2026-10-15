# Plano de implementação — Crysis: Contact Demake sobre Crispy Doom

Data: 2026-10-05.

Base: [CODEX_IMPLEMENTACAO_CRYSIS_CRISPY_DOOM.md](CODEX_IMPLEMENTACAO_CRYSIS_CRISPY_DOOM.md), seções 0–40.

Status atualizado em 2026-10-15: sistemas das Fases 0–8 implementados, com pendências de correção e aceite; Fase 9 parcial (mapa técnico) e Fase 10 parcial (ADS/FOV/scope). O vertical slice completo ainda não está aprovado. A [revisão da implementação](docs/validacao/revisao-2026-10-15.md) registra os defeitos encontrados, as validações atuais e as próximas prioridades. O backlog abaixo conserva os requisitos de aceite, não constitui uma declaração de conclusão.

## 1. Resultado esperado e situação atual

Entregar um vertical slice single-player que reproduza o ciclo de observar, escolher abordagem, usar Nanosuit, combater ou infiltrar, reposicionar e continuar a missão. A entrega inclui executável, PWAD separado, mapa técnico, mapa jogável, instruções de execução e evidências de validação.

O slice deve oferecer praia, encontro narrativo, patrulha, floresta, mirante, vila com múltiplas rotas, jammer opcional e saída. Deve ser completável por combate frontal, stealth/cloak e rota lateral com jammer.

### Situação do checkout em 2026-10-15

- Fork baseado no Crispy Doom 7.1; fontes em `src/doom/cr_*` e hooks pequenos no motor.
- Build Windows x64 reproduzido com o toolchain portátil de `scripts/setup-build.ps1`.
- Nanosuit, saúde, armas, attachments, percepção/KPA, objetivos e interação implementados; testes automatizados não substituem o aceite interativo nem cobrem todos os defeitos encontrados.
- PWAD técnico versionado em `content/pwad/crysis-technical.wad`, derivado do MAP01 do Freedoom; não é o mapa Contact completo.
- ADS/FOV/scope implementados parcialmente, com inconsistência de projeção confirmada na revisão.
- Execução pelo Zed em `.zed/tasks.json`, incluindo cenário técnico e comparação vanilla; instruções em `README_CRYSIS.md`.
- Pendências prioritárias: corrigir o fatal da investigação da IA, timers entre níveis, direção real de tiro e projeção; depois concluir mapa, playtests das três abordagens e profiling.

### Registro histórico do planejamento inicial (2026-10-05)

As constatações a seguir descrevem a pasta antes da integração do upstream, não a situação atual:

- A pasta contém somente a especificação original antes da criação deste plano.
- Não existem checkout do motor, `src/`, `CMakeLists.txt` ou `.git` na pasta.
- `git status --short` e `git rev-parse HEAD` retornaram que a pasta não é um repositório Git. Não há commit-base disponível para registrar.
- Não foram encontrados `AGENTS.md` na pasta ou nos diretórios ancestrais consultados.
- Não foi possível estabelecer baseline de compilação porque o código-fonte ainda não está presente. Compilador, dependências e IWAD ainda precisam ser inventariados.

Na tarefa inicial, a primeira execução foi limitada à Fase 0, como determina a seção 36 da especificação. Esse recorte histórico não exige reintegrar o upstream nem repetir a Fase 0 no checkout atual.

## 2. Escopo e decisões de entrega

| Categoria | Decisão para o slice |
|---|---|
| Plataforma inicial | Windows x64, ambiente local; preservar portabilidade do C quando possível |
| Motor | Fork do Crispy Doom, C99 e SDL2, renderer por software existente |
| Ativação | `-crysis`; comportamento original preservado sem o parâmetro |
| Conteúdo | PWAD separado e assets próprios/livres com procedência registrada |
| Base de mapas | Proposta: formato Doom com numeração MAPxx e IWAD compatível com Doom II; validar o IWAD efetivamente escolhido |
| Armas | Melee, SOCOM, SCAR e FY71 equivalentes, transportados por slots vanilla |
| Optics | Reflex obrigatório na Fase 5; scope com zoom real consolidado na Fase 10 |
| ADS | Mecânica e psprites na Fase 5; FOV real na Fase 10 |
| Persistência | Save/load indisponível no modo Crysis até existir serialização versionada; não é requisito de conclusão do primeiro slice |
| Demos e rede | Bloqueio explícito no modo Crysis; caminhos vanilla mantidos |
| Fora do slice | Veículos, física geral, multiplayer, campanha completa, renderer novo, modelos 3D, extração de assets comerciais |
| Adiáveis | Crouch, laser, radar completo, menus radiais, granadas e objetos arremessáveis |

O pacote de conteúdo deve indicar o IWAD necessário. Caso se adote um IWAD livre, validar sua compatibilidade e os termos dos arquivos efetivamente distribuídos. O planejamento não inclui aquisição, extração ou redistribuição de assets de Crysis.

## 3. Preparação e baseline — entrada da Fase 0

1. Preservar a especificação e este plano. Como a pasta não está vazia, obter o upstream em diretório temporário e integrar sua árvore de forma controlada, preservando os documentos; não executar clone sobre a pasta existente nem substituir arquivos silenciosamente.
2. Confirmar a origem oficial, selecionar uma revisão e registrar URL, branch/tag e SHA completo. A menção a 7.1.0 na especificação é uma referência, não um checkout verificado.
3. Executar `git status` e identificar alterações existentes antes de cada tarefa. Registrar `git rev-parse HEAD` no relatório da Fase 0.
4. Ler instruções do checkout e os CMakeLists reais. Inventariar compilador, CMake, gerador, SDL2 e demais bibliotecas exigidas pela revisão. Fixar versões e arquitetura compatíveis.
5. Selecionar o IWAD de teste, registrar caminho e hash, e manter conteúdo comercial fora do repositório.
6. Compilar o upstream sem alterações de código. Registrar comando, saída, warnings preexistentes e caminho real do executável.
7. Abrir o jogo original e validar entrada em mapa, movimento, tiro, áudio, menu e encerramento. Guardar configuração e cenário para comparação posterior.
8. Só então começar os hooks da Fase 0. Dependência ausente ou build original quebrada deve constar como bloqueio concreto no relatório.

Comandos de referência, ainda não executados:

```powershell
git status --short
git rev-parse HEAD
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build --config RelWithDebInfo --parallel
```

Adaptar o gerador e o toolchain à instalação disponível. Em geradores multiconfiguração, selecionar a configuração no build; não pressupor que `CMAKE_BUILD_TYPE` a controla. O relatório deve registrar os comandos finais, sem placeholders.

## 4. Arquitetura e contratos de integração

### 4.1 Responsabilidades

| Módulo | Responsabilidade | Integração prevista |
|---|---|---|
| `cr_game.[ch]` | Ativação, lifecycle, coordenação e restrições do modo | Inicialização Doom, nova partida, entrada/saída de nível e ticker lógico |
| `cr_defs.h` | Tipos e constantes compartilhadas de baixo nível | Sem implementação ou dependências circulares |
| `cr_input.[ch]` | Adaptar bindings para `ticcmd_t` | `G_BuildTiccmd()`; módulo adicional para manter o hook pequeno |
| `cr_player.[ch]` | Estado paralelo, movimento, regen e coordenação do jogador | `P_PlayerThink()`, movimento, morte e respawn |
| `cr_nanosuit.[ch]` | Modos, energia, absorção, salto e visibilidade | Chamado por player, dano, arma e percepção |
| `cr_weapon.[ch]` | Inventário Crysis, tiros, reload, modos e attachments | Seleção, psprites, munição, pickups e ataques |
| `cr_sound.[ch]` | Eventos auditivos com posição e alcance | Armas, passos, impactos e explosões |
| `cr_ai.[ch]` | Percepção e máquina de estados dos soldados | Actions próprias, spawn e remoção de atores |
| `cr_interact.[ch]` | Uso contextual e despacho de controles | Caminho de use e specials de linhas |
| `cr_objective.[ch]` | Estados e dependências dos objetivos | Eventos de mapa e saída |
| `cr_hud.[ch]` | Apresentação do estado do jogo | Hook de desenho que preserve menu, mensagens e automap |
| `cr_debug.[ch]` | Diagnóstico e métricas sob `-crdebug` | Instrumentação progressiva, sem logs por tic |
| `cr_render.[ch]` | FOV de ADS e invalidação de projeção | Somente na etapa de FOV real |

Criar os módulos gradualmente e registrá-los no CMake quando existirem. Toda implementação específica usa `CR_`, `cr_` e comentários `// [crysis]` nos hooks herdados. Não expandir `weapontype_t` nem substituir sistemas centrais do motor.

As tabelas de estado pertencem aos módulos responsáveis. HUD e debug consultam o estado sem executar gameplay. O adaptador de input é o único ponto novo que lê dispositivos; a simulação consome comandos por tic.

### 4.2 Estado e ciclo de vida

- `CR_Init()`: detectar `-crysis` uma vez, configurar o modo e emitir uma única mensagem de ativação.
- `CR_NewGame()`: limpar progresso da missão e inicializar estado do jogador conforme loadout definido.
- `CR_LevelStart()`: reconstruir registros do nível, zerar referências transitórias e inicializar relógios ligados a `leveltime`.
- `CR_LevelEnd()`: invalidar referências a mobjs e descartar eventos pendentes antes de destruir o nível.
- `CR_PlayerReset()`: distinguir nova partida/respawn de mera troca de nível; definir explicitamente o que persiste.
- `CR_Ticker()`: executar coordenação global uma vez por tic de simulação ativa. Pausa e menus que pausam o jogo não avançam timers.

Proposta de persistência entre níveis: conservar inventário e equipamentos em transição normal; limpar ADS, sprint, reload em andamento, input anterior e referências a atores. Nova partida ou respawn reinicia o loadout. A implementação deve adaptar os callbacks aos caminhos reais do motor para evitar reset duplicado.

Validar `player_t *` antes do acesso a `cr_players`. Evitar subtrair ponteiros que não pertençam comprovadamente ao array `players`; uma busca curta por igualdade de endereços é suficiente para `MAXPLAYERS`.

Timers devem ter unidade explícita em tics; energia, suspeita, munição e saúde devem ter limites claros. Nenhuma atualização de gameplay depende da taxa de renderização. RNG de gameplay usa a infraestrutura do motor.

### 4.3 Ordem do tic

Definir e documentar a ordem após inspecionar o ticker real:

1. Capturar o comando e calcular bordas das ações.
2. Resolver modo da Nanosuit e estados ADS/sprint/interação do jogador vivo.
3. Avançar timers e aplicar movimento, salto e lógica de armas nos pontos próprios do motor.
4. Registrar dano, disparo e ruído no momento em que ocorrem.
5. Atualizar percepção/objetivos na etapa definida para os módulos globais.
6. Desenhar HUD a partir do estado resultante, sem modificá-lo.

Cada sistema deve ter um único dono de atualização. Não chamar a mesma lógica por `CR_Ticker()` e por hook de jogador/ator no mesmo tic. Se a fila de ruído for consumida no tic seguinte, documentar esse limite de latência.

### 4.4 Decisões de gameplay propostas

| Tema | Regra inicial |
|---|---|
| Input contínuo | Sprint e ADS ativos enquanto pressionados |
| Input por borda | Reload, suit, interact, fire mode e attachments disparam uma vez por pressionamento |
| Sprint e ADS | ADS tem prioridade; enquanto ADS estiver ativo, sprint fica suspenso |
| Reload | Duração em tics; munição transferida somente ao concluir; troca de arma e morte cancelam sem transferência |
| Sprint no reload | Bloqueado; manter a decisão em uma regra centralizada |
| Energia zero | Encerrar Cloak e bônus Speed/Strength; retornar a Armor sem absorção até recuperar energia |
| Cloak ao disparar | Disparo efetivo revela o jogador, zera energia e aciona delay; tentativa com arma vazia não quebra cloak |
| Recarga da suit | Só ocorre após o delay e fora de ações que estejam drenando energia |
| Dano absorvido | Também reinicia o atraso de regeneração e recarga; dano ignorado por invulnerabilidade não conta como dano recebido |
| Regen | Jogador vivo, teto 100, sincronização de player e mobj; nunca reduzir saúde que já esteja acima do teto |
| Ópticas | Reflex e scope mutuamente exclusivos; suppressor independente quando compatível |
| Interação | Primeiro tentar interação Crysis; usar ação vanilla como fallback sem duplicar o evento |
| Jammer | Opcional; sua ausência nunca bloqueia a saída principal |

Os valores numéricos da especificação são parâmetros iniciais de tuning. Reservar crouch no protocolo de input sem implementar postura ou colisão reduzida no primeiro slice.

## 5. Backlog detalhado por fase

Cada fase depende do aceite da anterior. Todas exigem compilação, smoke test da feature e smoke test vanilla. As subdivisões são unidades sugeridas de patch/revisão; não autorizam avançar automaticamente à fase seguinte.

### Fase 0 — Baseline e modo Crysis

**Objetivo:** provar que o fork compila, executa e liga o modo sem modificar o gameplay.

1. F0.1: concluir preparação e baseline da seção 3.
2. F0.2: criar `cr_game.c`, `cr_game.h` e `cr_defs.h`, com a API mínima da especificação e estado de ativação privado.
3. F0.3: integrar `CR_Init()` após disponibilidade dos argumentos e antes de qualquer consulta ao modo; revisar `d_main.c` para escolher o ponto.
4. F0.4: mapear nova partida, carregamento, término e tic ativo; ligar callbacks mínimos sem criar estado de Nanosuit, armas ou IA.
5. F0.5: adicionar arquivos ao CMake do módulo Doom e registrar decisões de integração.

**Aceite:** build sem novos warnings relevantes; jogo abre com e sem `-crysis`; log `[CRYSIS] mode enabled` aparece exatamente uma vez quando ativado e não aparece no caminho vanilla. Entrar em mapa, reiniciar e encerrar funciona nos dois modos.

**Relatório obrigatório:** SHA-base, arquivos alterados, hooks escolhidos, dependências, comandos reais, resultado de cada smoke test e limitações. Não declarar baseline concluído apenas por gerar arquivos de build.

### Fase 1 — Estado do jogador e input

**Objetivo:** comandos verificáveis e isolamento do estado Crysis.

1. F1.1: criar `cr_player.[ch]`, array paralelo, acesso validado e reset. Adicionar campos de módulos posteriores somente quando necessários.
2. F1.2: criar `cr_input.[ch]`; registrar bindings configuráveis nos mecanismos de controles e configuração realmente presentes no checkout.
3. F1.3: preencher os oito bits propostos de `buttons2` somente em Crysis. Preservar salto, look e campos de comando existentes, sem alterar `sizeof(ticcmd_t)`.
4. F1.4: neutralizar conflito com run/autorun para que Shift não multiplique movimento duas vezes nas fases seguintes. Testar também bindings compartilhados com use, mouse e menus.
5. F1.5: calcular bordas a partir de comandos consumidos pela simulação; limpar estado anterior ao perder foco ou reiniciar, conforme os eventos upstream.
6. F1.6: adicionar diagnóstico sob `-crdebug`, registrando transições ou desenhando os bits, sem spam contínuo.
7. F1.7: bloquear caminhos de rede, gravação/reprodução de demos e save/load em Crysis antes de introduzir estado incompatível. Abranger CLI, menus, atalhos e sequência automática de demos do título; permitir entrada normal no menu.

**Aceite:** segurar Q/R/E/B/X gera uma ação até soltar e pressionar novamente; Shift/ADS mantêm estado; jump e freelook continuam funcionais; novo jogo limpa estado transitório; no modo vanilla, bindings, demos e save/load mantêm o comportamento original.

### Fase 2 — Nanosuit e movimento

**Objetivo:** os quatro modos operam com energia limitada e sem substituir a física do motor.

1. F2.1: criar tipos e APIs de `cr_nanosuit.[ch]`; centralizar energia, delays, custos e multiplicadores.
2. F2.2: implementar troca de modo, consumo e recarga; garantir que trocar modos não contorne atrasos de recarga.
3. F2.3: integrar Armor no caminho de dano ao jogador depois das proteções existentes e antes de reduzir HP. Preservar tratamento de danos especiais do motor e impedir dupla absorção por armor vanilla.
4. F2.4: aplicar fator de movimento antes do thrust; definir caminhada, corrida normal e sprint Speed. Manter clamps compatíveis com colisão e movimento diagonal.
5. F2.5: alterar apenas o impulso do salto no modo Strength e integrar modificador melee; manter salto normal sem Strength.
6. F2.6: implementar visibilidade e drain de Cloak, diferenciando parado, andando e correndo; não usar `CF_NOTARGET`.
7. F2.7: notificar a suit sobre disparos vanilla efetivamente realizados enquanto armas Crysis ainda não existem. Na Fase 4, transferir essa responsabilidade para o caminho único de tiro Crysis.
8. F2.8: criar o primeiro mapa técnico simples para dano, deslocamento e salto. Proposta: `MAP02` no PWAD técnico, separado de `MAP01` final; confirmar suporte pelo IWAD/warp.

**Aceite:** energia em `0..max`; dano residual correto quando a energia é insuficiente; dano integralmente absorvido bloqueia recarga; sprint não acumula multiplicadores; salto normal e Strength respeitam teto/colisão; drain e recarga têm os mesmos resultados em diferentes FPS; tiro quebra cloak uma única vez.

### Fase 3 — Health regeneration e HUD mínimo

**Objetivo:** o estado de sobrevivência fica visível e a recuperação é previsível.

1. F3.1: adicionar timer e acumulador de regen em `cr_player`; ponto de partida: 5 segundos sem dano e incremento a cada 4 tics.
2. F3.2: sincronizar saúde do jogador/mobj e revisar interação com morte, respawn, pickups e dano ambiental.
3. F3.3: criar `cr_hud.[ch]` para HP, energia e modo; selecionar hook que preserve console de mensagens, menu e automap.
4. F3.4: validar widescreen, resoluções disponíveis e tamanhos de tela; não vincular desenho aos timers.

**Aceite:** dano reinicia o atraso; jogador morto não regenera; HP/mobj concordam; HUD reflete as mudanças no próximo desenho; pausa congela a evolução; vanilla mantém seu HUD.

### Fase 4 — Armas, munição, reload e recoil

**Objetivo:** três armas completas, com inventários independentes e um único caminho de disparo.

1. F4.1: criar definições e estado runtime de `cr_weapon.[ch]`. Mapear fist/pistol/chaingun/plasma para melee/SOCOM/SCAR/FY71, validando seleção e posse.
2. F4.2: tornar magazine/reserve Crysis a fonte de verdade. Adaptar pickups, concessão de armas, seleção automática e checagens que hoje consultam `player->ammo`.
3. F4.3: integrar tiro, ready/refire e psprites; impedir que callbacks vanilla disparem ou consumam munição após o tiro Crysis. Não assumir que interceptar `P_FireWeapon()` sozinho cobre todos os caminhos.
4. F4.4: implementar reload temporizado e cancelamento centralizado. Arma cheia ou reserva zero não inicia reload útil.
5. F4.5: implementar semi por borda de ataque e auto por comando mantido, sujeitos à cadência lógica. Registrar RPM nominal e cadência efetiva após quantização a 35 Hz.
6. F4.6: reutilizar hitscan/freeaim; aplicar spread e recoil funcional, com Strength reduzindo recoil. Confirmar que a alteração de mira modifica a direção real dos ataques.
7. F4.7: configurar loadout inicial e pickups técnicos para obter todas as armas sem cheats; usar placeholders de psprites/sons identificados.
8. F4.8: estender HUD para arma, carregador, reserva e modo de tiro. Preparar parâmetros de ruído sem antecipar IA.

**Aceite:** SCAR 30→29 por tiro válido; vazio não atira; reload transfere `min(capacidade - magazine, reserva)` uma única vez; total de munição é conservado no reload; morte/troca cancela sem duplicação; semi não vira automático ao segurar; SCAR/FY71 não compartilham reserva por acidente; nenhuma bala/flash/consumo vanilla adicional.

### Fase 5 — ADS e attachments

**Objetivo:** mirar e equipar acessórios produz diferenças verificáveis antes de alterar projeção.

1. F5.1: implementar ADS com psprite centralizado, menor spread e velocidade reduzida; manter FOV existente nesta etapa.
2. F5.2: aplicar máscara de compatibilidade por arma; instalar/remover suppressor e reflex, conservando a escolha por arma.
3. F5.3: criar overlay simples controlado por comandos da simulação. Usar X para abrir/fechar e direções/interact para selecionar/confirmar; enquanto aberto, consumir navegação sem mover ou disparar inadvertidamente.
4. F5.4: definir precedência entre reload, ADS, sprint e overlay. Fechar overlay em morte/transição.
5. F5.5: variar som e raio declarado do disparo com suppressor; exibir o raio em debug para comparação antes da Fase 6.

**Aceite:** dispersão menor medida com sequência repetível de tiros; ADS reduz movimento e retorna ao normal ao soltar; attachments incompatíveis são recusados; suppressor reduz numericamente o raio e altera som. A validação de reação inimiga ao suppressor fica para a Fase 6.

### Fase 6 — Ruído e percepção

**Objetivo:** visão e audição geram suspeita gradual, com influência mensurável do Cloak.

1. F6.1: criar `cr_sound.[ch]` e `CR_EmitNoise()`. Definir unidades do raio e eventos com posição capturada no instante de emissão, tipo e validade.
2. F6.2: conectar tiros, passos, impactos e explosões relevantes. Impedir que `P_NoiseAlert()` contorne a percepção dos soldados Crysis; preservar funcionamento vanilla fora do modo.
3. F6.3: criar `cr_ai.[ch]` e registro dos atores relevantes. Usar armazenamento de estado limitado e com dono explícito; proposta inicial: registro externo criado no spawn e removido antes da liberação do mobj, sem heap por tic.
4. F6.4: criar um alvo técnico identificado para exercitar percepção antes do soldado completo da Fase 7. Não alterar globalmente monstros vanilla.
5. F6.5: filtrar por distância/cone antes de `P_CheckSight()`, acumular suspeita em `0..100` e aplicar fator de visibilidade da suit.
6. F6.6: processar ruído em eventos esparsos sobre atores relevantes; guardar posição ouvida, sem acompanhar automaticamente a posição atual da fonte.
7. F6.7: guardar resíduos em ponto fixo ou acumulador para que fatores baixos de Cloak não sejam truncados permanentemente para zero.
8. F6.8: distribuir verificações distantes em 2–4 tics e patrulha em 4–8 conforme medição; compensar o ganho/decay pelo tempo lógico decorrido.
9. F6.9: instrumentar número de atores, verificações de visão/LOS e eventos de ruído.

**Aceite:** costas sem ruído não detectam em distância normal; tiro alto causa investigação; tiro suprimido distante causa resposta menor ou nenhuma; cone frontal aumenta suspeita; Cloak demora mais para revelar; parede impede visão; evento auditivo preserva posição original quando o jogador se desloca; remoção da fonte não deixa ponteiro inválido.

### Fase 7 — Soldado humano e combate

**Objetivo:** um inimigo funcional investiga, combate e perde contato.

1. F7.1: reservar tipo de ator, DoomEd number e states após verificar conflitos; usar action própria com prefixo `CR_`, como `CR_KPAThink()`, conforme a assinatura exigida pelo motor.
2. F7.2: implementar PATROL, SUSPICIOUS, INVESTIGATE, ALERT, COMBAT, SEARCH e RETURN, com critérios de entrada/saída explícitos. ALERT representa a confirmação/reação antes do combate.
3. F7.3: representar rota de patrulha por marcadores de mapa identificados; não codificar coordenadas no C.
4. F7.4: reutilizar primitivas de movimento/colisão sem permitir que aquisição automática vanilla atribua a posição atual do jogador oculto.
5. F7.5: atualizar última posição vista somente sob percepção válida; investigar última posição ouvida; após timeout, buscar e retornar à rota.
6. F7.6: adicionar rifle hitscan, reação, rajada e precisão por distância; definir morte e drop opcional sem referências persistentes inválidas.
7. F7.7: tratar destino inalcançável com timeout e retorno/replanejamento local; não criar pathfinding global.

**Aceite:** observar todas as transições no mapa técnico; perder contato atrás de parede; procurar o último local conhecido; voltar à rotina sem perseguir para sempre; responder a ruído próximo; morrer durante investigação sem crash; evitar que dois callbacks atualizem a IA no mesmo tic.

### Fase 8 — Objetivos, interação e jammer

**Objetivo:** uma missão completa já pode ser percorrida no mapa técnico.

1. F8.1: criar `cr_objective.[ch]` com IDs estáveis, tabela da missão e transições LOCKED/ACTIVE/COMPLETE/FAILED. Eventos repetidos devem ser idempotentes.
2. F8.2: criar `cr_interact.[ch]`, alcance e direção de uso; delegar ao mecanismo de linhas do motor para respeitar obstáculos e contexto.
3. F8.3: auditar specials de cruzamento, use, tiro e demais extensões antes de reservar números. Os exemplos 220–222 da especificação não são números aprovados.
4. F8.4: documentar o contrato de mapa: número reservado, método de ativação, tag/evento, repetição, lado válido e pré-condições.
5. F8.5: separar ativação e conclusão de objetivos por eventos declarados; o exemplo `activate(tag)` sozinho não descreve a missão inteira.
6. F8.6: implementar jammer utilizável, feedback de som/textura e conclusão única do objetivo opcional.
7. F8.7: implementar saída condicionada apenas ao progresso principal; mostrar no HUD o objetivo que ainda falta.
8. F8.8: adicionar validação de IDs/tags desconhecidos e verificar sequências alternativas, incluindo chegada antecipada ao jammer.

Fluxo proposto: alcançar o encontro narrativo → chegar ao mirante/vila → alcançar a saída. Patrulha admite evasão e não exige eliminar todos os inimigos. Desativar jammer é ramo opcional acessível na vila; se concluído antecipadamente, não deve voltar a ACTIVE ao cruzar outro trigger.

**Aceite:** completar a missão sem cheats; jammer repetido não duplica efeitos; ID inválido não acessa tabela fora dos limites; sair sem jammer é possível após os objetivos principais; revisitar áreas, morrer e reiniciar não trava a progressão.

### Fase 9 — Mapa completo e conteúdo

**Objetivo:** converter os sistemas validados em uma experiência curta e coesa.

1. F9.1: construir graybox de praia → encontro narrativo → patrulha → floresta → mirante → vila → saída.
2. F9.2: definir três abordagens na vila, áreas de recuperação, cobertura que realmente corte LOS e conexão opcional ao jammer.
3. F9.3: posicionar patrulhas, gatilhos, pickups e objetivos usando o contrato da Fase 8. Garantir acesso às três armas por loadout ou pickups normais.
4. F9.4: registrar dimensões de obstáculos e distâncias de percepção que orientem o level design; testar saltos e rotas com energia baixa.
5. F9.5: substituir placeholders gradualmente; registrar arquivo, autor, origem, licença e modificações de cada asset. Não alterar a geometria para reproduzir literalmente Contact.
6. F9.6: usar sprites para vegetação e geometria para oclusão/colisão. Arbustos visuais não contam como bloqueio de LOS sem regra explicitamente implementada.
7. F9.7: documentar ferramentas de edição e node builder adotados, versões, fontes editáveis e geração do PWAD.
8. F9.8: adicionar execução direta do mapa Crysis pelo perfil/comando de lançamento; validar mensagem clara para PWAD ausente.

**Aceite:** três partidas completas, cada uma com uma abordagem; rota stealth viável sem cheats; jogador consegue se recuperar e prosseguir após gastar energia; jammer opcional não cria softlock; saída encerra corretamente o slice; fontes dos mapas e procedência dos assets acompanham a entrega.

### Fase 10 — Performance, FOV e acabamento

**Objetivo:** concluir a experiência, medir custos e remover regressões.

1. F10.1: registrar hardware, resolução, opções, build e cenário; medir áreas abertas, vila em alerta e campo com vegetação.
2. F10.2: separar tempo de simulação e renderização; medir mediana, p95/p99 e picos, além de atores, thinkers, LOS, ruído e sprites visíveis quando a instrumentação permitir.
3. F10.3: otimizar somente gargalos observados, incluindo frequência de percepção, varreduras e oclusão do mapa.
4. F10.4: criar `cr_render.[ch]`; aplicar FOV real em ADS com transição instantânea inicial, invalidando projeção apenas ao mudar estado/FOV ou dimensões relevantes.
5. F10.5: revisar projeção horizontal/vertical, limites e tabelas derivadas, clipping, psprites, crosshair e centro de mira. Validar widescreen, resize, troca de arma, menu e retorno do ADS.
6. F10.6: concluir scope com zoom e overlay; verificar que tiro e imagem correspondem à mesma mira.
7. F10.7: ajustar áudio, animações, energia, reação inimiga, alcance do ruído e distribuição de munição a partir dos três percursos.
8. F10.8: executar regressão completa, gerar pacote reproduzível e registrar limitações conhecidas.

**Aceite:** simulação mantém 35 Hz com folga no hardware de referência; orçamento máximo de um tic é aproximadamente 28,57 ms, com meta de engenharia proposta de p95 abaixo da metade desse valor. Definir a meta final de frametime de renderização após o baseline; verificar ausência de picos perceptíveis associados à IA. Essas metas são propostas de medição, não resultados já obtidos.

FOV real integra o aceite final do plano. Transição suave, radar e menus radiais continuam opcionais e não devem impedir a conclusão do slice.

## 6. Dependências e marcos de revisão

```text
Preparação do checkout + baseline
  → F0 modo e lifecycle
  → F1 estado/input e bloqueio de formatos incompatíveis
  → F2 Nanosuit/movimento + mapa técnico
  → F3 sobrevivência visível no HUD
  → F4 armas completas
  → F5 ADS e attachments
  → F6 percepção e ruído
  → F7 soldado e combate
  → F8 missão completa no mapa técnico
  → F9 mapa Contact reinterpretado
  → F10 performance, FOV e entrega
```

| Marco | Evidência necessária para avançar |
|---|---|
| Fundação, F0–F1 | Build reproduzível, baseline registrado, dois modos executáveis, input verificado |
| Jogador, F2–F3 | Mapa técnico de sobrevivência aprovado; energia e HP observáveis |
| Combate do jogador, F4–F5 | Três armas, reload, ADS, óptica e suppressor funcionando |
| Encontro, F6–F7 | Inimigo percebe, investiga, luta e perde contato |
| Missão, F8 | Fluxo de objetivos e saída completo sem mapa detalhado |
| Conteúdo, F9 | Três abordagens concluídas no slice |
| Entrega, F10 | Regressão aprovada, performance medida, conteúdo distribuível e pacote reproduzível |

Não há cronograma em dias validado. Checkout, baseline e sistemas já existem; permanecem correções, pipeline do mapa final e aceite interativo. Estimar os próximos passos após resolver os defeitos prioritários e revisar as estimativas ao concluir o graybox. Armas/psprites, IA e FOV concentram risco técnico; produção e tuning do mapa concentram esforço de conteúdo.

## 7. Estratégia de testes e evidências

### 7.1 Mapa técnico

Manter PWAD técnico independente do mapa final, com salas identificadas: dano/Armor, corredor de velocidade, plataformas e teto baixo, alvos em alturas diferentes, bancada de reload, inimigos frontal/de costas, parede de quebra de LOS, distâncias marcadas para ruído, rota de patrulha, jammer, gatilhos e saída.

O mapa deve permitir repetir cenários sem depender de encontrar um ponto específico da missão final. Cheats de diagnóstico podem facilitar testes isolados, mas não contam como evidência de conclusão da missão.

### 7.2 Matriz mínima

| Grupo | Casos decisivos |
|---|---|
| Inicialização | Com/sem flag, argumento repetido, entrada direta no mapa, PWAD ausente, encerramento |
| Lifecycle | Nova partida, restart, morte/respawn, transição, pausa, retorno do menu |
| Input | Pressionar/segurar/soltar, ações simultâneas, perda de foco, conflito com autorun/use/mouse |
| Nanosuit | Energia 0/1/max, troca rápida de modo, dano menor/igual/maior que capacidade, drain versus recarga |
| Movimento | Diagonal, parede, quina, degrau, teto baixo, ADS, energia esgotada, FPS variados |
| Saúde | Dano integralmente absorvido, dano consecutivo, morte, pickups e dano ambiental |
| Armas | Magazine cheio/vazio, reserva parcial/zero, reload cancelado, semi mantido, troca durante tiro, pickup |
| Mira | Freeaim vertical, recoil real, ADS, Strength, distância, óptica e FOV final |
| IA | Fora do cone, distância, parede, Cloak, ruído suprimido, busca expirada, destino inalcançável, morte/remoção |
| Objetivos | Repetição, ordem alternativa, jammer antes/depois, tag inválida, saída antecipada e válida |
| Vanilla | Movimento, armas, munição, IA, HUD, menu, save/load e amostra de demo reproduzível |
| Performance | Sem inimigos, patrulha, combate coletivo, ruído intenso, vila e vegetação |

### 7.3 Automação proporcional

Priorizar testes pequenos de lógica onde houver valor: conservação de munição, clamps de energia, transições/timers, bordas de input e idempotência de objetivos. Usar seed/estado RNG conhecido apenas nos cenários controlados; não depender de demos Crysis, que estão fora do escopo.

Acrescentar checks de compilação e de conteúdo: IDs duplicados, tags sem evento, assets ausentes e fontes fora da lista de build. Não substituir playtest por testes que apenas repitam o código. Avaliar sanitizers conforme suporte do toolchain, especialmente ao integrar estado por ator.

### 7.4 Registro por fase

Guardar, por exemplo, `docs/validacao/fase-N.md` contendo revisão-base/revisão testada, arquivos alterados, comandos, configuração, IWAD/PWAD com hashes, cenários, esperado/observado e pendências. Guardar logs de build relevantes e captura visual quando necessária para comprovar HUD/ADS.

Classificar cada verificação como passou, falhou ou não executada. Sem execução interativa disponível, registrar a limitação; não declarar o smoke test jogável aprovado apenas por observar um processo aberto.

## 8. Riscos, decisões pendentes e tratamento

| Risco ou lacuna | Tratamento previsto | Fase limite |
|---|---|---|
| Ausência de código/Git | Obter revisão upstream, preservar documentos, registrar SHA e build original | Entrada F0 |
| Dependências/toolchain desconhecidos | Inventário pelo CMake da revisão; registrar instalação e arquitetura | F0 |
| IWAD não definido | Escolher base compatível com slots e MAPxx; registrar requisito no pacote | F0/F2 |
| Oito bits de `buttons2` ocupados pelo plano | Auditar produtores/consumidores; manter jump/look nos caminhos existentes; não expandir estrutura na F1 | F1 |
| Shift/autorun com bônus duplo | Uma velocidade-base Crysis e sprint separado | F1/F2 |
| Callback por frame ou callback duplicado | Dono único por sistema e teste sob diferentes FPS | Todas |
| Armor dupla ou dano fatal convertido indevidamente | Revisar ordem do dano e preservar semântica dos casos especiais | F2 |
| Armas dependentes de slots/munição vanilla | Adaptar seleção, pickups, ammo checks, psprites e actions em conjunto | F4 |
| Som alerta inimigos sem percepção | Isolar alerta binário dos soldados Crysis | F6 |
| Cloak vira invisibilidade absoluta por truncamento | Ganho fracionário acumulado e teste de exposição prolongada | F6 |
| Ponteiro de ator removido ou nível destruído | Registro com remoção obrigatória, validação e limpeza de ciclo de vida | F6/F7 |
| IA conhece alvo atrás de paredes | Separar alvo visual, posição vista e posição ouvida; expirar informações | F7 |
| Specials 220–222 ou IDs de ator conflitam | Auditar todos os despachos e documentar faixa efetivamente escolhida | F7/F8 |
| Objetivo opcional bloqueia missão | Grafo principal independente; eventos repetidos/fora de ordem testados | F8 |
| Vegetação visual confundida com cobertura | Distinguir sprite decorativo de oclusão/colisão no mapa | F9 |
| FOV altera apenas parte da projeção | Auditar tabelas derivadas, clipping, mira e resize | F10 |
| Saves contêm estado incompleto | Bloquear todas as entradas Crysis até haver formato versionado | F1 em diante |
| Assets sem procedência | Manifesto desde o primeiro placeholder e revisão do pacote final | F2–F10 |

Decisões de revisão-base, toolchain, IWAD, IDs de ator e specials devem ser fechadas com evidência antes das respectivas alterações. Ajustes de balanceamento podem usar os valores iniciais da especificação e ser refinados por playtest, sem bloquear a arquitetura.

## 9. Rastreabilidade da especificação

| Seções da especificação | Entrega neste plano |
|---|---|
| 0–5, 28–32, 36–37, 40 | Preparação, compatibilidade, F0, protocolo de validação e tarefas limitadas |
| 6–8 | Arquitetura modular, estado paralelo e F1 |
| 9–11 | F2–F3: suit, movimento e regeneração |
| 12, 22 | F4: armas e recoil |
| 13–14 | F5 e F10: ADS, attachments e FOV |
| 15–18 | F6–F7: ruído, percepção e soldado |
| 19–20 | F8: interação, objetivos, jammer e saída |
| 21 | HUD mínimo F3, armas F4, attachments F5 e objetivos F8 |
| 23 | Mapa técnico F2 e slice detalhado F9 |
| 24, 34 | Instrumentação F6 e performance F10 |
| 25 | Bloqueios F1; serialização posterior versionada |
| 26–27 | Debug desde F1, métricas F6 e logging por eventos |
| 3, 33, 38–39 | Conteúdo, matriz de testes, aceite final e loop de gameplay |
| 2, 35 | Escopo adiado e backlog posterior |

## 10. Definition of Done e entrega

- [ ] Build reproduzível e sem novos warnings relevantes; SHA, toolchain e comandos registrados.
- [ ] Vanilla validado sem `-crysis`, incluindo armas, IA, HUD e fluxos persistentes existentes.
- [ ] Modo Crysis inicia diretamente no mapa previsto; combinações incompatíveis têm mensagem clara.
- [ ] Freelook/freeaim, sprint, salto normal e Strength funcionam.
- [ ] Armor, Strength, Speed e Cloak, energia, absorção e regeneração aprovados.
- [ ] SOCOM, SCAR e FY71 com munição independente, reload, semi/auto aplicável e recoil funcional.
- [ ] ADS, FOV real, suppressor e óptica entregues e testados.
- [ ] Ruído, visão, suspeita, patrulha, investigação, combate, busca e perda de contato aprovados.
- [ ] HUD completo com saúde, energia, suit, arma, carregador, reserva, fire mode e objetivo.
- [ ] Objetivos, jammer opcional e saída funcionam sem softlocks conhecidos.
- [ ] Três abordagens do slice completadas sem cheats.
- [ ] Performance medida no hardware de referência e gargalos críticos resolvidos.
- [ ] PWAD, fontes editáveis de mapas e assets permitidos com manifesto de procedência.
- [ ] README com build, execução, controles, IWAD necessário e limitações.
- [ ] Relatórios de validação registram testes aprovados, falhas resolvidas e verificações não executadas.

Savegames versionados entram em uma tarefa posterior: serializar campos individualmente, nunca despejar structs ou ponteiros crus; incluir player/suit/armas, objetivos, IA, posições conhecidas e timers; validar versão e integridade antes de restaurar. Radar, granadas, comunicação de esquadrão, arremesso de objetos e menus radiais seguem a prioridade da seção 35 original.

## 11. Primeira tarefa executável

Registro histórico do prompt inicial, já executado. Não reaplicar a obtenção do upstream sobre a árvore atual; consultar a revisão de 2026-10-15 para as próximas tarefas.

```text
Leia a especificação original e este plano.
Execute somente a Fase 0.

Como esta pasta ainda não contém o upstream, obtenha uma revisão verificável
do Crispy Doom preservando os documentos existentes. Registre origem e SHA.
Inspecione as instruções do checkout e execute git status antes de alterar código.
Compile e rode o upstream sem modificações para estabelecer o baseline.

Depois implemente somente cr_game.c, cr_game.h, cr_defs.h, ativação por -crysis,
API mínima de lifecycle, hooks pequenos e integração CMake.
Não implemente input novo, Nanosuit, HUD, armas, IA ou mapa final nesta tarefa.

Compile e execute smoke tests com e sem -crysis.
Registre arquivos alterados, pontos de integração, comandos reais e resultados.
Se algum teste não puder ser executado, informe o impedimento concretamente.
Encerre após o relatório da Fase 0, sem avançar à Fase 1.
```

## 12. Conferência técnica externa e limites

Durante o planejamento inicial, ainda sem checkout local, foram consultadas referências primárias do upstream para orientar riscos, sem fixar números de linha ou declarar equivalência com a futura revisão-base:

- [`src/d_ticcmd.h`](https://raw.githubusercontent.com/fabiangreffrath/crispy-doom/master/src/d_ticcmd.h): a estrutura consultada contém `buttons2`, `arti`, `lookfly` e `lookdir`; ainda será necessário auditar seus consumidores no checkout.
- [`src/doom/p_user.c`](https://raw.githubusercontent.com/fabiangreffrath/crispy-doom/master/src/doom/p_user.c): o salto consultado usa `arti`/`AFLAG_JUMP`; o movimento aplica thrust a partir de forwardmove/sidemove. Isso orienta preservar o transporte existente de salto e modificar o fator de movimento no ponto adequado.
- [`src/doom/p_pspr.c`](https://raw.githubusercontent.com/fabiangreffrath/crispy-doom/master/src/doom/p_pspr.c): `P_FireWeapon()` envolve checagem de munição, mudança de psprite e alerta sonoro; ready/refire também participam do fluxo. Por isso o planejamento exige revisar o conjunto antes de substituir armas.

Essas URLs apontam para `master` e podem mudar. No início da implementação, substituir a referência operacional pela revisão registrada e revisar os arquivos locais reais. Nenhum build, smoke test ou medição de performance foi executado nesta tarefa de planejamento.
