export interface NotificationMessage {
  to: string;
  subject: string;
  text: string;
}

export interface NotificationProvider {
  send(message: NotificationMessage): Promise<{ messageId: string }>;
}
