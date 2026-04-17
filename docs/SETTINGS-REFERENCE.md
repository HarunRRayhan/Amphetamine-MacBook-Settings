# Settings reference

Every key this repo touches in `com.if.Amphetamine`, what it does, and the value used by the default preset.

The full set of keys Amphetamine writes is larger than this — see `settings/default.xml.plist` for the exhaustive list. The keys below are the ones that change behavior we actually care about.

| Key                                            | Type   | Default preset | Effect                                                                                     |
| ---------------------------------------------- | ------ | -------------- | ------------------------------------------------------------------------------------------ |
| `Launch At Login`                              | bool   | `true` (1)     | Amphetamine starts every time you log in.                                                  |
| `Start Session On Launch`                      | bool   | `true` (1)     | A session begins automatically when Amphetamine launches.                                  |
| `Allow Closed-Display Sleep`                   | bool   | `false` (0)    | When `0`, the Mac stays awake with the lid closed. *This is the critical setting.*         |
| `Allow Display Sleep`                          | bool   | `true` (1)     | Lets the display sleep during a session. Saves battery and reduces heat.                   |
| `End Sessions If Battery Is Below Percentage`  | bool   | `true` (1)     | Enables the battery threshold that auto-ends a session.                                    |
| `Battery Threshold`                            | int    | `30`           | Session ends when battery charge drops below this %.                                       |
| `Ignore Battery on AC`                         | bool   | `true` (1)     | When on AC power, the battery threshold is ignored (so sessions run indefinitely).         |
| `Allow Screen Saver`                           | bool   | `false` (0)    | Prevents the screen saver from starting during a session.                                  |
| `End Sessions On Forced Sleep`                 | bool   | `false` (0)    | If you manually sleep (e.g. hotkey), the session does *not* auto-end.                      |
| `Enable Session Notifications`                 | bool   | `false` (0)    | Suppresses the "session started/ended" notifications.                                      |
| `Enable Session Auto End Notifications`        | bool   | `true` (1)     | Notifies you when a session auto-ends (e.g. hit the battery threshold).                    |
| `Hide Dock Icon`                               | bool   | `true` (1)     | Menu-bar only, no Dock icon.                                                               |

## Reading / writing from the command line

```bash
# Read a value
defaults read com.if.Amphetamine 'Allow Closed-Display Sleep'

# Write a value (Amphetamine must be quit first)
defaults write com.if.Amphetamine 'Battery Threshold' -int 25

# Export everything
defaults export com.if.Amphetamine ~/Desktop/my-settings.plist

# Import everything (overwrites current prefs)
defaults import com.if.Amphetamine ~/Desktop/my-settings.plist
```

## Where the plist lives on disk

Because Amphetamine is a sandboxed Mac App Store app, its preferences are stored in its container, not in `~/Library/Preferences/`:

```
~/Library/Containers/com.if.Amphetamine/Data/Library/Preferences/com.if.Amphetamine.plist
```

The `defaults` command still works with the `com.if.Amphetamine` domain from anywhere — you don't normally need to touch the file directly.

## Caveat: key name stability

Amphetamine's key names have occasionally changed between versions. If a key from this reference doesn't exist on your install, inspect your local plist:

```bash
defaults read com.if.Amphetamine | less
```

…find the corresponding key, and update this document via PR if needed.
