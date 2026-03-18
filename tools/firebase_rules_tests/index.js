const fs = require("fs");
const path = require("path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  getFirestore,
  doc,
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const {
  getStorage,
  ref,
  uploadBytes,
  deleteObject,
  getDownloadURL,
} = require("firebase/storage");

const rulesPath = (name) =>
  fs.readFileSync(path.resolve(__dirname, "..", "..", name), "utf8");

const now = () => new Date();

(async () => {
  const testEnv = await initializeTestEnvironment({
    projectId: "rules-tests",
    firestore: {
      rules: rulesPath("firestore.rules"),
    },
    storage: {
      rules: rulesPath("storage.rules"),
    },
  });

  try {
    await testEnv.clearFirestore();

    const alice = testEnv.authenticatedContext("alice");
    const bob = testEnv.authenticatedContext("bob");
    const unauth = testEnv.unauthenticatedContext();

    const aliceDb = getFirestore(alice.app);
    const bobDb = getFirestore(bob.app);
    const unauthDb = getFirestore(unauth.app);

    // Posts: unauthenticated create should fail
    await assertFails(
      setDoc(doc(unauthDb, "posts/post1"), {
        authorId: "alice",
        authorName: "Alice",
        content: "Hello",
        imageUrls: [],
        createdAt: now(),
        updatedAt: now(),
      }),
    );

    // Posts: authenticated create with author mismatch should fail
    await assertFails(
      setDoc(doc(bobDb, "posts/post2"), {
        authorId: "alice",
        authorName: "Alice",
        content: "Hello",
        imageUrls: ["https://example.com/x.jpg"],
        createdAt: now(),
        updatedAt: now(),
      }),
    );

    // Posts: image-only post should succeed for owner
    await assertSucceeds(
      setDoc(doc(aliceDb, "posts/post3"), {
        authorId: "alice",
        authorName: "Alice",
        content: "",
        imageUrls: ["https://example.com/x.jpg"],
        createdAt: now(),
        updatedAt: now(),
        talent: null,
      }),
    );

    // Posts: cannot change authorId
    await assertFails(
      updateDoc(doc(aliceDb, "posts/post3"), {
        authorId: "bob",
      }),
    );

    // Comments: valid create should succeed
    await assertSucceeds(
      setDoc(doc(aliceDb, "comments/comment1"), {
        authorId: "alice",
        content: "Nice",
        postId: "post3",
        createdAt: now(),
      }),
    );

    // Conversations: create requires 2 participants including caller
    await assertSucceeds(
      setDoc(doc(aliceDb, "conversations/conv1"), {
        participantIds: ["alice", "bob"],
        createdAt: now(),
      }),
    );

    // Conversations: cannot change participants
    await assertFails(
      updateDoc(doc(aliceDb, "conversations/conv1"), {
        participantIds: ["alice", "charlie"],
      }),
    );

    // Notifications: user cannot create for another user
    await assertFails(
      setDoc(doc(bobDb, "notifications/alice/userNotifications/notify1"), {
        title: "Hi",
        createdAt: now(),
      }),
    );

    // Storage: public read, owner write
    const aliceStorage = getStorage(alice.app);
    const bobStorage = getStorage(bob.app);
    const unauthStorage = getStorage(unauth.app);

    const data = new Uint8Array([1, 2, 3, 4]);
    const aliceFile = ref(aliceStorage, "posts/alice/test.jpg");

    await assertSucceeds(uploadBytes(aliceFile, data));
    await assertFails(uploadBytes(ref(bobStorage, "posts/alice/evil.jpg"), data));
    await assertFails(
      uploadBytes(ref(unauthStorage, "posts/alice/anon.jpg"), data),
    );

    await assertSucceeds(getDownloadURL(ref(unauthStorage, "posts/alice/test.jpg")));
    await assertFails(deleteObject(ref(bobStorage, "posts/alice/test.jpg")));
    await assertSucceeds(deleteObject(ref(aliceStorage, "posts/alice/test.jpg")));

    console.log("Firebase rules verification passed.");
  } finally {
    await testEnv.cleanup();
  }
})().catch((error) => {
  console.error("Firebase rules verification failed:", error);
  process.exit(1);
});
