import { expect, test } from "@playwright/test";

test("renders the PayCraft feasibility shell", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Clear quotes. Clear decisions." })).toBeVisible();
  await expect(page.getByText("Payments are simulated.")).toBeVisible();
});
