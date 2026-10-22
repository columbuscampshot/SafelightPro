# Safelight

An iPhone app for the Camp Snap Pro, styled like an old darkroom.

Plug your camera into your iPhone and Safelight lets you swap the filters on the dial and pull your photos into the Photos app. No computer, and no digging through the Files app.

Safelight is a personal hobby project. It is not affiliated with or endorsed by Camp Snap.

## What it does

1. **Connects on its own.** Plug the camera in with a USB-C cable and the safelight lamp turns on.
2. **Developing trays.** The four dial positions (STD, VTG1, VTG2, BW) show as trays. Tap one, pick a filter, and Safelight renames the file and copies it to the camera.
3. **Chemical shelf.** Keeps all your `.flt` filter files on your phone so you can swap looks in seconds.
4. **Film strip.** New photos show as negatives. Tap Develop and they go into a Camp Snap album in Photos. Safelight remembers what it already imported, so you never get duplicates.
5. **Clean up.** Clear photos off the camera once they're safely in Photos.

Safelight doesn't include any filters. Build your own with Camp Snap's filter tool (choose CS-Pro Camera), or use filters the community has shared.

## What you need

1. An iPhone running iOS 17 or later
2. A Mac with Xcode 16 or later (free from the Mac App Store)
3. A free Apple account
4. A Camp Snap Pro and a USB-C cable that carries data. Older Lightning iPhones need Apple's USB camera adapter.

## Install it on your iPhone

1. Download this project. Click the green Code button, then Download ZIP, and unzip it.
2. Open `Safelight.xcodeproj` in Xcode.
3. In Xcode, open Settings, then Accounts, and sign in with your Apple account.
4. Click Safelight in the left sidebar, choose the Safelight target, and open Signing & Capabilities. Pick your name under Team.
5. Change the Bundle Identifier from `com.example.safelight` to something unique, like `com.yourname.safelight`.
6. Plug your iPhone into the Mac. If the phone asks, tap Trust.
7. On the iPhone, turn on Developer Mode in Settings, Privacy & Security, Developer Mode. The phone restarts.
8. In Xcode, pick your iPhone at the top of the window. Make sure it's your phone and not a simulator. Then press Run.
9. The first launch is blocked. On the iPhone, go to Settings, General, VPN & Device Management, tap your Apple account, and tap Trust.

With a free Apple account the app stops opening after 7 days. Plug in and press Run again to renew it. A paid Apple Developer account extends that to a year.

## First run

1. Plug in the camera and tap Find my camera.
2. Tap Browse, tap the camera under Locations, then tap Open. You only do this once.
3. Add filters with the Add .flt filters button. If they came in a zip, tap the zip in the Files app first to unpack it.

Your filters also appear in the Files app under On My iPhone, Safelight, Filters.

## Good to know

1. The Camp Snap Pro's stock filters are built into the camera. Loading a filter overrides that dial position. Return to camera default in each tray removes your filter and should bring the stock look back. Test it with one tray first.
2. Clearing frames only deletes photos Safelight already put into Photos.
3. Safelight never connects to the internet and collects no data.

## License

MIT. See LICENSE.
