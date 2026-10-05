# Pawmate Documentation

Pawmate is a private, self-hostable application for two people. It combines a
Flutter client with a Gin server and currently supports pairing, per-device
sessions, member profiles, and synchronized text chat. Shared home content,
backups, search, calls, and games remain planned features.

Pawmate is designed for two people sharing one private instance. This book
describes the product's current behavior, service boundaries, data rules, and
API contracts. It is reference documentation for readers of the project; the
source code and server README remain the operational references.

Build the book locally from the repository root:

```bash
mdbook build books
mdbook serve books --open
```
