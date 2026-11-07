# Bulletin — product rules and screen map

Working name: **Bulletin**. Last updated Nov 7, 2026.
Prototype: https://claude.ai/artifact/1oVEdpHoRtBQZEHYui9Vu2

---

## The concept

Bulletin sits between a group chat and social media. Everyone gets a **personal bulletin board that resets every month**. You post whatever you want through the month (thoughts, photos, journal entries), and it reads like a journal. At the end of the month the board is sealed and goes onto your shelf, so you can flip back through past months like a stack of zines.

Only a small group can see your board: **a guest list capped at 20 people**. It's not meant to be seen by more. You're not meant to influence or be an influencer. It's about close friends, and the feeling of early Facebook walls, when people posted stream-of-consciousness and didn't worry about what others thought.

## Guiding principles

- **The audience cap is the product.** Nobody performs for strangers.
- **Journal-first, with friends as visitors.** You always land on your own board. Friends show up as notes left on your board and a quiet "doorbell," never as a feed.
- **Months finish.** A feed never ends; a board seals on the 1st.
- **Honest, not curated.** Late additions are marked, sealed months can't be rewritten.
- **Silence is a feature.** Removals, ignored requests, visits and tucked-away notes never notify anyone.
- **No public metrics.** No like counts, no follower counts, no like button.

---

## Rules

### Board and posting
- The board is organized by **day rows**, oldest at top, today at the bottom near the composer. Reads like a diary.
- Items within a day are loose and messy (tilted, overlapping), but days keep the order obvious.
- **Posting works like texting:** type and pin. No compose screen, no captions step. Posts land on today automatically.
- **Pinch out** for a month view (calendar grid, each day shows its first photo or note). Empty days stay blank. No streaks.
- Header shows two cards: **"Currently into"** (personal, set by you) and **the monthly prompt** (shared by everyone).

### Post types
- **V1:** sticky note, photo (one at a time), journal entry (folded note).
- Text over ~280 characters automatically becomes a **folded note**: title + first line on the board, fold lines, and a read time. Opens into a full page in a serif font.
- **Later:** multiple photos, voice notes, links, doodles, and **songs**: link Spotify and pick the song you've had on repeat, shown as a **vinyl record** on the board. Reserve a slot for it in the design.

### Monthly prompt
- **Bulletin writes one global prompt per month** for v1. Later: friend groups can submit or vote on prompts.
- The prompt card shows **your answer's thumbnail** and the day you answered. Tapping it scrolls to and highlights the post.
- If unanswered, the card shows a dashed "+" and tapping it points your next post at the prompt.
- Prompt answers are any post type with a small **"prompt" tag**. They stay visible even when their day collapses into a stack.
- Friends' boards show the same card, linking to their answer.
- Later idea: a "how everyone answered" gallery.

### Busy days
- After ~4 items, a day **collapses into a stack**: the first 2 items stay visible, the rest pile up with a "+N" count. Tap to fan out, in posting order.
- Journal entries and prompt answers always stay on top, never inside the stack.

### Added later (paperclip)
- You can post to any **past day in the current month**. Those items get a **paperclip instead of a pushpin**. Tap the clip to see when it was added.
- Anything added the same day gets a normal pin.
- When the composer targets a past day, the pin button turns into a paperclip and the placeholder reads "add to Tue 3…". After posting, it snaps back to today.
- Friends can see paperclips.
- Sealed months can't be clipped onto.

### Editing
**Your own posts**
- During the month: edit or delete freely. No "edited" marker on notes and photos.
- After sealing: **delete yes, edit no.** Sealed months can lose things but never gain or change.
- Moving a post to a different day only counts as a move on the same day it was posted. After that it's a clipped addition.

**Friends' notes on your board**
- You can **move** them anywhere.
- You can **tuck away** a note: hidden from everyone, sender not notified, recoverable by you. Works in sealed months too.

**Notes you left on someone else's board**
- Edit or delete while their month is live. After their month seals, delete only.

