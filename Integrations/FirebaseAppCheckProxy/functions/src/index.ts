import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";

// Initialize Firebase Admin SDK for token verification and consumption
initializeApp();

// Define the secret stored in Google Cloud Secret Manager
const typesafeApiKey = defineSecret("TYPESAFE_API_KEY");

/**
 * A Firebase Cloud Function (2nd Gen) reverse proxy that:
 * 1. Enforces Firebase App Check at platform ingress (Apple App Attest / DeviceCheck).
 * 2. Optionally consumes limited-use tokens for replay protection (when CONSUME_APP_CHECK="true").
 * 3. Validates incoming payload shape to prevent unauthorized traffic from reaching upstream.
 * 4. Injects the upstream TYPESAFE_API_KEY from Google Secret Manager.
 * 5. Forwards requests to TypeSafe AI's Jev System One evaluation endpoint with a timeout.
 * 6. Preserves upstream status codes and payload bodies for client decoding.
 */
export const systemone = onRequest(
  {
    cors: false,
    enforceAppCheck: true, // Rejects unverified traffic at Google Cloud edge
    secrets: [typesafeApiKey],
    // Performance tuning:
    // minInstances: 1 keeps a container warm 24/7 to eliminate ~500ms-1.5s cold starts.
    // Omit or set to 0 for cost-optimized personal projects.
    minInstances: 1,
    // Concurrency allows up to 80 concurrent mobile requests per warm container
    concurrency: 80,
  },
  async (req, res) => {
    // Only POST requests are valid for Jev evaluations
    if (req.method !== "POST") {
      res.status(405).json({ error: "Method Not Allowed" });
      return;
    }

    // Optional Limited-Use Token Replay Protection
    const appCheckToken = req.header("X-Firebase-AppCheck");
    const consume = process.env.CONSUME_APP_CHECK === "true";
    if (consume && appCheckToken) {
      try {
        const claims = await getAppCheck().verifyToken(appCheckToken, { consume: true });
        if (claims.alreadyConsumed) {
          res.status(401).json({ error: "Unauthorized: App Check token has already been consumed" });
          return;
        }
      } catch (error: any) {
        res.status(401).json({ error: `Unauthorized: Invalid App Check token (${error.message ?? error})` });
        return;
      }
    }

    // Validate request payload structure before forwarding to billable upstream
    const { state, questions } = req.body ?? {};
    if (!state || typeof state !== "string" || !questions || typeof questions !== "object" || Array.isArray(questions)) {
      res.status(400).json({ error: "Bad Request: Payload must include a 'state' string and a 'questions' object" });
      return;
    }

    try {
      const upstreamResponse = await fetch("https://api.typesafe.ai/v1/systemone", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${typesafeApiKey.value()}`,
        },
        body: JSON.stringify(req.body),
        signal: AbortSignal.timeout(15000), // 15-second upstream timeout
      });

      const responseText = await upstreamResponse.text();
      res
        .status(upstreamResponse.status)
        .header("Content-Type", upstreamResponse.headers.get("Content-Type") || "application/json")
        .send(responseText);
    } catch (error: any) {
      res.status(502).json({ error: error.message ?? "Upstream proxy failure" });
    }
  }
);
