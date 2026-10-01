<img width="100" height="100" src="https://github.com/user-attachments/assets/1c42dda2-b778-4342-9f94-8f852c3ad652" />

# Reynard Browser

Reynard is a **Gecko-based** web browser for iOS 13+.

Unlike other browsers on iOS that are forced to use Apple's **WebKit** engine (including Safari and all third-party browsers), Reynard uses **Gecko**. This is the same engine that powers the Firefox browser on desktop and Android devices.

This project is mainly for users on older iOS versions who are stuck with an outdated version of WebKit. Because WebKit is bundled with the OS, these devices cannot receive engine updates and often fail to load modern websites. By using Gecko, which is kept up to date independently, Reynard allows these sites to work again. Users on newer iOS versions can also use the browser if they want an alternative to WebKit, including Firefox add-ons and other Gecko-exclusive features.

## Installation

The latest builds are uploaded only as [GitHub Actions artifacts](https://github.com/qwer12345uui/reynard-browser/actions/workflows/build-trollstore.yml). Open the latest successful **Build RootHide IPA** run and download the `Reynard-RootHide-IPA-<commit>` artifact. This fork does not publish new GitHub Releases and intentionally produces **only** the RootHide package, `Reynard-Jailbroken.ipa`. Please note that this project is still in an early experimental state, so expect bugs and missing features.

### RootHide jailbreak

Reynard is available as a standard build, a TrollStore build[^2], and a jailbroken build[^3], depending on your iOS version and installation method:

<table>
  <thead>
    <tr>
      <th>Method</th>
      <th>iOS version</th>
      <th>Build</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><a href="https://altstore.io/">AltStore</a> or <a href="https://sidestore.io/">SideStore</a></td>
      <td>iOS 17.4+</td>
      <td><a href="https://github.com/minh-ton/reynard-browser/releases/latest/download/Reynard.ipa"><code>Reynard.ipa</code></a></td>
    </tr>
    <tr>
      <td><a href="https://github.com/opa334/TrollStore">TrollStore</a></td>
      <td>iOS 14 - 16.6.1, 17.0</td>
      <td><a href="https://github.com/minh-ton/reynard-browser/releases/latest/download/Reynard-TrollStore.tipa"><code>Reynard-TrollStore.tipa</code></a></td>
    </tr>
    <tr>
      <td><a href="https://github.com/opa334/TrollStore">TrollStore</a></td>
      <td>Jailbroken iOS 14</td>
      <td><a href="https://github.com/minh-ton/reynard-browser/releases/latest/download/Reynard-Jailbroken.ipa"><code>Reynard-Jailbroken.ipa</code></a></td>
    </tr>
    <tr>
      <td><a href="https://havoc.app/package/trollstorelite">TrollStore Lite</a></td>
      <td>Jailbroken iOS 16.7 - 16.7.16, 17.0.1+</td>
      <td><a href="https://github.com/minh-ton/reynard-browser/releases/latest/download/Reynard-TrollStore.tipa"><code>Reynard-TrollStore.tipa</code></a></td>
    </tr>
    <tr>
      <td><a href="https://www.tigisoftware.com/default/?page_id=78">Filza File Manager</a> + <a href="https://github.com/akemin-dayo/AppSync">AppSync Unified</a></td>
      <td>Jailbroken iOS 13</td>
      <td><a href="https://github.com/minh-ton/reynard-browser/releases/latest/download/Reynard-Jailbroken.ipa"><code>Reynard-Jailbroken.ipa</code></a></td>
    </tr>
  </tbody>
</table>

[^2]: The TrollStore build provides automatic JIT enablement, better performance, and automatic app updates. For automatic app updates, make sure **URL Scheme Enabled** is turned on in TrollStore.
[^3]: The jailbroken build provides automatic JIT enablement and better performance.

> [!NOTE]
> Although jailbroken builds are available, using Reynard on a jailbroken device is not recommended. Tweaks and other system modifications may affect the browser's performance, stability, or functionality, and support for resulting issues may be limited. **On any jailbroken device**, disable tweak injection for Reynard and its extensions using tools such as [Choicy](https://github.com/opa334/Choicy).

**For AltStore or SideStore installations:**

Make sure to select **Keep App Extensions** during installation, as Reynard will not work without them.

You can also [click here](https://altdirect.app/?url=https://github.com/minh-ton/reynard-browser/releases/download/0.0.1-a1/source.json&exclude=livecontainer,stikstore,trollapps,feather) to add the AltSource for Reynard to AltStore or SideStore.

> [!IMPORTANT]
> - **LiveContainer is not supported** due to its own limitations.
> - Sideloading using a distribution certificate for signing is **not supported**.⁠
> - Other sideloading methods may be **incompatible with Reynard**, and **no support will be provided** for issues arising from them.

## Preview

### iOS 14 (iPhone 6S Plus, 14.1)

These sites are known to break or render incorrectly on iOS 14. The screenshots below compare how they load in Safari versus Reynard.

<table>
  <tr>
    <th colspan="2">github.com</th>
    <th colspan="2">chatgpt.com</th>
    <th colspan="2">apple.com</th>
  </tr>
  <tr>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
    <td align="center">Safari</td>
    <td align="center">Reynard</td>
  </tr>
  <tr>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/d89f4385-c478-4aea-aa9d-6c9fca72252b"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/917ee435-39cb-469d-835f-8e69f9e13d03"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/1a68024e-83d4-489c-a576-26d5ea43011c"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/6880b1ac-63f9-421f-a373-5d69c5745cd7"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/d237118e-be3b-43d1-b14c-032784b43571"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/9f799569-d712-44d0-918a-21d523874c6e"><br>
    </td>
  </tr>
</table>

### iOS 15 (iPhone 7, 15.8.6)

<table>
  <tr>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/a7f1b302-51b6-4afe-a2ce-35b518e5b761"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/f5dbfba5-c1a8-4729-bd7d-b96a7ace1237"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/986c8cfb-7979-4f4b-9305-73ebd1a87b19"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/544ff493-6807-4b2f-b526-6d34f029e1d3"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/31ef9486-8631-4d0e-ad9a-1281d513151f"><br>
    </td>
  </tr>
</table>

### iOS 26 (iPhone 13 mini, 26.1)

Reynard also works great on the latest version of iOS!

<table>
  <tr>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/974e8ce1-f798-4bef-bac1-621ee535c5ee"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/1429c985-f439-4e58-9385-0eefef4add4c"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/a9eeaf68-828f-4ead-b619-8b9914e0ed2c"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/bbc08422-4bf3-4928-933e-71cdad551fed"><br>
    </td>
    <td>
      <img width=150 src="https://github.com/user-attachments/assets/cf01d298-a8d2-49ea-a557-7b1bbd1d893a"><br>
    </td>
  </tr>
</table>

## Building

> [!WARNING]
> Build instructions are included below for reference. Please be aware that I **do not** provide support for issues or errors encountered during the build process.

To build the project, you'll need Xcode, [Python 3](https://www.python.org/downloads/), [Rust and Cargo](https://doc.rust-lang.org/cargo/getting-started/installation.html), and [ldid](https://formulae.brew.sh/formula/ldid).

Clone the repository.

```bash
git clone --recursive https://github.com/minh-ton/reynard-browser
cd reynard-browser
```

Download Gecko and apply patches.

```bash
./tools/development/update-gecko.sh
./tools/development/apply-patches.sh
```

Build dependencies and the Gecko engine.

```bash
./tools/development/build-idevice.sh
./tools/development/build-gecko.sh
```

To run Reynard, open `Reynard.xcodeproj` in Xcode and build/run it from there.

## Notes

This project initially started out of curiosity. I wanted to see if I could get Gecko to run without the [BrowserEngineKit](https://developer.apple.com/documentation/browserenginekit) framework, so it could be further modified to run on iOS versions as far back as possible. I got it working, and since then, I’ve been focusing on developing engine patches for better UIKit integration, fixing bugs, and turning this into a full, usable browser.

If you’ve come across this repository and find it interesting, I’d love to get help or collaborate on it. I’m learning as I go here and don’t have much prior experience with iOS app development or with Gecko itself, so any contributions, feedback, or pointers would be greatly appreciated.

## Acknowledgements
- [LiveContainer](https://github.com/LiveContainer/LiveContainer): app extension handling and NSExtension usage.
- [StikDebug](https://github.com/StephenDev0/StikDebug) and [idevice](https://github.com/jkcoxson/idevice): pairing-based JIT enablement support.
- [TrollStore](https://github.com/opa334/TrollStore): spawning a binary as root and JIT enablement.
- [Amethyst-iOS](https://github.com/AngelAuraMC/Amethyst-iOS), [dolphin-ios](https://github.com/OatmealDome/dolphin-ios), [DukeX](https://github.com/MaftyManicEMU/DukeX), and [MeloNX](https://git.ryujinx.app/projects/MeloNX): Various utility functions, numerous private API usage, and JIT memory handling.
- [Pre-existing work](https://bugzilla.mozilla.org/show_bug.cgi?id=1882872) on bringing Gecko to iOS using BrowserEngineKit: most of the difficult engine integration. 

## License

This project is licensed under the [GNU General Public License v3.0](https://github.com/minh-ton/reynard-browser/blob/main/LICENSE), except for the `patches` directory containing the modifications to the Firefox Gecko engine and therefore is licensed under the [Mozilla Public License 2.0](https://github.com/minh-ton/reynard-browser/blob/main/LICENSE.firefox).