### Friends and visiting
- **Two separate lists:**
  - **Boards you can see:** people who put you on their list.
  - **Who can see your board:** your guest list.
  - These are **one-way**. Being on someone's list doesn't put them on yours.
- **Doorbell:** one pill on the Friends tab: "4 boards have new things." Tapping it opens a **finite queue** of only the updated boards, one at a time, like stories with an end. Then you're done.
- Friends' boards show in **their look** (background, colors), with **the same day rows**, a "today" marker, and new-since-last-visit items outlined.
- **The only action on a friend's board is leaving a note.** No likes.
- **Placing a note:** you write it, then drag it to where you want it on their board, next to the post it's about. If you skip dragging, it lands on that day's row. Once stuck, only the owner can move it.
- **Notes from other visitors are visible** to everyone who can see the board.
- Visits show as a **count only**, never names.

### Guest list
- **Hard cap of 20.** When full, adding someone requires taking someone off first.
- **Hybrid renewal:** the list carries over automatically each month and can be edited anytime. The seal ritual includes an **optional "review next month's list"** step.
- Removals during the review take effect on the 1st. Edits during the month take effect immediately.
- **Removal is silent.** Your board simply disappears from their Friends tab.
- Notes left by a removed person **stay on your board** (you can tuck them away).
- Re-adding someone follows the same rules as a new guest.

### Archive visibility (sealed months)
- **Current list only, from join date on.**
  - Removed from your list = lose access to **everything**, including months they were on the list for.
  - Newly added guests see **only from the month they were added** onward.
- **Sharing past months:**
  - **At add time:** after adding someone, an optional step lets you pick which past months to share. Default is none.
  - Editable later from that person's row in your guest list.
  - **Guests can request a past month.** On your shelf they see months they can't access as **plain locked covers** (month name only, no title or cover photo). Tapping one asks you.
  - **One request per month.** Ignored requests expire silently. No decline notice.
- **Private months:** any sealed month can be marked **"just for me."** It disappears entirely from everyone's view of your shelf, including locked covers.
- **Sealed means sealed:** friends can't leave new notes on past months.

### Seal ritual (the 1st of the month)
1. **Last chance:** "October seals tonight. Anything to clip on before it's done?" Shows once, on your first open of the 1st. The month stays open until midnight.
2. **Name it:** optional title ("the month of yzma"), a cover chosen from your most-noted posts, and a small recap (things pinned, notes from friends, busiest day).
3. **Review next month's list** (optional).
4. **Set up the new month:** pick the background and sticky note color, set what you're "into," and the new prompt is revealed.
- Skipping everything seals the month with defaults (most-noted post as cover, no title) and carries last month's look forward.
- The sealed month becomes a **zine cover on the shelf**. Opening it shows the full board, read-only, with friend notes where they were left. Flip between months with arrows.

### Board customization
- **A look per month:** ~8 preset backgrounds (cork, graph paper, kraft, fridge door…) plus a sticky note color.
- Chosen during the seal ritual, editable anytime during the month.
- Each sealed month keeps its own look on the shelf.
- Later: photo backgrounds.

### Onboarding and invites
- **V1: invite links only.** No search, no requests to join, no suggestions.
- **Usernames are collected at onboarding** so search can be added later without a migration. Unique, changeable occasionally (e.g. once a month).
- **Invite links are private single-use tokens,** never the username (otherwise usernames become guessable entry points). They expire after about a week and can be cancelled from the guest list.
- When someone puts you on their list, an in-app **"Add them to yours?"** card appears on your Friends tab. Reciprocity is one tap, never required.
- A new user's board works on day one with nobody else around (journal-first).
- **Future discovery path**, in order of openness: exact username lookup → contacts → friends of friends. Open name search is off the table. If requests are added later, they should be off by default.

### Notifications (v1)
1. Someone left a note on your board (batched).
2. Weekly doorbell summary: "4 boards have new things," on a day you pick. No ping per post.
3. Month turnover on the 1st: "October seals tonight."

