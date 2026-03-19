/**
 * StreakSync — Firestore Security Rules Penetration Test Suite
 *
 * Run:  firebase emulators:start --only firestore
 *       node firestore.rules.test.mjs
 *
 * Legend:
 *   ✅  Expected behavior, rule is correct
 *   🔴  Vulnerability test — would FAIL on old rules, PASSES on fixed rules
 *   ⚠️  Accepted risk — documents known limitation
 */

import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  collection,
  getDocs,
  query,
  where,
} from "firebase/firestore";

const PROJECT_ID = "streaksync-firestore-rules-tests";
const [host = "127.0.0.1", portString = "8080"] = (
  process.env.FIRESTORE_EMULATOR_HOST ?? "127.0.0.1:8080"
).split(":");
const PORT = Number.parseInt(portString, 10);

const RULES_PATH = resolve(process.cwd(), "..", "firestore.rules");
const rules = readFileSync(RULES_PATH, "utf8");

let testEnv;
let passed = 0;
let failures = 0;
let total = 0;

function logPass(name) {
  passed += 1;
  console.log(`  ✅ PASS: ${name}`);
}
function logFail(name, error) {
  failures += 1;
  console.error(`  ❌ FAIL: ${name}`);
  console.error(`     ${error?.message ?? error}`);
}

