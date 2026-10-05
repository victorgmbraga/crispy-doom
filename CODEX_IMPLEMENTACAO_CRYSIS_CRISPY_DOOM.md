# Crysis: Contact Demake sobre Crispy Doom
## Especificação de implementação para Codex

> Documento de engenharia para orientar a implementação incremental de um demake inspirado na primeira missão de **Crysis (Contact)** sobre um fork do **Crispy Doom**.
>
> O objetivo é reproduzir as principais mecânicas de Crysis — Nanosuit, sprint, cloak, ADS, armas com carregador/reload, attachments, IA com percepção, objetivos e exploração semiaberta — usando a arquitetura e o renderer de Doom como base.

---

## 0. Instruções obrigatórias para o Codex

Antes de alterar qualquer arquivo:

1. Leia este documento inteiro.
2. Inspecione a versão real dos arquivos citados antes de aplicar patches; não suponha que números de linha continuam iguais.
3. Execute `git status` e não sobrescreva alterações locais não relacionadas.
4. Registre o commit-base com `git rev-parse HEAD` no relatório da primeira tarefa.
5. Compile o projeto original antes da primeira alteração para estabelecer um baseline.
6. Faça mudanças pequenas e compiláveis. Não tente implementar todos os sistemas em um único patch.
7. Não refatore código do Crispy Doom que não seja necessário para a tarefa atual.
8. Todo código específico deste projeto deve usar o prefixo `CR_` para funções, `cr_` para variáveis/arquivos e comentários `// [crysis]` quando houver integração em código herdado.
9. Preserve o comportamento original do Crispy Doom quando o modo Crysis estiver desativado.
10. Depois de cada milestone, compile e execute um smoke test antes de iniciar o próximo.

### Regra principal de arquitetura

Não transformar `p_user.c`, `p_enemy.c`, `p_pspr.c`, `p_inter.c` ou `st_stuff.c` em arquivos contendo a lógica completa do novo jogo.

Esses arquivos devem conter apenas **hooks pequenos** que delegam para módulos `cr_*`.

Exemplo desejado:

```c
// [crysis]
if (CR_IsActive())
{
    CR_PlayerThink(player);
}
```

Evitar:

```c
// NÃO FAZER: centenas de linhas de Nanosuit diretamente em P_PlayerThink().
```

---

# 1. Objetivo do projeto

Criar um fork do Crispy Doom capaz de executar um vertical slice inspirado na missão **Contact**, de Crysis 1.

O primeiro alvo jogável deve conter:

```text
praia / ponto inicial
        ↓
travessia inicial
        ↓
encontro narrativo equivalente ao Aztec
        ↓
primeira patrulha inimiga
        ↓
floresta / aproximação
        ↓
área aberta com múltiplas rotas
        ↓
vila inimiga
        ↓
objetivo opcional: jammer
        ↓
saída para a próxima área
```

A geometria não deve ser uma conversão literal do mapa original. O mapa deve ser redesenhado para funcionar bem no renderer BSP do Doom.

### O vertical slice é considerado bem-sucedido quando

O jogador consegue:

- iniciar uma partida diretamente no mapa do projeto;
- usar freelook e mira vertical;
- correr usando sprint;
- pular;
- alternar entre Armor, Strength, Speed e Cloak;
- consumir e regenerar energia da Nanosuit;
- receber dano com proteção do Armor;
- recuperar saúde depois de permanecer algum tempo sem receber dano;
- mirar usando ADS;
- usar pelo menos SOCOM, SCAR e FY71 equivalentes;
- recarregar armas com carregadores independentes da reserva de munição;
- alternar modo de tiro quando suportado;
- usar pelo menos silenciador e uma mira como attachments;
- ser detectado gradualmente pelos inimigos;
- usar Cloak para reduzir a capacidade de detecção;
- atrair inimigos por ruído;
- completar objetivos da missão;
- desativar o jammer;
- terminar o vertical slice sem erros, crashes ou softlocks.

---

# 2. Escopo e não-escopo

## 2.1 Incluído na primeira versão

- single-player;
- mapa próprio inspirado em Contact;
- Nanosuit;
- sprint;
- health regeneration;
- ADS;
- recoil;
- magazine/reload;
- modos de tiro;
- attachments básicos;
- soldados inimigos humanos;
- sistema de percepção visual e auditiva;
- estados de patrulha, suspeita, investigação, combate e busca;
- HUD próprio;
- sistema de objetivos;
- gatilhos de missão;
- vegetação baseada majoritariamente em sprites;
- suporte a resolução e framerate já existentes no Crispy Doom.

## 2.2 Fora do escopo inicial

Não implementar no primeiro vertical slice:

- veículos dirigíveis;
- física equivalente ao CryEngine;
- destruição completa de estruturas;
- árvores fisicamente quebráveis;
- ragdolls;
- multiplayer;
- coop;
- netplay determinístico;
- compatibilidade com demos vanilla enquanto `-crysis` estiver ativo;
- campanha completa de Crysis;
- renderer OpenGL/Vulkan;
- voxels ou modelos 3D;
- slopes generalizados;
- room-over-room real;
- conversão automática de assets de Crysis;
- reprodução pixel-perfect da interface original.

Esses itens podem ser reavaliados somente após o vertical slice estar funcional e estável.

---

# 3. Licenciamento e assets

O código-base do Crispy Doom é distribuído sob GPLv2. As alterações do fork devem respeitar essa licença.

Os assets comerciais de Crysis **não fazem parte do código do Crispy Doom e não devem ser incorporados automaticamente ao repositório**.

Para desenvolvimento inicial, usar:

- sprites temporários;
- texturas próprias ou livres;
- sons placeholders próprios/livres;
- nomes internos genéricos quando necessário;
- um PWAD separado para conteúdo do vertical slice.

Não implementar ferramentas para extrair ou redistribuir assets proprietários como parte desta tarefa.

---

# 4. Baseline técnico do Crispy Doom

A estrutura upstream observada para esta especificação corresponde ao layout da linha 7.1.0 disponível no `master` consultado em 2026-10-05. O checkout local deve continuar sendo tratado como fonte de verdade.

Ela usa:

- linguagem C;
- padrão C99 no CMake;
- SDL2;
- `src/doom/` para a lógica específica de Doom;
- `src/doom/CMakeLists.txt` para a biblioteca estática `doom`;
- `src/CMakeLists.txt` para os executáveis e código compartilhado.

Na árvore upstream atual, os principais pontos de integração são:

| Arquivo | Responsabilidade relevante |
|---|---|
| `src/doom/p_user.c` | movimento, altura de visão, jump, `P_PlayerThink()` |
| `src/doom/p_inter.c` | dano, pickups, `P_DamageMobj()` |
| `src/doom/p_pspr.c` | armas/psprites, `P_FireWeapon()`, `A_WeaponReady()`, `A_ReFire()` |
| `src/doom/p_enemy.c` | aquisição de alvo e comportamento vanilla, `A_Look()`, `A_Chase()` |
| `src/doom/p_sight.c` | line-of-sight |
| `src/doom/g_game.c` | criação do `ticcmd`, incluindo `G_BuildTiccmd()` |
| `src/d_ticcmd.h` | estrutura de comandos por tic |
| `src/m_controls.c` | bindings de teclado/mouse/joystick |
| `src/doom/st_stuff.c` | status bar/HUD clássico |
| `src/doom/r_main.c` | projeção, FOV fixo, view size e mapeamento de ângulos |
| `src/doom/p_spec.c` | especiais de linhas/setores |
| `src/doom/p_saveg.c` | savegame vanilla |
| `src/doom/CMakeLists.txt` | lista dos fontes específicos de Doom |

O Crispy Doom já possui infraestrutura útil de:

- freelook;
- mouse look;
- free aim;
- jumping;
- uncapped rendering/interpolação;
- widescreen;
- crosshair;
- resolução superior ao vanilla;
- blockmap e vários limites expandidos.

### Estilo do upstream

Embora o build use C99, o projeto habilita avisos como `-Wdeclaration-after-statement`. Portanto:

- declarar variáveis preferencialmente no início do bloco;
- evitar recursos C modernos desnecessários;
- manter o estilo próximo do restante do código;
- compilar sem novos warnings.

---

# 5. Estratégia de compatibilidade

O projeto deve introduzir um **modo Crysis explícito**, inicialmente ativado por:

```text
-crysis
```

Quando `-crysis` não estiver presente:

- Doom deve continuar funcionando normalmente;
- o comportamento de armas vanilla deve permanecer intacto;
- a IA vanilla deve permanecer intacta;
- o HUD vanilla deve permanecer disponível;
- demos/netplay não devem receber lógica Crysis;
- nenhuma constante de balanceamento Crysis deve afetar o jogo vanilla.

Isso é uma ferramenta de engenharia e regressão, mesmo que o fork futuramente se torne um jogo dedicado.

### API mínima

Criar:

```text
src/doom/cr_game.c
src/doom/cr_game.h
```

API inicial:

```c
boolean CR_IsActive(void);
void CR_Init(void);
void CR_NewGame(void);
void CR_LevelStart(void);
void CR_LevelEnd(void);
void CR_Ticker(void);
```

`CR_Init()` deve detectar o argumento `-crysis` usando a infraestrutura existente de argumentos do projeto.

Não espalhar `M_CheckParm("-crysis")` pelo código. Somente `CR_IsActive()` deve ser usado depois da inicialização.

---

# 6. Estrutura de módulos

Criar gradualmente os seguintes arquivos em `src/doom/`:

```text
cr_game.c / cr_game.h
cr_defs.h
cr_player.c / cr_player.h
cr_nanosuit.c / cr_nanosuit.h
cr_weapon.c / cr_weapon.h
cr_ai.c / cr_ai.h
cr_sound.c / cr_sound.h
cr_interact.c / cr_interact.h
cr_objective.c / cr_objective.h
cr_hud.c / cr_hud.h
cr_render.c / cr_render.h        # somente quando necessário para ADS/FOV
cr_debug.c / cr_debug.h          # opcional, mas recomendado
```

Adicionar cada `.c/.h` a `src/doom/CMakeLists.txt` somente quando o módulo passar a existir.

### Dependências desejadas

```text
                 cr_game
                    │
        ┌───────────┼───────────┐
        │           │           │
    cr_player   cr_objective   cr_hud
        │
   ┌────┼─────┬────────┐
   │    │     │        │
nanosuit weapon interact sound
                    │
                   ai
```

Evitar dependências circulares.

`cr_defs.h` deve conter apenas tipos, enums e constantes compartilhadas de baixo nível.

---

# 7. Estado do jogador

## 7.1 Não aumentar `player_t` indiscriminadamente

Para isolar o fork do estado vanilla, a primeira implementação deve preferir um estado paralelo:

```c
typedef struct
{
    boolean initialized;

    int health_regen_delay;
    int last_damage_tic;

    boolean sprinting;
    boolean ads;
    boolean crouching;

    cr_nanosuit_t suit;
    cr_weapon_state_t weapon;

    mobj_t *held_object;
} cr_player_state_t;
```

Armazenar:

```c
extern cr_player_state_t cr_players[MAXPLAYERS];
```

Fornecer:

```c
cr_player_state_t *CR_PlayerState(player_t *player);
const cr_player_state_t *CR_PlayerStateConst(const player_t *player);
void CR_PlayerReset(player_t *player);
void CR_PlayerThink(player_t *player);
```

O índice pode ser obtido pela posição do `player` no array global `players`, validando o intervalo antes de acessar `cr_players`.

Isso reduz alterações no `player_t` e facilita manter Doom vanilla funcional.

---

# 8. Input

## 8.1 Usar `ticcmd_t`, não estado global diretamente no gameplay

A lógica de gameplay deve consumir comandos do `ticcmd`, preservando a filosofia de simulação por tics.

A estrutura upstream já possui `buttons2`. Para a primeira versão, reutilizar `buttons2` quando `CR_IsActive()` for verdadeiro.

Definir em header específico:

```c
#define CR_BT2_SPRINT       0x01
#define CR_BT2_ADS          0x02
#define CR_BT2_RELOAD       0x04
#define CR_BT2_INTERACT     0x08
#define CR_BT2_SUIT_NEXT    0x10
#define CR_BT2_FIREMODE     0x20
#define CR_BT2_ATTACHMENT   0x40
#define CR_BT2_CROUCH       0x80
```

Não alterar o tamanho de `ticcmd_t` na Fase 1.

## 8.2 Bindings iniciais

Adicionar bindings configuráveis:

```text
Shift direito/esquerdo  sprint
botão direito do mouse  ADS
R                       reload
E                       interact
Q                       alternar Nanosuit
B                       alternar fire mode
X                       attachments
C                       crouch (fase posterior se necessário)
```

Os defaults podem ser ajustados conforme conflitos com o Crispy Doom.

Criar variáveis como:

```c
int key_cr_sprint;
int key_cr_reload;
int key_cr_interact;
int key_cr_suit;
int key_cr_firemode;
int key_cr_attachment;
int key_cr_crouch;

int mouseb_cr_ads;
```

Registrar os bindings usando `M_BindIntVariable()`.

## 8.3 `G_BuildTiccmd()`

Adicionar um hook pequeno ao final da composição do comando:

```c
if (CR_IsActive())
{
    CR_BuildTiccmd(cmd);
}
```

