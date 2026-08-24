# Reply to App Review — Guideline 2.1, Information Needed

Paste the section below into the App Store Connect reply. Everything in
**[SQUARE BRACKETS]** is yours to fill in before sending — those are the only
places where I do not know the answer for you.

---

## 1. Screen recording

**You must record this yourself on a physical iPhone.** I cannot produce it, and
it is the one item that will not clear without you. Apple asks for a real device
on the latest OS, and the camera flow does not exist in the Simulator at all.

Keep it under five minutes, portrait, sound off is fine. Record in this order so
every item Apple listed is covered:

| # | What to show | Why it is in the list |
|---|---|---|
| 1 | Launch from the Home screen, the four onboarding screens | "begin with launching the app" |
| 2 | **Create Account** — type an email and password, tap Create Account | account registration |
| 3 | Initial Setup — plate, the three deadline windows, currency, Save Setup | first-run flow |
| 4 | Queue, empty. Tap **Add Fine**, fill in notice number, vehicle, dates, amount 80, discounted 40, Save | the core feature |
| 5 | The fine appears in the Queue with its countdown ring and "Each day of delay" | the core feature |
| 6 | Tap **Why This Order** — the arithmetic behind the sorting | the core feature |
| 7 | Open the fine — **Three Clocks** and the money scale | the core feature |
| 8 | **Pay or Appeal**, mark a ground, Mark for Appeal | the core feature |
| 9 | **Evidence → Add Evidence → Camera.** Let the permission prompt appear and tap Allow | "prompts requesting access to ... camera" |
| 10 | Add a second item using **Library** so the photo permission prompt appears | "prompts requesting access to sensitive data" |
| 11 | **Record Payment** — the fine closes and the PAID stamp lands | the core feature |
| 12 | Documents tab — add a document with an expiry date | the core feature |
| 13 | Insights and Calendar tabs | the core feature |
| 14 | Settings → Notifications → **Turn Reminders On**, let the system prompt appear | "prompts requesting access to ... device capabilities" |
| 15 | Settings → Account — signed-in devices and sync status | account management |
| 16 | **Sign Out**, then sign in again with the demo account below; the records appear | login flow, and it shows sync working |
| 17 | Account → **Delete Account** → enter the password → confirm; the app returns to the sign-in screen | account deletion flow |

Nothing else on Apple's list applies, and it is worth saying so in the reply —
the sentences are already written into section 1 of the text below.

---

## 2. Devices and operating systems tested

**[FILL IN — do not send my guess.]** List the physical devices you actually
ran it on, for example:

- iPhone 15 Pro — iOS 18.5
- iPhone 12 — iOS 18.4

If you have only run it in the Simulator so far, test on a real iPhone before
replying. Two things in this app cannot be exercised in the Simulator at all:
the camera used by **Scan Notice**, and local notifications with a real
permission prompt. Apple is asking for a device recording precisely because that
is where such things break.

What I can state factually: the app was built with Xcode 16.4, targets **iOS
17.0 and later**, is built for iPhone and iPad, and was exercised end to end in
the iOS 18.5 Simulator on iPhone 16 Pro.

---

## 3–7. The reply text

Copy everything below this line into App Store Connect.

---

Thank you for the review. Here is the information requested.

**1. Screen recording**

A screen recording made on a physical iPhone running the latest iOS is attached.
It starts with the app launching and walks through registration, the first-run
setup, adding a fine, the three deadline clocks, the pay-or-appeal decision,
adding evidence with the camera, recording a payment, the documents and insights
sections, signing out and back in, and finally deleting the account from inside
the app.

Two items on your list do not apply to this app:

- **Paid content, purchases or subscriptions.** There are none. The app has no
  in-app purchases, no subscriptions and no paid tiers. StoreKit is not linked.
- **Content reporting and blocking.** All content in the app is private to the
  person who entered it. There is no sharing between users, no public or shared
  feed, no comments, no messaging and no way for one account to see another
  account's data, so there is nothing for a user to report or block.

**2. Devices and operating systems tested**

[FILL IN: for example "iPhone 15 Pro — iOS 18.5; iPhone 12 — iOS 18.4"]

The app is built with Xcode 16.4, requires iOS 17.0 or later, and is built for
iPhone and iPad.

**3. What the app does, and who it is for**

*The problem.* When a vehicle fine arrives, the amount printed on it is rarely
what it ends up costing. Most notices carry three separate deadlines that end on
different days: a reduced amount if you pay early, a shorter window in which you
may contest it, and a later date after which the debt is passed on for
enforcement and costs are added. Missing one of those dates routinely costs more
than the fine itself. Existing apps show a total owed; none of them work with
the dates, which is where the money actually goes.

*What the app does.* Ticket Ledger is a private record book for everything with
a deadline attached to a car. The owner enters their vehicles, drivers, fines
and documents. For each fine the app counts the three windows from the dates on
the notice and puts every obligation into one queue ordered by what delay costs:
whatever is already losing money first, then by how soon a deadline falls, and
inside that by how much money moves per day of waiting. Tapping "Why This Order"
shows the arithmetic behind each position.

It also tracks documents that expire — insurance, technical inspection, road
tax, licences, permits — in the same queue, records who was driving at the time
of each fine, keeps the grounds and evidence for a contested notice, records
payments and compares them against what was due on that date, and at the end
shows two figures: money lost only because a date passed, and what delay cost
over the period.

*Who it is for.* Adults who own or drive a vehicle, particularly people with more
than one car or more than one driver in a household or a small business, where
notices and renewal dates are easy to lose track of.

