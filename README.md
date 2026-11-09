# curbox-patcher

Builds [Curbox](https://github.com/curbox-app/curbox-android) releases (fdroid flavor) with one extra patch: **Curbox only switches off a grayscale filter it switched on itself.** Filters that you or another app (such as GrayScaler+) turn on are left alone. With no grayscale groups, or all groups disabled, Curbox never changes the grayscale setting.

Unofficial build, not made by the Curbox developers. Supports Curbox **6 and later** (there was no release 5).

## Download

| Where | Link |
| --- | --- |
| App hub (always the newest build) | [Curbox.apk](https://github.com/fabiantorrestech/android-apps/releases/download/curbox/Curbox.apk), also listed on [fabiantorrestech.github.io/android-apps](https://fabiantorrestech.github.io/android-apps/) |
| Every build, by version | [Releases](https://github.com/fabiantorrestech/curbox-patcher/releases) (`<version>-grayscale`) |
| Automatic updates | In [Obtainium](https://github.com/ImranR98/Obtainium), add `https://github.com/fabiantorrestech/curbox-patcher` |

## How it works

```
Daily at 09:00 UTC, or when you press "Run workflow"
        |
        v
1. Find the Curbox release to build ("latest" asks GitHub for the newest one)
2. Already built "<version>-grayscale"?  yes -> stop (unless "force" is ticked)
3. Download the official Curbox source code for that release
4. Apply patches/grayscale.patch
5. Run the patch's unit tests
6. Build the fdroid release APK and sign it with the PERSONAL key
7. Check the signer matches PERSONAL in android-apps/apps.json (stops if not)
8. Publish release "<version>-grayscale" here
9. If it is the newest Curbox release, also replace Curbox.apk on the app hub
```

The patch is a list of edits, like "in this file, replace this line with that one." Each new Curbox release gets a fresh copy of the official code, and the edits are applied on top. Applying only fails when Curbox itself changed the same lines the patch edits.

### What the patch changes

- **New file `GrayscaleOwnership.kt`.** It holds the rules, with no Android code, and has unit tests:
  - Curbox owns the filter only after it sees the filter turn on following its own request.
  - It only switches the filter off while it owns it and the filter is still on.
  - If anything else switches the filter off, Curbox stops owning it.
  - Commands run one at a time, so a slow Shizuku "on" can't land after a later "off".
- **New file `GrayscaleOwner.kt`.** It watches the system grayscale setting and runs those rules. It stores "Curbox owns it" in a folder Android never backs up, so restoring a backup can't bring back an old value.
- **`GrayScaleFilter.kt` (Curbox's file).** Only 6 lines change: its on/off calls go through `GrayscaleOwner`. Keeping this small is what makes future releases easy to patch.
- **Known edge case:** if another app turns grayscale on within 10 seconds after a Curbox "on" that failed, Curbox treats that filter as its own.

## Patching it yourself

### Usually: nothing

A new Curbox release is built the next morning. Obtainium notifies you, and the hub link updates on its own.

### Build a specific version now

1. On github.com (desktop site on a phone works), open this repo → **Actions** → **Build patched Curbox** → **Run workflow**.
2. In **release**, type the version (for example `7`), or leave `latest`.
3. Tick **force** only to rebuild a version that already exists.
4. Press **Run workflow**. The APK appears under **Releases** after about 5 minutes.

### A new Curbox release won't patch

GitHub emails you that the run failed. Its summary lists the conflicting files. On the PC, using Git Bash:

```bash
cd ~/Documents/Developer/repos/curbox-patcher
scripts/refresh-patch.sh ../curbox-android 7        # 7 = the new Curbox release
```

The script:
1. downloads Curbox 7
2. moves your patch (one commit on branch `patch/grayscale` in `curbox-android`) on top of it
3. runs the tests
4. rewrites `patches/grayscale.patch`

If it stops on a conflict:
1. Open each listed file in `curbox-android`.
2. Keep Curbox's new code, and keep the patch's `grayscaleOwner.…` lines in place of the old `grayscaleControl.enableGrayscale/disableGrayscale` calls.
3. Run `git add <file>`, then `git rebase --continue`.
4. Run the script again with the same arguments.

When it finishes, it prints three steps:

```bash
git -C ../curbox-android push --force-with-lease origin patch/grayscale
git add patches/grayscale.patch && git commit -m "Patch for Curbox 7" && git push
# then Actions -> Run workflow -> release 7
```

### Change what the patch does

1. In `curbox-android`, run `git switch patch/grayscale`.
2. Edit the files.
3. Run `./gradlew testFullDebugUnitTest --tests "*GrayscaleOwnership*"`.
4. Run `git commit -a --amend`. The patch must stay **one** commit.
5. Run `scripts/refresh-patch.sh ../curbox-android <current version>`.
6. Do the three printed steps, then run the workflow with **force** ticked.

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

A Curbox backup is a plain settings file (`curbox-settings-backup`, format version 1). It holds no app signature or package check, and the patch doesn't change any settings. So a backup made in one app restores in the other, as long as both are the same Curbox version. Restoring is only offered during onboarding.

| Backup made in → restored into | Works? |
| --- | --- |
| Official Curbox → patched build (same version) | ✅ |
| Patched build → official Curbox (same version) | ✅ |
| Patched build → patched build, or official → official | ✅ |
| Older Curbox → newer Curbox, while both use backup format 1 | ✅ |
| Into a Curbox whose backup format number differs | ❌ "Unsupported backup version" |
| Into a build without the UI hider or grayscale (Play Store flavor) | ✅ but those parts are dropped |

What a backup does **not** carry, in either app:

| Item | In the backup? |
| --- | --- |
| Blocking groups, schedules, keywords, grayscale groups, focus mode and other settings | ✅ |
| Usage history and statistics | ❌ |
| Accessibility, Shizuku, device admin and other permissions (grant them again) | ❌ |
| The patch's "Curbox owns the filter" flag (starts fresh, which is the safe default) | ❌ |

## Cost

- GitHub Actions is free for public repositories.
- A daily check takes about 20 seconds; a build takes about 5 minutes.
- GitHub pauses scheduled workflows after 60 days without repository activity. It emails first; turn it back on with **Enable workflow** on the Actions tab.

## Files

```
.github/workflows/build.yml   the build (manual + daily)
patches/grayscale.patch       the patch, exported from curbox-android branch patch/grayscale
scripts/refresh-patch.sh      moves the patch onto a new Curbox release and re-exports it
```

## License

GPL-3.0, same as Curbox. The patch source is `patches/grayscale.patch`.
