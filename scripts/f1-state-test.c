/* Phase 1 contract tests: compile the real input/player modules with small
 * engine boundary stubs. No replacement implementation of their logic. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_input.h"
#include "cr_player.h"
#include "doomstat.h"
#include "doomkeys.h"
#include "m_config.h"

player_t players[MAXPLAYERS];
boolean playeringame[MAXPLAYERS];
gamestate_t gamestate = GS_LEVEL;
boolean menuactive;
boolean paused;
int consoleplayer;
int gametic;
int leveltime;
static boolean active = true;
static int assertions;

typedef struct { const char *name; int *value; } binding_t;
static binding_t bindings[32];
static int binding_count;

boolean CR_IsActive(void) { return active; }
boolean CR_DebugEnabled(void) { return false; }

/* Weapon module boundary: the player module resets loadout here. */
void CR_WeaponReset(player_t *player) { (void) player; }
void CR_WeaponLevelStart(player_t *player) { (void) player; }
void CR_WeaponOverlayCommand(player_t *player, ticcmd_t *cmd)
{
    (void) player;
    (void) cmd;
}

void M_BindIntVariable(const char *name, int *value)
{
    if (binding_count >= 32) { fputs("too many bindings\n", stderr); exit(2); }
    bindings[binding_count].name = name;
    bindings[binding_count++].value = value;
}

#define CHECK(test) do { ++assertions; if (!(test)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #test); exit(1); \
} } while (0)

static int *Binding(const char *name)
{
    int i;
    for (i = 0; i < binding_count; ++i)
        if (!strcmp(bindings[i].name, name)) return bindings[i].value;
    fprintf(stderr, "missing binding: %s\n", name);
    exit(1);
}

static void Key(evtype_t type, int code)
{
    event_t event;
    memset(&event, 0, sizeof(event));
    event.type = type;
    event.data1 = code;
    CR_InputEvent(&event);
}

static void Mouse(int mask)
{
    event_t event;
    memset(&event, 0, sizeof(event));
    event.type = ev_mouse;
    event.data1 = mask;
    CR_InputEvent(&event);
}

static void Focus(int focused)
{
    event_t event;
    memset(&event, 0, sizeof(event));
    event.type = ev_focus;
    event.data1 = focused;
    CR_InputEvent(&event);
}

static ticcmd_t Build(void)
{
    ticcmd_t cmd;
    memset(&cmd, 0, sizeof(cmd));
    cmd.arti = 16;
    cmd.lookfly = 7;
    cmd.lookdir = 123;
    cmd.buttons = BT_ATTACK | BT_USE;
    CR_BuildTiccmd(&cmd);
    CHECK(cmd.arti == 16 && cmd.lookfly == 7 && cmd.lookdir == 123);
    CHECK(cmd.buttons == (BT_ATTACK | BT_USE));
    return cmd;
}

static void Consume(ticcmd_t cmd)
{
    players[0].cmd = cmd;
    ++gametic;
    CR_PlayerThink(&players[0]);
}

