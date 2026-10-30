/* DailyWell configuration — edit these values BEFORE building the store apps.
   Everything here is public by design (it ships inside the app). NEVER put a
   service_role / secret key, a database password, or any private key in this file. */
window.DAILYWELL_CONFIG = {
  // From Supabase: Project Settings -> API
  SUPABASE_URL: 'YOUR_SUPABASE_URL',              // e.g. https://abcdefgh.supabase.co
  SUPABASE_KEY: 'YOUR_SUPABASE_PUBLISHABLE_KEY',  // publishable key (sb_publishable_...) or legacy anon key

  // Public web address of the DailyWell web app. Email confirmation and password-reset
  // links open this page in the phone's browser (the in-app address is not a real website).
  // Also add it to Supabase: Authentication -> URL Configuration -> Site URL / Redirect URLs.
  WEB_URL: 'https://biswajitdas01.github.io/Das.github.io/dailywell/',

  // Shown in Settings; required by Apple and Google. Host these pages publicly.
  PRIVACY_URL: 'https://biswajitdas01.github.io/Das.github.io/dailywell/privacy.html',
  SUPPORT_URL: 'https://biswajitdas01.github.io/Das.github.io/dailywell/support.html'
};
