// Self-check for pi-extensions/agent-memory.ts ordering:
//   node --experimental-strip-types agent-memory.test.ts
import assert from "node:assert/strict";
import { MIN_QUERY_WORDS, MIN_SIMILARITY, mergeHits, wordCount } from "./agent-memory.ts";

const hit = (id: string, project: string, score?: number) => ({
  memory: { content: id, content_hash: id, tags: [`project:${project}`] },
  similarity_score: score,
});
const ids = (hs: { memory: { content_hash: string } }[]) => hs.map((h) => h.memory.content_hash);

// own project first, in by-tag (newest-first) order, ahead of a better-scoring stranger
assert.deepEqual(
  ids(mergeHits([hit("p1", "ws/pgesq"), hit("p2", "ws/pgesq")], [hit("x", "ws/postgres/xtc", 0.9)], "ws/pgesq", 10)),
  ["p1", "p2", "x"],
);
// below-threshold relevance hits dropped (the "please continue" case)
assert.deepEqual(ids(mergeHits([], [hit("noise", "ws/postgres/xtc", 0.64)], "ws/pgesq", 10)), []);
// near projects (parent/child) outrank far ones at any score, original order kept within a group
assert.deepEqual(
  ids(
    mergeHits(
      [],
      [hit("far", "ws/libxtc", 0.9), hit("child", "ws/postgres/xtc", 0.75), hit("parent", "ws", 0.72)],
      "ws/postgres",
      10,
    ),
  ),
  ["child", "parent", "far"],
);
// not a prefix match on names: ws/postgres-x is not near ws/postgres
assert.deepEqual(
  ids(mergeHits([], [hit("a", "ws/libdb", 0.8), hit("b", "ws/postgres-x", 0.8)], "ws/postgres", 10)),
  ["a", "b"],
);
// dedupe across the two lists, and the cap
assert.deepEqual(ids(mergeHits([hit("p1", "ws/a")], [hit("p1", "ws/a", 0.9), hit("q", "ws/b", 0.9)], "ws/a", 10)), [
  "p1",
  "q",
]);
assert.equal(mergeHits([hit("1", "a"), hit("2", "a"), hit("3", "a")], [], "a", 2).length, 2);
// short prompts skip the search
assert.ok(wordCount("please continue") < MIN_QUERY_WORDS);
assert.ok(wordCount("rebase the cf branch on origin/master") >= MIN_QUERY_WORDS);
assert.ok(MIN_SIMILARITY > 0.65 && MIN_SIMILARITY < 0.73);
console.log("agent-memory ordering: ok");
