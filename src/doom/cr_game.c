//
// Copyright(C) 2026 Crysis Contact Demake contributors
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// Crysis mode foundation. State remains independent of vanilla gameplay.
//

#include <stdio.h>

#include "cr_ai.h"
#include "cr_defs.h"
#include "cr_game.h"
#include "cr_input.h"
#include "cr_objective.h"
#include "cr_player.h"
#include "cr_sound.h"
#include "doomstat.h"
#include "i_system.h"
#include "m_argv.h"

static boolean cr_initialized;
static boolean cr_active;
static boolean cr_level_started;
static boolean cr_debug;

boolean CR_IsActive(void)
{
    return cr_active;
}

boolean CR_DebugEnabled(void)
{
    return cr_active && cr_debug;
}

boolean CR_RejectUnsupported(const char *feature)
{
    static char message[160];

    if (!cr_active)
    {
        return false;
    }

    snprintf(message, sizeof(message), "CRYSIS: %s indisponivel nesta fase.",
             feature);
    puts(message);
    players[consoleplayer].message = message;
    return true;
}

void CR_Init(void)
{
    if (cr_initialized)
    {
        return;
    }

    cr_initialized = true;
    cr_active = M_CheckParm(CR_MODE_ARGUMENT) != 0;
    cr_debug = cr_active && M_CheckParm("-crdebug") != 0;

    if (cr_active)
    {
        I_AtExit(CR_LevelEnd, true);
        puts(CR_LOG_PREFIX " mode enabled");
    }
}

void CR_NewGame(void)
{
    int i;

    if (!cr_active)
    {
        return;
    }

    // Discard the old level before vanilla resets the player array.
    CR_LevelEnd();
    CR_SoundReset();
    CR_AIReset();
    CR_ObjectivesReset();
    CR_ClearInput();
    for (i = 0; i < MAXPLAYERS; ++i)
    {
        CR_PlayerReset(&players[i]);
    }
}

void CR_LevelStart(void)
{
    int i;

    if (!cr_active)
    {
        return;
    }

    CR_ClearInput();
    CR_PlayerClearCommands();
    for (i = 0; i < MAXPLAYERS; ++i)
    {
        if (playeringame[i])
        {
            if (!cr_players[i].initialized)
            {
                CR_PlayerReset(&players[i]);
            }

            // Timers tied to leveltime never survive a level transition.
            CR_PlayerLevelStart(&players[i]);
        }
    }
    cr_level_started = true;
}

void CR_LevelEnd(void)
{
    if (!cr_active || !cr_level_started)
    {
        return;
    }

    CR_ClearInput();
    CR_PlayerClearCommands();
    CR_SoundLevelEnd();
    CR_AILevelEnd();
    cr_level_started = false;
}

void CR_Ticker(void)
{
    if (!cr_active || !cr_level_started)
    {
        return;
    }

    // Player input has one owner: the hook in P_PlayerThink, after G_Ticker
    // has selected the ticcmd. Later global systems will coordinate here.
}
