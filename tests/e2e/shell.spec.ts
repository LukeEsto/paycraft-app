import { expect, test } from "@playwright/test";

test("renders the PayCraft feasibility shell", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "Clear quotes. Clear decisions." })).toBeVisible();
  await expect(page.getByText("Payments are simulated.")).toBeVisible();
});

test("does not expose acceptance controls for an invalid public capability", async ({ page }) => {
  await page.goto("/q/not-a-valid-capability");
  await expect(page.getByRole("heading", { name: "This quote link is unavailable" })).toBeVisible();
  await expect(page.getByRole("button", { name: /accept quote/i })).toHaveCount(0);
});
