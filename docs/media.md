# Photos and GIFs: how they're stored and shown

Goal: keep the Firebase bill small. Firebase Storage charges mostly for **downloads** (egress), so every picture
is made small once, on the phone, and each phone downloads the least it can.

## On the phone, before anything is kept or uploaded (`MediaProcessor`)
- **Photo:** decoded at the target size (never full camera resolution), rotated, **EXIF and GPS removed**, saved twice:
  - full: JPEG, at most 1600 px on the long side, quality 0.8 (typically 200-400 KB)
  - thumbnail: JPEG, at most 480 px, quality 0.7 (typically 30-60 KB)
- **GIF:** frames shrunk to at most 480 px and 48 frames (long GIFs lose frames, keeping the same total time), then
  shrunk in steps (400, 320, 240 px) until under 2.5 MB. The thumbnail is its first frame, a small JPEG.
  Inputs over 40 MB are refused.
- **Profile photos:** 512 px.

## In Firebase Storage (`MediaUploadPlan`)
- Paths: `posts/{uid}/{hash}.jpg`, `posts/{uid}/{hash}_t.jpg`, `posts/{uid}/{hash}.gif`, and for GIFs `posts/{uid}/{hash}_f.gif` (the feed animation). `hash` is a fingerprint of the bytes.
- Upload metadata: `contentType`, and `cacheControl: public, max-age=31536000, immutable`. Files never change, so
  phones (and any CDN in front) keep them and never ask again.
- Use resumable uploads, and upload the thumbnail first so it appears for friends first.
- Suggested Storage security rules (adjust once friend lists exist):

```
match /posts/{uid}/{file} {
  allow read: if request.auth != null;            // tighten to "is a friend of uid"
  allow write: if request.auth.uid == uid
    && request.resource.size < 3 * 1024 * 1024
    && request.resource.contentType.matches('image/(jpeg|gif)');
}
```

## In Firestore (`StoredMedia`, saved on each post)
`fullPath`, `thumbPath`, `width`, `height`, `isAnimated`. A feed reads the post records (one read each), lays out
every tile from `width`/`height`, and fetches **only thumbnails**.

## Feeds
- Shared tab: one summary record per friend (latest post + its thumbnail path), so opening it costs about one read per friend.
- A friend's board: page it (for example the current month, 20 posts at a time), never "load everything".
- A GIF in a feed or on a tile plays its small feed animation (`_f.gif`: about 280 px, at most 24 frames, under 300 KB). It plays only while on screen and pauses when scrolled away. With Reduce Motion on, the still thumbnail is shown instead.
- The full picture or full GIF downloads only when a post is opened. Egress tradeoff: each GIF post costs up to about 300 KB per viewer in the feed. The app shows the 480 px still first and only loads the animation once the tile is on screen (and lets it go when it scrolls away). When the backend is added: download `_f.gif` only at that point, cache it on disk with the immutable cache headers, page the feed, and keep the still (not the animation) on cellular with Low Data Mode on.
- Cache thumbnails on the phone (an image cache keyed by path) so scrolling back never downloads again.
- Delete the old files when a post is deleted (a Cloud Function on delete is enough).
