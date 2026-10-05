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

#include <string.h>

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_input.h"
#include "doomkeys.h"
#include "doomstat.h"
#include "i_input.h"
#include "m_config.h"

// Both physical Shift keys are translated to KEY_RSHIFT upstream.
int key_cr_sprint = KEY_RSHIFT;
int key_cr_ads = 0;
int key_cr_reload = 'r';
int key_cr_interact = 'e';
int key_cr_suit = 'q';
int key_cr_firemode = 'b';
int key_cr_attachment = 'x';
int key_cr_crouch = 'c';

int mouseb_cr_sprint = -1;
int mouseb_cr_ads = 1;
int mouseb_cr_reload = -1;
int mouseb_cr_interact = -1;
int mouseb_cr_suit = -1;
int mouseb_cr_firemode = -1;
int mouseb_cr_attachment = -1;
int mouseb_cr_crouch = -1;

#define CR_INPUT_KEYS 256

typedef struct
{
    byte bit;
    int *key;
    int *mouse;
} cr_input_binding_t;

static const cr_input_binding_t cr_bindings[] =
{
    { CR_BT2_SPRINT,     &key_cr_sprint,     &mouseb_cr_sprint },
    { CR_BT2_ADS,        &key_cr_ads,        &mouseb_cr_ads },
    { CR_BT2_RELOAD,     &key_cr_reload,     &mouseb_cr_reload },
    { CR_BT2_INTERACT,   &key_cr_interact,   &mouseb_cr_interact },
    { CR_BT2_SUIT_NEXT,  &key_cr_suit,       &mouseb_cr_suit },
    { CR_BT2_FIREMODE,   &key_cr_firemode,   &mouseb_cr_firemode },
    { CR_BT2_ATTACHMENT, &key_cr_attachment, &mouseb_cr_attachment },
    { CR_BT2_CROUCH,     &key_cr_crouch,     &mouseb_cr_crouch },
};

static boolean cr_keys[CR_INPUT_KEYS];
static unsigned int cr_mouse_buttons;
static boolean cr_input_focused = true;
static byte cr_pending_buttons;

#define CR_INPUT_ACTIONS (CR_BT2_RELOAD | CR_BT2_INTERACT | CR_BT2_SUIT_NEXT \
                        | CR_BT2_FIREMODE | CR_BT2_ATTACHMENT)

// Preserve brief physical presses until command sampling. This only encodes
// input; gameplay edges are still calculated from consumed ticcmds.
static void CR_QueueKeyPress(int key)
{
    unsigned int i;

    for (i = 0; i < arrlen(cr_bindings); ++i)
    {
        if (*cr_bindings[i].key == key
            && (cr_bindings[i].bit & CR_INPUT_ACTIONS))
        {
            cr_pending_buttons |= cr_bindings[i].bit;
        }
    }
}

static void CR_QueueMousePress(unsigned int down)
{
    unsigned int i;

    for (i = 0; i < arrlen(cr_bindings); ++i)
    {
        const int button = *cr_bindings[i].mouse;

        if (button >= 0 && button < MAX_MOUSE_BUTTONS
            && (down & (1U << button))
            && ((cr_bindings[i].bit & CR_INPUT_ACTIONS)
                || button == 3 || button == 4))
        {
            // Wheel events arrive as down+up in a single event batch.
            cr_pending_buttons |= cr_bindings[i].bit;
        }
    }
}

