# DailyWell — Daily Health Routine Tracker

A private, multi-user health routine app: workouts (gym and home), meals and nutrition, water, sleep and wake-up times, recovery and massage reminders, supplements, body tracking, habits, reports and reminders.

- **Frontend:** one file, `index.html` (HTML + CSS + vanilla JavaScript). No npm, no build step, no server.
- **Backend:** Supabase (Auth + PostgreSQL with Row Level Security), set up with `supabase_setup.sql`.
- **Hosting:** GitHub Pages (any static host works).
- **Charts:** Chart.js and the Supabase client load from the jsDelivr CDN.

> DailyWell is a tracker and reminder tool. It is not a medical device and does not give medical advice.

## Files

| File | Purpose |
|---|---|
| `index.html` | The whole app |
| `supabase_setup.sql` | Tables, constraints, indexes, RLS policies, triggers, account-deletion function |
| `README.md` | This guide |
| `.gitignore` | Keeps editor/OS files and any local secrets out of git |

## 1. Try it right now (Local demo mode)

Open `index.html` in a browser (double-click it). While the two Supabase placeholders are unchanged, the app runs in **Local demo mode**:

- click **Open the demo** on the landing page,
- data is stored only in that browser (`localStorage`) on that device,
- there is no account, no sync, and no password protection.

Use it to explore (the onboarding step offers sample data). Do not treat it as a place for data you cannot lose.

## 2. Set up the backend (Supabase)

1. Create a free project at <https://supabase.com> (Dashboard → New project). Save the database password somewhere safe — you never put it in `index.html`.
2. Open **SQL Editor → New query**, paste the full contents of `supabase_setup.sql`, and click **Run**. It is safe to run again later.
3. Open **Project Settings → API** and copy:
   - **Project URL**
   - the **publishable key** (`sb_publishable_…`) — or, on older projects, the **anon** key.
   - **Never** copy the `service_role` / secret key into `index.html`.
4. In `index.html`, find the two constants near the top of the script and paste your values:

   ```js
   const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
   const SUPABASE_KEY = 'sb_publishable_...';
   ```

### Configure Auth

In **Authentication → URL Configuration**:

- **Site URL:** your published address, e.g. `https://YOUR-USER.github.io/YOUR-REPO/`
- **Redirect URLs:** add the same address (and `http://localhost:3000/` or similar if you test locally with a small static server).

Without this, confirmation and password-reset emails will point to the wrong place.

In **Authentication → Providers → Email**:

- Leave **Confirm email** on for a public site (users must verify their address).
- Raise the minimum password length to 8 or more (the app already requires 8).

In **Authentication → Rate Limits / SMTP**:

- Supabase's built-in email sender is heavily rate limited and meant for testing. For a public site, configure your own SMTP provider.

## 3. Deploy on GitHub Pages

1. Create a new GitHub repository (public repositories are required for free Pages on most plans).
2. Upload `index.html`, `supabase_setup.sql`, `README.md` and `.gitignore` (**Add file → Upload files**), then commit.
3. Go to **Settings → Pages**. Under **Build and deployment** choose **Deploy from a branch**, select `main` and `/ (root)`, and save.
4. After a minute your site is live at `https://YOUR-USER.github.io/YOUR-REPO/`.
5. Put that address into Supabase **Site URL** and **Redirect URLs** (section 2).
6. Visit the site, sign up, confirm your email, log in.

**GitHub Pages is public hosting.** Anyone can open the site and read `index.html`. That is expected: the project URL and publishable key in it are public by design. Your users' data is protected by Row Level Security in the database, not by hiding the code.

## 4. How your data is protected

- Every user table has `user_id` defaulting to `auth.uid()`, and RLS policies for SELECT, INSERT, UPDATE and DELETE that only allow rows where `user_id = auth.uid()`.
- A trigger blocks any attempt to change a row's owner. Child tables (workout exercises, logs) use composite foreign keys so a child can only reference a parent owned by the same user.
- The `anon` role has no privileges on any table. Visitors who are not signed in can read nothing.
- No service-role key, database password or other secret exists in the frontend.
- All user-entered text is HTML-escaped before display. CSV exports neutralise cells starting with `=`, `+`, `-` or `@`.
- Sessions use the Supabase client with PKCE; the app removes auth codes from the address bar after sign-in. Error messages shown to users are generic and the app does not log entry contents.
- The app does not use analytics, ad trackers or AI services, and sends no health data anywhere except your Supabase project.
- The page ships a Content-Security-Policy meta tag limiting scripts to jsDelivr and network connections to `*.supabase.co`. **If you use a custom Supabase domain, edit the `connect-src` list in that tag.**

