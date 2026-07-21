const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc } = require('firebase/firestore');

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
