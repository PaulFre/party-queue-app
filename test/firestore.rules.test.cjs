const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  addDoc,
  collection,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const PROJECT_ID = 'demo-party-queue';

let testEnv;

function buildRoomState({
  roomCode = 'ROOM01',
  roomName = 'Security Test Room',
  hostUserId = 'host_user',
}) {
  return {
    code: roomCode,
    roomName,
    roomNameLower: roomName.toLowerCase(),
    roomPassword: '1234',
    isPublic: false,
    coreSettingsLocked: true,
    inviteLink: `https://partyqueue.app/join/${roomCode}`,
    hostUserId,
    createdAtMs: 1700000000000,
    ended: false,
    participants: {
      [hostUserId]: {
        id: hostUserId,
        name: 'Host',
        avatar: 'A',
        role: 'host',
      },
    },
  };
}

function buildRoomDoc({
  roomCode = 'ROOM01',
  hostUserId = 'host_user',
  hostAuthUid = 'host_uid',
  roomName,
}) {
  return {
    hostUserId,
    hostAuthUid,
    createdAtMs: 1700000000000,
    updatedAtMs: 1700000000000,
    state: buildRoomState({ roomCode, roomName, hostUserId }),
  };
}

async function seedRoom({
  roomCode = 'ROOM01',
  hostUserId = 'host_user',
  hostAuthUid = 'host_uid',
  roomName,
}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), `party_rooms/${roomCode}`),
      buildRoomDoc({ roomCode, hostUserId, hostAuthUid, roomName }),
    );
  });
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(
        path.join(process.cwd(), 'firestore.rules'),
        'utf8',
      ),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.afterEach(async () => {
  await testEnv.clearFirestore();
});

test('unauthenticated room read is denied', async () => {
  await seedRoom({});
  const unauthDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(unauthDb, 'party_rooms/ROOM01')));
});

test('host can create room only for own auth uid', async () => {
  const hostDb = testEnv.authenticatedContext('host_uid').firestore();
  const allowedRef = doc(hostDb, 'party_rooms/ROOM01');
  await assertSucceeds(
    setDoc(
      allowedRef,
      buildRoomDoc({
        roomCode: 'ROOM01',
        hostUserId: 'host_uid',
        hostAuthUid: 'host_uid',
      }),
    ),
  );

  const deniedRef = doc(hostDb, 'party_rooms/ROOM02');
  await assertFails(
    setDoc(
      deniedRef,
      buildRoomDoc({
        roomCode: 'ROOM02',
        hostUserId: 'host_uid',
        hostAuthUid: 'different_uid',
      }),
    ),
  );
});

test('only host may update room state', async () => {
  await seedRoom({
    roomCode: 'ROOM01',
    hostUserId: 'host_uid',
    hostAuthUid: 'host_uid',
  });

  const guestDb = testEnv.authenticatedContext('guest_uid').firestore();
  await assertFails(
    updateDoc(doc(guestDb, 'party_rooms/ROOM01'), {
      updatedAtMs: 1700000000001,
      state: buildRoomState({
        roomCode: 'ROOM01',
        hostUserId: 'host_uid',
        roomName: 'Mutated by guest',
      }),
    }),
  );

  const hostDb = testEnv.authenticatedContext('host_uid').firestore();
  await assertSucceeds(
    updateDoc(doc(hostDb, 'party_rooms/ROOM01'), {
      updatedAtMs: 1700000000001,
      state: buildRoomState({
        roomCode: 'ROOM01',
        hostUserId: 'host_uid',
        roomName: 'Updated by host',
      }),
    }),
  );
});

test('guest can create own command but not impersonate another user', async () => {
  await seedRoom({
    roomCode: 'ROOM01',
    hostUserId: 'host_uid',
    hostAuthUid: 'host_uid',
  });

  const guestDb = testEnv.authenticatedContext('guest_uid').firestore();
  const commands = collection(guestDb, 'party_rooms/ROOM01/commands');

  await assertSucceeds(
    addDoc(commands, {
      type: 'voteSong',
      userId: 'guest_uid',
      payload: { queueItemId: 'q1', vote: 'like' },
      createdAtMs: 1700000000001,
      processed: false,
    }),
  );

  await assertFails(
    addDoc(commands, {
      type: 'voteSong',
      userId: 'host_uid',
      payload: { queueItemId: 'q1', vote: 'like' },
      createdAtMs: 1700000000002,
      processed: false,
    }),
  );
});

test('only host can mark command as processed', async () => {
  await seedRoom({
    roomCode: 'ROOM01',
    hostUserId: 'host_uid',
    hostAuthUid: 'host_uid',
  });

  let commandId;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const writeDb = context.firestore();
    const created = await addDoc(
      collection(writeDb, 'party_rooms/ROOM01/commands'),
      {
        type: 'addSong',
        userId: 'guest_uid',
        payload: { song: { id: 'sp001' } },
        createdAtMs: 1700000000001,
        processed: false,
      },
    );
    commandId = created.id;
  });

  const guestDb = testEnv.authenticatedContext('guest_uid').firestore();
  await assertFails(
    updateDoc(doc(guestDb, `party_rooms/ROOM01/commands/${commandId}`), {
      processed: true,
      processedAtMs: 1700000000003,
      resultSuccess: true,
      resultMessage: 'ok',
    }),
  );

  const hostDb = testEnv.authenticatedContext('host_uid').firestore();
  await assertSucceeds(
    updateDoc(doc(hostDb, `party_rooms/ROOM01/commands/${commandId}`), {
      processed: true,
      processedAtMs: 1700000000003,
      resultSuccess: true,
      resultMessage: 'ok',
    }),
  );
});
