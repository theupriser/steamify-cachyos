// Texts per item; the backend's labels are the fallback.
pragma Singleton
import QtQuick

QtObject {
    readonly property var items: ({
        gaming: { label: "SteamOS conversion", hint: "Boot into gaming mode, Steam on the desktop",
                  body: "Boots straight into gaming mode. Switch to Desktop in Steam works, and Return to Gaming Mode on the desktop brings you back.",
                  changes: ["Autologin into gamescope", "Return to Gaming Mode shortcut"] },
        boot: { label: "Boot into", hint: "Where the PC starts",
                body: "Where the PC starts after a restart. Switching back and forth works the same either way.",
                changes: ["Desktop: the Plasma session is set before login", "Gaming: the SteamOS default"] },
        silent: { label: "Start Steam silently in desktop mode", hint: "In the tray at login on the desktop, no window",
                  body: "Steam starts by itself when you log in to the Plasma desktop, in the tray without a window. Gaming mode starts its own Steam.",
                  changes: ["Steam is started with -steamdeck -silent (Steam's own autostart entry, desktop only)", "Off: the autostart entry is removed again"] },
        nvidia: { label: "Gaming on NVIDIA", hint: "Steam on the desktop, started at login",
                  body: "gamescope's own gaming mode shows a corrupted picture on NVIDIA graphics cards (an open NVIDIA driver bug), so it isn't offered here. This puts Steam on the Plasma desktop instead and starts it when you log in.",
                  changes: ["Steam is installed when it's missing", "Steam starts at login (a systemd user service)", "Off: the service is removed again; Steam is only removed if Steamify installed it"] },
        bigpicture: { label: "Steam starts in Big Picture", hint: "The controller-friendly Steam, or the normal window",
                      body: "Steam opens in Big Picture at login, which works well with a controller on the TV. Untick it for Steam's normal window.",
                      changes: ["Steam is started with -gamepadui", "Plasma starts with an empty session, so old windows don't cover Big Picture", "Off: Steam starts in its normal window"] },
        nvsilent: { label: "Start Steam silently", hint: "In the tray at login, no window",
                    body: "Steam starts in the tray at login without a window. Not together with Big Picture: ticking one unticks the other.",
                    changes: ["Steam is started with -silent", "Off: Steam starts in its normal window"] },
        theme: { label: "SteamOS theme", hint: "Vapor look for the desktop, Add to Steam",
                 body: "The Vapor look of SteamOS for the desktop, with its panel, launcher icon and wallpaper.",
                 changes: ["cachyos-vapor global theme", "Add to Steam in right-click menus", "Nested Desktop, Steam keyboard window rule"] },
        glyphs: { label: "Steam Deck/Machine icons", hint: "Deck button icons in gaming mode",
                  body: "Steam shows Steam Deck button icons in gaming mode.", changes: ["STEAM_GAMEPADUI_ARGS -steamos3"] },
        single: { label: "Single user mode", hint: "No password, lock screen or wallet prompts",
                  body: "Like SteamOS: never a login or lock screen, and no KDE wallet password prompts. Typing a password with a controller is no fun.",
                  changes: ["No lock screen or user switching", "Valve's empty wallet; your own is kept aside", "Launcher shows Sleep, Restart, Shut Down only"] },
        launcher: { label: "Steamify shortcut", hint: "The app on the desktop and in the launcher",
                    body: "Opens the newest Steamify app, so you never need the install command again. Steamify Terminal in the launcher opens the terminal menu.",
                    changes: ["Steamify CachyOS on the desktop and in the launcher (the app)", "Steamify Terminal in the launcher"] },
        steamgame: { label: "Add as non-Steam game", hint: "Steamify in your Steam library",
                     body: "Adds Steamify to your Steam library as a non-Steam game. Started from Steam it gets your controller (a Steam Controller only talks to Steam while Steam runs), and you can open it in gaming mode. Steam closes for a moment and starts again, since it only reads its games list at startup: so this is done from the desktop, not from gaming mode or with Steamify started from Steam.",
                     changes: ["Steamify CachyOS in your Steam library, with its icon", "An entry that's already there is updated, not added twice", "Off (or the shortcut off): removed from the library again"] },
        notify: { label: "Update notifications", hint: "A notification when there's a new Steamify",
                  body: "Checks once a day and when you log in to the desktop. When there's a new Steamify you get a notification and a tray icon: open the app to see what's new and choose what to update, or skip that version. It never updates anything by itself.",
                  changes: ["A daily check (systemd user timer), only on the desktop", "Tray icon only while an update is waiting", "Skip this version: quiet until the next one"] },
        extended_controller_support: { label: "Extended controller support", hint: "Xbox wireless dongle, Xbox controllers over Bluetooth",
                  body: "Drivers for Xbox controllers that Linux doesn't handle well by itself. xone makes the Xbox wireless dongle work (the kernel has no driver for it), xpadneo gives an Xbox controller over Bluetooth rumble including the triggers, the right button mapping and its battery level. They are built for every installed kernel, which takes a minute or two each.",
                  changes: ["xone (the dongle) with its firmware, and xpadneo (Bluetooth), from the CachyOS repo", "Kernel headers for every installed kernel, so the drivers build for each", "Off: only what Steamify installed is removed again"] },
        vram: { label: "VRAM booster", hint: "The game in front keeps its VRAM",
                body: "Like SteamOS 3.9: the game you're playing keeps its video memory, and background apps are moved out first. Without it a game that needs most of the video memory can spill into system RAM and stutter. Shown for GPUs whose driver supports it (AMD, Intel, NVIDIA with its open kernel modules from driver 615) on kernel 7.2 or newer.",
                changes: ["dmemcg-booster (system and user service)", "plasma-foreground-booster, which tells it which window is in front", "Off: removed again, unless you had installed them yourself"] },
        cec: { label: "HDMI-CEC", hint: "Use Steam with the TV remote, TV on/off with the PC", experimental: true,
               body: "Use Steam with your TV remote, and the TV turns on and off with the PC. Turn on CEC on the TV too (Sony: BRAVIA Sync, Samsung: Anynet+, LG: SimpLink).",
               changes: ["Valve's cecd and cec-audio-control", "HDMI CEC section in Steam's Display settings", "Volume buttons for the TV in the Quick Access menu"] },
        cecaudio: { label: "HDMI-CEC volume", hint: "The TV's volume buttons in Steam, with Valve's PipeWire and WirePlumber",
                    body: "Steam's Audio settings get SteamOS's TV Volume buttons (minus, plus, mute) and the HDMI CEC toggle, instead of a slider that doesn't reach the TV. That part of Steam only works with Valve's builds of PipeWire and WirePlumber, which carry a patch CachyOS's don't have. They replace CachyOS's, so audio on this PC may behave differently, and PipeWire stays a little behind CachyOS's version (Valve takes it from Arch with a delay).",
                    changes: ["PipeWire and WirePlumber, 64-bit and 32-bit, from Valve's SteamOS repositories (checksums verified), in a local pacman repository listed before CachyOS's, so updates don't undo it", "A weekly timer fetches Valve's newer builds into that repository; the next pacman update installs them", "Valve's packages bring steamdeck-dsp and noisetorch along", "Needs a restart (nothing is restarted live, so a Moonlight stream keeps running until then); off: CachyOS's PipeWire and WirePlumber come back"] },
        machine: { label: "Steam Machine support", hint: "LED bar, fan and performance settings in Steam",
                   body: "The front LED bar works, Steam's hardware settings work, and the power button puts it to sleep like a console.",
                   changes: ["leds-valve driver for every kernel (DKMS)", "steamos-manager for Steam's settings", "Console-like power handling"] },
        fancontrol: { label: "Fan monitoring / control (DKMS)", hint: "Sensors and Steam's OS fan curve",
                      body: "Adds the Fremont sensor modules and CachyOS's jupiter-fan-control package. Steam's existing switch still chooses between the OS fan curve and firmware control; the package can be installed while its service is inactive.",
                      changes: ["Missing steamdeck and steamdeck_hwmon providers for each installed kernel (DKMS)", "jupiter-fan-control from the official CachyOS repositories when it is missing", "Modules are loaded at the next boot; nothing is loaded or started while Steamify runs", "Off: the service hands control back to firmware before Steamify-owned files are removed"] },
        poweroff: { label: "Power-off fix", hint: "Stays off after shutting down",
                    body: "With recent kernels the Steam Machine starts again right after shutting down: the firmware leaves a wake bit set, and newer kernels (7.2, and updates of 6.x, 7.0 and 7.1) no longer clear it. Valve's own kernel clears it; this small module does the same right before power-off.",
                    changes: ["steamify-fremont-poweroff module for each installed kernel (DKMS)", "Only on a Steam Machine, only touches that one wake bit", "Off: recent kernels may start it again after shutting down"] },
        wifi: { label: "Wi-Fi firmware from SteamOS", hint: "Wake-on-WLAN works",
                body: "The Steam Machine's Wi-Fi chip has a different firmware build on SteamOS than on CachyOS, with the same version number. With CachyOS's the machine wakes up again right away when it sleeps with Wake-on-WLAN on. This installs Valve's build, so it stays asleep and wakes on a Wi-Fi magic packet.",
                changes: ["Valve's amss.bin for the QCA2066 Wi-Fi chip, from SteamOS's holo-main repository (checksum verified), in /usr/lib/firmware/updates", "Nothing of linux-firmware is overwritten, so its updates don't undo it", "Needs a restart; off: one file removed, CachyOS's firmware is used again"] },
        wol: { label: "Wake-on-LAN", hint: "Wakes on a magic packet over the cable",
               body: "Wakes the Steam Machine from sleep with a magic packet over the network cable. It does not work from power-off: that was tried on a Steam Machine and does not start it. Linux forgets this setting at every restart, so NetworkManager keeps it.",
               changes: ["One NetworkManager setting (/etc/NetworkManager/conf.d), nothing else of NetworkManager is changed", "From sleep only, not from power-off", "Off: the file is removed again"] },
        wowlan: { label: "Wake-on-WLAN", hint: "Wakes from sleep on a magic packet over Wi-Fi",
                  body: "Wakes the Steam Machine from sleep with a magic packet over Wi-Fi. It does not work from power-off. It needs the SteamOS Wi-Fi firmware, so that item is ticked along with this one: with CachyOS's own firmware the machine wakes up again right away.",
                  changes: ["A NetworkManager dispatcher script turns it on as soon as the Wi-Fi connects (also before the first sleep after a restart)", "A small script in /usr/lib/systemd/system-sleep turns it on again right before every sleep", "Brings along the Wi-Fi firmware from SteamOS", "Off: both scripts are removed again"] },
        kpin: { label: "Pin the kernel", hint: "No longer needed: untick for CachyOS's current kernel",
                body: "Kept the Steam Machine on CachyOS kernel 7.1.6, which powered off properly. The power-off fix does that on every kernel now, so the pin is removed and CachyOS's current kernel comes back.",
                changes: ["Removed from IgnorePkg", "linux-cachyos updated to CachyOS's current version"] },
        hdmi: { label: "HDMI refresh boost", hint: "No longer needed: removed",
                body: "Made HDMI displays run above 60 Hz on the pinned kernel. Current kernels do that themselves, so what's left of it is removed and every display uses its own EDID again.",
                changes: ["Saved display EDIDs and the hotplug service removed", "The old kernel parameter removed, if it's still there"] },
        bios: { label: "Update BIOS", hint: "",
                body: "Installs Valve's newest Steam Machine BIOS, at your own risk. It checks Valve's checksum and asks fwupd whether the file fits this machine, then warns you twice before anything is written.",
                changes: ["Valve's fremont-hw-support package (checksum checked)", "fwupd writes the BIOS during the next restart", "Keep the power on until the machine has fully started again"] }
    })
    // Replaces the explanation of an option that can't be turned on here.
    readonly property var unsupported: ({
        // The body comes from the backend (item.note): it depends on the driver.
        vram: { changes: ["Nothing until then"] }
    })

    // Per plan action: the review's chip [text, colour, background] and the
    // progress screen's verb.
    readonly property var actions: ({
        on: ["Turn on", Theme.good, Theme.goodBg, "Turn on "], off: ["Turn off", Theme.bad, Theme.badBg, "Turn off "],
        again: ["Re-apply", Theme.info, Theme.infoBg, "Re-apply "], update: ["Update", Theme.warn, Theme.warnBg, ""],
        desktop: ["Desktop", Theme.info, Theme.infoBg, "Boot into "], gaming: ["Gaming", Theme.info, Theme.infoBg, "Boot into "],
        check: ["Check", Theme.warn, Theme.warnBg, "Download and check the "], flash: ["Flash", Theme.bad, Theme.badBg, "Hand to fwupd: the "]
    })

    function of(item) {
        var tx = items[item.id] || {};
        if (item.selectable !== false || !unsupported[item.id]) return tx;
        return Object.assign({}, tx, unsupported[item.id], item.note ? { body: item.note } : {});
    }
    function label(id, fallback) { return (items[id] || {}).label || fallback || id; }
}
