import "server-only";

import { MockNotificationProvider } from "./mock-notification-provider";
import type { NotificationProvider } from "./types";

export function getNotificationProvider(): NotificationProvider {
  if (process.env.MOCK_SERVICES_ENABLED !== "true") {
    throw new Error("Only the mock notification provider is available in this feasibility build.");
  }

  return new MockNotificationProvider();
}