Criar `CR_BuildTiccmd()` em módulo próprio sempre que possível.

### Sprint e o run vanilla

O Crispy Doom já usa a tecla de velocidade para selecionar velocidades vanilla. Em modo Crysis, não permitir que Shift aplique simultaneamente:

1. o multiplicador vanilla de run; e
2. o multiplicador do Nanosuit.

Em `-crysis`, a velocidade de base deve ser controlada pelo código Crysis e o sprint deve entrar como estado separado.

---

# 9. Nanosuit

Criar:

```text
cr_nanosuit.c
cr_nanosuit.h
```

## 9.1 Tipos

```c
typedef enum
{
    CR_SUIT_ARMOR = 0,
    CR_SUIT_STRENGTH,
    CR_SUIT_SPEED,
    CR_SUIT_CLOAK,
    CR_SUIT_COUNT
} cr_suit_mode_t;

typedef struct
{
    cr_suit_mode_t mode;
    int energy;
    int max_energy;
    int recharge_delay_tics;
    int recharge_block_until;
    boolean cloak_visible;
} cr_nanosuit_t;
```

## 9.2 Constantes iniciais

Manter balanceamento em um único local.

Exemplo de ponto de partida, sujeito a tuning:

```c
#define CR_SUIT_MAX_ENERGY             100
#define CR_SUIT_RECHARGE_DELAY_TICS     35
#define CR_SUIT_RECHARGE_PER_TIC         1
#define CR_CLOAK_IDLE_DRAIN_TICS         8
#define CR_CLOAK_MOVE_DRAIN_TICS         3
#define CR_SPEED_SPRINT_DRAIN_TICS       3
#define CR_ARMOR_DAMAGE_ENERGY_NUM       1
#define CR_ARMOR_DAMAGE_ENERGY_DEN       1
```

Não espalhar números mágicos pelo gameplay.

## 9.3 API

```c
void CR_SuitInit(cr_nanosuit_t *suit);
void CR_SuitTick(player_t *player);
void CR_SuitSetMode(player_t *player, cr_suit_mode_t mode);
void CR_SuitNextMode(player_t *player);
int  CR_SuitAbsorbDamage(player_t *player, int damage);
void CR_SuitOnWeaponFired(player_t *player);
boolean CR_SuitConsume(player_t *player, int amount);
int CR_SuitVisibilityFactor(const player_t *player);
```

## 9.4 Armor

Integrar em `P_DamageMobj()` somente no caminho de dano ao player.

Ordem desejada em modo Crysis:

```text
dano bruto
   ↓
god/invulnerability
   ↓
CR_SuitAbsorbDamage()
   ↓
saúde
```

Não aplicar simultaneamente Armor do Doom e Armor do Nanosuit no modo Crysis.

Quando Armor estiver ativo:

- parte do dano deve ser absorvida;
- a absorção reduz energia;
- dano excedente passa para saúde;
- receber dano bloqueia temporariamente a recarga de energia;
- registrar `last_damage_tic` para health regeneration.

## 9.5 Speed

Speed afeta prioritariamente sprint.

Fluxo:

```text
movimento normal
    ↓
CR_PlayerMoveScale()
    ↓
Speed ativo + sprint pressionado + energia > 0
    ↓
velocidade aumentada
    ↓
consumo de energia por tic
```

Não multiplicar momentum sem limite. Aplicar clamp adequado para evitar velocidades que quebrem colisão e atravessamento de linhas.

## 9.6 Strength

Na primeira versão, Strength deve afetar:

- altura/impulso do salto;
- dano melee;
- recoil;
- futuramente arremesso de objetos.

Pulo normal deve continuar funcional mesmo fora de Strength.

Exemplo de API:

```c
fixed_t CR_SuitJumpMomentum(const player_t *player, fixed_t normal_momz);
int CR_SuitMeleeDamage(const player_t *player, int base_damage);
fixed_t CR_SuitRecoilScale(const player_t *player);
```

## 9.7 Cloak

Cloak não deve simplesmente ativar `CF_NOTARGET`, pois isso elimina a mecânica de percepção.

Em vez disso:

- produzir um fator de visibilidade;
- reduzir drasticamente detecção visual quando parado;
- aumentar um pouco a visibilidade ao caminhar;
- aumentar mais quando correndo;
- consumir energia continuamente;
- disparar uma arma quebra o cloak ou zera a energia;
- explosões e contatos muito próximos podem revelar o jogador.

A IA deve consultar `CR_SuitVisibilityFactor()`.

---

# 10. Health regeneration

Criar o comportamento em `cr_player.c`.

Estado mínimo:

```c
int last_damage_tic;
int health_regen_accumulator;
```

Regras iniciais:

- máximo padrão: 100;
- após receber dano, aguardar um delay;
- depois regenerar gradualmente;
- dano novo reinicia o delay;
- regeneração não deve ocorrer morto;
- sincronizar `player->health` e `player->mo->health`.

Constantes sugeridas:

```c
#define CR_HEALTH_MAX                  100
#define CR_HEALTH_REGEN_DELAY_TICS    (5 * TICRATE)
#define CR_HEALTH_REGEN_STEP_TICS       4
```

Esses valores são tuning, não contrato de gameplay.

---

# 11. Movimento

## 11.1 Hook principal

`P_MovePlayer()` é o ponto onde o upstream aplica `cmd->forwardmove` e `cmd->sidemove` através de `P_Thrust()`.

Em modo Crysis, calcular um fator de movimento antes do thrust.

Preferir algo como:

```c
fixed_t CR_PlayerMoveFactor(player_t *player);
```

ou funções que retornem movimentos escalados, evitando duplicar `P_MovePlayer()` inteiro.

## 11.2 Velocidades

Estados:

```text
walk / normal
run normal
Speed sprint
ADS movement
crouch movement (fase posterior)
```

ADS reduz velocidade.

Sprint não deve ser permitido em situações como:

- morto;
- recarregando, caso o balanceamento escolhido exija;
- energia zerada em Speed;
- estado de interação bloqueante.

## 11.3 Jump

O upstream já aplica momentum vertical na lógica de jump.

Substituir somente o valor do impulso quando Crysis estiver ativo:

```c
momz = CR_SuitJumpMomentum(player, normal_momz);
```

Não duplicar a lógica completa de jump.

---

# 12. Sistema de armas

Criar:

```text
cr_weapon.c
cr_weapon.h
```

## 12.1 Estratégia da primeira versão

**Não expandir `weapontype_t` imediatamente.**

Na Fase 1, reutilizar slots vanilla como transporte interno para reduzir o impacto em arrays, DEHACKED, saves e seleção de arma.

Mapeamento inicial sugerido:

