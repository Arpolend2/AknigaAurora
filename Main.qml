import QtQuick 2.6
import Sailfish.Silica 1.0
import Aurora.Controls 1.0
import ru.auroraos.WebView 1.0

Item {
    id: root

    property bool pageLoaded: false
    property bool hasBook: false
    property bool isPlaying: false
    property string bookTitle: "Выберите аудиокнигу"
    property string bookAuthor: "Каталог akniga.org"
    property string coverUrl: ""
    property real currentTime: 0
    property real duration: 0
    property string pageStatus: "Загрузка каталога…"
    readonly property bool darkTheme: Theme.colorScheme === Theme.LightOnDark
    readonly property color panelColor: darkTheme ? "#17212b" : "#f4f4f4"
    readonly property color buttonColor: darkTheme ? "#263746" : "#dce1e4"
    readonly property color pressedColor: darkTheme ? "#374757" : "#c5ced4"

    onDarkThemeChanged: if (pageLoaded) syncPlayer()

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0
        var minutes = Math.floor(seconds / 60)
        var remainder = Math.floor(seconds % 60)
        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder
    }

    function playerPrelude() {
        return "var article=document.querySelector('.book--page[data-bid]');"
                + "var active=document.querySelector('.jpl.player[data-bid]');"
                + "var audio=active?active.querySelector('audio'):null;"
                + "var bid=active?active.getAttribute('data-bid'):'';"
                + "if(!audio){"
                + "var audios=document.querySelectorAll('.jpl[data-bid]:not(.empty) audio');"
                + "for(var i=0;i<audios.length;i++){"
                + "if(!audios[i].paused){audio=audios[i];bid=audio.parentNode.getAttribute('data-bid');break;}}"
                + "}"
                + "if(!audio&&article){"
                + "var containers=document.querySelectorAll('.jpl[data-bid]:not(.empty)');"
                + "for(var j=0;j<containers.length;j++){"
                + "if(containers[j].getAttribute('data-bid')===article.getAttribute('data-bid')){"
                + "audio=containers[j].querySelector('audio');bid=containers[j].getAttribute('data-bid');break;}}"
                + "}"
    }

    function syncPlayer() {
        if (!pageLoaded)
            return

        var script = "(function(){"
                + "if(location.hostname==='akniga.org'&&document.body){"
                + "var dark=" + (darkTheme ? "true" : "false") + ";"
                + "if(document.body.classList.contains('theme-night')!==dark){"
                + "if(typeof switchUserColorScheme==='function')switchUserColorScheme(dark?'dark':'light');"
                + "else document.body.classList.toggle('theme-night',dark);}}"
                + "if(location.hostname!=='akniga.org')return JSON.stringify({book:false});"
                + playerPrelude()
                + "var heading=document.querySelector('.caption__article-main');"
                + "var author=document.querySelector('.caption__article-author');"
                + "var image=document.querySelector('.book--cover img')||document.querySelector('.book--header img');"
                + "var metadata=bid&&typeof bookData!=='undefined'?bookData[bid]:null;"
                + "var title=metadata&&metadata.titleonly?metadata.titleonly:(heading?heading.textContent.trim():'');"
                + "var imageUrl=image?(image.currentSrc||image.src):'';"
                + "var duration=audio&&isFinite(audio.duration)?audio.duration:0;"
                + "var offlineIssue='';"
                + "var downloadContainer=document.querySelector('#hls-download-button-container');"
                + "if(downloadContainer&&typeof window.offlineDownloadAvailable==='function'"
                + "&&window.offlineDownloadAvailable()&&typeof window.initOfflineDownload==='function'"
                + "&&typeof hlsSupport!=='undefined'&&hlsSupport==='true'"
                + "&&typeof forceHlsTransport!=='undefined'&&!forceHlsTransport"
                + "&&typeof _nativeHls!=='undefined'&&typeof _mseAac!=='undefined'"
                + "&&(_nativeHls||_mseAac)){"
                + "forceHlsTransport=true;forceMp3Transport=false;window.initOfflineDownload();}"
                + "if(downloadContainer&&typeof window.offlineDownloadAvailable==='function'"
                + "&&!window.offlineDownloadAvailable()){"
                + "if(!/Android/i.test(navigator.userAgent))offlineIssue='User-Agent не распознан как Android';"
                + "else if(!('serviceWorker' in navigator))offlineIssue='Service Worker недоступен';"
                + "else offlineIssue='Сайт не смог запустить офлайн-режим';"
                + "}"
                + "else if(downloadContainer&&typeof window.offlineDownloadAvailable==='function'){"
                + "var downloadButton=downloadContainer.querySelector('.js-hls-download');"
                + "if(downloadButton&&getComputedStyle(downloadButton).display==='none'){"
                + "if(typeof hlsSupport!=='undefined'&&hlsSupport==='false')offlineIssue='HLS не поддерживается';"
                + "else if(typeof forceHlsTransport!=='undefined'&&!forceHlsTransport"
                + "&&((typeof forceMp3Transport!=='undefined'&&forceMp3Transport)"
                + "||(typeof _nativeHls!=='undefined'&&!_nativeHls&&typeof Hls!=='undefined'&&Hls.isSupported())))"
                + "offlineIssue='HLS: аудиоформат недоступен';"
                + "else offlineIssue='Сайт скрыл кнопку загрузки';"
                + "}}"
                + "return JSON.stringify({book:!!article||!!audio,"
                + "title:title,author:metadata&&metadata.author?metadata.author:(author?author.textContent.trim():''),"
                + "cover:metadata&&metadata.preview?metadata.preview:imageUrl,"
                + "current:audio&&isFinite(audio.currentTime)?audio.currentTime:0,duration:duration,"
                + "playing:!!audio&&!audio.paused,error:audio&&audio.error?audio.error.code:0,"
                + "offlineIssue:offlineIssue});"
                + "})()"

        webView.runJavaScript(script, function(result) {
            if (typeof result !== "string" || result.length === 0) {
                root.pageStatus = "Не удалось получить состояние плеера"
                return
            }
            try {
                var state = JSON.parse(result)
                root.hasBook = state.book
                root.bookTitle = state.title || (state.book ? "Аудиокнига" : "Выберите аудиокнигу")
                root.bookAuthor = state.author || (state.book ? "Слушайте на akniga.org" : "Каталог akniga.org")
                root.coverUrl = state.cover || ""
                root.currentTime = Number(state.current) || 0
                root.duration = Number(state.duration) || 0
                root.isPlaying = state.playing
                root.pageStatus = state.error ? "Ошибка воспроизведения: " + state.error
                                              : (state.offlineIssue || (state.book ? "Аудиокнига на странице" : "Каталог и поиск книг"))
            } catch (error) {
                root.pageStatus = "Не удалось обновить состояние плеера"
            }
        }, function(error) {
            console.warn("Player state:", error)
            root.pageStatus = "Не удалось связаться с плеером"
        })
    }

    function runPlayerCommand(command) {
        if (!pageLoaded)
            return
        var script = "(function(){if(location.hostname!=='akniga.org')return false;"
                + playerPrelude() + command + "})()"
        webView.runJavaScript(script, function(result) {
            if (result === false)
                root.pageStatus = "Плеер ещё не готов"
            else
                root.syncPlayer()
        }, function(error) {
            console.warn("Player command:", error)
            root.pageStatus = "Не удалось управлять плеером"
        })
    }

    function togglePlayback() {
        runPlayerCommand("var bar=document.querySelector('.player__wrapper--bar[data-bid]');"
                         + "var button=bar&&bid===bar.getAttribute('data-bid')"
                         + "?bar.querySelector('.button__player--play'):null;"
                         + "button=button||(article&&article.querySelector('button.button__player--play'));"
                         + "if(button){button.click();return true;}"
                         + "if(audio){if(audio.paused){var play=audio.play();"
                         + "if(play&&play.catch)play.catch(function(e){console.error('Playback failed:',e);});"
                         + "}else audio.pause();return true;}"
                         + "return false;")
    }

    function seekBy(seconds) {
        runPlayerCommand("if(!audio)return false;"
                         + "if(bid&&" + (seconds < 0 ? "typeof playerRewind==='function'" : "typeof playerForward==='function'") + "){"
                         + (seconds < 0 ? "playerRewind(bid);" : "playerForward(bid);") + "return true;}"
                         + "if(!isFinite(audio.duration))return false;"
                         + "audio.currentTime=Math.max(0,Math.min(audio.duration,audio.currentTime+("
                         + seconds + ")));return true;")
    }

    function seekToFraction(fraction) {
        if (duration <= 0)
            return
        var position = Math.max(0, Math.min(1, fraction)) * duration
        runPlayerCommand("if(!audio||!isFinite(audio.duration))return false;"
                         + "audio.currentTime=" + position + ";return true;")
    }

    function navigateBack() {
        if (webView.canGoBack())
            webView.goBack()
    }

    function navigateForward() {
        if (webView.canGoForward())
            webView.goForward()
    }

    AppBar {
        id: topBar
        objectName: "topBar"
        headerText: "AKNIGA"
        subHeaderText: root.pageStatus
        background: true

        AppBarButton {
            objectName: "backButton"
            context: "Назад"
            icon.source: "image://theme/icon-m-back"
            onClicked: root.navigateBack()
        }

        AppBarSpacer {}

        AppBarButton {
            objectName: "homeButton"
            context: "Главная"
            icon.source: "image://theme/icon-m-home"
            onClicked: {
                root.pageLoaded = false
                webView.url = "https://akniga.org/"
            }
        }
    }

    WebView {
        id: webView
        anchors.top: topBar.bottom
        anchors.bottom: player.top
        width: parent.width
        focus: true
        dpr: Math.max(1, Theme.pixelRatio * 1.8)
        userAgent: "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 "
                   + "(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"

        TouchInput {
            id: touchInput
            objectName: "webTouchInput"
            property int navigationPoint: -1
            property real startX: 0
            property real startY: 0
            property bool navigationCandidate: false

            onPressed: {
                if (navigationPoint !== -1 || touchPoints.length !== 1) {
                    navigationCandidate = false
                    return
                }
                var point = touchPoints[0]
                navigationPoint = point.pointId
                startX = point.x
                startY = point.y
                navigationCandidate = true
            }
            onReleased: {
                for (var i = 0; i < touchPoints.length; ++i) {
                    var point = touchPoints[i]
                    if (point.pointId !== navigationPoint)
                        continue
                    var dx = point.x - startX
                    var dy = point.y - startY
                    if (navigationCandidate && Math.abs(dx) >= Theme.dp(64) && Math.abs(dx) > Math.abs(dy) * 2) {
                        if (dx > 0)
                            root.navigateBack()
                        else
                            root.navigateForward()
                    }
                    navigationPoint = -1
                    navigationCandidate = false
                    break
                }
            }
            onCanceled: {
                navigationPoint = -1
                navigationCandidate = false
            }
        }
        MouseInput {}
        KeyboardInput { enabled: true }

        onLoadFinished: {
            root.pageLoaded = true
            root.syncPlayer()
        }
        onLoadError: {
            root.pageLoaded = false
            root.pageStatus = "Не удалось загрузить сайт"
        }
        Component.onCompleted: url = "https://akniga.org/"
    }

    MouseArea {
        anchors.fill: parent
        z: 100
        acceptedButtons: Qt.BackButton | Qt.ForwardButton
        onClicked: {
            if (mouse.button === Qt.BackButton)
                root.navigateBack()
            else if (mouse.button === Qt.ForwardButton)
                root.navigateForward()
        }
    }

    Rectangle {
        id: player
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(Theme.itemSizeLarge, trackInfo.implicitHeight + Theme.paddingMedium * 2,
                         controls.implicitHeight + Theme.paddingSmall * 2)
        color: root.panelColor

        Rectangle {
            id: cover
            width: Theme.itemSizeMedium
            height: width
            anchors.left: parent.left
            anchors.leftMargin: Theme.paddingMedium
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.paddingSmall
            color: "#5b4638"
            clip: true

            Image {
                anchors.fill: parent
                source: root.coverUrl
                visible: root.coverUrl !== ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: !root.coverUrl
                text: "♫"
                color: "#f0d7b1"
                font.pixelSize: Theme.fontSizeLarge
            }
            Rectangle {
                width: Theme.itemSizeSmall * 0.65
                height: width
                anchors.centerIn: parent
                radius: width / 2
                color: "#bf17212b"
                opacity: root.hasBook ? 1 : 0.45

                Text {
                    anchors.centerIn: parent
                    text: root.isPlaying ? "Ⅱ" : "▶"
                    color: "#ffffff"
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.hasBook
                    onClicked: root.togglePlayback()
                }
            }
        }

        Column {
            id: trackInfo
            objectName: "playerTrackInfo"
            anchors.left: cover.right
            anchors.leftMargin: Theme.paddingSmall
            anchors.right: controls.left
            anchors.rightMargin: Theme.paddingSmall
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall / 2

            Text {
                width: parent.width
                text: root.bookTitle
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.bookAuthor
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                elide: Text.ElideRight
            }
            Item {
                width: parent.width
                height: Theme.fontSizeExtraSmall + Theme.paddingMedium
                Rectangle {
                    id: progressTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.max(2, Theme.paddingSmall / 3)
                    radius: height / 2
                    color: root.buttonColor
                    Rectangle {
                        width: root.duration > 0
                               ? parent.width * Math.min(1, root.currentTime / root.duration) : 0
                        height: parent.height
                        radius: parent.radius
                        color: Theme.highlightColor
                    }
                    MouseArea {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Theme.itemSizeSmall / 2
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.seekToFraction(mouse.x / width)
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.top: progressTrack.bottom
                    text: root.formatTime(root.currentTime)
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
                Text {
                    anchors.right: parent.right
                    anchors.top: progressTrack.bottom
                    text: root.duration > 0 ? root.formatTime(root.duration) : "--:--"
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                }
            }
        }

        Row {
            id: controls
            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingMedium
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.paddingSmall / 2

            Repeater {
                model: [
                    { label: "−15", command: "back", icon: "image://theme/icon-cover-previous" },
                    { label: "+15", command: "forward", icon: "image://theme/icon-cover-next" }
                ]

                delegate: Rectangle {
                    width: Math.max(Theme.itemSizeSmall * 0.8,
                                    controlContent.implicitWidth + Theme.paddingSmall * 2)
                    height: Theme.itemSizeSmall
                    radius: Theme.paddingMedium
                    color: controlMouse.pressed ? root.pressedColor : root.buttonColor

                    Row {
                        id: controlContent
                        anchors.centerIn: parent
                        spacing: Theme.paddingSmall / 2
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.command === "back"
                            text: modelData.label
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeTiny
                        }
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.iconSizeSmall
                            height: width
                            source: modelData.icon
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.command === "forward"
                            text: modelData.label
                            color: Theme.primaryColor
                            font.pixelSize: Theme.fontSizeTiny
                        }
                    }
                    MouseArea {
                        id: controlMouse
                        anchors.fill: parent
                        enabled: root.hasBook
                        onClicked: {
                            root.seekBy(modelData.command === "back" ? -15 : 15)
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.pageLoaded
        onTriggered: root.syncPlayer()
    }
}
