/* Phase 5 contract tests: ADS placement and the attachment overlay in the
 * real weapon module with small engine boundary stubs. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cr_defs.h"
#include "cr_game.h"
#include "cr_nanosuit.h"
#include "cr_player.h"
#include "cr_sound.h"
#include "cr_weapon.h"
#include "crispy.h"
#include "doomstat.h"
#include "d_items.h"
#include "d_event.h"
#include "m_random.h"
#include "p_pspr.h"
#include "s_sound.h"

player_t players[MAXPLAYERS];
boolean playeringame[MAXPLAYERS];
gamestate_t gamestate = GS_LEVEL;
skill_t gameskill = sk_medium;
boolean menuactive;
boolean paused;
int consoleplayer;
int gametic;
int leveltime;
weaponinfo_t weaponinfo[NUMWEAPONS];
int clipammo[NUMAMMO] = {4, 8, 8, 4};
crispy_t cr_crispy_data;
crispy_t *const crispy = &cr_crispy_data;
const crispy_t *critical = &cr_crispy_data;
int cr_damage_recorded;

static boolean active = true;
static int assertions;

boolean CR_IsActive(void) { return active; }
boolean CR_DebugEnabled(void) { return false; }
int P_SubRandom(void) { return 0; }
int P_Random(void) { return 0; }

void P_SetPsprite(player_t *player, int position, statenum_t stnum)
{
    (void) player;
    (void) position;
    (void) stnum;
}

boolean P_SetMobjState(mobj_t *mobj, statenum_t state)
{
    (void) mobj;
    (void) state;
    return true;
}

fixed_t P_AimLineAttack(mobj_t *t1, angle_t angle, fixed_t distance)
{
    (void) t1;
    (void) angle;
    (void) distance;
    return 0;
}

void P_LineAttack(mobj_t *t1, angle_t angle, fixed_t distance, fixed_t slope,
                  int damage)
{
    (void) t1;
    (void) angle;
    (void) distance;
    (void) slope;
    cr_damage_recorded += damage;
}

void S_StartSound(void *origin, int sound_id)
{
    (void) origin;
    (void) sound_id;
}

void S_StartSoundAtVolume(void *origin, int sound_id, int volume)
{
    (void) origin;
    (void) sound_id;
    (void) volume;
}

/* Perception boundary: noise dispatch is inert in this fixture. */
void CR_AIDispatchNoise(const cr_noise_event_t *event) { (void) event; }

/* Render module boundary: FOV requests are inert in this fixture. */
void CR_RenderUpdate(const player_t *player) { (void) player; }
void CR_RenderReset(void) {}
int CR_RenderFOV(void) { return 2048; }
boolean CR_RenderScopeActive(const player_t *player) { (void) player; return false; }

#define CHECK(test) do { ++assertions; if (!(test)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #test); exit(1); \
} } while (0)

static cr_player_state_t *State(void)
{
    cr_player_state_t *state = CR_PlayerState(&players[0]);
    if (state == NULL) { fputs("missing player state\n", stderr); exit(1); }
    return state;
}

static void Tic(void)
{
    CR_WeaponTick(&players[0]);
}