```text
wp_fist      → melee
wp_pistol    → SOCOM
wp_chaingun  → SCAR
wp_plasma    → FY71
```

A interface Crysis deve esconder essa implementação.

No futuro, quando o sistema estiver estável, avaliar substituir o mapeamento por IDs próprios de forma mais profunda.

## 12.2 Definição de arma

```c
typedef enum
{
    CR_WEAPON_MELEE = 0,
    CR_WEAPON_SOCOM,
    CR_WEAPON_SCAR,
    CR_WEAPON_FY71,
    CR_WEAPON_COUNT
} cr_weapon_id_t;

typedef enum
{
    CR_FIRE_SEMI = 1 << 0,
    CR_FIRE_AUTO = 1 << 1,
    CR_FIRE_BURST = 1 << 2
} cr_fire_mode_mask_t;

typedef struct
{
    const char *name;
    int damage;
    int magazine_size;
    int reserve_max;
    int shots_per_minute;
    fixed_t hip_spread;
    fixed_t ads_spread;
    fixed_t recoil_pitch;
    fixed_t recoil_yaw;
    int noise_radius;
    unsigned int fire_modes;
    unsigned int attachment_mask;
} cr_weapon_def_t;
```

Estado runtime:

```c
typedef struct
{
    cr_weapon_id_t current;
    int magazine[CR_WEAPON_COUNT];
    int reserve[CR_WEAPON_COUNT];
    unsigned int fire_mode[CR_WEAPON_COUNT];
    unsigned int attachments[CR_WEAPON_COUNT];
    int next_fire_tic;
    int reload_end_tic;
    boolean reloading;
} cr_weapon_state_t;
```

## 12.3 Magazine e reload

Diferenciar:

```text
magazine
reserve ammo
```

Ao disparar:

```text
magazine--
```

Ao recarregar:

```text
needed = magazine_size - magazine
loaded = MIN(needed, reserve)
magazine += loaded
reserve -= loaded
```

Reload deve possuir duração em tics e não ser instantâneo.

Cancelar ou não reload ao sprint/weapon switch deve ser decisão explícita e centralizada.

## 12.4 Integração com `P_FireWeapon()`

Modificar `P_FireWeapon()` de forma mínima:

```c
if (CR_IsActive())
{
    CR_WeaponFire(player);
    return;
}
```

A lógica vanilla abaixo desse hook deve permanecer intocada sempre que possível.

`CR_WeaponFire()` deve:

1. verificar reload;
2. verificar magazine;
3. verificar cadence (`next_fire_tic`);
4. disparar hitscan/projétil;
5. reduzir magazine;
6. aplicar recoil;
7. gerar evento de ruído;
8. notificar Nanosuit para quebrar Cloak;
9. iniciar animação/flash apropriados;
10. definir próximo tic permitido.

## 12.5 Fire rate

Converter RPM para tics:

```text
tics_per_shot ≈ TICRATE * 60 / rpm
```

Como o Doom simula em 35 Hz, alguns RPMs não podem ser representados exatamente. Preferir consistência a micro-otimizações.

## 12.6 Hitscan

Reaproveitar:

- `P_AimLineAttack()`;
- `P_LineAttack()`;
- mecanismos existentes de slope/freeaim quando aplicáveis.

Não criar um sistema de raycast paralelo sem necessidade.

## 12.7 Spread

Spread depende de:

- hip fire;
- ADS;
- movimento;
- sprint;
- stance;
- estado Strength, se desejado.

O cálculo deve ficar em:

```c
fixed_t CR_WeaponCurrentSpread(const player_t *player);
```

## 12.8 Recoil

O upstream já possui `player->recoilpitch` usado pelo Crispy Doom.

Reutilizar essa infraestrutura antes de criar um sistema paralelo completo.

Adicionar yaw recoil somente se necessário.

Strength reduz recoil por multiplicador centralizado.

---

# 13. ADS e FOV

ADS precisa produzir pelo menos:

- FOV reduzido;
- arma reposicionada/centralizada;
- spread menor;
- velocidade menor;
- sensibilidade de mouse opcionalmente reduzida;
- overlay de scope quando apropriado.

## 13.1 Implementação em duas etapas

### Etapa A — MVP

Implementar ADS sem FOV variável complexo:

- alterar posição do psprite;
- reduzir spread;
- reduzir movement factor;
- desenhar retícula/overlay;
- usar o FOV existente.

Isso permite validar armas sem tocar cedo demais no renderer.

### Etapa B — FOV real

O renderer atual usa `FIELDOFVIEW` em `r_main.c`, especialmente em `R_InitTextureMapping()`.

Transformar o valor fixo em estado configurável apenas quando o MVP estiver estável.

Criar API semelhante a:

```c
void CR_RenderSetADS(boolean ads);
```

Não recalcular tabelas de projeção a cada frame se nada mudou.

Na primeira versão com FOV real, aceitar transição instantânea:

```text
hip FOV → ADS FOV
```

A interpolação suave pode vir depois.

---

# 14. Attachments

Attachments iniciais:

```text
Suppressor
Reflex sight
Scope
Laser (opcional no primeiro slice)
```

Flags:

```c
#define CR_ATTACH_SUPPRESSOR  (1u << 0)
#define CR_ATTACH_REFLEX      (1u << 1)
#define CR_ATTACH_SCOPE       (1u << 2)
#define CR_ATTACH_LASER       (1u << 3)
```

Efeitos mínimos:

### Suppressor

- reduz `noise_radius`;
- pode reduzir levemente dano/alcance somente se desejado pelo balanceamento;
- altera som do disparo.

### Reflex

- ADS padrão;
- retícula própria.

### Scope

- FOV mais fechado;
- overlay próprio;
- maior precisão.

### Laser

- reduzir hip spread;
- elemento visual pode ser adiado.

## Menu de attachments

Primeiro implementar uma UI funcional simples.

Não é necessário começar com menu radial perfeito.

MVP:

```text
pressionar X
  ↓
abre pequeno overlay
  ↓
teclas/direções escolhem slot
  ↓
X/Use confirma
```

Depois substituir por radial.

---

# 15. Sistema de ruído

O Doom já chama `P_NoiseAlert()` no disparo vanilla. Em modo Crysis, não usar isso como mecanismo principal porque ele tende a acordar inimigos de forma binária.

Criar:

```text
cr_sound.c
cr_sound.h
```

API:

```c
typedef enum
{
    CR_NOISE_FOOTSTEP,
    CR_NOISE_GUNSHOT,
    CR_NOISE_SUPPRESSED_GUNSHOT,
    CR_NOISE_EXPLOSION,
    CR_NOISE_IMPACT
} cr_noise_type_t;

void CR_EmitNoise(mobj_t *source,
                  fixed_t x,
                  fixed_t y,
                  int radius,
                  cr_noise_type_t type);
```

