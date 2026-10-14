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
// Real ADS field of view. Projection tables are rebuilt only when the
// desired FOV actually changes.
//

#ifndef CR_RENDER_H
#define CR_RENDER_H

#include "doomdef.h"
#include "d_player.h"

#define CR_FOV_DEFAULT 2048 // Matches FIELDOFVIEW from r_main.c.
#define CR_FOV_ADS     1024
#define CR_FOV_SCOPE    768

// Called once per simulation tic; applies ADS/scope FOV when it changes.
void CR_RenderUpdate(const player_t *player);
void CR_RenderReset(void);

// Current projection FOV for R_InitTextureMapping.
int CR_RenderFOV(void);
boolean CR_RenderScopeActive(const player_t *player);

#endif
