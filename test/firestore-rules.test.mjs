import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';

let environment;

before(async () => {
  environment = await initializeTestEnvironment({
    projectId: 'avora-rules-test',
    firestore: {rules: fs.readFileSync('firestore.rules', 'utf8')},
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'system/counters'), {
      lastUserId: 9999999,
    });
  });
});

after(async () => {
  if (environment) await environment.cleanup();
});

const userPayload = (id, username) => ({
  originalAvoraId: id,
  username,
  role: 'user',
  authorityRole: 'user',
  commerceRole: 'none',
  staffAssignments: [],
  scopeType: 'self',
  countryCode: null,
  managerId: null,
  bdId: null,
  agencyId: null,
  displayName: username,
  createdAt: serverTimestamp(),
  usernameChangedAt: serverTimestamp(),
});

async function allocate(uid, username) {
  const db = environment.authenticatedContext(uid).firestore();
  return runTransaction(db, async (transaction) => {
    const counterRef = doc(db, 'system/counters');
    const userRef = doc(db, `users/${uid}`);
    const usernameRef = doc(db, `usernames/${username}`);
    const [counter, existingUser] = await Promise.all([
      transaction.get(counterRef),
      transaction.get(userRef),
      transaction.get(usernameRef),
    ]);
    assert.equal(existingUser.exists(), false);
    const id = counter.data().lastUserId + 1;
    transaction.update(counterRef, {lastUserId: id});
    transaction.set(usernameRef, {
      uid,
      username,
      avoraId: id,
      createdAt: serverTimestamp(),
    });
    transaction.set(userRef, userPayload(id, username));
    return id;
  });
}

async function allocateWithContentionRetry(uid, username) {
  let lastError;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      return await allocate(uid, username);
    } catch (error) {
      lastError = error;
      if (error?.code !== 'permission-denied' && error?.code !== 'aborted') {
        throw error;
      }
    }
  }
  throw lastError;
}

async function ageUsername(uid, days) {
  await environment.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), `users/${uid}`), {
      usernameChangedAt: Timestamp.fromMillis(Date.now() - days * 86400000),
    });
  });
}

async function rename(uid, newUsername) {
  const db = environment.authenticatedContext(uid).firestore();
  return runTransaction(db, async (transaction) => {
    const userRef = doc(db, `users/${uid}`);
    const userSnapshot = await transaction.get(userRef);
    const user = userSnapshot.data();
    const oldUsername = user.username;
    const avoraId = user.originalAvoraId;
    const newUsernameRef = doc(db, `usernames/${newUsername}`);
    await transaction.get(newUsernameRef);
    transaction.set(newUsernameRef, {
      uid,
      username: newUsername,
      avoraId,
      createdAt: serverTimestamp(),
    });
    transaction.set(doc(db, `usernameHistory/${oldUsername}`), {
      uid,
      username: oldUsername,
      replacementUsername: newUsername,
      avoraId,
      reservedAt: serverTimestamp(),
    });
    transaction.set(doc(db, `identityAudit/${uid}-rename`), {
      action: 'username.rename',
      uid,
      oldUsername,
      newUsername,
      createdAt: serverTimestamp(),
    });
    transaction.update(userRef, {
      username: newUsername,
      usernameChangedAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  });
}

test('first production identity is exactly 10000000', async () => {
  assert.equal(await assertSucceeds(allocate('user-a', 'member_a')), 10000000);
});

test('concurrent signups receive unique sequential IDs', async () => {
  const ids = await Promise.all([
    allocateWithContentionRetry('user-a', 'member_a'),
    allocateWithContentionRetry('user-b', 'member_b'),
  ]);
  assert.deepEqual([...ids].sort(), [10000000, 10000001]);
});

test('case variants and duplicate usernames cannot be reserved', async () => {
  await assertSucceeds(allocate('user-a', 'member_a'));
  await assertFails(allocate('user-b', 'member_a'));
  await assertFails(allocate('user-c', 'Member_A'));
});

test('reserved impersonation usernames are rejected', async () => {
  await assertFails(allocate('user-a', 'avora_owner'));
  await assertFails(allocate('user-b', 'official'));
});

test('identity, username and authority fields are immutable for users', async () => {
  await assertSucceeds(allocate('user-a', 'member_a'));
  const db = environment.authenticatedContext('user-a').firestore();
  await assertFails(updateDoc(doc(db, 'users/user-a'), {originalAvoraId: 7}));
  await assertFails(updateDoc(doc(db, 'users/user-a'), {username: 'member_b'}));
  await assertFails(updateDoc(doc(db, 'users/user-a'), {role: 'owner'}));
});

test('only a custom-claim Owner can perform privileged profile updates', async () => {
  await assertSucceeds(allocate('user-a', 'member_a'));
  const ordinary = environment.authenticatedContext('user-b').firestore();
  const owner = environment.authenticatedContext('owner-a', {
    avora_owner: true,
  }).firestore();
  await assertFails(updateDoc(doc(ordinary, 'users/user-a'), {displayName: 'Bad'}));
  await assertSucceeds(updateDoc(doc(owner, 'users/user-a'), {displayName: 'Reviewed'}));
  assert.equal((await getDoc(doc(owner, 'users/user-a'))).data().displayName, 'Reviewed');
});

test('username rename enforces cooldown and preserves permanent history', async () => {
  await assertSucceeds(allocate('user-a', 'member_a'));
  await assertFails(rename('user-a', 'member_new'));
  await ageUsername('user-a', 31);
  await assertSucceeds(rename('user-a', 'member_new'));

  const db = environment.authenticatedContext('user-a').firestore();
  const history = await getDoc(doc(db, 'usernameHistory/member_a'));
  assert.equal(history.data().replacementUsername, 'member_new');

  await ageUsername('user-a', 31);
  await assertFails(rename('user-a', 'member_a'));
});
