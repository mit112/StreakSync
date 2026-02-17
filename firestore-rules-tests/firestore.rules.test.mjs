import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc } from "firebase/firestore";

const PROJECT_ID = "streaksync-firestore-rules-tests";
const [host = "127.0.0.1", portString = "8080"] =
  (process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080").split(":");
const PORT = Number.parseInt(portString, 10);

const RULES_PATH = resolve(process.cwd(), "..", "firestore.rules");
const rules = readFileSync(RULES_PATH, "utf8");

let testEnv;
let failures = 0;

function logPass(name) {
  console.log(`PASS: ${name}`);
}

function logFail(name, error) {
  failures += 1;
  console.error(`FAIL: ${name}`);
  console.error(error?.message ?? error);
}

async function runCase(name, fn) {
  try {
    await testEnv.clearFirestore();
    await fn();
    logPass(name);
  } catch (error) {
    logFail(name, error);
  }
}

async function seedDoc(path, data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), path), data);
  });
}

async function main() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      host,
      port: PORT,
      rules,
    },
  });

  await runCase("users read allowed for accepted friend", async () => {
    await seedDoc("users/alice", { displayName: "Alice", friends: ["bob"] });
    const db = testEnv.authenticatedContext("bob").firestore();
    await assertSucceeds(getDoc(doc(db, "users/alice")));
  });

  await runCase("users read denied for non-friend", async () => {
    await seedDoc("users/alice", { displayName: "Alice", friends: ["bob"] });
    const db = testEnv.authenticatedContext("charlie").firestore();
    await assertFails(getDoc(doc(db, "users/alice")));
  });

  await runCase("scores read allowed only for users in allowedReaders", async () => {
    await seedDoc("scores/score1", {
      userId: "alice",
      gameId: "wordle",
      dateInt: 20260217,
      gameName: "Wordle",
      completed: true,
      allowedReaders: ["alice", "bob"],
      score: 3,
      maxAttempts: 6,
      currentStreak: 10,
    });

    const bobDb = testEnv.authenticatedContext("bob").firestore();
    const charlieDb = testEnv.authenticatedContext("charlie").firestore();

    await assertSucceeds(getDoc(doc(bobDb, "scores/score1")));
    await assertFails(getDoc(doc(charlieDb, "scores/score1")));
  });

  await runCase("scores create denied when allowedReaders omits current user", async () => {
    const db = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(db, "scores/score2"), {
        userId: "alice",
        gameId: "wordle",
        dateInt: 20260217,
        gameName: "Wordle",
        completed: true,
        allowedReaders: ["bob"],
      }),
    );
  });

  await runCase("scores create denied for malformed optional field types", async () => {
    const db = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(db, "scores/score3"), {
        userId: "alice",
        gameId: "wordle",
        dateInt: 20260217,
        gameName: "Wordle",
        completed: true,
        allowedReaders: ["alice"],
        maxAttempts: "6",
      }),
    );
  });

  await runCase("friendship accept allowed only for recipient", async () => {
    await seedDoc("friendships/f1", {
      userId1: "alice",
      userId2: "bob",
      status: "pending",
      createdAt: 1708128000,
    });

    const bobDb = testEnv.authenticatedContext("bob").firestore();
    await assertSucceeds(
      updateDoc(doc(bobDb, "friendships/f1"), {
        userId1: "alice",
        userId2: "bob",
        status: "accepted",
        createdAt: 1708128000,
      }),
    );
  });

  await runCase("friendship accept denied for sender", async () => {
    await seedDoc("friendships/f2", {
      userId1: "alice",
      userId2: "bob",
      status: "pending",
      createdAt: 1708128000,
    });

    const aliceDb = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      updateDoc(doc(aliceDb, "friendships/f2"), {
        userId1: "alice",
        userId2: "bob",
        status: "accepted",
        createdAt: 1708128000,
      }),
    );
  });

  await runCase("friendship create denied when initial status is not pending", async () => {
    const db = testEnv.authenticatedContext("alice").firestore();
    await assertFails(
      setDoc(doc(db, "friendships/f3"), {
        userId1: "alice",
        userId2: "bob",
        status: "accepted",
        createdAt: 1708128000,
      }),
    );
  });

  await runCase("friendship update denied when immutable user fields are changed", async () => {
    await seedDoc("friendships/f4", {
      userId1: "alice",
      userId2: "bob",
      status: "pending",
      createdAt: 1708128000,
    });

    const bobDb = testEnv.authenticatedContext("bob").firestore();
    await assertFails(
      updateDoc(doc(bobDb, "friendships/f4"), {
        userId1: "mallory",
        userId2: "bob",
        status: "accepted",
        createdAt: 1708128000,
      }),
    );
  });

  await testEnv.cleanup();
  if (failures > 0) {
    console.error(`\n${failures} rule test(s) failed.`);
    process.exitCode = 1;
    return;
  }
  console.log("\nAll Firestore rules tests passed.");
}

main().catch(async (error) => {
  console.error("Fatal error running Firestore rules tests:", error);
  if (testEnv) {
    await testEnv.cleanup();
  }
  process.exit(1);
});
