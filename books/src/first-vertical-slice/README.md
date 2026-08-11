# First vertical slice: instance onboarding and pairing

The first product feature is not chat. It is the secure path that lets two
people connect the Flutter app to their own server and establish their one
couple relationship.

At the end of this slice, a user can:

1. Enter a Pawmate server URL when launching the app for the first time.
2. Verify that the URL points to a compatible Pawmate instance.
3. Register or sign in.
4. Create a one-time invitation.
5. Let the other person redeem that invitation from the same instance.
6. Enter a minimal shared-home screen once the couple exists.

This chapter is intentionally a vertical slice: it changes the Flutter UI,
server API, persistence, and tests together.
