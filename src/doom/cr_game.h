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
// Mode activation, lifecycle and unsupported-format guards.
//

#ifndef CR_GAME_H
#define CR_GAME_H

#include "doomtype.h"

boolean CR_IsActive(void);
boolean CR_DebugEnabled(void);
// Returns true and reports a rejection only in Crysis mode.
boolean CR_RejectUnsupported(const char *feature);

// Arguments must have been expanded before initialization. Safe to repeat.
void CR_Init(void);
void CR_NewGame(void);
void CR_LevelStart(void);

// Safe to repeat; called before level memory is freed and on process exit.
void CR_LevelEnd(void);

// Called once per active simulation tic, before player and world thinkers.
void CR_Ticker(void);

#endif
