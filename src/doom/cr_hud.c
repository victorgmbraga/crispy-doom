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
// Minimal Crysis HUD: health, energy, suit mode. Weapon and objective
// readouts are added by their own phases.
//

#include <stdio.h>
#include <string.h>

#include "doomdef.h"
#include "doomstat.h"
#include "hu_stuff.h"
#include "i_swap.h"
#include "i_video.h"
#include "st_stuff.h"
#include "v_trans.h"
#include "v_video.h"

#include "cr_game.h"
#include "cr_hud.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "crispy.h"

#define CR_HUD_FULL_HEIGHT 24 // Floating strip height in original units.

static int CR_HUDTextWidth(const char *text)
{
    int width = 0;

    for (; *text != '\0'; ++text)
    {
        const int index = *text - HU_FONTSTART;

        if (index >= 0 && index < HU_FONTSIZE && hu_font[index] != NULL)
        {
            width += SHORT(hu_font[index]->width) + 1;
        }
        else
        {
            width += 4;
        }
    }

    return width;
}

static void CR_HUDText(int x, int y, const char *text, byte *color)
{
    for (; *text != '\0'; ++text)
    {
        const int index = *text - HU_FONTSTART;

        if (index >= 0 && index < HU_FONTSIZE && hu_font[index] != NULL)
        {
            dp_translation = color;
            V_DrawPatch(x, y, hu_font[index]);
            x += SHORT(hu_font[index]->width) + 1;
        }
        else
        {
            x += 4;
        }
    }

    dp_translation = NULL;
}

static byte *HealthColor(int health)
{
    if (health <= 25)
    {
        return cr[CR_RED];
    }
    else if (health <= 50)
    {
        return cr[CR_GOLD];
    }

    return cr[CR_GREEN];
}

void CR_HUDDraw(boolean fullscreen)
{
    const player_t *player = &players[displayplayer];
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_nanosuit_t *suit;
    char buffer[64];
    int origtop;
    int y1;
    int x;

    if (!CR_IsActive() || state == NULL || gamestate != GS_LEVEL)
    {
        return;
    }

    suit = &state->suit;

    // Opaque strip over the reserved status area (or a floating one).
    origtop = fullscreen ? ORIGHEIGHT - CR_HUD_FULL_HEIGHT
                         : ORIGHEIGHT - ST_HEIGHT;
    V_DrawFilledBox(0, origtop << crispy->hires, SCREENWIDTH,
                    (ORIGHEIGHT - origtop) << crispy->hires, 0);

    y1 = origtop + 5;

    snprintf(buffer, sizeof(buffer), "HP %d", player->health);
    x = 8;
    CR_HUDText(x, y1, buffer, HealthColor(player->health));
    x += CR_HUDTextWidth(buffer) + 12;

    snprintf(buffer, sizeof(buffer), "ENERGY %d", suit->energy);
    CR_HUDText(x, y1, buffer,
               suit->energy <= 25 ? cr[CR_RED] : cr[CR_BLUE]);
    x += CR_HUDTextWidth(buffer) + 12;

    snprintf(buffer, sizeof(buffer), "SUIT %s", CR_SuitModeName(suit->mode));
    CR_HUDText(x, y1, buffer, cr[CR_GOLD]);

    // Second row is owned by later phases (weapon, objective).
    (void) buffer;
}
