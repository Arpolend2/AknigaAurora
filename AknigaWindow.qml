import QtQuick 2.6
import Sailfish.Silica 1.0

ApplicationWindow {
    id: window
    allowedOrientations: Orientation.All
    property var player: null

    cover: Component {
        CoverBackground {
            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: coverActionArea.top
                anchors.margins: Theme.paddingMedium
                spacing: Theme.paddingSmall
                clip: true

                Label {
                    width: parent.width
                    text: window.player ? window.player.bookTitle : "Выберите аудиокнигу"
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Label {
                    width: parent.width
                    text: window.player ? window.player.bookAuthor : ""
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryColor
                    elide: Text.ElideRight
                }
            }
            CoverActionList {
                CoverAction {
                    iconSource: "image://theme/icon-cover-previous"
                    onTriggered: if (window.player && window.player.hasBook)
                                     window.player.seekBy(-15)
                }
                CoverAction {
                    iconSource: window.player && window.player.isPlaying
                                ? "image://theme/icon-cover-pause"
                                : "image://theme/icon-cover-play"
                    onTriggered: if (window.player && window.player.hasBook)
                                     window.player.togglePlayback()
                }
                CoverAction {
                    iconSource: "image://theme/icon-cover-next"
                    onTriggered: if (window.player && window.player.hasBook)
                                     window.player.seekBy(15)
                }
            }
        }
    }

    initialPage: Component {
        Page {
            allowedOrientations: Orientation.All

            Main {
                id: player
                anchors.fill: parent
                Component.onCompleted: window.player = player
                Component.onDestruction: window.player = null
            }
        }
    }
}
