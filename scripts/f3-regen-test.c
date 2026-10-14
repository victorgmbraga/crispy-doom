/* Phase 3 contract tests: health regeneration in the real player module with
 * small engine boundary stubs. No replacement implementation of its logic. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "doomstat.h"
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
    (void) name;
    (void) value;
}

#define CHECK(test) do { ++assertions; if (!(test)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #test); exit(1); \
} } while (0)

static cr_player_state_t *State(void)
{
    cr_player_state_t *state = CR_PlayerState(&players[0]);
    if (state == NULL) { fputs("missing player state\n", stderr); exit(1); }
    return state;
}

static void Think(void)
{
    ticcmd_t empty;
    memset(&empty, 0, sizeof(empty));
    players[0].cmd = empty;
    CR_PlayerThink(&players[0]);
}

int main(void)
{
    cr_player_state_t *state;
    mobj_t actor;
    int i;

    memset(&actor, 0, sizeof(actor));
    actor.health = 60;
    players[0].mo = &actor;
    players[0].health = 60;
    players[0].playerstate = PST_LIVE;
    playeringame[0] = true;

    CR_PlayerReset(&players[0]);
    state = State();

    /* No regeneration before the delay has elapsed since the hit. */
    state->last_damage_tic = 100;
    leveltime = 100;
    for (i = 0; i < CR_HEALTH_REGEN_DELAY_TICS; ++i)
    {
        Think();
        ++leveltime;
    }
    CHECK(players[0].health == 60);

    /* One point per step, mirrored into the mobj. */
    for (i = 0; i < CR_HEALTH_REGEN_STEP_TICS - 1; ++i)
    {
        Think();
        ++leveltime;
    }
    CHECK(players[0].health == 60);
    Think();
    CHECK(players[0].health == 61);
    CHECK(actor.health == 61);
    CHECK(state->health_regen_accumulator == 0);

    /* A new hit restarts the delay from that tic. */
    CR_PlayerNoteDamage(&players[0]);
    CHECK(state->last_damage_tic == leveltime);
    for (i = 0; i < CR_HEALTH_REGEN_DELAY_TICS - 1; ++i)
    {
        Think();
        ++leveltime;
    }
    CHECK(players[0].health == 61);
    leveltime = state->last_damage_tic + CR_HEALTH_REGEN_DELAY_TICS;
    for (i = 0; i < CR_HEALTH_REGEN_STEP_TICS; ++i)
    {
        Think();
        ++leveltime;
    }
    CHECK(players[0].health == 62);

    /* Regeneration stops at the cap, not beyond it. */
    players[0].health = 99;
    actor.health = 99;
    for (i = 0; i < CR_HEALTH_REGEN_STEP_TICS * 4; ++i)
    {
        Think();
        ++leveltime;
    }
    CHECK(players[0].health == CR_HEALTH_MAX);
    CHECK(actor.health == CR_HEALTH_MAX);
    CHECK(state->health_regen_accumulator == 0);

    /* Dead players never regenerate. */
    players[0].playerstate = PST_DEAD;
    players[0].health = 40;
    for (i = 0; i < CR_HEALTH_REGEN_STEP_TICS * 4; ++i)
    {
        Think();
        ++leveltime;
    }
    CHECK(players[0].health == 40);
    players[0].playerstate = PST_LIVE;

    /* Level start clears timers tied to the previous leveltime. */
    state->last_damage_tic = 500;
    state->health_regen_accumulator = 3;
    CR_PlayerLevelStart(&players[0]);
    CHECK(state->last_damage_tic == 0);
    CHECK(state->health_regen_accumulator == 0);

    /* Vanilla gate: the whole think path is inert without the mode. */
    active = false;
    players[0].health = 50;
    actor.health = 50;
    leveltime = 10000;
    for (i = 0; i < CR_HEALTH_REGEN_STEP_TICS * 4; ++i)
    {
        Think();
    }
    CHECK(players[0].health == 50);
    active = true;

    printf("F3_LOGIC PASS assertions=%d\n", assertions);
    return 0;
}
