# Manual setup through the Amphetamine UI

If you'd rather click through Amphetamine's Settings window yourself instead of running the installer, this is the full click-path to reproduce the default preset.

## 1. Install Amphetamine

From the [Mac App Store](https://apps.apple.com/us/app/amphetamine/id937984704). Launch it once so the menu-bar icon appears (a small pill icon near the clock).

## 2. Open Settings

Click the Amphetamine menu-bar icon → **Settings…**.

## 3. General tab

- ✅ **Launch Amphetamine at login**
- ✅ **Start session when Amphetamine launches**
- ✅ **Hide Amphetamine in the Dock** *(personal preference — menu-bar only)*

## 4. Session Defaults tab

Under **Default Duration**:
- **Indefinitely**

Under **Display Sleep**:
- ✅ **Allow display sleep**

Under **Closed-Display Mode**:
- ❌ **Allow system sleep when display is closed** — this is the critical one, leave it **unchecked**.

Under **Battery**:
- ✅ **End session if charge (%) is below** — set slider to **30%**
- ✅ **Ignore charge (%) if power adapter is connected**

Under **Power Adapter**:
- Whatever default Amphetamine ships with is fine.

## 5. Verify

Click the menu-bar icon → **Start New Session → Indefinitely**. The icon should change to indicate an active session. Then open Terminal and run:

```bash
pmset -g assertions | grep -i amphetamine
```

You should see a line like:

```
pid XXXXX(Amphetamine): PreventUserIdleSystemSleep named: "Amphetamine (Single-Use - System)"
```

## 6. Close the lid

Close the lid on battery. Your Mac should stay running, internal display off. Open Activity Monitor / iStat Menus / Stats after reopening to confirm it never slept.

---

*Prefer to automate this? Run `./scripts/install.sh` from the repo root and pick option 1.*
