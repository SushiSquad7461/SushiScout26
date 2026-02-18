"""Firestore triggers module."""

from .match_sync import on_match_created, on_match_updated

__all__ = ['on_match_created', 'on_match_updated']
