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
// Project line specials. The engine owns reach, side and obstacle rules;
// this module owns the mission semantics dispatched from p_spec/p_switch.
//

#ifndef CR_INTERACT_H
#define CR_INTERACT_H

#include "doomdef.h"
#include "r_defs.h"
#include "p_mobj.h"
#include "p_spec.h"

// Reserved private specials, audited above the highest engine special (272).
#define CR_SPECIAL_OBJECTIVE_TRIGGER 300 // Cross: activate/complete by tag.
#define CR_SPECIAL_OBJECTIVE_USE     301 // Use: activate/complete by tag.
#define CR_SPECIAL_MISSION_EXIT      302 // Use: leave when main objectives done.
#define CR_SPECIAL_JAMMER            303 // Use: complete the optional objective.

// Called from P_CrossSpecialLinePtr and P_UseSpecialLine while Crysis is on.
boolean CR_CrossSpecialLine(line_t *line, mobj_t *thing);
boolean CR_UseSpecialLine(mobj_t *thing, line_t *line);

#endif
