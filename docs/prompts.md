# Monthly prompts

One question per month, the same for every user, written by hand. They are questions (not themes) so a friend's
answer is something you can compare with your own.

## Where they live
- **In the app:** `ios/Bulletin/Models/PromptCalendar.swift` holds the list, keyed by month (`2026-12`). It is always
  available, even offline. If a month has no entry, the app uses "What's been on your mind?"
- **To change one without an app update:** in the Firebase console, add a document to the `prompts` collection named for
  the month (for example `2026-12`) with a `text` field. The app picks it up and uses it instead of the bundled one.
  Nobody can write prompts from the app itself (see `backend/firestore.rules`; **re-deploy the rules** after changing them).

## The list (December 2026 to September 2028)
| Month | Prompt |
|---|---|
| Nov 2026 | What made you smile |
| Dec 2026 | What's something you'd like to remember? |
| Jan 2027 | What are you looking forward to? |
| Feb 2027 | What's the smallest good thing that happened? |
| Mar 2027 | What have you been putting off? |
| Apr 2027 | What did you make? |
| May 2027 | What's your favorite spot right now? |
| Jun 2027 | What would you do with an extra day? |
| Jul 2027 | What's the best thing you ate? |
| Aug 2027 | What did you do just for fun? |
| Sep 2027 | What did you learn lately? |
| Oct 2027 | What felt a little strange? |
| Nov 2027 | Who are you thankful for? |
| Dec 2027 | What are you proud of lately? |
| Jan 2028 | What would you tell yourself a month ago? |
| Feb 2028 | What are you reading or watching? |
| Mar 2028 | What's a small thing that's been bugging you? |
| Apr 2028 | What are you obsessed with? |
| May 2028 | What did your morning look like? |
| Jun 2028 | What are you listening to on repeat? |
| Jul 2028 | What's in your bag right now? |
| Aug 2028 | What surprised you? |
| Sep 2028 | What's been on your mind? |

**The list runs out after September 2028.** Write more before then.

## Not picked (kept in case you want them later)
What changed this month? / Who made your day better? / Who do you miss? / Who made you laugh? /
What's the best thing a friend said? / What's the best thing you saw? / Where did you wander? /
What does a perfect afternoon look like?
