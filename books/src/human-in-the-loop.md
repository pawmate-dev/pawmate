# Working human-in-the-loop

The book proposes implementation steps; it does not replace product or security
decisions. Before starting a chapter, explicitly approve its choices about data
storage, authentication, URL handling, and user experience.

For every chapter:

1. Create a branch, for example `feat/instance-onboarding`.
2. Keep Flutter and Gin changes in the same branch when they change one API
   contract.
3. Add tests with the behavior, not after it.
4. Verify the feature against a real Android emulator and a local server.
5. Review privacy implications before exporting, syncing, or sharing data.

Do not commit a real server URL, passwords, access tokens, chat content, backup
archives, or screenshots containing private messages.
