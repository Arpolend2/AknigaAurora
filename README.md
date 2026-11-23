# Akniga for Aurora OS

A lightweight Aurora OS application for browsing https://akniga.org. The site
opens in Aurora's Chromium WebView; the compact player stays visible while
browsing and follows the current book page.

The player bar shows the book cover, title and author, playback position and
duration. Its play/pause and 15-second skip buttons control the site's HTML
audio player. Tapping the progress line seeks within the current track.
The system cover offers play/pause and 15-second backward and forward skips. The app
follows the device's light or dark theme, including on akniga.org, and uses
Aurora's interface size settings.
Web pages are enlarged according to the device's interface scale. Playback
controls follow the site's active player, including while browsing the catalog.
Swipe left or right on the web page to navigate its history. Mouse back and
forward buttons and the scroll wheel are also supported.
The WebView identifies as Android Chrome so the site's mobile offline-download
feature can be offered. Offline books are stored in the WebView's site data.

Open `CMakeLists.txt` in Aurora IDE, choose a kit for the target device, then
build and deploy from the IDE. Internet and Audio permissions are required to
load the catalog and play audio.

The application code is licensed under the WTFPL; website content belongs to
its respective owners.
