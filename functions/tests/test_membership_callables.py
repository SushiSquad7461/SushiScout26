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
            main.create_team.__wrapped__.__wrapped__(_req(None, {'name': '254'}))

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

        result = main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': '254'}))

        # The caller's claim must include the new team as admin.
        mock_claims.assert_called_once_with('uid1', {'team_new': 'admin'})
        self.assertEqual(result['teamId'], 'team_new')
        self.assertEqual(result['inviteCode'], 'ABC123')

    def test_rejects_non_numeric_name(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': 'Alpha'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_rejects_too_long_name(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': '123456'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_rejects_leading_zero_name(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': '00042'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_rejects_empty_name(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': ''}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_rejects_unicode_digit_name(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': '2٥5'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_rejects_non_string_name(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            main.create_team.__wrapped__.__wrapped__(_req('uid1', {'name': ['254']}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)


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
        team_ref.get.return_value = Mock(exists=True, **{'to_dict.return_value': {'memberCount': 2}})
        member_snap = Mock(exists=True)
        member_snap.to_dict.return_value = {'role': 'admin'}
        team_ref.collection.return_value.document.return_value.get.return_value = member_snap
        # Only one admin in the members subcollection -> leaving is blocked,
        # even though memberCount (2) would have passed the old buggy check.
        admin_doc = Mock()
        team_ref.collection.return_value.where.return_value.get.return_value = [admin_doc]
        db.collection.return_value.document.return_value = team_ref

        with self.assertRaises(https_fn.HttpsError):
            main.leave_team.__wrapped__.__wrapped__(_req('uid1', {'teamId': 'team_x'}))
        mock_claims.assert_not_called()

    @patch('main._set_team_claims')
    @patch('main.get_db')
    def test_non_last_admin_can_leave(self, mock_db, mock_claims):
        db = mock_db.return_value
        team_ref = MagicMock()
        team_ref.get.return_value = Mock(exists=True, **{'to_dict.return_value': {'memberCount': 2}})
        member_snap = Mock(exists=True)
        member_snap.to_dict.return_value = {'role': 'admin'}
        team_ref.collection.return_value.document.return_value.get.return_value = member_snap
        # Two admins in the members subcollection -> this admin may leave.
        team_ref.collection.return_value.where.return_value.get.return_value = [Mock(), Mock()]
        db.collection.return_value.document.return_value = team_ref

        result = main.leave_team.__wrapped__.__wrapped__(_req('uid1', {'teamId': 'team_x'}))
        self.assertTrue(result['success'])
        mock_claims.assert_called_once()


class TestSetTeamClaims(unittest.TestCase):
    @patch('main.fb_auth')
    def test_wraps_memberships_under_teams_key(self, mock_fb_auth):
        main._set_team_claims('uid1', {'teamA': 'admin'})
        mock_fb_auth.set_custom_user_claims.assert_called_once_with(
            'uid1', {'teams': {'teamA': 'admin'}}
        )


class TestGenerateInviteCode(unittest.TestCase):
    def test_returns_eight_char_code_from_expected_charset(self):
        charset = set('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')
        for _ in range(50):
            code = main._generate_invite_code()
            self.assertEqual(len(code), 8)
            self.assertTrue(set(code).issubset(charset))



class TestRegenerateInviteCode(unittest.TestCase):
    """Invite rotation moved server-side: it used to be a client transaction
    whose only check was `createdBy == uid`, on a field the same client could
    rewrite (rules allowed any member to update the whole team doc)."""

    def setUp(self):
        main._db = None

    @staticmethod
    def _req_with_claim(uid, teams, data):
        r = Mock()
        if uid:
            r.auth = Mock(uid=uid)
            r.auth.token = {'teams': teams}
        else:
            r.auth = None
        r.data = data
        return r

    def _call(self, req):
        return main.regenerate_invite_code.__wrapped__.__wrapped__(req)

    def test_unauthenticated_raises(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(self._req_with_claim(None, {}, {'teamId': 't1'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.UNAUTHENTICATED)

    def test_missing_team_id_raises(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(self._req_with_claim('u1', {'t1': 'admin'}, {}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.INVALID_ARGUMENT)

    def test_plain_member_is_denied(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(self._req_with_claim('u1', {'t1': 'member'}, {'teamId': 't1'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.PERMISSION_DENIED)

    def test_admin_of_another_team_is_denied(self):
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(self._req_with_claim('u1', {'other': 'admin'}, {'teamId': 't1'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.PERMISSION_DENIED)

    @patch('main.get_db')
    def test_missing_team_raises_not_found(self, mock_db):
        team_ref = MagicMock()
        team_ref.get.return_value = Mock(exists=False)
        mock_db.return_value.collection.return_value.document.return_value = team_ref
        with self.assertRaises(https_fn.HttpsError) as cm:
            self._call(self._req_with_claim('u1', {'t1': 'admin'}, {'teamId': 't1'}))
        self.assertEqual(cm.exception.code,
                         https_fn.FunctionsErrorCode.NOT_FOUND)

    @patch('main.get_db')
    def test_admin_rotates_code_with_server_generated_value(self, mock_db):
        db = mock_db.return_value
        team_ref = MagicMock()
        team_ref.get.return_value = Mock(exists=True)
        db.collection.return_value.document.return_value = team_ref
        # No collision on the first generated code.
        db.collection.return_value.where.return_value.limit.return_value.get.return_value = []

        result = self._call(
            self._req_with_claim('u1', {'t1': 'admin'}, {'teamId': 't1'}))

        new_code = result['inviteCode']
        # Server charset and length, not the client's 6-char dart:math code.
        self.assertEqual(len(new_code), 8)
        self.assertTrue(set(new_code).issubset(set('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789')))
        team_ref.update.assert_called_once()
        self.assertEqual(team_ref.update.call_args[0][0]['inviteCode'], new_code)

    @patch('main.get_db')
    def test_retries_until_code_is_unique(self, mock_db):
        db = mock_db.return_value
        team_ref = MagicMock()
        team_ref.get.return_value = Mock(exists=True)
        db.collection.return_value.document.return_value = team_ref
        # First candidate collides with an existing team, second is free.
        db.collection.return_value.where.return_value.limit.return_value.get.side_effect = [
            [Mock()], []
        ]

        result = self._call(
            self._req_with_claim('u1', {'t1': 'admin'}, {'teamId': 't1'}))
        self.assertEqual(len(result['inviteCode']), 8)



if __name__ == '__main__':
    unittest.main()