Recommended hardening: pin the CDN scripts to exact versions with Subresource Integrity (`integrity="sha384-…"`) hashes — get them from jsDelivr's page for each file.

## 5. Backup and export

- **In the app:** Settings → *Download everything (JSON)*, or Reports → *Export my data (CSV)* per dataset. Weights, lengths and volumes are exported in kg, cm and ml.
- **Database:** Supabase Dashboard → Database → Backups (daily backups on paid plans; on the free plan, export regularly or use `pg_dump` from the Connect panel).
- **Delete account:** Settings → *Delete my account and data* permanently removes the user and all their rows (database cascade).

## 6. Maintenance

- **Schema changes:** edit `supabase_setup.sql`, keep it idempotent, and re-run it. Column additions need matching changes in the `ENT` definitions in `index.html`.
- **Dependencies:** the only dependencies are the two CDN scripts. Update the version numbers in the `<script src>` tags and test.
- **Keys:** if you rotate API keys in Supabase, update `SUPABASE_KEY` and redeploy.
- **Monitor:** Supabase Dashboard → Auth logs and Database → Reports.
- **Large accounts:** the app loads each table fully when you log in (paged 1,000 rows at a time). That is fine for years of personal data; very heavy use may want date-range queries.

## 7. What is complete, and what is limited

Working in local demo mode and written for Supabase mode: add / edit / delete / search / filter / sort for all main records, daily plan with templates and "copy yesterday's plan", workouts with exercise log and personal records, home gym with equipment-aware routines and timer (stopwatch, intervals, rest) with sound and vibration, nutrition (targets, calculator, food log, food library, weekly meal plan, grocery list, diet-aware ideas), water, sleep (midnight and clock-change safe), recovery and soreness, supplements and adherence, body tracking, habits with heat-map and daily check-in, reminders with snooze / done / quiet hours, reports with charts, CSV / JSON export and print, insights, settings and units, light / dark theme, onboarding, removable sample data, account deletion.

Known limitations (please read):

- **Notifications:** banners and browser notifications fire only while DailyWell is open in a tab or window. Reliable background push when the app is closed needs a service worker and server-side push, which a single static file cannot provide.
- **Offline / PWA:** the app includes an inline manifest so "Add to Home Screen" works on most phones, but there is **no service worker**, so it does **not** work offline and the browser may not show a full install prompt. Offline support would need an extra `sw.js` file.
- **Progress photos are not included** (they would need private Supabase Storage with its own policies).
- **Time zones:** the app uses your device's clock and time zone. The time zone stored in your profile is informational. If you travel, change your device time zone.
- **Per-weekday sleep targets:** one bedtime / wake time target applies to every day.
- **Calorie calculator:** an estimate from a standard formula for adults 18+, with a minimum floor; not medical advice.
- **Local demo mode** is not secure storage and does not sync.
- **Tested:** the front-end was syntax-checked and exercised end to end in a headless browser simulation (jsdom) in **local demo mode** — every page, adding / editing validation, search, timer, CSV / JSON export, settings, sample data clearing and local account deletion. **The Supabase code path (sign-up, log-in, RLS, account deletion RPC) has not been run against a live Supabase project in this environment.** Follow the checklist below once after setup.

### Post-setup checklist

1. Sign up with a real email and confirm it.
2. Log in; finish onboarding; add a workout, a meal, a sleep entry and a reminder; refresh the page — they should persist.
3. Log in from a second device or private window — the data should be there.
4. Create a second account — it should see none of the first account's data.
5. Test "Forgot your password?" and Settings → Change password.
6. Download the JSON export.
7. Delete the test account from Settings.