void CR_BindInputVariables(void)
{
    M_BindIntVariable("key_cr_sprint",      &key_cr_sprint);
    M_BindIntVariable("key_cr_ads",         &key_cr_ads);
    M_BindIntVariable("key_cr_reload",      &key_cr_reload);
    M_BindIntVariable("key_cr_interact",    &key_cr_interact);
    M_BindIntVariable("key_cr_suit",        &key_cr_suit);
    M_BindIntVariable("key_cr_firemode",    &key_cr_firemode);
    M_BindIntVariable("key_cr_attachment",  &key_cr_attachment);
    M_BindIntVariable("key_cr_crouch",      &key_cr_crouch);

    M_BindIntVariable("mouseb_cr_sprint",    &mouseb_cr_sprint);
    M_BindIntVariable("mouseb_cr_ads",       &mouseb_cr_ads);
    M_BindIntVariable("mouseb_cr_reload",    &mouseb_cr_reload);
    M_BindIntVariable("mouseb_cr_interact",  &mouseb_cr_interact);
    M_BindIntVariable("mouseb_cr_suit",      &mouseb_cr_suit);
    M_BindIntVariable("mouseb_cr_firemode",  &mouseb_cr_firemode);
    M_BindIntVariable("mouseb_cr_attachment", &mouseb_cr_attachment);
    M_BindIntVariable("mouseb_cr_crouch",    &mouseb_cr_crouch);
}

void CR_ClearInput(void)
{
    memset(cr_keys, 0, sizeof(cr_keys));
    cr_mouse_buttons = 0;
    cr_pending_buttons = 0;
}

boolean CR_InputHasFocus(void)
{
    return cr_input_focused;
}

void CR_InputEvent(const event_t *event)
{
    if (!CR_IsActive() || event == NULL)
    {
        return;
    }

    switch (event->type)
    {
        case ev_keydown:
            if (!cr_input_focused || gamestate != GS_LEVEL
                || menuactive || paused)
            {
                break;
            }
            if (event->data1 > 0 && event->data1 < CR_INPUT_KEYS)
            {
                if (!cr_keys[event->data1])
                {
                    CR_QueueKeyPress(event->data1);
                }
                cr_keys[event->data1] = true;
            }
            break;

        case ev_keyup:
            if (event->data1 > 0 && event->data1 < CR_INPUT_KEYS)
            {
                cr_keys[event->data1] = false;
            }
            break;

        case ev_mouse:
            if (cr_input_focused && gamestate == GS_LEVEL
                && !menuactive && !paused)
            {
                CR_QueueMousePress((unsigned int) event->data1
                                  & ~cr_mouse_buttons);
                cr_mouse_buttons = (unsigned int) event->data1;
            }
            break;

        case ev_focus:
            cr_input_focused = event->data1 != 0;
            CR_ClearInput();
            break;

        default:
            break;
    }
}

static boolean CR_BindingHeld(const cr_input_binding_t *binding)
{
    const int key = *binding->key;
    const int mouse = *binding->mouse;

    return (key > 0 && key < CR_INPUT_KEYS && cr_keys[key])
        || (mouse >= 0 && mouse < MAX_MOUSE_BUTTONS
            && (cr_mouse_buttons & (1U << mouse)) != 0);
}

boolean CR_InputMouseReserved(int button)
{
    unsigned int i;

    if (!CR_IsActive() || button < 0 || button >= MAX_MOUSE_BUTTONS)
    {
        return false;
    }

    for (i = 0; i < arrlen(cr_bindings); ++i)
    {
        if (*cr_bindings[i].mouse == button)
        {
            return true;
        }
    }

    return false;
}

void CR_BuildTiccmd(ticcmd_t *cmd)
{
    unsigned int i;

    if (!CR_IsActive() || cmd == NULL)
    {
        return;
    }

    cmd->buttons2 = 0;

    if (!cr_input_focused || gamestate != GS_LEVEL || menuactive || paused
        || (cmd->buttons & BT_SPECIAL))
    {
        CR_ClearInput();
        return;
    }

    cmd->buttons2 = cr_pending_buttons;
    cr_pending_buttons = 0;

    for (i = 0; i < arrlen(cr_bindings); ++i)
    {
        if (CR_BindingHeld(&cr_bindings[i]))
        {
            cmd->buttons2 |= cr_bindings[i].bit;
        }
    }

    // Until contextual objectives arrive, E still opens vanilla doors.
    if (cmd->buttons2 & CR_BT2_INTERACT)
    {
        cmd->buttons |= BT_USE;
    }
}
