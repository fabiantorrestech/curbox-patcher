# curbox-patcher

Builds [Curbox](https://github.com/curbox-app/curbox-android) releases (fdroid flavor) with one extra patch: **Curbox only switches off a grayscale filter it switched on itself.** Filters you or another app (such as GrayScaler+) turn on are left alone. With no grayscale groups, or all groups disabled, Curbox never changes the grayscale setting.

Supports Curbox **6 and later**. There was no release 5.

## Install on your phone

- **Updates:** in [Obtainium](https://github.com/ImranR98/Obtainium), add `https://github.com/fabiantorrestech/curbox-patcher`. It notifies you about each new `<version>-grayscale` release and installs it.
- **Build a specific version:** github.com → this repo → **Actions** → **Build patched Curbox** → **Run workflow** → type the release (for example `6`) → **Run**. The APK appears under **Releases** after about 5 to 8 minutes.
- New upstream releases are also built automatically by a daily check at 09:00 UTC.

### First time only: switching from official Curbox

The patched APK is signed with a different key than official Curbox, so Android can't update one with the other.

1. In official Curbox, use **Backup** and save the file.
2. Turn off anti uninstall / device admin protection, then uninstall Curbox.
3. Install `curbox-<version>-grayscale-fdroid.apk` from this repo's Releases.
4. Restore the backup during onboarding.
5. Re-grant accessibility and Shizuku.

Every later patched release installs over the previous one, as long as this repo keeps the same signing key.

## When a new Curbox release won't patch

The workflow fails and its summary lists the conflicting files. To fix it, run this from Git Bash:

```bash
scripts/refresh-patch.sh ../curbox-android <new tag>
```

The script:
- moves the patch (one commit on branch `patch/grayscale` in `curbox-android`) onto the new release
- runs the patch's tests
- rewrites `patches/grayscale.patch`

Then follow the "Next" steps the script prints.

## How the patch works

- It adds `GrayscaleOwnership.kt` (rules, unit tested) and `GrayscaleOwner.kt` (watches the system setting).
- `GrayScaleFilter.kt` changes by only six lines, which keeps conflicts with future releases unlikely.
- Ownership rules:
  - Curbox owns the filter only after it sees the filter turn on following its own request.
  - If anything else switches the filter off, Curbox stops owning it.
  - Commands run one at a time, so a slow Shizuku "on" can't land after a later "off".
  - Ownership is stored outside Android backup, so a restore can't bring back a stale value.
- Known edge case: if another app turns grayscale on within the 10 seconds after a Curbox enable that failed, Curbox treats that filter as its own.

## Signing key (decision record)

- Releases are signed with a personal keystore stored as repository secrets: `SIGNING_KEY` (base64 of the .jks), `ALIAS`, `KEY_STORE_PASSWORD` and `KEY_PASSWORD`.
- **Keep an offline backup of the keystore.** Losing it means uninstalling and reinstalling again.
- The app ID stays `neth.iecal.curbox`, so the patched app replaces official Curbox. Two copies with competing accessibility services would fight each other.

## Cost

- GitHub Actions is free for public repositories.
- A daily check takes about 20 seconds; a build takes about 5 to 8 minutes.
- GitHub pauses scheduled workflows after 60 days without repository activity. It emails first, and you turn it back on with **Enable workflow** on the Actions tab.

## License

GPL-3.0, same as Curbox. The patch source is in `patches/grayscale.patch`.
