const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField } = require('firebase/firestore');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-sushiscout',
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, '../../firestore.rules'),
        'utf8'
      ),
    },
  });
});

afterAll(() => testEnv.cleanup());
beforeEach(() => testEnv.clearFirestore());

// Alice is a member of teamA (via her custom claim); Bob is not.
const alice = () =>
  testEnv.authenticatedContext('alice', { teams: { teamA: 'admin' } }).firestore();
const bob = () =>
  testEnv.authenticatedContext('bob', { teams: { teamB: 'member' } }).firestore();

async function seedMatch(teamId) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'matches/m1'), {
      eventId: `${teamId}_2026casf`,
      teamId,
      isDeleted: false,
    });
  });
}

test('member reads own team match', async () => {
  await seedMatch('teamA');
  await assertSucceeds(getDoc(doc(alice(), 'matches/m1')));
});

test('non-member cannot read another team match', async () => {
  await seedMatch('teamA');
  await assertFails(getDoc(doc(bob(), 'matches/m1')));
});

test('empty teamId is NOT globally readable', async () => {
  await seedMatch('');
  await assertFails(getDoc(doc(alice(), 'matches/m1')));
});

test('member can create a match for own team', async () => {
  await assertSucceeds(
    setDoc(doc(alice(), 'matches/m2'), {
      eventId: 'teamA_2026casf',
      teamId: 'teamA',
      isDeleted: false,
    })
  );
});

test('member cannot create a match stamped for another team', async () => {
  await assertFails(
    setDoc(doc(alice(), 'matches/m3'), {
      eventId: 'teamB_2026casf',
      teamId: 'teamB',
      isDeleted: false,
    })
  );
});

test('member cannot create a match with own teamId but another team\'s eventId', async () => {
  await assertFails(
    setDoc(doc(alice(), 'matches/m4'), {
      eventId: 'teamB_2026casf',
      teamId: 'teamA',
      isDeleted: false,
    })
  );
});

// --- The two privilege-escalation vectors this fix closes ---

test('client cannot write its own teamMemberships (claim-source escalation)', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), {
      displayName: 'Alice',
      teamMemberships: {},
    });
  });
  // She may update her profile...
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice'), { displayName: 'Al' }, { merge: true })
  );
  // ...but NOT teamMemberships (the claim source is server-only).
  await assertFails(
    setDoc(doc(alice(), 'users/alice'), { teamMemberships: { teamB: 'admin' } }, { merge: true })
  );
});

test('client cannot self-insert a team member doc (self-join escalation)', async () => {
  await assertFails(
    setDoc(doc(alice(), 'teams/teamB/members/alice'), { role: 'admin', userId: 'alice' })
  );
});

// --- New: lock teamMemberships on CREATE too, and pin teamId on UPDATE ---

test('client cannot create own user doc with non-empty teamMemberships', async () => {
  await assertFails(
    setDoc(doc(alice(), 'users/alice'), {
      displayName: 'Alice',
      teamMemberships: { teamA: 'admin' },
    })
  );
});

test('client can create own user doc with teamMemberships omitted', async () => {
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice'), { displayName: 'Alice' })
  );
});

test('client can create own user doc with teamMemberships explicitly empty', async () => {
  await assertSucceeds(
    setDoc(doc(alice(), 'users/alice'), { displayName: 'Alice', teamMemberships: {} })
  );
});

test('member cannot update a match to reparent it to another team', async () => {
  await seedMatch('teamA');
  await assertFails(
    setDoc(doc(alice(), 'matches/m1'), { teamId: 'teamB' }, { merge: true })
  );
});

test('member can update a teamA match while keeping teamId unchanged', async () => {
  await seedMatch('teamA');
  await assertSucceeds(
    setDoc(doc(alice(), 'matches/m1'), { isDeleted: true }, { merge: true })
  );
});

// --- Regression: get-or-create flow reads the event BEFORE it exists ---
// A null `resource` made the read rule throw (Null value error) and denied
// the first match submitted for any new event.

test('member can read a NON-EXISTENT event doc for their own team (get-or-create)', async () => {
  await assertSucceeds(getDoc(doc(alice(), 'events/teamA_2026casf')));
});

