"""Auth + input validation on the schedule callables.

Both were public endpoints that never looked at req.auth, unlike every other
callable in this codebase — an anonymous caller could drive Firestore writes
and spend the project's TBA/FIRST API credentials.
"""

import unittest
from unittest.mock import Mock, patch

with patch('firebase_admin.initialize_app'):
    import tba_sync
    import ftc_api

from firebase_functions import https_fn


def _req(authed, data):
    r = Mock()
    r.auth = Mock(uid='u1') if authed else None
    r.data = data
    return r


class TestFetchEventScheduleAuth(unittest.TestCase):
    def _call(self, req):
        return tba_sync.fetch_event_schedule.__wrapped__.__wrapped__(req)

    def test_unauthenticated_is_rejected(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(_req(False, {'eventKey': '2026casj'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.UNAUTHENTICATED)

    def test_missing_event_key_rejected(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(_req(True, {}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_event_key_with_slash_rejected(self):
        # A '/' would redirect the tba_cache write into a subcollection and
        # inject an extra segment into the TBA URL path.
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(_req(True, {'eventKey': '2026casj/../evil'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_auth_is_checked_before_any_firestore_access(self):
        with patch.object(tba_sync, '_get_db') as db:
            with self.assertRaises(https_fn.HttpsError):
                self._call(_req(False, {'eventKey': '2026casj'}))
            db.assert_not_called()


class TestFetchFtcScheduleAuth(unittest.TestCase):
    def _call(self, req):
        return ftc_api.fetch_ftc_schedule.__wrapped__.__wrapped__(req)

    def test_unauthenticated_is_rejected(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(_req(False, {'eventCode': 'USNYEXCL'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.UNAUTHENTICATED)

    def test_event_code_with_slash_rejected(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(_req(True, {'eventCode': 'A/B'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_auth_is_checked_before_any_firestore_access(self):
        with patch.object(ftc_api, '_get_db') as db:
            with self.assertRaises(https_fn.HttpsError):
                self._call(_req(False, {'eventCode': 'USNYEXCL'}))
            db.assert_not_called()


if __name__ == '__main__':
    unittest.main()
