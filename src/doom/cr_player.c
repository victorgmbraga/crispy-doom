// Copyright(C) 2026 Crysis Contact Demake contributors
// SPDX-License-Identifier: GPL-2.0-or-later

#include <stdio.h>
#include <string.h>

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "doomstat.h"

cr_player_state_t cr_players[MAXPLAYERS];

static int PlayerIndex(const player_t *player)
{
    int i;

    // Compare addresses: subtracting an unrelated pointer is undefined.
    for (i = 0; i < MAXPLAYERS; ++i)
    {
        if (player == &players[i])
        {
            return i;
        }
    }
    return -1;
}

cr_player_state_t *CR_PlayerState(player_t *player)
{
    int index = PlayerIndex(player);

    return index < 0 ? NULL : &cr_players[index];
}

const cr_player_state_t *CR_PlayerStateConst(const player_t *player)
{
    int index = PlayerIndex(player);

    return index < 0 ? NULL : &cr_players[index];
}

static void ClearCommands(cr_player_state_t *state)
{
    state->buttons_down = 0;
    state->buttons_pressed = 0;
    state->buttons_released = 0;
    state->sprinting = false;
    state->ads = false;
    state->crouching = false;
}

void CR_PlayerReset(player_t *player)
{
    cr_player_state_t *state = CR_PlayerState(player);

    if (!CR_IsActive() || state == NULL)
    {
        return;
    }

    memset(state, 0, sizeof(*state));
    state->initialized = true;
    CR_SuitInit(&state->suit);
    player->cmd.buttons2 = 0;
}

void CR_PlayerNoteDamage(player_t *player)
{
    cr_player_state_t *state;

    if (!CR_IsActive())
    {
        return;
    }

    state = CR_PlayerState(player);

    if (state == NULL)
    {
        return;
    }

    state->last_damage_tic = leveltime;
    state->health_regen_accumulator = 0;
}

void CR_PlayerLevelStart(player_t *player)
{
    cr_player_state_t *state;

    if (!CR_IsActive())
    {
        return;
    }

    state = CR_PlayerState(player);

    if (state == NULL)
    {
        return;
    }

    state->last_damage_tic = 0;
    state->health_regen_accumulator = 0;
}

// Player is live; recover health after the delay since the last hit.
static void PlayerRegenTick(player_t *player, cr_player_state_t *state)
{
    if (player->health <= 0 || player->health >= CR_HEALTH_MAX)
    {
        state->health_regen_accumulator = 0;
        return;
    }

    if (leveltime - state->last_damage_tic < CR_HEALTH_REGEN_DELAY_TICS)
    {
        state->health_regen_accumulator = 0;
        return;
    }

    if (++state->health_regen_accumulator >= CR_HEALTH_REGEN_STEP_TICS)
    {
        state->health_regen_accumulator = 0;
        player->health++;

        // Keep player and mobj health in agreement.
        if (player->mo != NULL)
        {
            player->mo->health = player->health;
        }
    }
}

void CR_PlayerClearCommands(void)
{
    int i;

    if (!CR_IsActive())
    {
        return;
    }

    for (i = 0; i < MAXPLAYERS; ++i)
    {
        ClearCommands(&cr_players[i]);
        players[i].cmd.buttons2 = 0;
    }
}

void CR_PlayerThink(player_t *player)
{
    cr_player_state_t *state = CR_PlayerState(player);
    byte down;

    if (!CR_IsActive() || state == NULL)
    {
        return;
    }

    if (!state->initialized)
    {
        // Level start/reborn normally initializes this before input is read.
        state->initialized = true;
    }

    if (player->playerstate != PST_LIVE)
    {
        ClearCommands(state);
        return;
    }

    // Commands are already selected for this simulation tic by G_Ticker.
    // No keyboard/mouse state is read by gameplay.
    down = player->cmd.buttons2;
    state->buttons_pressed = down & ~state->buttons_down;
    state->buttons_released = state->buttons_down & ~down;
    state->buttons_down = down;
    state->sprinting = (down & CR_BT2_SPRINT) != 0;
    state->ads = (down & CR_BT2_ADS) != 0;
    state->crouching = (down & CR_BT2_CROUCH) != 0;

    if (CR_DebugEnabled()
     && (state->buttons_pressed || state->buttons_released))
    {
        printf(CR_LOG_PREFIX " input player=%d tic=%d down=%02x"
               " pressed=%02x released=%02x sprint=%d ads=%d\n",
               PlayerIndex(player), leveltime, (unsigned int) down,
               (unsigned int) state->buttons_pressed,
               (unsigned int) state->buttons_released,
               state->sprinting, state->ads);
    }

    // [crysis] Health regeneration (Phase 3). One owner, live players only.
    PlayerRegenTick(player, state);
}