A IA deve receber eventos de ruído e decidir se investiga.

Não fazer busca O(N²) desnecessária para cada tic. Eventos de som são esparsos; percorrer atores relevantes quando um evento é emitido é aceitável inicialmente.

---

# 16. IA inimiga

Criar:

```text
cr_ai.c
cr_ai.h
```

## 16.1 Estados

```c
typedef enum
{
    CR_AI_PATROL = 0,
    CR_AI_SUSPICIOUS,
    CR_AI_INVESTIGATE,
    CR_AI_ALERT,
    CR_AI_COMBAT,
    CR_AI_SEARCH,
    CR_AI_RETURN
} cr_ai_state_t;
```

Fluxo principal:

```text
PATROL
  │
  ├─ visão parcial / ruído ─→ SUSPICIOUS
  │                             │
  │                             └→ INVESTIGATE
  │                                    │
  │                                    ├→ SEARCH
  │                                    │    │
  │                                    │    └→ RETURN
  │                                    │
  └─ confirmação visual ────────────────┴→ COMBAT
```

## 16.2 Estado por ator

Para a primeira implementação, é aceitável adicionar poucos campos específicos em `mobj_t` se isso simplificar muito a lógica.

Preferir campos escalares, não estruturas enormes.

Exemplo:

```c
byte cr_ai_state;
byte cr_suspicion;
int cr_last_seen_tic;
fixed_t cr_last_seen_x;
fixed_t cr_last_seen_y;
int cr_last_heard_tic;
fixed_t cr_last_heard_x;
fixed_t cr_last_heard_y;
```

Marcar claramente com comentários `[crysis]`.

Como savegames não fazem parte do milestone inicial, a serialização desses campos pode ser adiada, mas deve existir um TODO explícito.

## 16.3 Percepção visual

Não substituir `P_CheckSight()`; utilizá-lo como parte do cálculo.

Detecção deve depender de:

```text
line of sight
+ distância
+ ângulo em relação à direção do inimigo
+ movimento do jogador
+ cloak
+ exposição/visibilidade simplificada
+ tempo contínuo de observação
```

Modelo simples:

```c
suspicion += CR_AIVisualGain(actor, player);
suspicion -= CR_AISuspicionDecay(actor);
```

Clampar em `0..100`.

Sugestão de estados:

```text
0-24    patrol
25-49   suspicious
50-99   investigate/alert
100     combat
```

Não usar apenas uma rolagem aleatória por tic.

## 16.4 FOV da IA

Calcular diferença angular entre:

- `actor->angle`;
- direção para o player.

Dentro do cone frontal, aplicar ganho normal.

Atrás do inimigo:

- ganho zero ou muito reduzido;
- distância extremamente pequena pode permitir detecção.

## 16.5 Cloak e percepção

`CR_AIVisualGain()` deve multiplicar o ganho pelo fator retornado pelo Nanosuit.

Exemplo conceitual:

```text
sem cloak, parado     1.00
cloak, parado         0.05
cloak, andando        0.15
cloak, correndo       0.35
cloak + disparo       revelado
```

Os valores exatos ficam centralizados em constantes.

## 16.6 Audição

Ao receber `CR_EmitNoise()`:

- verificar distância;
- registrar posição ouvida;
- aumentar suspeita;
- entrar em `INVESTIGATE` quando apropriado;
- não revelar magicamente a posição atual do jogador para sempre.

## 16.7 Combate

Na primeira versão, reaproveitar o máximo possível do movimento e ataque vanilla.

Não é necessário construir navegação avançada imediatamente.

Objetivo da IA do vertical slice:

- patrulhar;
- perceber;
- investigar;
- buscar último local conhecido;
- entrar em combate;
- perder o player depois de quebra de LOS + tempo;
- voltar gradualmente à rotina.

Flanqueamento sofisticado é posterior.

---

# 17. Integração com `A_Look()` e `A_Chase()`

Não reescrever `p_enemy.c` inteiro.

Para atores marcados como soldados Crysis:

```c
if (CR_IsActive() && CR_AIHandlesActor(actor))
{
    CR_AIThink(actor);
    return;
}
```

A localização exata do hook deve ser escolhida após inspecionar os states usados pelo novo inimigo.

É preferível que o novo soldado use uma action function própria, por exemplo:

```c
void A_CRKPAThink(mobj_t *actor);
```

Essa função delega para `CR_AIThink()`.

Assim, monstros Doom vanilla podem continuar usando `A_Look()`/`A_Chase()` normalmente.

---

# 18. Soldado KPA equivalente

Criar pelo menos um tipo de inimigo humano.

Características iniciais:

- 100 HP ou valor de tuning próximo;
- ataque hitscan de rifle;
- precisão dependente de distância;
- pequeno tempo de reação;
- burst fire;
- movimentação similar a humano;
- percepção Crysis;
- drop opcional de munição/arma.

Não criar múltiplas classes de soldados antes de a IA básica funcionar.

Para placeholder inicial, é aceitável reutilizar sprite/sons livres ou temporários.

---

# 19. Interação com objetos

Criar:

```text
cr_interact.c
cr_interact.h
```

API inicial:

```c
boolean CR_TryInteract(player_t *player);
```

Fase 1:

- objetivos utilizáveis;
- jammer;
- portas/controles especiais quando necessário.

Fase posterior:

- pegar caixas;
- carregar objetos;
- lançar objetos usando Strength.

## Objetos carregáveis

Não implementar antes do sistema principal estar jogável.

Quando implementado:

```text
Use perto do objeto
      ↓
held_object = objeto
      ↓
objeto acompanha posição frontal do player
      ↓
Fire/Use
      ↓
solta ou arremessa
```

Evitar tentar criar física geral. Usar momentum do `mobj_t`.

---

# 20. Sistema de objetivos

Criar:

```text
cr_objective.c
cr_objective.h
```

Tipos:

```c
typedef enum
{
    CR_OBJ_LOCKED,
    CR_OBJ_ACTIVE,
    CR_OBJ_COMPLETE,
    CR_OBJ_FAILED
} cr_objective_state_t;
```

Estrutura:

```c
typedef struct
{
    int id;
    const char *title;
    const char *description;
    boolean optional;
    cr_objective_state_t state;
} cr_objective_t;
```

API:

```c
void CR_ObjectivesReset(void);
void CR_ObjectiveActivate(int id);
void CR_ObjectiveComplete(int id);
void CR_ObjectiveFail(int id);
const cr_objective_t *CR_ObjectiveCurrent(void);
```

## 20.1 Gatilhos de mapa

Evitar lógica baseada em coordenadas hardcoded em C.

Preferir linedef specials exclusivos do projeto.

