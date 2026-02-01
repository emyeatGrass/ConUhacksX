# Lost & Jammed


https://github.com/user-attachments/assets/c290d625-79cd-4564-929d-fb629e88c8c1


#### Try it here: https://lost-and-jammed.vercel.app
###### The database (found inventory) already contains 25 different items. Download them and the sample test images, or add and fetch your own items to and from the found inventory. Each tab has its own database; refreshing or reopening the page resets it.


## About the project

### Inspiration
ConUHacks gave us two challenges that seem unrelated at first, but both center on the same idea: getting an item back. We wanted to merge them into one coherent experience. First, a powerful, AI-powered lost-and-found system. Then, a top-down shooter game where recovering your item becomes a short quest.

### What we built
**Lost & Jammed** is a web app with an integrated game:

- **Lost-and-found matching**: Users upload a clear photo to deposit a found item into a private inventory, or upload a photo of a lost item in the hope of finding a match. The app is fully intelligent and autonomous: no admin required to operate the lost-and-found.
- (Skippable) **Playable retrieval quest**: When a strong match is found, the website launches our **Godot HTML5 game directly in-page** (only on desktop with extended keyboard), turning the pickup into an interactive adventure where the user needs to fetch their item in the game, located north of several dangerous highways jammed with cars to be crossed.

### How it works
1. **Upload a photo** of the item (add or find).
2. **AI turns the image into searchable descriptors** (object name, synonyms, colour, shape, brand, key attributes...).
3. **We search a private database inventory**. Then a refinement step compares the query image against the top candidate images to pick the best match.
4. **If a match is confirmed**, the matched item is revealed and the **embedded HTML5 game** starts.
5. **Beat the level to reclaim your item**.

### The game
Inspired by Crossy Road, our protagonist must cross multiple roads while destroying cars that threaten to run them over. When a car is destroyed, its angry driver retaliates and becomes a new threat. Shooting coins at the drivers calms them down. Survive to the end to retrieve the item. The game supports **singleplayer and local  co-op multiplayer**, including downed and revive mechanics.

### How we built it
- **Frontend**: Next.js (App Router) with a clean “Add Item / Find Item” flow, plus client-side image compression for fast uploads.
- **Backend**: A Next.js API route that orchestrates AI description generation, candidate search, and match selection.
- **Database**: SQLite, storing each found item’s image bytes and its generated descriptions.
- **Game**: Godot, exported as **HTML5** and embedded in the website for a seamless handoff from match confirmation to gameplay.

### Challenges we faced
- **Privacy and trust**: The inventory must stay private and resist false claims, so we designed the system to reveal only high-confidence results instead of exposing the database. Only one item can be fetched at a time.
- **Matching reliability**: Photos vary wildly (angles, lighting, clutter), so we combined deterministic filtering with an AI refinement step.
- **Integration complexity**: Bridging web flows, database, and an embedded HTML5 game requires careful coordination across toolchains and runtime constraints.
- **Hackathon scope**: Building two full experiences under time pressure forced strong prioritization and clean interfaces between components.

### What we learned
- How to structure an end-to-end prototype that blends web, database, and generative AI without losing reliability.
- How to improve search quality with a two-stage approach: fast heuristic ranking plus AI-based verification.
- How to ship a game that is small in scope but complete in systems, including multiplayer-ready gameplay loops.

### Challenges targeted
- **Lost item matching system**: Private inventory, photo-based requests, automated matching to reduce manual searching and false declarations.
- **Multiplayer 2D top-down shooter**: A structured Godot project delivered under a 24-hour constraint, with combat, progression, and multiplayer co-op support.
