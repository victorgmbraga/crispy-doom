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
// Translate the engine's existing input events into Crysis tic commands.
// Gameplay reads those commands, never these raw input states.
//

#ifndef CR_INPUT_H
#define CR_INPUT_H

#include "d_event.h"
#include "d_ticcmd.h"

extern int key_cr_sprint;
extern int key_cr_ads;
extern int key_cr_reload;
extern int key_cr_interact;
extern int key_cr_suit;
extern int key_cr_firemode;
extern int key_cr_attachment;
extern int key_cr_crouch;

extern int mouseb_cr_sprint;
extern int mouseb_cr_ads;
extern int mouseb_cr_reload;
extern int mouseb_cr_interact;
extern int mouseb_cr_suit;
extern int mouseb_cr_firemode;
extern int mouseb_cr_attachment;
extern int mouseb_cr_crouch;

// Bind even in vanilla, so saving a shared config preserves these settings.
void CR_BindInputVariables(void);

// Observe releases/focus before menus, accepted presses afterwards.
// Do not consume or poll events.
void CR_InputEvent(const event_t *event);
void CR_ClearInput(void);
boolean CR_InputHasFocus(void);

// Fill buttons2 only in Crysis, retaining brief action/wheel presses until
// sampling. Jump/look and the ticcmd layout stay intact.
void CR_BuildTiccmd(ticcmd_t *cmd);

// Reserve Crysis mouse bindings from vanilla movement/double-click actions.
// Fire remains available, and interact deliberately also produces BT_USE.
boolean CR_InputMouseReserved(int button);

#endif