**Never notified:** being added to a list (shown in-app instead), removals, ignored requests, visits, edits, tucked-away notes.

### Safety
- **Block:** removes them from your list and you from theirs, and neither can invite the other again. Silent.
- **Report** a note or a board.
- A removed or blocked person's notes stay on your board until you tuck them away.

### Later
- **Printable months and a printed year book** (12 covers bound together). Design the sealed month and cover so they translate to print.
- Spotify song as a vinyl record.
- Prompt gallery, friend-group prompts.
- Desktop and web.
- Time zones and day boundaries when traveling.

---

## Screen map

Name Figma/FigJam frames with these IDs (e.g. `BRD-01 Board / today`) so Claude can match them when building.

✓ = exists in the prototype.

### Onboarding
| ID | Screen | Notes |
|---|---|---|
| ONB-01 | Invite welcome | "Maya put you on her list." Invite path only |
| ONB-02 | Profile setup | Name, username, photo |
| ONB-03 | Into this month | Set the "currently into" header |
| ONB-04 | Add inviter back | "Add Maya to your list?" Invite path only |
| ONB-05 | Invite your first people | Skippable |
| ONB-06 | First post | Empty board with a gentle first-post prompt (cold start) |

### My board
| ID | Screen | Notes |
|---|---|---|
| BRD-01 ✓ | Board / today | Default home. Day rows, header cards, composer |
| BRD-02 ✓ | Board / busy day collapsed | Stack with "+N" |
| BRD-03 ✓ | Board / busy day expanded | Fanned out, "stack them back up" |
| BRD-04 ✓ | Composer / clip to past day | Day chips, paperclip button |
| BRD-05 ✓ | Composer / answering prompt | Placeholder targets the prompt |
| BRD-06 ✓ | Journal entry opened | Full page, serif, notes at bottom |
| BRD-07 | Month view | Pinch-out calendar grid |
| BRD-08 | Board / empty month | Start of a new month |
| BRD-09 ✓ | Prompt answer highlighted | After tapping the prompt card |

### Editing
| ID | Screen | Notes |
|---|---|---|
| EDT-01 | Post actions | Edit, delete, move (same day only) |
| EDT-02 | Friend note actions | Move, tuck away |
| EDT-03 | Tucked-away notes | Recover hidden notes |

### Friends
| ID | Screen | Notes |
|---|---|---|
| FRN-01 ✓ | Friends tab | Doorbell, boards you can see, guest list summary |
| FRN-02 | Friends / empty | Nobody has added you yet, invite CTA |
| FRN-03 | Add-back card | "Maya put you on her list. Add her to yours?" |

### Visiting a friend
| ID | Screen | Notes |
|---|---|---|
| VIS-01 ✓ | Friend's board | Day rows, their look, new items outlined, header cards |
| VIS-02 ✓ | Write a note | Sticky note sheet |
| VIS-03 | Place a note | Drag the note into position |
| VIS-04 | All caught up | End of the doorbell queue |
| VIS-05 | Friend's shelf | Shared months open, others as locked covers |
| VIS-06 | Request a past month | "Ask Alina to see October?" |
| VIS-07 | Friend's past month opened | Read-only |

### Guest list
| ID | Screen | Notes |
|---|---|---|
| GST-01 ✓ | Guest list editor | 20-cap meter, add/remove, "you can/can't see their board" |
| GST-02 ✓ | Guest list full | "Take someone off first" |
| GST-03 | Guest detail | Months shared, remove, block |
| GST-04 | Share past months | Step after adding someone |
| GST-05 | Past-month requests | Incoming requests, share or ignore |

### Invites
| ID | Screen | Notes |
|---|---|---|
| INV-01 | Create invite | Generate and send a single-use link |
| INV-02 | Pending invites | Cancel or resend |

### Shelf (archive)
| ID | Screen | Notes |
|---|---|---|
| ARC-01 ✓ | Shelf | Sealed month covers |
| ARC-02 ✓ | Past month opened | Read-only, "sealed · no new notes," month-to-month arrows |
| ARC-03 | Month settings | "Just for me" privacy, delete posts |

