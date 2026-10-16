import { describe, expect, it } from "vitest";
import { render, screen } from "@testing-library/react";
import ComparisonTable from "./ComparisonTable";
import { sampleOf } from "@/test/openapiSample";
import type { SkillComparison } from "@/types";

// Protects: the web reads the fields the API really sends (audit R-08).
// The response body comes from api/swagger/v1/swagger.yaml, which the API's own request specs keep honest.
describe("ComparisonTable <- FitGapReport contract", () => {
  const row = (patch: Record<string, unknown>) =>
    ({ ...(sampleOf("SkillComparison") as object), skill_label: "Test Skill", ...patch }) as unknown as SkillComparison;

  it("shows the required level and the candidate level of a gap", () => {
    render(<ComparisonTable comparisons={[row({ expected_level: 4, candidate_level: 2, result: "gap", delta: -2 })]} />);

    expect(screen.getByText("L4")).toBeInTheDocument(); // required
    expect(screen.getByText("L2")).toBeInTheDocument(); // candidate
  });

  it("renders a skill that was never assessed without crashing (regression guard)", () => {
    render(<ComparisonTable comparisons={[row({ expected_level: 3, candidate_level: null, result: "not_assessed", delta: null })]} />);

    expect(screen.getByText("Test Skill")).toBeInTheDocument();
    expect(screen.getByText(/not assessed/i)).toBeInTheDocument();
  });
});
