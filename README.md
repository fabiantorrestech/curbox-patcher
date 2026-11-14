# curbox-patcher

Builds [Curbox](https://github.com/curbox-app/curbox-android) releases (fdroid flavor) with three extra patches:

- **Grayscale: Curbox only switches off a grayscale filter it switched on itself.** Filters that you or another app (such as GrayScaler+) turn on are left alone. With no grayscale groups, or all groups disabled, Curbox never changes the grayscale setting.
- **Firefox: links opened from another app are checked right away.** In stock Curbox, a link opened in Firefox from a text or chat showed its first page unblocked, and the block only came on the first tap inside the page.
- **Unlock waits: a growing wait between app unlocks, plus an emergency password.** After an app group unlock ends, the next unlock waits 1 minute, then 2, then 3 and so on (you pick the numbers per group). The waits start over at your "day end" time, set per weekday. An optional emergency password unlocks right away a few times a day.

Unofficial build, not made by the Curbox developers. Supports Curbox **6 and later** (there was no release 5).

## Download

| Where | Link |
| --- | --- |
| App hub (always the newest build) | [Curbox.apk](https://github.com/fabiantorrestech/android-apps/releases/download/curbox/Curbox.apk), also listed on [fabiantorrestech.github.io/android-apps](https://fabiantorrestech.github.io/android-apps/) |
| Every build, by version | [Releases](https://github.com/fabiantorrestech/curbox-patcher/releases) (`<version>-grayscale-p<patch set>`, e.g. `6-grayscale-p4`) |
| Automatic updates | In [Obtainium](https://github.com/ImranR98/Obtainium), add `https://github.com/fabiantorrestech/curbox-patcher` |

## How it works

```
Daily at 09:00 UTC, or when you press "Run workflow"
        |
        v
1. Find the Curbox release to build ("latest" asks GitHub for the newest one)
2. Already built "<version>-grayscale-p<patch set>"?  yes -> stop (unless "force" is ticked)
3. Download the official Curbox source code for that release
4. Apply every patches/*.patch, in name order
5. Run the grayscale patch's unit tests
6. Build the fdroid release APK and sign it with the PERSONAL key
7. Check the signer matches PERSONAL in android-apps/apps.json (stops if not)
8. Publish release "<version>-grayscale-p<patch set>" here (an older Curbox version is marked pre-release)
9. If it is the newest Curbox release, also replace Curbox.apk on the app hub
```

A patch is a list of edits, like "in this file, replace this line with that one." Each new Curbox release gets a fresh copy of the official code, and the edits are applied on top. Applying only fails when Curbox itself changed the same lines a patch edits. The patches are applied in name order, each as its own commit, and they apply cleanly together on Curbox 6.

### Release names

Each release is named `<version>-grayscale-p<patch set>`, for example `6-grayscale-p4`:

- `<version>` is the Curbox release, like `6`.
- `<patch set>` counts the commits on `main` that changed `patches/`. Any patch change makes it go up by one. That only holds on `main` with its full history, so the workflow refuses to publish from another branch or a shallow checkout. Don't rewrite `main`'s history (force push): a number could repeat, and the build would be skipped as "already built".

Why: Obtainium decides there is an update when the release name changes. It can't use the app's own version, because the patches never change it (Curbox 6 is always `6-fdroid`). So a rebuild under the same name looks like no update at all. A new patch set gets a new name, so:

- Obtainium offers it as an update.
- The daily check builds it on its own, because that name isn't built yet. No **force** needed.
- Older releases stay as they are. The first releases, named `6-grayscale`, stay too.

**force** rebuilds the same name in place, so Obtainium won't notice it. Use it only to fix a broken build.

A build of an older Curbox version (for example `6` after `7` is out) is published as a pre-release. Obtainium skips pre-releases by default, so it never offers an older Curbox as an update.

#### One-time check in Obtainium

Releases made before this change were all named `6-grayscale`. Open Curbox in Obtainium, tap the settings (gear) icon, and check:

- **Sort method** (in the GitHub options): **Release date**. That's the default for apps added from the GitHub link. Other sort methods can't tell `6-grayscale` and `6-grayscale-p4` apart and may keep the old one.
- **Include pre-releases**: off (the default).

Then pull down to check for updates. The first `-p` release shows up as an update even if the APK is the same as the one you have.

### What the grayscale patch changes

- **New file `GrayscaleOwnership.kt`.** It holds the rules, with no Android code, and has unit tests:
  - Curbox owns the filter only after it sees the filter turn on following its own request.
  - It only switches the filter off while it owns it and the filter is still on.
  - If anything else switches the filter off, Curbox stops owning it.
  - Commands run one at a time, so a slow Shizuku "on" can't land after a later "off".
- **New file `GrayscaleOwner.kt`.** It watches the system grayscale setting and runs those rules. It stores "Curbox owns it" in a folder Android never backs up, so restoring a backup can't bring back an old value.
- **`GrayScaleFilter.kt` (Curbox's file).** Only 6 lines change: its on/off calls go through `GrayscaleOwner`. Keeping this small is what makes future releases easy to patch.
- **Known edge case:** if another app turns grayscale on within 10 seconds after a Curbox "on" that failed, Curbox treats that filter as its own.

### What the Firefox patch changes

Only one Curbox file, `trackers/WebsiteUsageTracker.kt`, and no settings or stored data.

- **The bug.** When Firefox opens a link from another app, it fires its screen events before its address bar exists, then goes quiet. Curbox only read the address bar during those events, so it never saw the first page.
- **The fix.** After each burst of browser events, Curbox reads the address bar again, 0.8 and 2.5 seconds later. A new event restarts the wait. It only reads while that same browser is still on screen.
- **Why a tree walk.** Firefox draws its address bar with Compose, and Android's "find by id" can't see Compose tags. If that lookup fails, Curbox looks through the top 500 screen elements instead. The bar is around the 30th, so this takes a few milliseconds.
- **Checked on a phone:** 10 of 10 links opened from outside Firefox were read within about a second. Typed addresses and Chrome work as before.
- Other supported browsers get the same extra read, which changes nothing when they already reported the address.

### What the unlock waits patch changes

- **Per app group** (Configure Warning Screen > Advanced > "Wait longer after each unlock"): first wait, minutes added each time, longest wait. Default 1, 1, 30: waits of 1, 2, 3 … 30 minutes.
- **The wait starts when the unlock ends.** For a timed unlock that is its end time. For "on each open", it is when you leave the group's apps; opening the share sheet or a permission prompt doesn't count as leaving. During the wait the warning screen shows a countdown and no Proceed button, then the normal wait timer runs. A wait always ends by your day end, even if it would be longer.
- **Reducers > Advanced > Unlock waits** holds the shared settings: when each day ends (per weekday, before noon the next morning, e.g. Friday night ends at 4:00) and the emergency password with how many emergency unlocks you get per day.
- **Emergency unlock** opens the app for the group's normal time and skips the wait, limits and challenges. It does not make the next wait longer.
- **Settings change delay:** turning waits off, making them shorter, moving a day end, setting a password or allowing more emergencies count as weaker changes and wait out the delay. Day ends and the emergency password are separate settings, so a stricter change to one (like removing the password) applies right away even while a day end change is waiting.
- **Stored data:** new settings fields with defaults (old backups still load). The unlock count lives in the blocker service's own preferences, so it survives a service restart. No database change.
- **Checked on a phone (Pixel 5, debug build):** waits of 1 then 2 minutes, countdown kept after killing the service, on each open waits start on leaving, wrong password refused, emergency unlock during a wait, day end reset, change delay holds a weaker change.

## Patching it yourself

### Usually: nothing

A new Curbox release, or a pushed patch change, is built the next morning. Obtainium notifies you, and the hub link updates on its own.

### Build a specific version now

1. On github.com (desktop site on a phone works), open this repo → **Actions** → **Build patched Curbox** → **Run workflow**.
2. In **release**, type the version (for example `7`), or leave `latest`.
3. Tick **force** only to rebuild a release that already exists with the same patches (Obtainium won't see it as an update).
4. Press **Run workflow**. The APK appears under **Releases** after about 5 minutes.

### A new Curbox release won't patch

GitHub emails you that the run failed. Its summary names the patch and lists the conflicting files. On the PC, using Git Bash:

```bash
cd ~/Documents/Developer/repos/curbox-patcher
scripts/refresh-patch.sh ../curbox-android 7                      # grayscale patch (the default)
scripts/refresh-patch.sh ../curbox-android 7 firefox-url-rescan   # Firefox patch
scripts/refresh-patch.sh ../curbox-android 7 unlock-gap           # unlock waits patch
```

`7` is the new Curbox release. Run it once for each patch that failed.

The script:
1. downloads Curbox 7
2. moves the patch (one commit on branch `patch/<name>` in `curbox-android`) on top of it
3. runs the grayscale tests, or builds the fdroid flavor for the other patches
4. rewrites `patches/<name>.patch`

If it stops on a conflict:
1. Open each listed file in `curbox-android`.
2. Keep Curbox's new code and put the patch's lines back:
   - grayscale: keep the patch's `grayscaleOwner.…` lines in place of the old `grayscaleControl.enableGrayscale/disableGrayscale` calls
   - Firefox: keep the `scheduleUrlRescan(packageName)` call in `onEvent` and the rescan functions
   - unlock waits: keep the patch's added lines; it mostly adds code next to Curbox's own (new settings fields, `UNLOCK_GAP` and `EMERGENCY_UNLOCK` branches, the gap checks in `AppBlocker` and `WarningActivity`)
3. Run `git add <file>`, then `git rebase --continue`.
4. Run the script again with the same arguments.

When it finishes, it prints three steps:

```bash
git -C ../curbox-android push --force-with-lease origin patch/<name>
git add patches/<name>.patch && git commit -m "Patch for Curbox 7" && git push
# then Actions -> Run workflow -> release 7
```

### Change what a patch does

1. In `curbox-android`, run `git switch patch/<name>`.
2. Edit the files.
3. Grayscale: run `./gradlew testFullDebugUnitTest --tests "*GrayscaleOwnership*"`. Other patches: run `./gradlew assembleFdroidDebug`.
4. Run `git commit -a --amend`. Each patch must stay **one** commit.
5. Run `scripts/refresh-patch.sh ../curbox-android <current version> <name>`.
6. Do the three printed steps. The next daily check builds the new patch set as a new release; to get it now, run the workflow (no **force** needed).

### Run the tests locally

Curbox's fdroid unit tests don't compile in stock Curbox, because `SupabaseRestTest` needs sync-only classes. That's why the patch's tests run on the `full` flavor. They test the same logic.

## Signing

- APKs are signed with the **PERSONAL** key, the same key as SleepyGuy, Shortcut Hub and GrayScaler+ (android-apps ADR 2 and 8). The key and its password live in 1Password, vault "Android Signing", item `PERSONAL` (android-apps ADR 5).
- This repo needs these Actions secrets (names only; the values never go in any file):

  | Secret | Holds |
  | --- | --- |
  | `SIGNING_KEY` | the PERSONAL keystore, base64 |
  | `ALIAS` | its key alias |
  | `KEY_STORE_PASSWORD`, `KEY_PASSWORD` | its password |
  | `APP_HUB_TOKEN` | fine-grained token with contents read/write on `android-apps` only; without it the hub step is skipped with a warning |

- To set them again from 1Password without printing anything:

  ```bash
  R=fabiantorrestech/curbox-patcher; V="Android Signing"
  base64 -w0 ~/.android-signing/PERSONAL.keystore | gh secret set SIGNING_KEY -R $R
  op read "op://$V/PERSONAL/alias"    | tr -d '\r\n' | gh secret set ALIAS -R $R
  op read "op://$V/PERSONAL/password" | tr -d '\r\n' | gh secret set KEY_STORE_PASSWORD -R $R
  op read "op://$V/PERSONAL/password" | tr -d '\r\n' | gh secret set KEY_PASSWORD -R $R
  gh secret set APP_HUB_TOKEN -R $R     # paste the token at the prompt
  ```

- The app ID stays `neth.iecal.curbox`, so this build replaces official Curbox. Two copies would run two accessibility services that fight each other.

### Switching from official Curbox, or from a build with a different key

Android can't install an app over a copy signed with a different key, so this happens once:

1. In Curbox, use **Backup** and save the file.
2. Turn off anti uninstall / device admin protection, then uninstall Curbox.
3. Install `Curbox.apk`.
4. Restore the backup during onboarding.
5. Re-grant accessibility and Shizuku.

## Backups

A Curbox backup is a plain settings file (`curbox-settings-backup`, format version 1). It holds no app signature or package check, so a backup made in one app restores in the other, as long as both are the same Curbox version. Restoring is only offered during onboarding.

The grayscale and Firefox patches add no settings. The unlock waits patch does: each group's waits (on or off, first wait, step, longest wait), the day end times, and the emergency password with its daily count. These are saved in the backup and restore into a patched build. Official Curbox doesn't know them, so it skips them without a warning.

| Backup made in → restored into | Works? |
| --- | --- |
| Official Curbox → patched build (same version) | ✅ |
| Patched build → official Curbox (same version) | ✅ but the unlock waits, day ends and emergency password are dropped |
| Patched build → patched build, or official → official | ✅ |
| Older Curbox → newer Curbox, while both use backup format 1 | ✅ |
| Backup from before the unlock waits patch → patched build | ✅ waits start off, day ends at 0:00, no emergency password |
| Into a Curbox whose backup format number differs | ❌ "Unsupported backup version" |
| Into a build without the UI hider or grayscale (Play Store flavor) | ✅ but those parts are dropped |

What a backup does **not** carry, in either app:

| Item | In the backup? |
| --- | --- |
| Blocking groups, schedules, keywords, grayscale groups, focus mode and other settings | ✅ |
| Usage history and statistics | ❌ |
| Accessibility, Shizuku, device admin and other permissions (grant them again) | ❌ |
| Unlock waits and emergency password settings | ✅ (patched builds only) |
| The grayscale patch's "Curbox owns the filter" flag (starts fresh, which is the safe default) | ❌ |
| How many unlocks you had today and the running wait (start fresh) | ❌ |

## Cost

- GitHub Actions is free for public repositories.
- A daily check takes about 20 seconds; a build takes about 5 minutes.
- GitHub pauses scheduled workflows after 60 days without repository activity. It emails first; turn it back on with **Enable workflow** on the Actions tab.

## Files

```
.github/workflows/build.yml   the build (manual + daily)
patches/firefox-url-rescan.patch   the Firefox patch, from curbox-android branch patch/firefox-url-rescan
patches/grayscale.patch            the grayscale patch, from curbox-android branch patch/grayscale
patches/unlock-gap.patch           the unlock waits patch, from curbox-android branch patch/unlock-gap
scripts/refresh-patch.sh           moves one patch onto a new Curbox release and re-exports it
```

## License

GPL-3.0, same as Curbox. The patch sources are the files in `patches/`.