### Seal ritual
| ID | Screen | Notes |
|---|---|---|
| SEAL-01 ✓ | Last chance | Clip something or seal now |
| SEAL-02 ✓ | Name it | Title, cover, recap stats |
| SEAL-03 | Review next month's list | Optional |
| SEAL-04 | Set up the new month | Look, "into," prompt reveal |

### Settings and safety
| ID | Screen | Notes |
|---|---|---|
| SET-01 | Board look | Background presets, sticky color |
| SET-02 | Notifications | Notes, doorbell day, month turnover |
| SET-03 | Blocked people | |
| SET-04 | Profile and username | |
| RPT-01 | Report | Note or board |

---

## Still open (small)
- Exact username change limit.
- Invite link expiry length.
- Default day for the weekly doorbell.
- Cap on notes per visitor per post (suggested: one).
- The exact set of ~8 background presets.
- Print format and size for months and the year book.

---

## Design handoff: key frames and components

Alina designs the key frames and components in Figma. Claude derives the remaining screens from them.

### Key frames (designed by Alina)
| # | ID | Why it's key |
|---|---|---|
| 1 | BRD-01 Board / today | Defines most of the board. Include a collapsed busy day, a folded journal entry, a clipped item, a prompt answer, and today's row by the composer |
| 2 | BRD-06 Journal entry opened | Reading typography and the bottom sheet pattern |
| 3 | FRN-01 Friends tab | Doorbell, boards you can see, guest list summary |
| 4 | VIS-01 Friend's board | Visitor chrome: queue progress, their look, new-item outlines, other notes, "Leave a note" |
| 5 | VIS-03 Place a note | Signature interaction. Show the note mid-drag |
| 6 | GST-01 Guest list editor | List row and settings pattern, 20-cap meter |
| 7 | ARC-01 Shelf | Sealed covers. Include one locked cover |
| 8 | SEAL-02 Name it | Ritual style for all seal steps |
| 9 | ONB-01 Invite welcome | Onboarding tone and layout |
| 10 | BRD-08 Board / empty month | Empty-state personality; doubles as the first-post screen |

### Components
**Board items**
- `Item/Sticky`: color variants; states pinned, clipped, new-outlined, prompt-tagged
- `Item/Polaroid`: photo + caption; same states
- `Item/Folded`: title, first line, read time, fold edge
- `Item/Stack`: collapsed busy day with "+N"
- `Item/FriendNote`: sticky with author name
- `Attach/Pushpin`, `Attach/Paperclip`, `Attach/PromptTag`
- `Item/Vinyl`: placeholder for the future Spotify song

**Board structure**
- `Day/Header`: default, today
- `Header/Into`, `Header/Prompt` (answered, unanswered)
- `Composer`: default, past-day target, prompt mode; `Composer/DayChip`

**Navigation and people**
- `Nav/Tabs`, `Nav/Top` (own board, visiting with progress)
- `Doorbell`
- `Avatar`: sizes, with/without "new" dot
- `GuestRow`: on, off, locked
- `Meter/Capacity`

**Archive and system**
- `Cover`: sealed, locked, just-for-me
- `Seal/Wax`
- `Sheet`, `Button` (primary, secondary), `TextField`, `Toast`

**Looks**
- ~8 background presets and sticky note colors, set up as **Figma variables** (each month's look swaps them)

### Derived by Claude from the above
BRD-02, BRD-03, BRD-04, BRD-05, BRD-07, BRD-09 · all EDT screens · FRN-02, FRN-03 · VIS-02, VIS-04 to VIS-07 · GST-02 to GST-05 · INV-01, INV-02 · ARC-02, ARC-03 · SEAL-01, SEAL-03, SEAL-04 · ONB-02 to ONB-06 · all SET screens · RPT-01

### Handoff conventions
- Name frames with their screen ID (e.g. `BRD-01 Board / today`).
- Name components with the slash names above.
- Use Figma variables for color and type so styles map straight into code.
