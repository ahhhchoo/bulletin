# bulletin
Journal for you and your close friends

## Setting up the iOS app on a new machine

1. Install XcodeGen (`brew install xcodegen`), then from `ios/` run `xcodegen generate`. Run it again whenever you add a file or change `ios/project.yml`.
2. **Add `GoogleService-Info.plist`.** It is not in git (it's in `.gitignore`), and **the app crashes at launch without it.**
   Download it from the Firebase console: project `bulletin-1f0cf` > Project settings (gear) > Your apps > the iOS app (`com.bananalab.bulletin`) > `GoogleService-Info.plist`. Put it in `ios/Bulletin/`.
3. Open `ios/Bulletin.xcodeproj` and run.

### Notes
- Bundle ID: `com.bananalab.bulletin`. It can never change once the app is published.
- Phone sign-in in the simulator only works with the fake test numbers set in the Firebase console (Authentication > Sign-in method > Phone > Phone numbers for testing).
- Firebase must be configured in the app delegate (`ios/Bulletin/AppDelegate.swift`), not in `App.init`, or phone sign-in fails with "notification not forwarded".
- Photos and GIFs: see `docs/media.md`.

### Backend (Firebase)
- Rules live in `backend/` (`firestore.rules`, `storage.rules`). **Rules are not live until you deploy them.** With everything closed by default, the app can't read or write anything until you do.
- Deploy: `cd backend && npx firebase-tools login` (once), then `npx firebase-tools deploy --only firestore:rules,storage`. Re-run it after any change to a `.rules` file.
- Data layout: `users/{uid}` (private: name, birthday), `profiles/{uid}` (public: username, photo), `usernames/{name}` (makes names unique), `posts/{id}` (a post: owner, month, day, text, and the paths of its pictures in Storage), `prompts/{yyyy-MM}` (the month's question).
- `boards/{uid}_{yyyy-MM}` (one per month): what you are into that month, and once sealed its title, cover and numbers. **A sealed month can't gain or change posts** (the rules enforce it); deleting is still allowed.
- Pictures live in Storage under `posts/{uid}/` and `avatars/{uid}/`, named by a fingerprint of the file, so they never change and phones keep them forever (see `docs/media.md`).

### Testing other dates
Launch with `-today 2027-03-02` (debug builds) to see the app on another day. The board follows the real calendar: when a month ends, the app asks you to name it and seal it onto the Shelf the next time it opens.
**Careful:** sealing is real, even in a test. Sealing a month locks it on the server. Test with a future month (a month you aren't really using), not the current one.
