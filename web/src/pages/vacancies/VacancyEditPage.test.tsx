import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter, Route, Routes } from "react-router-dom";

vi.mock("@/services/vacancies", () => ({
  vacanciesApi: { get: vi.fn(), update: vi.fn() },
}));

import { vacanciesApi } from "@/services/vacancies";
import VacancyEditPage from "./VacancyEditPage";

// Protects: a requirement removed from a vacancy is really removed, because fit/gap compares against what is stored (audit R-03).
describe("VacancyEditPage - removing an expected skill", () => {
  beforeEach(() => {
    vi.mocked(vacanciesApi.get).mockResolvedValue({
      data: {
        vacancy: {
          id: 5, role_title: "Senior Engineer", culture_dimensions: "", competency_expectations: "",
          skills: [
            { id: 21, skill_id: "SK-TEST-001", skill_label: "Skill One", expected_level: 3 },
            { id: 22, skill_id: "SK-TEST-002", skill_label: "Skill Two", expected_level: 2 },
          ],
        },
      },
    } as never);
    vi.mocked(vacanciesApi.update).mockResolvedValue({ data: {} } as never);
  });

  it("tells the API to destroy the skill the user removed", async () => {
    const user = userEvent.setup();
    const { container } = render(
      <MemoryRouter initialEntries={["/vacancies/5/edit"]}>
        <Routes>
          <Route path="/vacancies/:id/edit" element={<VacancyEditPage />} />
          <Route path="*" element={<div>saved</div>} />
        </Routes>
      </MemoryRouter>
    );

    await screen.findByText("Skill One");
    // The remove control is an unlabeled icon button inside the first skill card.
    const removeButton = container.querySelector("svg.lucide-x")?.closest("button");
    expect(removeButton).toBeTruthy();
    await user.click(removeButton as HTMLButtonElement);
    expect(screen.queryByText("Skill One")).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /save changes/i }));

    await waitFor(() => expect(vacanciesApi.update).toHaveBeenCalled());
    const [, payload] = vi.mocked(vacanciesApi.update).mock.calls[0];
    expect(payload.vacancy_skills_attributes).toEqual(
      expect.arrayContaining([expect.objectContaining({ id: 21, _destroy: true })])
    );
  });
});
