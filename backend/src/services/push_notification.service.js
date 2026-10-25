const { cert, getApps, initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const { query } = require('../config/database');

const getFirebaseApp = () => {
  const apps = getApps();
  if (apps.length) return apps[0];

  const encodedCredentials = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (!encodedCredentials) {
    const error = new Error('Firebase push credentials are not configured.');
    error.statusCode = 503;
    error.code = 'FCM_NOT_CONFIGURED';
    throw error;
  }

  let credentials;
  try {
    credentials = JSON.parse(
      Buffer.from(encodedCredentials, 'base64').toString('utf8')
    );
  } catch (cause) {
    const error = new Error('Firebase service account configuration is invalid.');
    error.statusCode = 503;
    error.code = 'FCM_INVALID_CONFIGURATION';
    error.cause = cause;
    throw error;
  }

  return initializeApp({
    credential: cert(credentials),
  });
};

const sendBroadcast = async ({ title, body }) => {
  const result = await query('SELECT token FROM push_tokens');
  const tokens = result.rows.map(row => row.token).filter(Boolean);
  if (tokens.length === 0) {
    return { successCount: 0, failureCount: 0, deviceCount: 0 };
  }

  const messaging = getMessaging(getFirebaseApp());
  let successCount = 0;
  let failureCount = 0;
  const invalidTokens = [];

  for (let start = 0; start < tokens.length; start += 500) {
    const batch = tokens.slice(start, start + 500);
    const response = await messaging.sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
    });
    successCount += response.successCount;
    failureCount += response.failureCount;

    response.responses.forEach((sendResponse, index) => {
      const code = sendResponse.error?.code;
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        invalidTokens.push(batch[index]);
      }
    });
  }

  if (invalidTokens.length > 0) {
    await query(
      'DELETE FROM push_tokens WHERE token = ANY($1::text[])',
      [invalidTokens]
    );
  }

  return { successCount, failureCount, deviceCount: tokens.length };
};

module.exports = { sendBroadcast };
