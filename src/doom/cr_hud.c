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
#include "cr_objective.h"
#include "cr_player.h"
#include "cr_render.h"
#include "cr_weapon.h"
#include "crispy.h"
#include "r_main.h"

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

    // Row 2: weapon, magazine, reserve and fire mode.
    y1 = origtop + 15;
    x = 8;

    if (CR_WeaponIsMelee(player))
    {
        CR_HUDText(x, y1, "MELEE", cr[CR_GRAY]);
    }
    else
    {
        const cr_weapon_def_t *def = CR_WeaponCurrentDef(player);

        snprintf(buffer, sizeof(buffer), "%s %d/%d %s%s%s", def->name,
                 CR_WeaponMagazine(player), CR_WeaponReserve(player),
                 CR_WeaponFireModeName(CR_WeaponFireMode(player)),
                 CR_WeaponIsReloading(player) ? " RELOAD" : "",
                 (state->ads && !CR_WeaponIsMelee(player)) ? " ADS" : "");
        CR_HUDText(x, y1, buffer,
                   CR_WeaponIsReloading(player) ? cr[CR_RED] : cr[CR_GRAY]);
    }
}

void CR_HUDOverlayDraw(void)
{
    const player_t *player = &players[displayplayer];
    const cr_player_state_t *state = CR_PlayerStateConst(player);
    const cr_objective_t *objective = CR_ObjectiveCurrent();
    const boolean fullscreen = (viewheight == SCREENHEIGHT);
    const int origtop = fullscreen ? ORIGHEIGHT - CR_HUD_FULL_HEIGHT
                                   : ORIGHEIGHT - ST_HEIGHT;
    char buffer[64];

    if (!CR_IsActive() || state == NULL || gamestate != GS_LEVEL)
    {
        return;
    }

    // Current objective, top-right.
    if (objective != NULL)
    {
        int width;

        snprintf(buffer, sizeof(buffer), "OBJECTIVE: %s", objective->title);
        width = CR_HUDTextWidth(buffer);
        CR_HUDText(ORIGWIDTH - 8 - width, 4, buffer, cr[CR_GOLD]);
    }

    // Scope overlay: black frame around a clear center after the world render.
    if (CR_RenderScopeActive(player))
    {
        const int shift = crispy->hires;
        int size = 150 << shift;
        int cx = SCREENWIDTH / 2;
        int cy = viewheight / 2;
        int half;

        if (size > viewheight)
        {
            size = viewheight;
        }

        half = size / 2;

        V_DrawFilledBox(0, 0, SCREENWIDTH, cy - half, 0);
        V_DrawFilledBox(0, cy + half, SCREENWIDTH,
                        SCREENHEIGHT - (cy + half), 0);
        V_DrawFilledBox(0, cy - half, cx - half, size, 0);
        V_DrawFilledBox(cx + half, cy - half, SCREENWIDTH - (cx + half),
                        size, 0);
    }

    if (!CR_WeaponOverlayActive(player))
    {
        return;
    }

    // Attachment overlay: slot list above the strip, after the world render.
    {
        int count = CR_WeaponOverlaySlotCount(player);
        int selected = CR_WeaponOverlaySlotIndex(player);
        int i;
        int y = origtop - (count + 1) * 10;

        CR_HUDText(8, y, "ATTACHMENTS  X CLOSE  E TOGGLE", cr[CR_GOLD]);
        y += 10;

        for (i = 0; i < count; ++i)
        {
            unsigned int mask = CR_WeaponOverlaySlotMask(player, i);
            boolean on = CR_WeaponAttachmentInstalled(player, mask);

            snprintf(buffer, sizeof(buffer), "%s%s %s",
                     i == selected ? "> " : "  ",
                     CR_WeaponAttachmentName(mask), on ? "[ON]" : "[OFF]");
            CR_HUDText(8, y, buffer,
                       i == selected ? cr[CR_GOLD]
                                     : (on ? cr[CR_GREEN] : cr[CR_GRAY]));
            y += 9;
        }
    }
}