int main(void)
{
    int i;
    int *reload;
    int *sprint;
    int *ads;
    ticcmd_t cmd;
    player_t foreign;
    mobj_t actor;
    cr_player_state_t *state;
    const char *key_names[] = {"key_cr_sprint", "key_cr_reload",
        "key_cr_interact", "key_cr_suit", "key_cr_firemode",
        "key_cr_attachment", "key_cr_crouch"};

    CHECK(sizeof(ticcmd_t) == 20);
    memset(&actor, 0, sizeof(actor));
    actor.health = 100;
    players[0].mo = &actor;
    players[0].health = 100;
    players[0].playerstate = PST_LIVE;
    playeringame[0] = true;
    CR_BindInputVariables();
    for (i = 0; i < MAXPLAYERS; ++i) {
        CR_PlayerReset(&players[i]);
        CHECK(CR_PlayerState(&players[i]) == &cr_players[i]);
        CHECK(CR_PlayerStateConst(&players[i]) == &cr_players[i]);
    }
    CHECK(CR_PlayerState(NULL) == NULL);
    CHECK(CR_PlayerStateConst(NULL) == NULL);
    CHECK(CR_PlayerState(&foreign) == NULL);
    CHECK(CR_PlayerStateConst(&foreign) == NULL);
    CHECK(CR_PlayerState(&players[MAXPLAYERS]) == NULL);
    CR_PlayerReset(&foreign);
    CR_PlayerThink(&foreign);
    state = CR_PlayerState(&players[0]);
    CHECK(state != NULL && state->initialized);

    /* Build can run several times before a simulation tic. Edges belong
     * to consumption, so command generation must not eat an edge. */
    for (i = 0; i < 7; ++i) Key(ev_keydown, *Binding(key_names[i]));
    ads = Binding("mouseb_cr_ads");
    Mouse(1 << *ads);
    cmd = Build();
    CHECK(cmd.buttons2 == 255);
    CHECK(Build().buttons2 == 255);
    Consume(cmd);
    CHECK(state->buttons_down == 255 && state->buttons_pressed == 255);
    CHECK(state->buttons_released == 0);
    CHECK(state->sprinting && state->ads && state->crouching);
    for (i = 0; i < 10; ++i) {
        Consume(Build());
        CHECK(state->buttons_down == 255 && state->buttons_pressed == 0);
        CHECK(state->buttons_released == 0);
        CHECK(state->sprinting && state->ads && state->crouching);
    }
    for (i = 0; i < 7; ++i) Key(ev_keyup, *Binding(key_names[i]));
    Mouse(0);
    Consume(Build());
    CHECK(state->buttons_down == 0 && state->buttons_pressed == 0);
    CHECK(state->buttons_released == 255);
    CHECK(!state->sprinting && !state->ads && !state->crouching);
    Consume(Build());
    CHECK(state->buttons_released == 0);

    /* User-configured bindings, simultaneous actions and keyboard repeat. */
    reload = Binding("key_cr_reload");
    *reload = 'v';
    Key(ev_keydown, 'r');
    CHECK((Build().buttons2 & CR_BT2_RELOAD) == 0);
    Key(ev_keydown, 'v');
    Consume(Build());
    CHECK(state->buttons_pressed == CR_BT2_RELOAD);

    /* Focus loss clears physical state; input remains ignored until focus
     * returns and a fresh press arrives. Menus/pauses cannot queue actions. */
    Focus(0);
    CHECK(Build().buttons2 == 0);
    Key(ev_keydown, 'v');
    Mouse(2);
    CHECK(Build().buttons2 == 0);
    Focus(1);
    CHECK(Build().buttons2 == 0);
    Key(ev_keydown, 'v');
    CHECK(Build().buttons2 == CR_BT2_RELOAD);
    menuactive = true;
    CHECK(Build().buttons2 == 0);
    Key(ev_keydown, 'v');
    menuactive = false;
    CHECK(Build().buttons2 == 0);
    Key(ev_keydown, 'v');
    CHECK(Build().buttons2 == CR_BT2_RELOAD);
    paused = true;
    CHECK(Build().buttons2 == 0);
    Key(ev_keydown, 'v');
    paused = false;
    CHECK(Build().buttons2 == 0);
    gamestate = GS_DEMOSCREEN;
    Key(ev_keydown, 'v');
    CHECK(Build().buttons2 == 0);
    gamestate = GS_LEVEL;
    Key(ev_keydown, 'v');
    CHECK(Build().buttons2 == CR_BT2_RELOAD);
    CR_ClearInput();
    CR_InputEvent(NULL);
    CR_BuildTiccmd(NULL);
    Key(ev_keydown, *Binding("key_cr_interact"));
    memset(&cmd, 0, sizeof(cmd));
    CR_BuildTiccmd(&cmd);
    CHECK(cmd.buttons2 == CR_BT2_INTERACT && (cmd.buttons & BT_USE));
    CR_ClearInput();
    Key(ev_keydown, 'v');
    Consume(Build());
    CHECK(state->buttons_pressed == 0);
    Key(ev_keyup, 'v');
    Consume(Build());
    Key(ev_keydown, 'v');
    Consume(Build());
    CHECK(state->buttons_pressed == CR_BT2_RELOAD);

    /* Invalid keyboard and mouse configuration must remain bounded. */
    CR_ClearInput();
    Key(ev_keydown, -1);
    Key(ev_keydown, 100000);
    *reload = -1;
    sprint = Binding("key_cr_sprint");
    *sprint = 100000;
    *ads = 100000;
    Mouse(-1);
    CHECK(Build().buttons2 == 0);
    CHECK(!CR_InputMouseReserved(-1));
    CHECK(!CR_InputMouseReserved(100000));
    *ads = 1;
    CHECK(CR_InputMouseReserved(1));
    CHECK(!CR_InputMouseReserved(0));

    /* Clear all command consumers on focus/reset, including repeated calls. */
    *reload = 'r';
    *sprint = KEY_RSHIFT;
    Key(ev_keydown, 'r');
    Mouse(2);
    Consume(Build());
    CR_ClearInput();
    CR_PlayerClearCommands();
    CHECK(Build().buttons2 == 0);
    CHECK(state->buttons_down == 0 && state->buttons_pressed == 0);
    CHECK(state->buttons_released == 0);
    CHECK(!state->sprinting && !state->ads && !state->crouching);
    CR_PlayerClearCommands();
    Key(ev_keydown, 'r');
    Consume(Build());
    CHECK(state->buttons_pressed == CR_BT2_RELOAD);
    CR_PlayerReset(&players[0]);
    CHECK(state->buttons_down == 0 && state->buttons_pressed == 0);
    CHECK(!state->sprinting && !state->ads && !state->crouching);

    /* Quick action taps may begin and end between command builds. They
     * survive for one command, while keyboard repeat cannot retrigger. */
    CR_ClearInput();
    CR_PlayerClearCommands();
    Key(ev_keydown, *Binding("key_cr_suit"));
    Key(ev_keyup, *Binding("key_cr_suit"));
    cmd = Build();
    CHECK(cmd.buttons2 == CR_BT2_SUIT_NEXT);
    Consume(cmd);
    CHECK(state->buttons_pressed == CR_BT2_SUIT_NEXT);
    Consume(Build());
    CHECK(state->buttons_down == 0 && state->buttons_released == CR_BT2_SUIT_NEXT);
    Key(ev_keydown, *Binding("key_cr_suit"));
    Consume(Build());
    CHECK(state->buttons_pressed == CR_BT2_SUIT_NEXT);
    for (i = 0; i < 10; ++i) {
        Key(ev_keydown, *Binding("key_cr_suit"));
        Consume(Build());
        CHECK(state->buttons_down == CR_BT2_SUIT_NEXT && state->buttons_pressed == 0);
    }
    Key(ev_keyup, *Binding("key_cr_suit"));
    Consume(Build());
    CHECK(state->buttons_released == CR_BT2_SUIT_NEXT);

    /* SDL wheel events are down/up pairs before a build. Both directions
     * must survive as a single pulse when configured as Crysis actions. */
    *Binding("mouseb_cr_suit") = 3;
    *Binding("mouseb_cr_attachment") = 4;
    for (i = 3; i <= 4; ++i) {
        const byte expected = i == 3 ? CR_BT2_SUIT_NEXT : CR_BT2_ATTACHMENT;
        CR_ClearInput();
        CR_PlayerClearCommands();
        Mouse(1 << i);
        Mouse(0);
        cmd = Build();
        CHECK(cmd.buttons2 == expected);
        Consume(cmd);
        CHECK(state->buttons_pressed == expected);
        Consume(Build());
        CHECK(state->buttons_down == 0 && state->buttons_released == expected);
    }
    *Binding("mouseb_cr_suit") = -1;
    *Binding("mouseb_cr_attachment") = -1;
    *Binding("mouseb_cr_reload") = 2;
    Mouse(4);
    Mouse(0);
    cmd = Build();
    CHECK(cmd.buttons2 == CR_BT2_RELOAD);
    Consume(cmd);
    CHECK(state->buttons_pressed == CR_BT2_RELOAD);
    Consume(Build());
    CHECK(state->buttons_released == CR_BT2_RELOAD);
    *Binding("mouseb_cr_reload") = -1;
    Key(ev_keydown, *Binding("key_cr_suit"));
    Key(ev_keyup, *Binding("key_cr_suit"));
    Focus(0);
    Focus(1);
    CHECK(Build().buttons2 == 0);

    /* A dead player must not keep continuous controls active. */
    players[0].playerstate = PST_DEAD;
    cmd.buttons2 = 255;
    Consume(cmd);
    CHECK(state->buttons_down == 0 && state->buttons_pressed == 0);
    CHECK(!state->sprinting && !state->ads && !state->crouching);
    players[0].playerstate = PST_LIVE;

    /* Vanilla command transport stays untouched when the mode is inactive. */
    active = false;
    memset(&cmd, 0, sizeof(cmd));
    cmd.buttons2 = 165;
    CR_BuildTiccmd(&cmd);
    CHECK(cmd.buttons2 == 165);
    CHECK(!CR_InputMouseReserved(1));
    printf("F1_LOGIC PASS assertions=%d ticcmd_size=%u\n", assertions,
           (unsigned int)sizeof(ticcmd_t));
    return 0;
}
