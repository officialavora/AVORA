import {after, before, beforeEach, test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  writeBatch,
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

test('users can persist safe profile fields but cannot inject authority', async () => {
  await assertSucceeds(allocate('user-a', 'member_a'));
  const db = environment.authenticatedContext('user-a').firestore();
  await assertSucceeds(updateDoc(doc(db, 'users/user-a'), {
    displayName: 'Member A',
    bio: 'Original AVORA profile',
    countryCode: 'SA',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'users/user-a'), {
    displayName: 'Member A',
    avora_owner: true,
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db, 'users/user-a'), {
    displayName: 'X',
    updatedAt: serverTimestamp(),
  }));
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

async function createRoom(uid, roomId = 'room-a') {
  const db = environment.authenticatedContext(uid).firestore();
  const roomRef = doc(db, `rooms/${roomId}`);
  const memberRef = doc(db, `rooms/${roomId}/members/${uid}`);
  const batch = writeBatch(db);
  batch.set(roomRef, {
    ownerUid: uid,
    name: 'Aurora Commons',
    description: 'An original AVORA social room',
    status: 'active',
    visibility: 'public',
    memberCount: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.set(memberRef, {
    uid,
    role: 'host',
    status: 'active',
    joinedAt: serverTimestamp(),
    lastActiveAt: serverTimestamp(),
  });
  await batch.commit();
}

test('rooms persist only with matching host membership', async () => {
  await assertSucceeds(createRoom('user-a'));
  const db = environment.authenticatedContext('user-b').firestore();
  await assertSucceeds(getDoc(doc(db, 'rooms/room-a')));
  await assertFails(setDoc(doc(db, 'rooms/room-b'), {
    ownerUid: 'user-a',
    name: 'Forged Room',
    description: '',
    status: 'active',
    visibility: 'public',
    memberCount: 1,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
});

test('room messages require membership and support audited moderation', async () => {
  await createRoom('host-a');
  const outsiderDb = environment.authenticatedContext('user-b').firestore();
  const outsiderMessage = doc(outsiderDb, 'rooms/room-a/messages/message-a');
  await assertFails(setDoc(outsiderMessage, {
    senderUid: 'user-b',
    senderName: 'Member B',
    body: 'Blocked until joined',
    status: 'active',
    createdAt: serverTimestamp(),
  }));

  await assertSucceeds(setDoc(doc(outsiderDb, 'rooms/room-a/members/user-b'), {
    uid: 'user-b',
    role: 'member',
    status: 'active',
    joinedAt: serverTimestamp(),
    lastActiveAt: serverTimestamp(),
  }));
  await assertSucceeds(setDoc(outsiderMessage, {
    senderUid: 'user-b',
    senderName: 'Member B',
    body: 'A real persisted message',
    status: 'active',
    createdAt: serverTimestamp(),
  }));

  const hostDb = environment.authenticatedContext('host-a').firestore();
  await assertSucceeds(updateDoc(doc(hostDb, 'rooms/room-a/messages/message-a'), {
    status: 'moderated',
    moderatedAt: serverTimestamp(),
    moderatedBy: 'host-a',
  }));
});

async function createConversation(uid, peerUid, id = 'user-a_user-b') {
  const db = environment.authenticatedContext(uid).firestore();
  await setDoc(doc(db, `conversations/${id}`), {
    participantUids: [uid, peerUid].sort(),
    participantNames: {[uid]: uid, [peerUid]: peerUid},
    createdBy: uid,
    status: 'active',
    lastMessage: '',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
}

test('direct messages are private to participants and persist atomically', async () => {
  await assertSucceeds(createConversation('user-a', 'user-b'));
  const memberDb = environment.authenticatedContext('user-b').firestore();
  const outsiderDb = environment.authenticatedContext('user-c').firestore();
  await assertSucceeds(getDoc(doc(memberDb, 'conversations/user-a_user-b')));
  await assertFails(getDoc(doc(outsiderDb, 'conversations/user-a_user-b')));

  const thread = doc(memberDb, 'conversations/user-a_user-b');
  const message = doc(memberDb, 'conversations/user-a_user-b/messages/m1');
  const batch = writeBatch(memberDb);
  batch.set(message, {
    senderUid: 'user-b',
    body: 'Persistent AVORA message',
    status: 'active',
    createdAt: serverTimestamp(),
  });
  batch.update(thread, {
    lastMessage: 'Persistent AVORA message',
    lastSenderUid: 'user-b',
    updatedAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());
});

test('blocking stops messages in both directions and reports are immutable', async () => {
  await createConversation('user-a', 'user-b');
  const blockerDb = environment.authenticatedContext('user-a').firestore();
  const peerDb = environment.authenticatedContext('user-b').firestore();
  await assertSucceeds(setDoc(doc(blockerDb, 'blocks/user-a_user-b'), {
    blockerUid: 'user-a',
    blockedUid: 'user-b',
    createdAt: serverTimestamp(),
  }));
  await assertFails(setDoc(
    doc(peerDb, 'conversations/user-a_user-b/messages/blocked'),
    {
      senderUid: 'user-b',
      body: 'This must not pass',
      status: 'active',
      createdAt: serverTimestamp(),
    },
  ));
  const report = doc(peerDb, 'reports/report-a');
  await assertSucceeds(setDoc(report, {
    reporterUid: 'user-b',
    targetUid: 'user-a',
    conversationId: 'user-a_user-b',
    category: 'direct_message',
    details: 'Abuse report',
    status: 'pending',
    createdAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(report, {status: 'dismissed'}));
});

test('follow and notification are atomic and blocked relationships cannot follow', async () => {
  await allocate('user-a', 'member_a');
  await allocate('user-b', 'member_b');
  const db = environment.authenticatedContext('user-a').firestore();
  const follow = doc(db, 'follows/user-a_user-b');
  const notice = doc(db, 'notifications/user-b/items/follow-a');
  const batch = writeBatch(db);
  batch.set(follow, {
    sourceUid: 'user-a',
    targetUid: 'user-b',
    targetUsername: 'member_b',
    status: 'active',
    createdAt: serverTimestamp(),
  });
  batch.set(notice, {
    recipientUid: 'user-b',
    actorUid: 'user-a',
    type: 'follow',
    title: 'New follower',
    body: 'An AVORA member followed you',
    read: false,
    createdAt: serverTimestamp(),
  });
  await assertSucceeds(batch.commit());

  const recipientDb = environment.authenticatedContext('user-b').firestore();
  await assertSucceeds(updateDoc(
    doc(recipientDb, 'notifications/user-b/items/follow-a'),
    {read: true},
  ));
  await assertFails(getDoc(doc(db, 'notifications/user-b/items/follow-a')));
  await assertSucceeds(setDoc(doc(recipientDb, 'blocks/user-b_user-a'), {
    blockerUid: 'user-b',
    blockedUid: 'user-a',
    createdAt: serverTimestamp(),
  }));
  await assertSucceeds(deleteDoc(follow));
  await assertFails(setDoc(follow, {
    sourceUid: 'user-a',
    targetUid: 'user-b',
    targetUsername: 'member_b',
    status: 'active',
    createdAt: serverTimestamp(),
  }));
});

test('only custom-claim Owner can review submitted reports', async () => {
  const reporter = environment.authenticatedContext('user-a').firestore();
  const report = doc(reporter, 'reports/owner-review');
  await assertSucceeds(setDoc(report, {
    reporterUid: 'user-a',
    targetUid: 'user-b',
    conversationId: 'user-a_user-b',
    category: 'direct_message',
    details: 'Needs review',
    status: 'pending',
    createdAt: serverTimestamp(),
  }));
  const ordinary = environment.authenticatedContext('user-b').firestore();
  await assertFails(updateDoc(doc(ordinary, 'reports/owner-review'), {
    status: 'approved',
  }));
  const owner = environment.authenticatedContext('owner-a', {
    avora_owner: true,
  }).firestore();
  await assertSucceeds(updateDoc(doc(owner, 'reports/owner-review'), {
    status: 'approved',
    reviewedBy: 'owner-a',
    reviewedAt: serverTimestamp(),
  }));
});