Reservar um intervalo privado, após verificar conflitos com o formato/port, por exemplo:

```text
220  CR objective trigger
221  CR objective use
222  CR mission exit
```

Usar `line->tag` para identificar o objetivo/evento.

Exemplo:

```text
special 220, tag 3
→ CR_ObjectiveActivate(3)
```

Antes de reservar números definitivos, verificar os especiais já utilizados pelo Crispy Doom e pelo formato de mapa escolhido.

## 20.2 Jammer

Implementação simples:

- linha/console utilizável com special próprio;
- ao usar:
  - tocar som;
  - completar objetivo opcional;
  - mudar estado visual se houver textura alternativa;
  - habilitar consequência de gameplay se desejado.

---

# 21. HUD

Criar:

```text
cr_hud.c
cr_hud.h
```

HUD inicial:

```text
┌──────────────────────────────────────────────────┐
│                                   OBJECTIVE      │
│                                                  │
│                       +                          │
│                                                  │
│                                                  │
│ RADAR*                              SCAR 28 / 180 │
│ HP     ██████████ 100               AUTO          │
│ ENERGY ████████░░  82               ARMOR         │
└──────────────────────────────────────────────────┘
```

`*` radar completo pode ser adiado.

Obrigatório no MVP:

- saúde;
- energia;
- modo da Nanosuit;
- arma;
- magazine;
- reserve ammo;
- fire mode;
- estado ADS se necessário;
- objetivo atual;
- indicador simples de suspeita/detecção opcional.

## Integração

Ao desenhar HUD:

```c
if (CR_IsActive())
{
    CR_HUDDraw();
    return;
}
```

Escolher o hook que preserve mensagens/menu/automap do upstream.

Não duplicar o sistema de vídeo.

---

# 22. Recoil

Usar inicialmente `player->recoilpitch` do Crispy Doom.

`CR_WeaponApplyRecoil()` deve:

- adicionar impulso vertical;
- opcionalmente pequeno yaw;
- aplicar escala de ADS;
- aplicar escala de Strength;
- respeitar limites de lookdir.

Não usar jitter visual puramente aleatório sem afetar a mira real, pois o objetivo é recoil funcional.

Gameplay RNG deve utilizar a infraestrutura determinística do Doom (`P_Random()`/equivalente apropriado), não `rand()`.

---

# 23. Mapa

## 23.1 Filosofia

O mapa deve transmitir a sensação de:

- ilha tropical;
- espaço aberto;
- múltiplas aproximações;
- stealth;
- combate emergente;

sem exigir que o software renderer desenhe quilômetros de cenário simultaneamente.

## 23.2 Oclusão natural

Usar:

- colinas;
- paredes rochosas;
- curvas;
- desníveis;
- florestas densas;
- construções;
- cânions;
- corredores naturais.

Objetivo: impedir longas linhas de visão atravessando grande parte do mapa.

## 23.3 Vegetação

Preferir sprites para:

```text
palmeiras
árvores
arbustos
capim alto
vegetação pequena
rochas pequenas
```

Geometria real somente onde afeta colisão ou composição do cenário.

Para árvores grandes:

- sprite visual;
- blocker simples/invisível ou raio de colisão apropriado;
- evitar dezenas de sidedefs por árvore.

## 23.4 Divisão do vertical slice

Sugestão:

```text
[ZONA A] praia
      ↓
[ZONA B] floresta / Aztec
      ↓
[ZONA C] patrulha
      ↓
[ZONA D] mirante
      ↓
┌────────────────────────────┐
│ [ZONA E] vila              │
│                            │
│ rota mata   rota estrada   │
│      \       /             │
│       jammer               │
│          \                 │
│          saída             │
└────────────────────────────┘
```

Cada zona deve ter oclusão suficiente para limitar o número de subsectors/sprites visíveis simultaneamente.

---

# 24. Performance

Performance é requisito central.

## 24.1 Não fazer por tic

Evitar:

- alocação heap frequente;
- varrer todos os thinkers várias vezes por inimigo;
- recalcular tabelas de FOV se nada mudou;
- fazer pathfinding global;
- criar centenas de partículas como mobjs;
- line-of-sight para todos contra todos.

## 24.2 IA

Usar percepção em frequências diferentes quando possível.

Exemplo:

```text
movimento/combate       todo tic
LOS distante            a cada 2-4 tics
patrulha sem contato    a cada 4-8 tics
```

Não sacrificar responsividade em combate.

## 24.3 Ruído

Processar somente quando um evento de ruído existe.

## 24.4 Sprites

Evitar densidade extrema de vegetação em uma única linha de visão.

## 24.5 Meta inicial

Em hardware moderno, o vertical slice deve permanecer confortavelmente acima da taxa lógica de 35 Hz e não apresentar stutter perceptível causado por IA.

Como o Crispy pode renderizar uncapped, medir também frametime do renderer em áreas críticas.

---

# 25. Savegames, demos e netplay

## Fase inicial

Quando `-crysis` estiver ativo:

- netplay pode ser explicitamente marcado como não suportado;
- demo recording/playback pode ser bloqueado com mensagem clara;
- save/load pode ser temporariamente desabilitado se o novo estado ainda não for serializado.

Não permitir silenciosamente saves corrompidos.

## Fase posterior

Quando os sistemas centrais estabilizarem, serializar:

- `cr_player_state_t`;
- energia/mode da Nanosuit;
- magazines/reserve ammo;
- attachments;
- fire mode;
- objective states;
- AI state e last known positions se necessário.

Adicionar versão própria ao bloco de save do modo Crysis.

---

# 26. Debug tooling

Criar opcionalmente:

```text
-crdebug
```

HUD debug pode mostrar:

```text
FPS
posição XYZ
setor/subsector
suit mode / energy
weapon / magazine / reserve
player visibility factor
número de inimigos alertados
AI state do alvo sob crosshair
suspicion
last seen position
last heard position
```

Não deixar debug visual ativo por padrão.

Funções sugeridas:

```c
boolean CR_DebugEnabled(void);
void CR_DebugDraw(void);
```

Isso economizará tempo significativo na construção da IA e do mapa.

---

# 27. Logging

Mensagens específicas devem usar prefixo consistente:

```text
[CRYSIS] ...
```

Evitar `printf()` por tic.

Usar logs para:

- inicialização;
- ativação do modo;
- carregamento de mapa;
- mudança de objetivo;
- erros de configuração;
- asserts importantes em debug.

---

# 28. Fases de implementação

A ordem abaixo é obrigatória salvo motivo técnico documentado.

---

## Fase 0 — Baseline e modo Crysis

### Implementar

- build limpo do upstream;
- `cr_game.[ch]`;
- `cr_defs.h`;
- parâmetro `-crysis`;
- lifecycle mínimo;
- integração CMake;
- log `[CRYSIS] mode enabled`.

