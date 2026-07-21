"""Tests for the membership callables: create_team / join_team / leave_team."""

import unittest
from unittest.mock import MagicMock, Mock, patch

with patch('firebase_admin.initialize_app'):
    import main  # noqa: E402

from firebase_functions import https_fn  # noqa: E402


def _req(uid, data):
    r = Mock()
    r.auth = Mock(uid=uid) if uid else None
    r.data = data
    return r


class TestCreateTeam(unittest.TestCase):
    def setUp(self):
        main._db = None

    def test_unauthenticated_raises(self):
        with self.assertRaises(https_fn.HttpsError):
            main.create_team.__wrapped__.__wrapped__(_req(None, {'name': 'Alpha'}))

    @patch('main._set_team_claims')
    @patch('main._generate_invite_code', return_value='ABC123')
    @patch('main.get_db')
    def test_creates_team_and_sets_admin_claim(self, mock_db, mock_code, mock_claims):
        db = mock_db.return_value
        # no invite collision
        db.collection.return_value.where.return_value.limit.return_value.get.return_value = []
        # new team ref with a generated id
        team_ref = MagicMock()
        team_ref.id = 'team_new'
        # user doc has no prior memberships
        user_ref = MagicMock()
        user_ref.get.return_value = Mock(exists=False)
        # route document() calls: teams.document() -> team_ref, users.document(uid) -> user_ref
        db.collection.return_value.document.side_effect = lambda *a: team_ref if not a else user_ref
        db.batch.return_value = MagicMock()

        result = main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': 'Alpha'}))

        # The caller's claim must include the new team as admin.
        mock_claims.assert_called_once_with('uid1', {'team_new': 'admin'})
        self.assertEqual(result['teamId'], 'team_new')
        self.assertEqual(result['inviteCode'], 'ABC123')


class TestJoinTeam(unittest.TestCase):
    def setUp(self):
        main._db = None

    @patch('main._set_team_claims')
    @patch('main.get_db')
    def test_rejects_when_already_member(self, mock_db, mock_claims):
        db = mock_db.return_value
        team_doc = Mock(id='team_x')
        team_doc.to_dict.return_value = {'name': 'X', 'memberCount': 2}
        db.collection.return_value.where.return_value.limit.return_value.get.return_value = [team_doc]
        # member doc already exists -> ALREADY_EXISTS
        db.collection.return_value.document.return_value.collection.return_value.document.return_value.get.return_value = Mock(exists=True)

        with self.assertRaises(https_fn.HttpsError):
            main.join_team.__wrapped__.__wrapped__(_req('uid1', {'inviteCode': 'ABC123'}))
        mock_claims.assert_not_called()

    @patch('main._set_team_claims')
    @patch('main.get_db')
    def test_invalid_code_raises(self, mock_db, mock_claims):
        db = mock_db.return_value
        db.collection.return_value.where.return_value.limit.return_value.get.return_value = []
        with self.assertRaises(https_fn.HttpsError):
            main.join_team.__wrapped__.__wrapped__(_req('uid1', {'inviteCode': 'NOPE00'}))


class TestLeaveTeam(unittest.TestCase):
    def setUp(self):
        main._db = None

    @patch('main._set_team_claims')
    @patch('main.get_db')
    def test_last_admin_cannot_leave(self, mock_db, mock_claims):
        db = mock_db.return_value
        team_ref = MagicMock()
        team_ref.get.return_value = Mock(exists=True, **{'to_dict.return_value': {'memberCount': 1}})
        member_snap = Mock(exists=True)
        member_snap.to_dict.return_value = {'role': 'admin'}
        team_ref.collection.return_value.document.return_value.get.return_value = member_snap
        db.collection.return_value.document.return_value = team_ref

        with self.assertRaises(https_fn.HttpsError):
            main.leave_team.__wrapped__.__wrapped__(_req('uid1', {'teamId': 'team_x'}))
        mock_claims.assert_not_called()


if __name__ == '__main__':
    unittest.main()