int main(void)
{
    cr_player_state_t *state;
    mobj_t actor;
    ticcmd_t cmd;
    pspdef_t psp;

    memset(&actor, 0, sizeof(actor));
    actor.health = 100;
    players[0].mo = &actor;
    players[0].health = 100;
    players[0].playerstate = PST_LIVE;
    players[0].readyweapon = wp_chaingun;
    players[0].pendingweapon = wp_nochange;
    playeringame[0] = true;

    CR_PlayerReset(&players[0]);
    state = State();

    /* Overlay starts closed with SCAR slot list: suppressor, reflex, scope. */
    CHECK(!CR_WeaponOverlayActive(&players[0]));
    CHECK(CR_WeaponOverlaySlotCount(&players[0]) == 3);
    CHECK(CR_WeaponOverlaySlotMask(&players[0], 0) == CR_ATTACH_SUPPRESSOR);
    CHECK(CR_WeaponOverlaySlotMask(&players[0], 1) == CR_ATTACH_REFLEX);
    CHECK(CR_WeaponOverlaySlotMask(&players[0], 2) == CR_ATTACH_SCOPE);
    CHECK(!strcmp(CR_WeaponAttachmentName(CR_ATTACH_SCOPE), "SCOPE"));

    /* X opens and closes the overlay. */
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic();
    CHECK(CR_WeaponOverlayActive(&players[0]));
    CHECK(CR_WeaponOverlaySlotIndex(&players[0]) == 0);
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic();
    CHECK(!CR_WeaponOverlayActive(&players[0]));

    /* While open, movement/turning/fire are consumed by the command hook. */
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic();
    memset(&cmd, 0, sizeof(cmd));
    cmd.forwardmove = 25;
    cmd.sidemove = -25;
    cmd.angleturn = 100;
    cmd.buttons = BT_ATTACK | BT_USE;
    CR_WeaponOverlayCommand(&players[0], &cmd);
    CHECK(cmd.forwardmove == 0 && cmd.sidemove == 0 && cmd.angleturn == 0);
    CHECK((cmd.buttons & (BT_ATTACK | BT_USE)) == 0);
    CHECK(CR_WeaponOverlaySlotIndex(&players[0]) == 2); // Up from slot 0 wraps.

    /* Navigation cycles through the compatible slots only. */
    memset(&cmd, 0, sizeof(cmd));
    cmd.forwardmove = -25;
    CR_WeaponOverlayCommand(&players[0], &cmd);
    CHECK(CR_WeaponOverlaySlotIndex(&players[0]) == 0);
    cmd.forwardmove = -25;
    CR_WeaponOverlayCommand(&players[0], &cmd);
    CHECK(CR_WeaponOverlaySlotIndex(&players[0]) == 1);

    /* E toggles the selected attachment; incompatibles are refused. */
    state->buttons_pressed = CR_BT2_INTERACT;
    Tic();
    CHECK(CR_WeaponAttachmentInstalled(&players[0], CR_ATTACH_REFLEX));
    CHECK(!CR_WeaponAttachmentInstalled(&players[0], CR_ATTACH_SCOPE));
    state->buttons_pressed = CR_BT2_INTERACT;
    Tic();
    CHECK(!CR_WeaponAttachmentInstalled(&players[0], CR_ATTACH_REFLEX));

    /* A closed overlay ignores the toggle command. */
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic(); // close
    memset(&cmd, 0, sizeof(cmd));
    cmd.forwardmove = 25;
    CR_WeaponOverlayCommand(&players[0], &cmd);
    CHECK(cmd.forwardmove == 25); // untouched when closed

    /* Suppressor install reduces the declared noise radius. */
    memset(&cmd, 0, sizeof(cmd));
    state->weapon.overlay_slot = 0;
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic(); // open
    state->buttons_pressed = CR_BT2_INTERACT;
    Tic(); // install suppressor
    CHECK(CR_WeaponAttachmentInstalled(&players[0], CR_ATTACH_SUPPRESSOR));
    CHECK(CR_WeaponCurrentNoiseRadius(&players[0])
          == FixedMul(1400 * FRACUNIT, 3 * FRACUNIT / 10));
    state->buttons_pressed = CR_BT2_INTERACT;
    Tic(); // remove suppressor
    CHECK(CR_WeaponCurrentNoiseRadius(&players[0]) == 1400 * FRACUNIT);
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic(); // close

    /* Reflex and scope are mutually exclusive. */
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic(); // open (slot resets to 0)
    state->weapon.overlay_slot = 1;
    state->buttons_pressed = CR_BT2_INTERACT;
    Tic(); // reflex on
    CHECK(CR_WeaponAttachmentInstalled(&players[0], CR_ATTACH_REFLEX));
    state->weapon.overlay_slot = 2;
    state->buttons_pressed = CR_BT2_INTERACT;
    Tic(); // scope on, reflex off
    CHECK(CR_WeaponAttachmentInstalled(&players[0], CR_ATTACH_SCOPE));
    CHECK(!CR_WeaponAttachmentInstalled(&players[0], CR_ATTACH_REFLEX));
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic(); // close

    /* SOCOM has no scope slot; its list is suppressor and reflex only. */
    players[0].readyweapon = wp_pistol;
    CHECK(CR_WeaponOverlaySlotCount(&players[0]) == 2);
    CHECK(CR_WeaponOverlaySlotMask(&players[0], 1) == CR_ATTACH_REFLEX);
    CHECK(CR_WeaponOverlaySlotMask(&players[0], 2) == 0);

    /* Death closes the overlay. */
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic();
    CHECK(CR_WeaponOverlayActive(&players[0]));
    players[0].playerstate = PST_DEAD;
    Tic();
    CHECK(!CR_WeaponOverlayActive(&players[0]));
    players[0].playerstate = PST_LIVE;

    /* ADS centers the weapon psprite; melee and hip fire stay untouched. */
    memset(&psp, 0, sizeof(psp));
    psp.sx = 12345;
    psp.sy = 23456;
    state->ads = false;
    CR_WeaponAdjustPsprite(&players[0], &psp);
    CHECK(psp.sx == 12345 && psp.sy == 23456);
    state->ads = true;
    CR_WeaponAdjustPsprite(&players[0], &psp);
    CHECK(psp.sx == FRACUNIT && psp.sy == 32 * FRACUNIT);
    players[0].readyweapon = wp_fist;
    psp.sx = 12345;
    CR_WeaponAdjustPsprite(&players[0], &psp);
    CHECK(psp.sx == 12345);
    players[0].readyweapon = wp_pistol;

    /* Combined rules stay ordered: reload blocks fire and sprint. */
    players[0].readyweapon = wp_chaingun;
    state->ads = false;
    state->weapon.magazine[CR_WEAPON_SCAR] = 0;
    state->weapon.reserve[CR_WEAPON_SCAR] = 30;
    CR_WeaponStartReload(&players[0]);
    CHECK(CR_WeaponIsReloading(&players[0]));
    state->sprinting = true;
    state->suit.mode = CR_SUIT_SPEED;
    state->suit.energy = 100;
    CHECK(CR_SuitMoveFactor(&players[0]) == FRACUNIT); // Sprint blocked.
    leveltime += 100;
    CR_WeaponCancelReload(&players[0]);

    /* Vanilla gate stays inert with the mode off. */
    active = false;
    memset(&cmd, 0, sizeof(cmd));
    cmd.forwardmove = 25;
    state->buttons_pressed = CR_BT2_ATTACHMENT;
    Tic();
    CR_WeaponOverlayCommand(&players[0], &cmd);
    CHECK(!CR_WeaponOverlayActive(&players[0]));
    active = true;

    printf("F5_LOGIC PASS assertions=%d\n", assertions);
    return 0;
}
