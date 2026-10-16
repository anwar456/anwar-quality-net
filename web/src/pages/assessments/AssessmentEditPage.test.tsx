import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";

vi.mock("@/services/assessments", () => ({
  assessmentsApi: { get: vi.fn(), update: vi.fn() },
}));

import { assessmentsApi } from "@/services/assessments";
import AssessmentEditPage from "./AssessmentEditPage";

const anchors = { l1_anchor: "a", l2_anchor: "b", l3_anchor: "c", l4_anchor: "d", l5_anchor: "e" };
const skill = (id: number, label: string, order: number) => ({
  id, skill_id: `SK-TEST-00${id}`, skill_label: label, is_custom: false, expected_level: 3, display_order: order, ...anchors,
});

// Protects: what the assessor sees on the edit form is what gets stored (audit R-03).
// The API removes a nested skill only when it receives { id, _destroy: true }; leaving it out keeps it.
describe("AssessmentEditPage - removing a skill", () => {
  beforeEach(() => {
    vi.mocked(assessmentsApi.get).mockResolvedValue({
      data: { assessment: { id: 7, name: "Backend Engineer", time_limit_min: 30, skills: [skill(11, "Skill One", 0), skill(12, "Skill Two", 1)] } },
    } as never);
    vi.mocked(assessmentsApi.update).mockResolvedValue({ data: {} } as never);
  });

  it("tells the API to destroy the skill the user removed", async () => {
    const user = userEvent.setup();
    render(
      <MemoryRouter initialEntries={["/assessments/7/edit"]}>
        <Routes>
          <Route path="/assessments/:id/edit" element={<AssessmentEditPage />} />
          <Route path="*" element={<div>saved</div>} />
        </Routes>
      </MemoryRouter>
    );

    await screen.findByText("Skill One");
    await user.click(screen.getAllByRole("button", { name: "Remove skill" })[0]);
    expect(screen.queryByText("Skill One")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /save changes/i }));

    await waitFor(() => expect(assessmentsApi.update).toHaveBeenCalled());
    const [, payload] = vi.mocked(assessmentsApi.update).mock.calls[0];
    expect(payload.assessment_skills_attributes).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: 11, _destroy: true })])
    );
    // and the skill that stayed is not destroyed
    expect(payload.assessment_skills_attributes).not.toEqual(
      expect.arrayContaining([expect.objectContaining({ id: 12, _destroy: true })])
    );
  });
});
