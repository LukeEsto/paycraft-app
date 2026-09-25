import { describe, expect, it } from "vitest";
import { MockNotificationProvider } from "@/lib/notifications/mock-notification-provider";

describe("MockNotificationProvider", () => {
  it("captures a message without contacting an external service", async () => {
    const provider = new MockNotificationProvider();
    const result = await provider.send({
      to: "customer@example.test",
      subject: "Your PayCraft quote",
      text: "https://example.test/q/development-token",
    });

    expect(result.messageId).toBeTruthy();
    expect(provider.outbox()).toHaveLength(1);
    expect(provider.outbox()[0].to).toBe("customer@example.test");
  });
});
