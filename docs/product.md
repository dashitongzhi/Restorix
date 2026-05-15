# Restorix Product Notes

Restorix is a small macOS utility for self-hosted Docker users. It answers one question:

> Are my Docker volumes backed up recently enough that I could restore them?

The MVP intentionally does not perform backups or restores. It scans existing Docker and restic state, generates health status, and prints safe restore commands.

