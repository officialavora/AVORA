import process from 'node:process';
import {applicationDefault, cert, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

const targetUid = process.env.AVORA_TARGET_UID?.trim();
const action = process.env.AVORA_OWNER_ACTION?.trim();
const reason = process.env.AVORA_OWNER_REASON?.trim();
const githubActor = process.env.GITHUB_ACTOR?.trim() || 'unknown';
const rawCredential = process.env.FIREBASE_SERVICE_ACCOUNT_AVORA?.trim();

if (!targetUid || !['grant', 'revoke'].includes(action) || !reason) {
  throw new Error('Target UID, grant/revoke action and reason are required');
}
if (reason.length < 10 || reason.length > 500) {
  throw new Error('Reason must contain 10-500 characters');
}

const credential = rawCredential
  ? cert(JSON.parse(rawCredential))
  : applicationDefault();
initializeApp({credential, projectId: 'avora-4ac0c'});

const auth = getAuth();
const firestore = getFirestore();
const auditRef = firestore.collection('privilegedAudit').doc();
const user = await auth.getUser(targetUid);
const before = user.customClaims?.avora_owner === true;
const after = action === 'grant';

await auditRef.create({
  action: `owner_claim.${action}`,
  targetUid,
  actorType: 'github_workflow',
  githubActor,
  reason,
  before,
  requestedAfter: after,
  status: 'pending',
  createdAt: FieldValue.serverTimestamp(),
});

try {
  await auth.setCustomUserClaims(targetUid, {
    ...(user.customClaims || {}),
    avora_owner: after,
  });
  await auditRef.update({
    status: 'completed',
    completedAt: FieldValue.serverTimestamp(),
  });
} catch (error) {
  await auditRef.update({
    status: 'failed',
    failedAt: FieldValue.serverTimestamp(),
    errorCode: error?.code || 'unknown',
  });
  throw error;
}

console.log(`Owner claim ${action} completed for UID ${targetUid}`);