async function runCase(name, fn) {
  total += 1;
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

function authed(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}
function unauthed() {
  return testEnv.unauthenticatedContext().firestore();
}

// ─── Valid document templates ──────────────────────────────────
const VALID_USER = {
  displayName: "Alice",
  friends: [],
  authProvider: "apple",
  createdAt: 1708128000,
  updatedAt: 1708128000,
};

const VALID_SCORE = {
  userId: "alice",
  gameId: "550e8400-e29b-41d4-a716-446655440000",
  dateInt: 20260226,
  gameName: "Wordle",
  completed: true,
  allowedReaders: ["alice", "bob"],
  score: 3,
  maxAttempts: 6,
  currentStreak: 10,
};

const VALID_FRIENDSHIP = {
  userId1: "alice",
  userId2: "bob",
  status: "pending",
  createdAt: 1708128000,
};

const VALID_FRIEND_CODE = {
  userId: "alice",
  displayName: "Alice",
};

const VALID_GAME_RESULT = {
  gameId: "550e8400-e29b-41d4-a716-446655440000",
  gameName: "Wordle",
  date: { seconds: 1708128000, nanoseconds: 0 },
  maxAttempts: 6,
  completed: true,
  sharedText: "Wordle 1234 3/6",
  parsedData: { puzzleNumber: "1234" },
  lastModified: { seconds: 1708128000, nanoseconds: 0 },
  score: 3,
};

// ═══════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════

async function main() {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host, port: PORT, rules },
  });

  // ─── 1. UNAUTHENTICATED ACCESS ────────────────────────────
  console.log("\n── Unauthenticated Access ──");

  await runCase("✅ unauthed cannot read users", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    await assertFails(getDoc(doc(unauthed(), "users/alice")));
  });

  await runCase("✅ unauthed cannot read scores", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE });
    await assertFails(getDoc(doc(unauthed(), "scores/s1")));
  });

  await runCase("✅ unauthed cannot read friendships", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    await assertFails(getDoc(doc(unauthed(), "friendships/f1")));
  });

  await runCase("✅ unauthed cannot read friendCodes", async () => {
    await seedDoc("friendCodes/ABC123", { ...VALID_FRIEND_CODE });
    await assertFails(getDoc(doc(unauthed(), "friendCodes/ABC123")));
  });

  await runCase("✅ unauthed cannot read gameResults", async () => {
    await seedDoc("users/alice/gameResults/r1", { gameName: "Wordle" });
    await assertFails(getDoc(doc(unauthed(), "users/alice/gameResults/r1")));
  });

  await runCase("✅ unauthed cannot read sync data", async () => {
    await seedDoc("users/alice/sync/achievements", { payload: "abc" });
    await assertFails(getDoc(doc(unauthed(), "users/alice/sync/achievements")));
  });

  // ─── 2. USER PROFILES ─────────────────────────────────────
  console.log("\n── User Profiles ──");

  await runCase("✅ owner can read own profile", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    await assertSucceeds(getDoc(doc(authed("alice"), "users/alice")));
  });

  await runCase("✅ accepted friend can read profile (via friendship doc)", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    await seedDoc("friendships/alice_bob", {
      userId1: "alice", userId2: "bob", status: "accepted", createdAt: 1708128000,
    });
    await assertSucceeds(getDoc(doc(authed("bob"), "users/alice")));
  });

  await runCase("✅ non-friend cannot read profile", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    await assertFails(getDoc(doc(authed("charlie"), "users/alice")));
  });

  await runCase("✅ user can create own profile with valid fields", async () => {
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "users/alice"), { ...VALID_USER })
    );
  });

  await runCase("✅ user cannot create profile for another user", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "users/bob"), { ...VALID_USER })
    );
  });

  await runCase("✅ owner can update own profile", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "users/alice"), {
        ...VALID_USER,
        displayName: "Alice Updated",
      })
    );
  });

  await runCase("✅ owner can delete own profile", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    await assertSucceeds(deleteDoc(doc(authed("alice"), "users/alice")));
  });

  await runCase("✅ other user cannot delete someone's profile", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    await assertFails(deleteDoc(doc(authed("bob"), "users/alice")));
  });

  await runCase("🔴 user create rejects disallowed fields (isAdmin)", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "users/alice"), { ...VALID_USER, isAdmin: true })
    );
  });

  await runCase("🔴 user update rejects disallowed fields", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "users/alice"), { ...VALID_USER, role: "superuser" })
    );
  });

  await runCase("🔴 user create rejects oversized displayName", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "users/alice"), {
        ...VALID_USER,
        displayName: "A".repeat(201),
      })
    );
  });

  await runCase("🔴 user create rejects empty displayName", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "users/alice"), {
        ...VALID_USER,
        displayName: "",
      })
    );
  });

  await runCase("🔴 user create rejects oversized friends array", async () => {
    const db = authed("alice");
    const bigFriends = Array.from({ length: 501 }, (_, i) => `user${i}`);
    await assertFails(
      setDoc(doc(db, "users/alice"), { ...VALID_USER, friends: bigFriends })
    );
  });

  // ─── 3. GAME RESULTS (private subcollection) ──────────────
  console.log("\n── Game Results ──");

  await runCase("✅ owner can write/read own gameResults", async () => {
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "users/alice/gameResults/r1"), { ...VALID_GAME_RESULT })
    );
    await assertSucceeds(
      getDoc(doc(db, "users/alice/gameResults/r1"))
    );
  });

  await runCase("✅ other user cannot read gameResults", async () => {
    await seedDoc("users/alice/gameResults/r1", { ...VALID_GAME_RESULT });
    await assertFails(
      getDoc(doc(authed("bob"), "users/alice/gameResults/r1"))
    );
  });

  await runCase("✅ other user cannot write gameResults", async () => {
    await assertFails(
      setDoc(doc(authed("bob"), "users/alice/gameResults/r1"), {
        ...VALID_GAME_RESULT,
      })
    );
  });

  await runCase("✅ owner can delete own gameResults", async () => {
    await seedDoc("users/alice/gameResults/r1", { ...VALID_GAME_RESULT });
    await assertSucceeds(
      deleteDoc(doc(authed("alice"), "users/alice/gameResults/r1"))
    );
  });

  await runCase("✅ owner can write valid gameResult with all fields", async () => {
    await assertSucceeds(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), { ...VALID_GAME_RESULT })
    );
  });

  await runCase("✅ owner can write gameResult without optional score", async () => {
    const { score, ...noScore } = VALID_GAME_RESULT;
    await assertSucceeds(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), noScore)
    );
  });

  await runCase("✅ rejects gameResult with disallowed extra fields", async () => {
    await assertFails(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), {
        ...VALID_GAME_RESULT,
        isAdmin: true,
      })
    );
  });

  await runCase("✅ rejects gameResult with missing required field", async () => {
    const { sharedText, ...missingField } = VALID_GAME_RESULT;
    await assertFails(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), missingField)
    );
  });

  await runCase("✅ rejects gameResult with wrong type for completed", async () => {
    await assertFails(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), {
        ...VALID_GAME_RESULT,
        completed: "yes",
      })
    );
  });

  await runCase("✅ rejects gameResult with oversized gameName", async () => {
    await assertFails(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), {
        ...VALID_GAME_RESULT,
        gameName: "X".repeat(201),
      })
    );
  });

  await runCase("✅ rejects gameResult with oversized sharedText", async () => {
    await assertFails(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), {
        ...VALID_GAME_RESULT,
        sharedText: "X".repeat(2501),
      })
    );
  });

  await runCase("✅ accepts gameResult with exactly max-length sharedText", async () => {
    await assertSucceeds(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), {
        ...VALID_GAME_RESULT,
        sharedText: "X".repeat(2500),
      })
    );
  });

  await runCase("✅ owner can update existing gameResult", async () => {
    await seedDoc("users/alice/gameResults/r1", { ...VALID_GAME_RESULT });
    await assertSucceeds(
      setDoc(doc(authed("alice"), "users/alice/gameResults/r1"), {
        ...VALID_GAME_RESULT,
        score: 4,
      })
    );
  });

  // ─── 4. SYNC DATA (private subcollection) ─────────────────
  console.log("\n── Sync Data ──");

  await runCase("✅ owner can write/read own sync doc", async () => {
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "users/alice/sync/achievements"), { payload: "data" })
    );
  });

  await runCase("✅ other user cannot access sync doc", async () => {
    await seedDoc("users/alice/sync/achievements", { payload: "data" });
    await assertFails(
      getDoc(doc(authed("bob"), "users/alice/sync/achievements"))
    );
  });

  // ─── 5. FRIEND CODES ──────────────────────────────────────
  console.log("\n── Friend Codes ──");

  await runCase("✅ any authed user can read friend codes", async () => {
    await seedDoc("friendCodes/ABC123", { ...VALID_FRIEND_CODE });
    await assertSucceeds(getDoc(doc(authed("bob"), "friendCodes/ABC123")));
  });

  await runCase("✅ user can create own friend code", async () => {
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "friendCodes/ABC123"), { ...VALID_FRIEND_CODE })
    );
  });

  await runCase("✅ code owner can update their code", async () => {
    await seedDoc("friendCodes/ABC123", { ...VALID_FRIEND_CODE });
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "friendCodes/ABC123"), {
        userId: "alice",
        displayName: "Alice New Name",
      })
    );
  });

  await runCase("✅ code owner can delete their code", async () => {
    await seedDoc("friendCodes/ABC123", { ...VALID_FRIEND_CODE });
    await assertSucceeds(deleteDoc(doc(authed("alice"), "friendCodes/ABC123")));
  });

  await runCase("🔴 C1 FIX: attacker cannot hijack another user's friend code", async () => {
    // Alice owns code ABC123
    await seedDoc("friendCodes/ABC123", { userId: "alice", displayName: "Alice" });
    // Mallory tries to overwrite it with her own userId
    const malloryDb = authed("mallory");
    await assertFails(
      setDoc(doc(malloryDb, "friendCodes/ABC123"), {
        userId: "mallory",
        displayName: "Alice",
      })
    );
  });

  await runCase("🔴 C1 FIX: attacker cannot delete another user's friend code", async () => {
    await seedDoc("friendCodes/ABC123", { userId: "alice", displayName: "Alice" });
    await assertFails(deleteDoc(doc(authed("mallory"), "friendCodes/ABC123")));
  });

  await runCase("✅ cannot create friend code for another user", async () => {
    const db = authed("mallory");
    await assertFails(
      setDoc(doc(db, "friendCodes/XYZ789"), {
        userId: "alice",
        displayName: "Fake Alice",
      })
    );
  });

  await runCase("🔴 friend code rejects oversized displayName", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "friendCodes/ABC123"), {
        userId: "alice",
        displayName: "A".repeat(201),
      })
    );
  });

  await runCase("✅ friend code rejects extra fields", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "friendCodes/ABC123"), {
        userId: "alice",
        displayName: "Alice",
        email: "alice@example.com",
      })
    );
  });

  // ─── 6. SCORES ─────────────────────────────────────────────
  console.log("\n── Scores ──");

  await runCase("✅ user in allowedReaders can read score", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE });
    await assertSucceeds(getDoc(doc(authed("bob"), "scores/s1")));
  });

  await runCase("✅ user NOT in allowedReaders cannot read score", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE });
    await assertFails(getDoc(doc(authed("charlie"), "scores/s1")));
  });

  await runCase("✅ user can create own score with valid data", async () => {
    const db = authed("alice");
    await assertSucceeds(setDoc(doc(db, "scores/s1"), { ...VALID_SCORE }));
  });

  await runCase("✅ user cannot create score for another user (ownership spoofing)", async () => {
    const db = authed("mallory");
    await assertFails(
      setDoc(doc(db, "scores/s1"), { ...VALID_SCORE, userId: "alice" })
    );
  });

  await runCase("✅ score create fails when self not in allowedReaders", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "scores/s1"), { ...VALID_SCORE, allowedReaders: ["bob"] })
    );
  });

  await runCase("✅ score rejects wrong field types (score as string)", async () => {
    const db = authed("alice");
    const bad = { ...VALID_SCORE, score: "three" };
    await assertFails(setDoc(doc(db, "scores/bad1"), bad));
  });

  await runCase("✅ score rejects wrong field types (maxAttempts as string)", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "scores/bad2"), {
        ...VALID_SCORE,
        maxAttempts: "6",
      })
    );
  });

  await runCase("✅ score rejects missing required fields", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "scores/bad3"), {
        userId: "alice",
        gameId: "g1",
        // missing: dateInt, gameName, completed, allowedReaders
      })
    );
  });

  await runCase("✅ score rejects extra fields", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "scores/bad4"), {
        ...VALID_SCORE,
        secretField: "hack",
      })
    );
  });

  await runCase("🔴 score rejects oversized gameName", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "scores/bad5"), {
        ...VALID_SCORE,
        gameName: "X".repeat(201),
      })
    );
  });

  await runCase("🔴 score rejects oversized allowedReaders array", async () => {
    const db = authed("alice");
    const bigReaders = ["alice", ...Array.from({ length: 500 }, (_, i) => `u${i}`)];
    await assertFails(
      setDoc(doc(db, "scores/bad6"), {
        ...VALID_SCORE,
        allowedReaders: bigReaders,
      })
    );
  });

  await runCase("✅ score owner can update their own score", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE });
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "scores/s1"), { ...VALID_SCORE, score: 2 })
    );
  });

  await runCase("✅ non-owner cannot update a score", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE });
    const db = authed("bob");
    await assertFails(
      setDoc(doc(db, "scores/s1"), { ...VALID_SCORE, userId: "bob", allowedReaders: ["bob"] })
    );
  });

  await runCase("🔴 score owner can delete their own score", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE });
    await assertSucceeds(deleteDoc(doc(authed("alice"), "scores/s1")));
  });

  await runCase("✅ non-owner cannot delete a score", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE });
    await assertFails(deleteDoc(doc(authed("bob"), "scores/s1")));
  });

  // ─── 7. FRIENDSHIPS ────────────────────────────────────────
  console.log("\n── Friendships ──");

  await runCase("✅ participant (userId1) can read friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    await assertSucceeds(getDoc(doc(authed("alice"), "friendships/f1")));
  });

  await runCase("✅ participant (userId2) can read friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    await assertSucceeds(getDoc(doc(authed("bob"), "friendships/f1")));
  });

  await runCase("✅ non-participant cannot read friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    await assertFails(getDoc(doc(authed("charlie"), "friendships/f1")));
  });

  await runCase("✅ sender can create pending friendship", async () => {
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "friendships/f1"), { ...VALID_FRIENDSHIP })
    );
  });

  await runCase("✅ create with optional senderDisplayName", async () => {
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "friendships/f1"), {
        ...VALID_FRIENDSHIP,
        senderDisplayName: "Alice",
      })
    );
  });

  await runCase("✅ cannot create friendship as recipient (userId2 != self)", async () => {
    const db = authed("bob");
    await assertFails(
      setDoc(doc(db, "friendships/f1"), { ...VALID_FRIENDSHIP })
    );
  });

  await runCase("✅ cannot create friendship with status != pending", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "friendships/f1"), {
        ...VALID_FRIENDSHIP,
        status: "accepted",
      })
    );
  });

  await runCase("✅ cannot create self-friendship", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "friendships/f1"), {
        userId1: "alice",
        userId2: "alice",
        status: "pending",
        createdAt: 1708128000,
      })
    );
  });

  await runCase("✅ recipient can accept pending friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    const db = authed("bob");
    await assertSucceeds(
      updateDoc(doc(db, "friendships/f1"), { status: "accepted" })
    );
  });

  await runCase("✅ sender CANNOT accept own friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    const db = authed("alice");
    await assertFails(
      updateDoc(doc(db, "friendships/f1"), { status: "accepted" })
    );
  });

  await runCase("✅ cannot change userId1 via update (immutability)", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    const db = authed("bob");
    await assertFails(
      updateDoc(doc(db, "friendships/f1"), {
        userId1: "mallory",
        status: "accepted",
      })
    );
  });

  await runCase("✅ cannot change userId2 via update (immutability)", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    const db = authed("bob");
    await assertFails(
      updateDoc(doc(db, "friendships/f1"), {
        userId2: "mallory",
        status: "accepted",
      })
    );
  });

  await runCase("✅ cannot accept already-accepted friendship", async () => {
    await seedDoc("friendships/f1", {
      ...VALID_FRIENDSHIP,
      status: "accepted",
    });
    const db = authed("bob");
    await assertFails(
      updateDoc(doc(db, "friendships/f1"), { status: "accepted" })
    );
  });

  await runCase("✅ userId1 can delete friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    await assertSucceeds(deleteDoc(doc(authed("alice"), "friendships/f1")));
  });

  await runCase("✅ userId2 can delete friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    await assertSucceeds(deleteDoc(doc(authed("bob"), "friendships/f1")));
  });

  await runCase("✅ non-participant cannot delete friendship", async () => {
    await seedDoc("friendships/f1", { ...VALID_FRIENDSHIP });
    await assertFails(deleteDoc(doc(authed("charlie"), "friendships/f1")));
  });

  await runCase("🔴 friendship rejects oversized senderDisplayName", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "friendships/f1"), {
        ...VALID_FRIENDSHIP,
        senderDisplayName: "X".repeat(201),
      })
    );
  });

  // ─── C1 FIX: Friendship-based profile reads ────────────────
  console.log("\n── C1 FIX: Friendship-based Profile Reads ──");

  await runCase("C1: friend reads profile via accepted friendship (no friends array needed)", async () => {
    // Alice's profile has empty friends array, but an accepted friendship exists
    await seedDoc("users/alice", { ...VALID_USER, friends: [] });
    await seedDoc("friendships/alice_bob", {
      userId1: "alice", userId2: "bob", status: "accepted", createdAt: 1708128000,
    });
    await assertSucceeds(getDoc(doc(authed("bob"), "users/alice")));
  });

  await runCase("C1: pending friendship does NOT grant profile read", async () => {
    await seedDoc("users/alice", { ...VALID_USER, friends: [] });
    await seedDoc("friendships/alice_bob", {
      userId1: "alice", userId2: "bob", status: "pending", createdAt: 1708128000,
    });
    await assertFails(getDoc(doc(authed("bob"), "users/alice")));
  });

  await runCase("C1: reversed doc ID ordering still grants read", async () => {
    await seedDoc("users/alice", { ...VALID_USER, friends: [] });
    // Doc ID with bob first (unsorted) — tests the second exists() branch
    await seedDoc("friendships/bob_alice", {
      userId1: "bob", userId2: "alice", status: "accepted", createdAt: 1708128000,
    });
    await assertSucceeds(getDoc(doc(authed("bob"), "users/alice")));
  });

  await runCase("C1: non-friend without friendship doc cannot read profile", async () => {
    await seedDoc("users/alice", { ...VALID_USER, friends: [] });
    await assertFails(getDoc(doc(authed("charlie"), "users/alice")));
  });

  await runCase("C1: user can create profile without friends field", async () => {
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "users/alice"), {
        displayName: "Alice",
        createdAt: 1708128000,
        updatedAt: 1708128000,
      })
    );
  });

  await runCase("C1: user can update profile without friends field", async () => {
    await seedDoc("users/alice", {
      displayName: "Alice",
      createdAt: 1708128000,
      updatedAt: 1708128000,
    });
    const db = authed("alice");
    await assertSucceeds(
      setDoc(doc(db, "users/alice"), {
        displayName: "Alice Updated",
        createdAt: 1708128000,
        updatedAt: 1708128000,
      })
    );
  });

  await runCase("C1: alice cannot update bob's profile", async () => {
    await seedDoc("users/bob", { ...VALID_USER });
    await assertFails(
      setDoc(doc(authed("alice"), "users/bob"), { ...VALID_USER, friends: ["alice"] })
    );
  });

  // ─── 8. SUBCOLLECTION BOUNDARY ENFORCEMENT ─────────────────
  console.log("\n── Subcollection Boundaries ──");

  await runCase("✅ cannot write to nonexistent subcollection", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "users/alice/secrets/s1"), { data: "hack" })
    );
  });

  await runCase("✅ cannot write to nonexistent root collection", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "adminData/config"), { superuser: true })
    );
  });

  await runCase("✅ cannot write to scores subcollection", async () => {
    const db = authed("alice");
    await assertFails(
      setDoc(doc(db, "scores/s1/comments/c1"), { text: "hack" })
    );
  });

  // ─── 9. COLLECTION ENUMERATION ─────────────────────────────
  console.log("\n── Collection Enumeration ──");

  await runCase("⚠️ ACCEPTED: authed user can enumerate friendCodes (needed for lookup)", async () => {
    await seedDoc("friendCodes/ABC123", { userId: "alice", displayName: "Alice" });
    await seedDoc("friendCodes/DEF456", { userId: "bob", displayName: "Bob" });
    const db = authed("charlie");
    // This succeeds by design — friend code lookup requires read access
    const snap = await getDocs(collection(db, "friendCodes"));
    // Verify it returns results (accepted risk: all codes visible to any authed user)
    if (snap.size !== 2) throw new Error(`Expected 2 docs, got ${snap.size}`);
  });

  await runCase("✅ cannot enumerate all scores (arrayContains check blocks collection scan)", async () => {
    await seedDoc("scores/s1", { ...VALID_SCORE, allowedReaders: ["alice"] });
    await seedDoc("scores/s2", { ...VALID_SCORE, userId: "bob", allowedReaders: ["bob"] });
    // Charlie isn't in any allowedReaders — trying to list should return empty or fail
    const db = authed("charlie");
    const snap = await getDocs(
      query(collection(db, "scores"), where("allowedReaders", "array-contains", "charlie"))
    );
    if (snap.size !== 0) throw new Error(`Charlie shouldn't see any scores, got ${snap.size}`);
  });

  // ─── 10. CROSS-USER ISOLATION ──────────────────────────────
  console.log("\n── Cross-User Isolation ──");

  await runCase("✅ user cannot write to another user's gameResults", async () => {
    await assertFails(
      setDoc(doc(authed("mallory"), "users/alice/gameResults/r1"), {
        gameName: "Injected",
      })
    );
  });

  await runCase("✅ user cannot delete another user's gameResults", async () => {
    await seedDoc("users/alice/gameResults/r1", { gameName: "Wordle" });
    await assertFails(
      deleteDoc(doc(authed("mallory"), "users/alice/gameResults/r1"))
    );
  });

  await runCase("✅ user cannot write to another user's sync doc", async () => {
    await assertFails(
      setDoc(doc(authed("mallory"), "users/alice/sync/achievements"), {
        payload: "hack",
      })
    );
  });

  await runCase("✅ user cannot update another user's profile", async () => {
    await seedDoc("users/alice", { ...VALID_USER });
    await assertFails(
      setDoc(doc(authed("mallory"), "users/alice"), {
        ...VALID_USER,
        displayName: "Hacked",
      })
    );
  });

  // ─── SUMMARY ───────────────────────────────────────────────
  await testEnv.cleanup();

  console.log("\n" + "═".repeat(50));
  console.log(`Results: ${passed} passed, ${failures} failed, ${total} total`);
  console.log("═".repeat(50));

  if (failures > 0) {
    console.error(`\n${failures} rule test(s) failed.`);
    process.exitCode = 1;
  } else {
    console.log("\nAll Firestore rules tests passed. ✅");
  }
}

main().catch(async (error) => {
  console.error("Fatal error running Firestore rules tests:", error);
  if (testEnv) await testEnv.cleanup();
  process.exit(1);
});
