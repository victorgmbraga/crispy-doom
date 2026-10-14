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
// ADS/scope field of view. The projection tables belong to the renderer;
// this module only requests a rebuild when the value changes.
//

#include <stdio.h>

#include "doomdef.h"
#include "r_main.h"

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "cr_render.h"
#include "cr_weapon.h"

// r_main.c publishes no prototype for the projection rebuild.
void R_InitTextureMapping(void);

static int cr_render_fov = CR_FOV_DEFAULT;

int CR_RenderFOV(void)
{
    return cr_render_fov;
}

boolean CR_RenderScopeActive(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);

    return state != NULL && state->ads && !CR_WeaponIsMelee(player)
        && CR_WeaponAttachmentInstalled(player, CR_ATTACH_SCOPE);
}

void CR_RenderReset(void)
{
    cr_render_fov = CR_FOV_DEFAULT;
}

void CR_RenderUpdate(const player_t *player)
{
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    int desired = CR_FOV_DEFAULT;

    if (!CR_IsActive() || state == NULL)
    {
        return;
    }

    if (state->ads && !CR_WeaponIsMelee(player))
    {
        desired = CR_RenderScopeActive(player) ? CR_FOV_SCOPE : CR_FOV_ADS;
    }

    if (desired != cr_render_fov)
    {
        cr_render_fov = desired;
        R_InitTextureMapping();

        if (CR_DebugEnabled())
        {
            printf(CR_LOG_PREFIX " fov=%d\n", cr_render_fov);
        }
    }
}