test('member canNOT read a NON-EXISTENT event doc belonging to another team', async () => {
  await assertFails(getDoc(doc(alice(), 'events/teamB_2026casf')));
});

test('member can read an EXISTING own-team event doc', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'events/teamA_2026casf'), {
      teamId: 'teamA', programType: 'FRC', tbaKey: '2026casf',
    });
  });
  await assertSucceeds(getDoc(doc(alice(), 'events/teamA_2026casf')));
});

// --- googleSheetId is server-authoritative: only the set_team_sheet
// callable (Admin SDK) may write it, since it validates the sheet with a
// write probe first. A client write would let any member silently redirect
// the team's export.

describe('teamSettings googleSheetId is server-authoritative', () => {
  const memberOfTeamA = () =>
    testEnv.authenticatedContext('carol', { teams: { teamA: 'member' } }).firestore();
  const adminOfTeamA = () =>
    testEnv.authenticatedContext('dave', { teams: { teamA: 'admin' } }).firestore();

  test('member cannot set googleSheetId', async () => {
    await assertFails(
      setDoc(doc(memberOfTeamA(), 'teamSettings/teamA'), { googleSheetId: 'evil' }, { merge: true })
    );
  });

  test('admin cannot set googleSheetId either', async () => {
    await assertFails(
      setDoc(doc(adminOfTeamA(), 'teamSettings/teamA'), { googleSheetId: 'evil' }, { merge: true })
    );
  });

  test('member cannot overwrite an existing googleSheetId with same-looking write', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'teamSettings/teamA'), { googleSheetId: 'sheet-1' });
    });
    await assertFails(
      setDoc(doc(memberOfTeamA(), 'teamSettings/teamA'), { googleSheetId: 'sheet-2' }, { merge: true })
    );
  });

  test('member can still write defaultEventCode', async () => {
    await assertSucceeds(
      setDoc(doc(memberOfTeamA(), 'teamSettings/teamA'), { defaultEventCode: 'waore' }, { merge: true })
    );
  });

  test('non-member cannot read teamSettings', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'teamSettings/teamA'), { defaultEventCode: 'waore' });
    });
    await assertFails(getDoc(doc(bob(), 'teamSettings/teamA')));
  });

  // --- Field-removal bypass: a plain "does the result contain the key"
  // check is fooled by writes that make the key disappear entirely.

  test('member cannot erase googleSheetId via non-merge setDoc', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'teamSettings/teamA'), {
        googleSheetId: 'sheet-1',
        defaultEventCode: 'waore',
      });
    });
    // Non-merge setDoc: the resulting document has no googleSheetId key at
    // all, which is a removal, not merely an absent-from-payload field.
    await assertFails(
      setDoc(doc(memberOfTeamA(), 'teamSettings/teamA'), { defaultEventCode: 'waore' })
    );
  });

  test('member cannot erase googleSheetId via deleteField()', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'teamSettings/teamA'), {
        googleSheetId: 'sheet-1',
        defaultEventCode: 'waore',
      });
    });
    await assertFails(
      updateDoc(doc(memberOfTeamA(), 'teamSettings/teamA'), {
        googleSheetId: deleteField(),
      })
    );
  });

  test('member cannot delete a teamSettings doc', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'teamSettings/teamA'), { googleSheetId: 'sheet-1' });
    });
    await assertFails(deleteDoc(doc(memberOfTeamA(), 'teamSettings/teamA')));
  });

  test('admin cannot delete a teamSettings doc either', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'teamSettings/teamA'), { googleSheetId: 'sheet-1' });
    });
    await assertFails(deleteDoc(doc(adminOfTeamA(), 'teamSettings/teamA')));
  });

  test('member can create a teamSettings doc without googleSheetId', async () => {
    await assertSucceeds(
      setDoc(doc(memberOfTeamA(), 'teamSettings/teamA'), { defaultEventCode: 'waore' })
    );
  });
});

// ---------------------------------------------------------------------------
// Security review 2026-07-28: the team document and the events namespace
// ---------------------------------------------------------------------------

