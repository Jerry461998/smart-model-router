class AnnouncementService:
    """Synthetic announcement behavior used only for router E2E validation."""

    def __init__(self):
        self.announcements = {}
        self.confirmed_users = set()

    def publish(self, announcement_id, text):
        self.announcements[announcement_id] = text

    def should_show(self, user_id, announcement_id):
        return (
            announcement_id in self.announcements
            and (user_id, announcement_id) not in self.confirmed_users
        )

    def confirm(self, user_id, announcement_id):
        if announcement_id not in self.announcements:
            raise KeyError(announcement_id)
        self.confirmed_users.add((user_id, announcement_id))