### Aceite

```text
crispy-doom sem -crysis → funciona como antes
crispy-doom -crysis     → inicia e imprime log, sem alterar gameplay ainda
```

---

## Fase 1 — Estado do jogador e input

### Implementar

- `cr_player.[ch]`;
- `cr_players[MAXPLAYERS]`;
- bindings;
- bits em `buttons2`;
- `CR_BuildTiccmd()`;
- reset por new game/level.

### Aceite

Debug HUD/log deve confirmar corretamente:

```text
SPRINT pressed
ADS pressed
RELOAD edge
SUIT edge
INTERACT edge
```

Sem comportamento de gameplay ainda.

---

## Fase 2 — Nanosuit

### Implementar

- quatro modos;
- energia;
- recharge delay;
- Armor;
- Strength jump;
- Speed sprint;
- Cloak drain;
- quebra do cloak ao disparar.

### Aceite

- energia nunca < 0 ou > max;
- Armor reduz dano;
- Strength aumenta jump;
- Speed aumenta velocidade somente enquanto aplicável;
- Cloak drena energia;
- energia volta após delay;
- Doom vanilla permanece intacto sem `-crysis`.

---

## Fase 3 — Health regen e HUD mínimo

### Implementar

- health regen;
- `cr_hud.[ch]`;
- HP;
- energia;
- suit mode.

### Aceite

Receber dano deve:

1. atualizar HP;
2. interromper regen;
3. atualizar HUD;
4. iniciar regen depois do delay.

---

## Fase 4 — Arma base

### Implementar

- `cr_weapon.[ch]`;
- SOCOM;
- SCAR;
- FY71;
- magazine;
- reserve ammo;
- reload;
- cadence;
- semi/auto;
- spread;
- recoil.

### Aceite

SCAR:

```text
magazine 30
→ dispara
→ 29
→ ...
→ 0
→ não dispara
→ R
→ reload timer
→ magazine preenchido a partir da reserva
```

Número exato do magazine pode ser ajustado depois; o importante é o sistema.

---

## Fase 5 — ADS e attachments

### Implementar

- ADS gameplay;
- redução de spread;
- redução de movement speed;
- reposicionamento de arma;
- suppressor;
- reflex/scope;
- fire mode UI;
- attachments UI simples.

### Aceite

Suppressor deve produzir diferença mensurável no sistema de ruído.

---

## Fase 6 — Ruído e percepção

### Implementar

- `cr_sound.[ch]`;
- `CR_EmitNoise()`;
- `cr_ai.[ch]`;
- suspicion;
- LOS;
- cone visual;
- percepção afetada por cloak;
- eventos auditivos.

### Aceite

Cenário mínimo de teste:

```text
inimigo de costas
player parado
→ não detecta

player dispara sem suppressor
→ inimigo investiga

player usa suppressor longe
→ inimigo não reage ou reage menos

player cruza cone visual sem cloak
→ suspicion sobe

player cruza com cloak
→ suspicion sobe muito mais devagar
```

---

## Fase 7 — KPA e combate

### Implementar

- ator humano próprio;
- estados de patrulha;
- investigação;
- busca;
- combate;
- perda de contato;
- último local conhecido;
- rifle inimigo.

### Aceite

O inimigo não deve:

- saber a posição atual do jogador atrás de paredes;
- continuar perseguindo para sempre depois de perder contato;
- ignorar completamente ruídos próximos.

---

## Fase 8 — Objetivos e interação

### Implementar

- `cr_objective.[ch]`;
- `cr_interact.[ch]`;
- triggers de mapa;
- objetivo principal;
- jammer opcional;
- saída da missão.

### Aceite

Sequência completa de objetivos executável sem cheats.

---

## Fase 9 — Vertical slice do mapa

Construir somente agora a versão detalhada de:

```text
praia
→ encontro narrativo
→ patrulha
→ floresta
→ mirante
→ vila
→ jammer
→ saída
```

Antes disso, os sistemas devem ser validados em um mapa de teste simples.

### Aceite

Completar o slice por no mínimo três abordagens:

```text
1. combate frontal
2. stealth/cloak
3. rota lateral + jammer
```

---

## Fase 10 — Performance e polish

### Implementar

- profiling;
- reduzir thinker scans;
- ajustar frequência da percepção;
- revisar densidade de vegetação;
- áudio;
- animações;
- tuning;
- FOV ADS real se ainda não implementado;
- UI radial se desejado.

---

# 29. Build