describe('teams doc is server-authoritative', () => {
  const memberOfTeamA = () =>
    testEnv.authenticatedContext('mem', { teams: { teamA: 'member' } }).firestore();
  const adminOfTeamA = () =>
    testEnv.authenticatedContext('adm', { teams: { teamA: 'admin' } }).firestore();

  async function seedTeam() {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), 'teams/teamA'), {
        name: '254',
        inviteCode: 'AAAA1111',
        createdBy: 'adm',
        memberCount: 2,
        isMasterTeam: false,
      });
    });
  }

  test('member can still read own team', async () => {
    await seedTeam();
    await assertSucceeds(getDoc(doc(memberOfTeamA(), 'teams/teamA')));
  });

  // The invite code is the only credential join_team accepts. A member who
  // could rewrite it could collide it with another team's code and hijack
  // that team's incoming scouts.
  test('member cannot rewrite inviteCode', async () => {
    await seedTeam();
    await assertFails(
      updateDoc(doc(memberOfTeamA(), 'teams/teamA'), { inviteCode: 'HIJACK00' })
    );
  });

  test('admin cannot rewrite inviteCode either (callable-only path)', async () => {
    await seedTeam();
    await assertFails(
      updateDoc(doc(adminOfTeamA(), 'teams/teamA'), { inviteCode: 'HIJACK00' })
    );
  });

  // createdBy was the ONLY authorization check on invite rotation, and it was
  // enforced client-side against this field.
  test('member cannot rewrite createdBy to themselves', async () => {
    await seedTeam();
    await assertFails(
      updateDoc(doc(memberOfTeamA(), 'teams/teamA'), { createdBy: 'mem' })
    );
  });

  test('member cannot forge memberCount or isMasterTeam', async () => {
    await seedTeam();
    await assertFails(
      updateDoc(doc(memberOfTeamA(), 'teams/teamA'), { memberCount: 999 })
    );
    await assertFails(
      updateDoc(doc(memberOfTeamA(), 'teams/teamA'), { isMasterTeam: true })
    );
  });

  test('client cannot create a team doc directly', async () => {
    await assertFails(
      setDoc(doc(adminOfTeamA(), 'teams/teamNew'), { name: '254', inviteCode: 'X' })
    );
  });
});

describe('events cannot be squatted across teams', () => {
  const alice2 = () =>
    testEnv.authenticatedContext('alice', { teams: { teamA: 'admin' } }).firestore();

  test('member can create an event under own team prefix', async () => {
    await assertSucceeds(
      setDoc(doc(alice2(), 'events/teamA_2026casj'), {
        teamId: 'teamA',
        programType: 'FRC',
        tbaKey: '2026casj',
      })
    );
  });

  // The core squat: own teamId in the payload, VICTIM's id in the document id.
  // Once written, every later rule evaluates against the squatter's teamId, so
  // the victim team can no longer read, update, or delete their own event id.
  test('member cannot squat another team\'s event id', async () => {
    await assertFails(
      setDoc(doc(alice2(), 'events/teamB_2026casj'), {
        teamId: 'teamA',
        programType: 'FTC',
        tbaKey: '2026casj',
      })
    );
  });

  test('member cannot create an event stamped for another team', async () => {
    await assertFails(
      setDoc(doc(alice2(), 'events/teamB_2026casj'), {
        teamId: 'teamB',
        programType: 'FRC',
        tbaKey: '2026casj',
      })
    );
  });
});

describe('matches eventId prefix is enforced on update, not just create', () => {
  const alice3 = () =>
    testEnv.authenticatedContext('alice', { teams: { teamA: 'admin' } }).firestore();

  test('member cannot rewrite eventId to an out-of-team value', async () => {
    await seedMatch('teamA');
    await assertFails(
      updateDoc(doc(alice3(), 'matches/m1'), { eventId: 'teamB_2026casj' })
    );
  });

  test('member can still update a match within its own event', async () => {
    await seedMatch('teamA');
    await assertSucceeds(
      updateDoc(doc(alice3(), 'matches/m1'), { isDeleted: true })
    );
  });
});
