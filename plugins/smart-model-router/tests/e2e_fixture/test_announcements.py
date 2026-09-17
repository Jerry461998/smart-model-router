import unittest

from announcements import AnnouncementService


class AnnouncementBehaviorTests(unittest.TestCase):
    def test_each_user_confirms_each_announcement_once(self):
        service = AnnouncementService()
        service.publish("a1", "First")
        self.assertTrue(service.should_show("u1", "a1"))
        self.assertTrue(service.should_show("u2", "a1"))
        service.confirm("u1", "a1")
        self.assertFalse(service.should_show("u1", "a1"))
        self.assertTrue(service.should_show("u2", "a1"))

    def test_new_announcement_is_shown_after_old_one_is_confirmed(self):
        service = AnnouncementService()
        service.publish("a1", "First")
        service.confirm("u1", "a1")
        service.publish("a2", "Second")
        self.assertTrue(service.should_show("u1", "a2"))


if __name__ == "__main__":
    unittest.main()
