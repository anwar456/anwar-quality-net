import { describe, expect, it } from "vitest";
import { withDestroyed } from "./nestedAttributes";

type Row = { id?: number; name?: string };

describe("withDestroyed", () => {
  const original: Row[] = [{ id: 1, name: "a" }, { id: 2, name: "b" }, { id: 3, name: "c" }];

  it("marks every loaded row that is no longer in the form", () => {
    const current: Row[] = [{ id: 2, name: "b" }];
    expect(withDestroyed(original, current)).toEqual([
      { id: 2, name: "b" },
      { id: 1, _destroy: true },
      { id: 3, _destroy: true },
    ]);
  });

  it("changes nothing when no row was removed", () => {
    expect(withDestroyed(original, original)).toEqual(original);
  });

  it("keeps rows that were added in the form (no id) and never destroys them", () => {
    const current: Row[] = [{ id: 1, name: "a" }, { name: "new" }];
    const result = withDestroyed(original, current);
    expect(result).toContainEqual({ name: "new" });
    expect(result.filter((r) => "_destroy" in r)).toEqual([{ id: 2, _destroy: true }, { id: 3, _destroy: true }]);
  });

  it("does not invent a destroy marker for loaded rows without an id", () => {
    expect(withDestroyed<Row>([{ name: "unsaved" }], [])).toEqual([]);
  });
});
