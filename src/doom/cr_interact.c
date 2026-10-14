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
// Project interaction: consumes the reserved specials and drives the
// objective table. Vanilla specials fall through to the engine dispatch.
//

#include <stdio.h>

#include "doomdef.h"
#include "doomstat.h"
#include "g_game.h"
#include "s_sound.h"

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_interact.h"
#include "cr_objective.h"
#include "sounds.h"

static char cr_objective_message[96];

static void ObjectiveMessage(player_t *player, int id)
{
    const cr_objective_t *objective = CR_ObjectiveById(id);

    if (player == NULL || objective == NULL)
    {
        return;
    }

    snprintf(cr_objective_message, sizeof(cr_objective_message),
             "OBJECTIVE %s",
             objective->state == CR_OBJ_COMPLETE ? "COMPLETE" : "ACTIVE");
    player->message = cr_objective_message;

    if (CR_DebugEnabled())
    {
        printf(CR_LOG_PREFIX " objective id=%d state=%d\n", id,
               (int) objective->state);
    }
}

// Shared handler; repeated events are idempotent in the objective table.
static boolean TriggerObjective(player_t *player, int id)
{
    if (CR_ObjectiveById(id) == NULL)
    {
        return false;
    }

    if (CR_ObjectiveTrigger(id))
    {
        ObjectiveMessage(player, id);
    }

    return true;
}

// Vanilla exit specials are allowed only after the main objectives.
static boolean ExitSpecial(int special)
{
    return special == 11 || special == 51 || special == 52;
}

// Returns true when the caller must stop (blocked); false lets the vanilla
// dispatch proceed (allowed exit or unrelated special).
static boolean GateVanillaExit(player_t *player, int special)
{
    if (!ExitSpecial(special))
    {
        return false;
    }

    if (!CR_ObjectiveCanExit())
    {
        player->message = "MAIN OBJECTIVES INCOMPLETE";
        return true;
    }

    CR_ObjectiveComplete(CR_OBJECTIVE_EXIT);
    return false;
}

boolean CR_CrossSpecialLine(line_t *line, mobj_t *thing)
{
    if (!CR_IsActive() || line == NULL || thing == NULL
        || thing->player == NULL)
    {
        return false;
    }

    if (line->special == CR_SPECIAL_OBJECTIVE_TRIGGER)
    {
        // Kept for retriggering: the table makes repeats idempotent, so the
        // second crossing can complete what the first activated.
        TriggerObjective(thing->player, line->tag);
        return true;
    }

    // Walkover exits stay gated by the objectives.
    return GateVanillaExit(thing->player, line->special);
}

boolean CR_UseSpecialLine(mobj_t *thing, line_t *line)
{
    player_t *player;

    if (!CR_IsActive() || thing == NULL || line == NULL
        || thing->player == NULL)
    {
        return false;
    }

    player = thing->player;

    switch (line->special)
    {
        case CR_SPECIAL_OBJECTIVE_USE:
            // Kept for reuse: ACTIVE then COMPLETE; repeats are no-ops.
            TriggerObjective(player, line->tag);
            return true;

        case CR_SPECIAL_JAMMER:
            if (CR_ObjectiveState(CR_OBJECTIVE_JAMMER) != CR_OBJ_COMPLETE)
            {
                CR_ObjectiveComplete(CR_OBJECTIVE_JAMMER);
                player->message = "JAMMER DISABLED";
                S_StartSound(NULL, sfx_swtchn);
                // Switch feedback, when the linedef maps to a switch pair.
                P_ChangeSwitchTexture(line, 0);
            }

            // One-shot by design; repeated use must not duplicate effects.
            line->special = 0;
            return true;

        case CR_SPECIAL_MISSION_EXIT:
            if (CR_ObjectiveCanExit())
            {
                CR_ObjectiveComplete(CR_OBJECTIVE_EXIT);
                player->message = "MISSION COMPLETE";
                G_ExitLevel();
            }
            else
            {
                player->message = "MAIN OBJECTIVES INCOMPLETE";
            }

            // Keep the line so the exit can be retried.
            return true;

        default:
            // Vanilla exit switches stay gated by the objectives.
            return GateVanillaExit(player, line->special);
    }
}