*What it deliberately does not do.* It does not connect to any official or
government register, does not pay fines, does not submit appeals, does not draft
appeal texts, and does not give legal advice or predict the outcome of a
challenge. Every figure in it is one the user typed. The app states this on its
own screens: a standing line reads "This app tracks dates you enter. It is not
legal advice and it does not connect to any official register. Check the fine
itself and the deadlines printed on it." Deadline windows differ by country and
by type of notice, so the user sets them from their own notice; the app offers a
starting point and says plainly that it does not know the local rule.

**4. Setting up and accessing the main features**

Demo account:

- Email: **[FILL IN — your existing account]**
- Password: **[FILL IN]**

Registration is also open, free and immediate if you prefer to start from
nothing: tap Create Account on the first screen, enter any email address and a
password of at least ten characters. No email confirmation, invitation code or
payment is required, and no sample files are needed.

Once signed in:

- **Queue** — every obligation, ordered by what waiting costs. "Why This Order"
  explains the sorting.
- **Fines** — add a notice by hand, or use "Scan Notice" to photograph it. The
  scan reads the number, date, amount and article on the device with Apple's
  Vision framework and puts them in the form for confirmation; nothing is ever
  saved without the user accepting it.
- Open any fine for **Three Clocks**, then **Pay or Appeal** for the decision
  screen, **Evidence** to attach material, and **Record Payment**.
- **Vehicles**, **Docs** and **Insights** are the other tabs. Settings holds
  export, notifications, deadline rules and the account.
- **Deleting the account**: Settings → Account → Delete Account, confirmed with
  the password. It removes every record from the server and clears the copy on
  the device.

**5. External services, tools and platforms**

The app uses no third-party services of any kind. There are no external
dependencies in the project — no Swift Package Manager packages, no CocoaPods,
no Carthage — and only Apple frameworks are linked: SwiftUI, Foundation, UIKit,
Observation, UserNotifications, PhotosUI, Vision and Security.

Specifically:

- **Authentication service:** none. Accounts are handled by our own server. There
  is no Google, Facebook, Firebase or other third-party sign-in, which is why
  Sign in with Apple is not offered.
- **Payment processor:** none. The app records that a payment was made; it never
  takes card details and cannot make a payment.
- **AI services:** none. The text recognition in "Scan Notice" is Apple's Vision
  framework running entirely on the device. Nothing is sent to any model or
  service.
- **Data providers:** none. The app does not query any official register,
  government database or commercial data source. Every value is entered by the
  user.
- **Analytics, advertising, crash reporting:** none. No SDK of that kind is
  present.

The only network destination is our own API at **[FILL IN: https://your-domain]**,
hosted on Hostinger shared hosting, which stores the account and the user's
records so the same ledger can open on a second device. All traffic is HTTPS;
App Transport Security is not weakened. Photographs of notices, documents and
evidence never leave the device — only the file name is synced.

**6. Regional differences**

There are none. The app behaves identically in every region: the same features,
the same content, no geographic restrictions, and nothing gated by country or
store front.

Two things are user settings rather than regional behaviour. The currency is
chosen by the user from a list and is used only to format amounts — no
conversion or rate lookup happens anywhere. The three deadline windows are set
by the user from their own notice, because those periods differ by country and by
type of fine; the app does not infer them from location and never reads the
device's location.

**7. Regulated industry and third-party material**

The app does not operate in a regulated industry and contains no protected
third-party material, so no authorisation, licence or credential is applicable.

To be concrete about why:

- It is a personal record-keeping tool. It does not provide legal services or
  legal advice, and says so on its own screens.
- It is not connected to any government or municipal system, and makes no claim
  to be official or endorsed. It reads no register and files nothing with any
  authority.
- It processes no payments and holds no payment credentials, so it is not a
  financial or payment service.
- It contains no third-party copyrighted or trademarked content. All text,
  artwork and code are original. There is no logo, emblem or branding belonging
  to any authority, insurer or other organisation.
- The only material in the app is what each user types about their own vehicles
  and notices, kept private to their own account.

Privacy policy and terms: **[FILL IN: https://your-domain/terms-and-services]**
Support: **[FILL IN: https://your-domain/contact-us]**

Please let us know if anything further would help.

---

## Before you send

- [ ] Put your existing account's address and password into section 4, and into
      **App Review Information → Sign-In Required** in App Store Connect so it
      is stored permanently rather than only in a reply.
- [ ] **Open that account and look at it first.** If its Queue is empty the
      reviewer opens an empty app, which is how this rejection usually repeats.
      Either add a few fines and a document by hand, or fill it in one command
      (below).
- [ ] Record the video on a physical iPhone following the shot list above.
- [ ] Fill in the device list in section 2 with devices you really tested on.
- [ ] Fill in your domain in sections 5 and 7.
- [ ] Check that `site.contact_email` is set in `config/config.php`, otherwise
      `/contact-us` still says the site is unfinished.

## If the account is empty

`bin/demo-account.php` fills an account with a ledger that shows every screen:
two vehicles, two drivers, nine fines (one whose discount ends tomorrow, one
under appeal with evidence, one already in enforcement, five closed and paid),
four documents including one expired, five payments and a renewal. Insights needs
five closed cases to show anything, which is why they are there.

Over SSH, or through hPanel → Advanced → Cron Jobs as a one-off job:

```
/usr/bin/php /home/USERNAME/public_html/bin/demo-account.php your@account.com 'YourPassword'
```

**It rebuilds that account from scratch**, so point it only at an account you are
happy to lose — the reviewer demo, never your own. Run it again any time to reset
the demo with fresh dates before the next submission. The password may not
contain the email address; the script says so plainly if it does.
