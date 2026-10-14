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
// Crysis HUD drawing. Reads state only; never advances simulation.
//

#ifndef CR_HUD_H
#define CR_HUD_H

#include "doomdef.h"

// Draws the Crysis status strip. fullscreen selects the floating variant
// used when the vanilla status bar has no reserved area.
void CR_HUDDraw(boolean fullscreen);

// Overlays that must appear after the world is rendered (attachment list).
void CR_HUDOverlayDraw(void);

#endif
