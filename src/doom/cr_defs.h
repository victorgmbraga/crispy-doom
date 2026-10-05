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
// Shared low-level constants. Gameplay definitions belong to later phases.
//

#ifndef CR_DEFS_H
#define CR_DEFS_H

#define CR_MODE_ARGUMENT "-crysis"
#define CR_LOG_PREFIX "[CRYSIS]"

// Doom uses neither Strife's buttons2 meanings nor extra ticcmd fields.
// These bits are interpreted only while -crysis is active.
#define CR_BT2_SPRINT       0x01
#define CR_BT2_ADS          0x02
#define CR_BT2_RELOAD       0x04
#define CR_BT2_INTERACT     0x08
#define CR_BT2_SUIT_NEXT    0x10
#define CR_BT2_FIREMODE     0x20
#define CR_BT2_ATTACHMENT   0x40
#define CR_BT2_CROUCH       0x80

#endif
