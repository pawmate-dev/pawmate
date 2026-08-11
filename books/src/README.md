# Pawmate Implementation Guide

Pawmate is a private, self-hostable application for two people. It combines a
Flutter client with a Gin server and will eventually support messaging, shared
home content, backups, search, calls, and games.

This book turns product decisions into small implementation slices. Each slice
is designed for a human to review before code is written and before a branch is
merged. It deliberately favors a working private instance for one couple over
premature multi-tenant infrastructure.

## How to use this book

1. Read the proposed chapter and decide on its open questions.
2. Create a feature branch yourself.
3. Implement the chapter in small commits.
4. Run the verification checklist.
5. Open a pull request and use the repository template for review.

Build the book locally from the repository root:

```bash
mdbook build books
mdbook serve books --open
```
