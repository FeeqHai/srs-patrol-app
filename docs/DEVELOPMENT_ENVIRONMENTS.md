# Local and Pi launch profiles

Updated: 2026-09-03.

The Flutter project has two VS Code launch configurations in `.vscode/launch.json`.
Each passes `SRS_API_BASE_URL` to the existing `ApiConstants` configuration. Both
run the same source code in debug mode on the selected device.

| Launch profile | API address | Database used |
| --- | --- | --- |
| iRonda - Local (XAMPP) | `http://<xampp-host>/srs_api/` | Local XAMPP `srs_db` |
| iRonda - Pi (HTTPS) | `https://api.ironda.app/srs_api/` | Raspberry Pi `srs_db` |

Use Local for development. Actions in the Pi profile read and update the Pi's
actual records. Profiles do not deploy PHP files, apply database migrations, or
synchronize records or uploaded images. Database credentials remain in the PHP
server configuration; the app only needs the API address.

## Run from VS Code

1. Open `C:\Users\rafee\Documents\UTeM\FYP\srs_app` as the VS Code folder,
   with the Flutter extension enabled.
2. Select your Android phone or emulator in the bottom status bar.
3. Open **Run and Debug** with **Ctrl+Shift+D**.
4. Select **iRonda - Local (XAMPP)** or **iRonda - Pi (HTTPS)** in the launch dropdown.
5. Press **F5**. Local prompts for the XAMPP host; Pi uses its fixed HTTPS address.

For Local, start Apache and MySQL in XAMPP. Choose the host according to where
the app is running:

| App runs on | XAMPP host to enter |
| --- | --- |
| Physical phone on the laptop's Wi-Fi | Laptop's current Wi-Fi IPv4 address; default `192.168.1.109` |
| Standard Android Studio emulator | `10.0.2.2` |
| Chrome on the XAMPP laptop | `127.0.0.1` |

Enter only the host, without `http://` or `/srs_api/`. If the laptop's address
changes, enter the new address at the prompt. A phone must be able to reach the
laptop over the local network. Pi access requires the Pi and its Cloudflare
tunnel to be running with an Internet connection.

## Switch servers

Log out in the app before switching. Stop the current debug session, select the
other launch profile, press F5, and sign in again. Both profiles use the same app
installation and saved-session storage. Their login tokens are not interchangeable.
Changing the API address requires a new launch; hot reload alone does not apply it.

## Terminal and release builds

VS Code launch selections do not affect separate terminal commands. For a
physical phone, the equivalent development commands are:

```powershell
flutter run --dart-define=SRS_API_BASE_URL=http://192.168.1.109/srs_api/
flutter run --dart-define=SRS_API_BASE_URL=https://api.ironda.app/srs_api/
```

Run one command for the server you want. A bare `flutter run` or build without an
override still uses the legacy DigitalOcean default in `ApiConstants`. For the
lecturer's APK, explicitly pass the Pi HTTPS address when building. Private
release signing and device acceptance remain pending; see
[Raspberry Pi deployment](RASPBERRY_PI_DEPLOYMENT.md).

## Verification

The launch configuration parses successfully, both Flutter entries point to
`lib/main.dart`, and the Local input resolves to the expected API address. On
2026-09-03, read-only requests to `auth/get_locations.php?level=states` returned
HTTP 200 and JSON `status: success` from both the laptop's `192.168.1.109` address
and the public Pi hostname using ordinary DNS and certificate validation. No
database records were changed. Launching these profiles on an Android device and
checking login still need a manual walkthrough.

Configuration references: [Dart Code launch configurations](https://dartcode.org/docs/launch-configuration/),
[VS Code input variables](https://code.visualstudio.com/docs/reference/variables-reference#_input-variables),
and [Dart environment declarations](https://dart.dev/libraries/core/environment-declarations).