Fluxo CMake recomendado:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j
```

O Codex deve adaptar o comando ao ambiente disponível e registrar qualquer dependência ausente.

Antes de afirmar que uma fase está concluída:

1. compilar;
2. corrigir erros;
3. corrigir novos warnings relevantes;
4. executar o jogo;
5. realizar smoke test da feature;
6. testar sem `-crysis`.

---

# 30. Política de alterações no upstream

## Permitido

- hooks pequenos;
- novos módulos `cr_*`;
- campos pequenos em structs quando realmente necessário;
- novos states/mobj types para conteúdo Crysis;
- novos bindings;
- novos linedef specials privados;
- mudanças localizadas no renderer para ADS/FOV.

## Evitar

- renomear APIs upstream em massa;
- formatar arquivos inteiros sem necessidade;
- migrar o projeto para C++;
- substituir SDL2;
- criar ECS;
- reescrever thinker system;
- trocar BSP renderer;
- remover compatibilidade vanilla desnecessariamente;
- adicionar dependências externas pesadas.

---

# 31. Convenções de código

Funções:

```c
CR_SuitTick()
CR_AIThink()
CR_WeaponFire()
```

Tipos:

```c
cr_nanosuit_t
cr_ai_state_t
cr_weapon_def_t
```

Globais:

```c
cr_players
cr_debug_enabled
```

Macros:

```c
CR_SUIT_MAX_ENERGY
CR_BT2_ADS
```

Comentários em código herdado:

```c
// [crysis] Delegate damage absorption to Nanosuit in Crysis mode.
```

---

# 32. Critérios de qualidade

Cada feature deve satisfazer:

### Correção

- sem crash;
- sem acesso fora de array;
- sem ponteiro stale óbvio;
- valores clampeados;
- edge-trigger de teclas funcionando;
- nenhum comportamento Crysis vazando para vanilla.

### Performance

- sem alocação por frame/tic sem justificativa;
- sem loops N² recorrentes evitáveis;
- sem log spam;
- sem recomputação cara desnecessária.

### Manutenibilidade

- lógica nova preferencialmente em `cr_*`;
- constantes centralizadas;
- APIs pequenas;
- sem números mágicos;
- nomes claros;
- comentários explicam *por quê*, não repetem o código.

---

# 33. Testes manuais mínimos

Manter um mapa técnico separado do mapa final, por exemplo `MAP99` ou outra entrada adequada ao IWAD/PWAD utilizado.

Esse mapa deve conter:

- sala para teste de dano;
- corredor para sprint;
- plataformas para jump;
- área de tiro;
- inimigo frontal;
- inimigo de costas;
- parede para quebra de LOS;
- jammer de teste;
- trigger de objetivo.

Checklist:

```text
[ ] Armor absorve dano
[ ] energia acaba corretamente
[ ] energia recarrega
[ ] Speed sprint consome energia
[ ] Strength jump funciona
[ ] Cloak reduz percepção
[ ] disparo quebra Cloak
[ ] health regen funciona
[ ] SOCOM dispara/recarrega
[ ] SCAR semi/auto funciona
[ ] FY71 dispara/recarrega
[ ] ADS reduz spread
[ ] suppressor reduz noise radius
[ ] AI reage a tiro alto
[ ] AI investiga último ruído
[ ] AI perde player atrás de cobertura
[ ] objective trigger ativa
[ ] jammer completa objetivo
[ ] saída final funciona
[ ] modo vanilla continua funcional
```

---

# 34. Instrumentação de performance

Depois da IA entrar no projeto, adicionar métricas em debug:

```text
active_cr_ai
visual_checks/frame-or-tic
sight_checks/tic
noise_events/tic
visible_sprites
thinker_count
```

Não otimizar prematuramente antes de medir.

O objetivo é identificar se gargalos vêm de:

```text
renderer
IA
LOS
thinkers
sprites
map geometry
```

---

# 35. Roadmap após o vertical slice

Somente após Fase 10:

## Prioridade A

- objects pickup/throw;
- Strength throw;
- granadas;
- inimigos adicionais;
- radar/minimap;
- comunicação de esquadrão;
- UI radial da Nanosuit;
- UI radial de attachments.

## Prioridade B

- água/nado;
- barcos simplificados;
- veículos;
- destruição limitada;
- objetos físicos adicionais.

## Prioridade C

- slopes;
- renderer avançado;
- modelos/voxels;
- campanha expandida.

---

# 36. Primeira tarefa concreta para o Codex

A primeira execução do Codex neste repositório deve fazer **somente a Fase 0**.

### Prompt operacional

```text
Leia CODEX_IMPLEMENTACAO_CRYSIS_CRISPY_DOOM.md integralmente.

Implemente somente a Fase 0: Baseline e modo Crysis.

Requisitos:
- não implemente Nanosuit, armas ou IA ainda;
- preserve completamente o funcionamento vanilla;
- crie cr_game.c, cr_game.h e cr_defs.h;
- adicione os arquivos ao CMake do módulo Doom;
- implemente CR_IsActive(), CR_Init(), CR_NewGame(), CR_LevelStart(),
  CR_LevelEnd() e CR_Ticker() como infraestrutura mínima;
- ative o modo com o argumento -crysis;
- inicialize a feature em um ponto apropriado da inicialização de Doom;
- imprima uma única mensagem '[CRYSIS] mode enabled' quando ativado;
- compile o projeto;
- execute smoke test com e sem -crysis;
- ao terminar, informe exatamente os arquivos alterados, as decisões de
  integração e os comandos de build/teste executados.

Não faça refactors não relacionados.
```

---

# 37. Forma de trabalho recomendada para tarefas seguintes

Para cada fase, fornecer ao Codex uma tarefa limitada.

Exemplo:

```text
Implemente somente a Fase 2 da especificação.
Antes de editar, revise o código produzido nas Fases 0 e 1.
Não avance para armas nem IA.
Compile e faça smoke tests ao final.
```

Evitar prompts como:

```text
"Implemente todo o projeto Crysis no Doom."
```

A granularidade por fase é fundamental para evitar regressões e mudanças arquiteturais desnecessárias.

---

# 38. Definition of Done do vertical slice

O vertical slice estará pronto quando todos os itens abaixo forem verdadeiros:

```text
[ ] build limpa
[ ] modo vanilla funciona sem -crysis
[ ] modo Crysis inicia com -crysis
[ ] mapa completo carregável
[ ] Nanosuit com 4 modos
[ ] energy drain/recharge
[ ] sprint
[ ] Strength jump
[ ] Armor damage absorption
[ ] Cloak + percepção
[ ] health regeneration
[ ] SOCOM
[ ] SCAR
[ ] FY71
[ ] magazine/reload
[ ] semi/auto quando aplicável
[ ] recoil
[ ] ADS
[ ] suppressor
[ ] optic
[ ] ruído
[ ] AI patrol
[ ] AI suspicious
[ ] AI investigate
[ ] AI combat
[ ] AI search/loss of target
[ ] objective system
[ ] jammer
[ ] HUD
[ ] rota de stealth viável
[ ] rota de combate viável
[ ] sem softlocks conhecidos
[ ] sem crashes conhecidos
[ ] performance aceitável nas áreas abertas
[ ] assets distribuíveis/licenciados corretamente
```

---

# 39. Princípio final de engenharia

A prioridade deste projeto não é reproduzir toda a tecnologia do CryEngine.

A prioridade é reproduzir o **loop de gameplay** de Crysis dentro das limitações e vantagens do motor do Doom:

```text
observar
   ↓
escolher abordagem
   ↓
selecionar modo da Nanosuit
   ↓
stealth / velocidade / força / proteção
   ↓
combate ou infiltração
   ↓
reposicionar
   ↓
regenerar energia
   ↓
continuar objetivo
```

Sempre que houver uma escolha entre:

```text
simulação complexa que imita o CryEngine
```

versus

```text
mecânica simples que produz a mesma decisão de gameplay
```

preferir a segunda.

Isso mantém o projeto rápido, modificável e coerente com a arquitetura do Crispy Doom.

---

# 40. Referências técnicas upstream a consultar durante a implementação

Antes de modificar uma subsystem, revisar a versão atual destes arquivos no próprio checkout:

```text
CMakeLists.txt
src/CMakeLists.txt
src/d_ticcmd.h
src/m_controls.c
src/doom/CMakeLists.txt
src/doom/d_main.c
src/doom/d_player.h
src/doom/g_game.c
src/doom/p_user.c
src/doom/p_inter.c
src/doom/p_pspr.c
src/doom/p_enemy.c
src/doom/p_sight.c
src/doom/p_spec.c
src/doom/p_mobj.c
src/doom/p_saveg.c
src/doom/r_main.c
src/doom/st_stuff.c
```

O checkout local é sempre a fonte de verdade. Esta documentação descreve a arquitetura desejada; se o upstream mudar, adaptar os hooks preservando os princípios desta especificação.
