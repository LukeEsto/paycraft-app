import type { NotificationMessage, NotificationProvider } from "./types";

export class MockNotificationProvider implements NotificationProvider {
  private readonly messages: Array<NotificationMessage & { id: string; sentAt: Date }> = [];

  async send(message: NotificationMessage): Promise<{ messageId: string }> {
    const id = crypto.randomUUID();
    this.messages.push({ ...message, id, sentAt: new Date() });
    return { messageId: id };
  }

  outbox(): ReadonlyArray<NotificationMessage & { id: string; sentAt: Date }> {
    return this.messages;
  }
}
