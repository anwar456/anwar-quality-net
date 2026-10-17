import { describe, expect, it } from "vitest";
import { formatSkillCode } from "./skillCode";

describe("formatSkillCode", () => {
  it("shows a taxonomy id exactly as stored, without a second SK- prefix", () => {
    expect(formatSkillCode("SK-ENG-001")).toBe("SK-ENG-001");
  });

  it("pads an older numeric id", () => {
    expect(formatSkillCode(7)).toBe("SK-007");
    expect(formatSkillCode("42")).toBe("SK-042");
  });

  it("shows nothing for a missing id", () => {
    expect(formatSkillCode(undefined)).toBe("");
    expect(formatSkillCode(null)).toBe("");
    expect(formatSkillCode("")).toBe("");
  });
});
