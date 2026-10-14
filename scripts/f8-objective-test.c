/* Phase 8 contract tests: the objective table with no engine stubs needed. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cr_objective.h"

static int assertions;

#define CHECK(test) do { ++assertions; if (!(test)) { \
    fprintf(stderr, "FAIL line %d: %s\n", __LINE__, #test); exit(1); \
} } while (0)

int main(void)
{
    const cr_objective_t *current;

    CR_ObjectivesReset();
    CHECK(CR_ObjectiveCount() == 4);

    /* Fresh mission: everything locked; the first main objective is next. */
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_MEETING) == CR_OBJ_LOCKED);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_JAMMER) == CR_OBJ_LOCKED);
    current = CR_ObjectiveCurrent();
    CHECK(current != NULL && current->id == CR_OBJECTIVE_MEETING);
    CHECK(!CR_ObjectiveCanExit());

    /* Trigger advances LOCKED -> ACTIVE -> COMPLETE and stays idempotent. */
    CHECK(CR_ObjectiveTrigger(CR_OBJECTIVE_MEETING));
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_MEETING) == CR_OBJ_ACTIVE);
    current = CR_ObjectiveCurrent();
    CHECK(current != NULL && current->id == CR_OBJECTIVE_MEETING);
    CHECK(!CR_ObjectiveTrigger(CR_OBJECTIVE_MEETING)
          || CR_ObjectiveState(CR_OBJECTIVE_MEETING) == CR_OBJ_COMPLETE);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_MEETING) == CR_OBJ_COMPLETE);
    CHECK(!CR_ObjectiveTrigger(CR_OBJECTIVE_MEETING));
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_MEETING) == CR_OBJ_COMPLETE);
    current = CR_ObjectiveCurrent();
    CHECK(current != NULL && current->id == CR_OBJECTIVE_PATROL);

    /* Unknown IDs are rejected without touching the table. */
    CHECK(!CR_ObjectiveTrigger(99));
    CHECK(CR_ObjectiveById(99) == NULL);
    CHECK(CR_ObjectiveState(99) == CR_OBJ_FAILED);
    CR_ObjectiveActivate(99);
    CR_ObjectiveComplete(99);
    CR_ObjectiveFail(99);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_MEETING) == CR_OBJ_COMPLETE);

    /* Complete/Fail/Activate with explicit states. */
    CR_ObjectiveActivate(CR_OBJECTIVE_PATROL);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_PATROL) == CR_OBJ_ACTIVE);
    CR_ObjectiveComplete(CR_OBJECTIVE_PATROL);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_PATROL) == CR_OBJ_COMPLETE);
    CHECK(CR_ObjectiveCanExit()); // Main objectives done; exit is allowed.

    /* The optional objective never gates the exit. */
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_JAMMER) == CR_OBJ_LOCKED);
    CR_ObjectiveComplete(CR_OBJECTIVE_JAMMER);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_JAMMER) == CR_OBJ_COMPLETE);
    CHECK(CR_ObjectiveCanExit());

    /* Failed objectives can be re-activated explicitly. */
    CR_ObjectivesReset();
    CR_ObjectiveActivate(CR_OBJECTIVE_PATROL);
    CR_ObjectiveFail(CR_OBJECTIVE_PATROL);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_PATROL) == CR_OBJ_FAILED);
    CR_ObjectiveActivate(CR_OBJECTIVE_PATROL);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_PATROL) == CR_OBJ_ACTIVE);
    CR_ObjectiveComplete(CR_OBJECTIVE_PATROL);
    CR_ObjectiveComplete(CR_OBJECTIVE_MEETING);
    CHECK(CR_ObjectiveCanExit());

    /* Reset returns every entry to LOCKED. */
    CR_ObjectivesReset();
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_MEETING) == CR_OBJ_LOCKED);
    CHECK(CR_ObjectiveState(CR_OBJECTIVE_EXIT) == CR_OBJ_LOCKED);
    CHECK(CR_ObjectiveAt(0) != NULL && CR_ObjectiveAt(0)->id == 1);
    CHECK(CR_ObjectiveAt(99) == NULL);

    printf("F8_LOGIC PASS assertions=%d\n", assertions);
    return 0;
}
