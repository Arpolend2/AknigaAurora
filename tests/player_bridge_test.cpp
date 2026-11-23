#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJSEngine>
#include <QMouseEvent>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QWheelEvent>

#include <cstdio>

static void check(bool condition, const char *message)
{
    if (!condition) {
        std::fprintf(stderr, "FAIL: %s\n", message);
        std::exit(1);
    }
}

static void writeFile(const QString &path, const QByteArray &contents)
{
    check(QDir().mkpath(QFileInfo(path).path()), "create test module directory");
    QFile file(path);
    check(file.open(QIODevice::WriteOnly), "open test module");
    check(file.write(contents) == contents.size(), "write test module");
}

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    check(argc == 2, "pass the path to Main.qml");
    QTemporaryDir modules;
    check(modules.isValid(), "create temporary module directory");

    const QString web = modules.path() + "/ru/auroraos/WebView/";
    writeFile(web + "qmldir", "module ru.auroraos.WebView\nWebView 1.0 WebView.qml\n"
                             "TouchInput 1.0 TouchInput.qml\nMouseInput 1.0 MouseInput.qml\n"
                             "KeyboardInput 1.0 KeyboardInput.qml\n");
    writeFile(web + "WebView.qml", R"(
import QtQuick 2.0
Item {
    objectName: "testWebView"
    property url url
    property string userAgent
    property string userAgentAtNavigation
    property real dpr
    property string lastScript
    property var successCallback
    property bool backAvailable: false
    property bool forwardAvailable: false
    property int backCount: 0
    property int forwardCount: 0
    property int wheelCount: 0
    signal loadFinished()
    signal loadError()
    onUrlChanged: userAgentAtNavigation = userAgent
    function runJavaScript(script, success, failure) {
        lastScript = script
        successCallback = success
    }
    function canGoBack() { return backAvailable }
    function canGoForward() { return forwardAvailable }
    function goBack() { backCount++ }
    function goForward() { forwardCount++ }
})");
    writeFile(web + "TouchInput.qml", "import QtQuick 2.0\nItem {\n"
              "signal pressed(var touchPoints)\nsignal released(var touchPoints)\n"
              "signal canceled(var touchPoints)\n}\n");
    writeFile(web + "MouseInput.qml", R"(
import QtQuick 2.0
Item {
    anchors.fill: parent
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onWheel: parent.parent.wheelCount++
    }
}
)");
    writeFile(web + "KeyboardInput.qml", "import QtQuick 2.0\nQtObject { property bool enabled: false }\n");

    QQmlEngine qml;
    qml.addImportPath(modules.path());
    QQmlComponent component(&qml, QUrl::fromLocalFile(QString::fromLocal8Bit(argv[1])));
    if (component.isError()) {
        for (const QQmlError &error : component.errors())
            std::fprintf(stderr, "%s\n", error.toString().toUtf8().constData());
    }
    check(component.isReady(), "load Main.qml");
    QScopedPointer<QObject> root(component.create());
    check(!root.isNull(), "create Main.qml");
    QQuickWindow window;
    window.resize(960, 540);
    qobject_cast<QQuickItem *>(root.data())->setParentItem(window.contentItem());
    QObject *webView = root->findChild<QObject *>("testWebView");
    check(webView, "find mock WebView");
    check(webView->property("userAgent").toString().contains("Android"), "use Android user agent");
    check(webView->property("userAgent").toString().contains("Chrome/"), "identify as mobile Chrome");
    check(webView->property("userAgentAtNavigation") == webView->property("userAgent"),
          "set user agent before initial navigation");
    QObject *trackInfo = root->findChild<QObject *>("playerTrackInfo");
    check(trackInfo, "find player layout");
    QObject *touch = root->findChild<QObject *>("webTouchInput");
    check(touch, "find touch input");
    QObject *topBar = root->findChild<QObject *>("topBar");
    QObject *backButton = root->findChild<QObject *>("backButton");
    QObject *homeButton = root->findChild<QObject *>("homeButton");
    check(topBar && backButton && homeButton, "find AppBar and navigation buttons");
    for (const QSize size : {QSize(540, 960), QSize(960, 540)}) {
        root->setProperty("width", size.width());
        root->setProperty("height", size.height());
        QCoreApplication::processEvents();
        check(webView->property("height").toDouble() > 0, "web view fits in both orientations");
        check(trackInfo->property("width").toDouble() > 0, "player information fits in both orientations");
        check(topBar->property("height").toDouble() > 0, "AppBar has height in both orientations");
    }

    check(QMetaObject::invokeMethod(root.data(), "navigateBack"), "invoke unavailable back navigation");
    check(webView->property("backCount").toInt() == 0, "unavailable back navigation is ignored");
    webView->setProperty("backAvailable", true);
    webView->setProperty("forwardAvailable", true);
    check(QMetaObject::invokeMethod(root.data(), "navigateBack"), "invoke back navigation");
    check(QMetaObject::invokeMethod(root.data(), "navigateForward"), "invoke forward navigation");
    check(webView->property("backCount").toInt() == 1, "navigate backward");
    check(webView->property("forwardCount").toInt() == 1, "navigate forward");

    auto touchEvent = [touch](const char *signal, int id, double x, double y) {
        QVariantMap point;
        point.insert("pointId", id);
        point.insert("x", x);
        point.insert("y", y);
        QVariant points = QVariantList{point};
        check(QMetaObject::invokeMethod(touch, signal, Q_ARG(QVariant, points)), "emit touch signal");
    };
    const double width = webView->property("width").toDouble();
    touchEvent("pressed", 1, 0, 100);
    touchEvent("released", 1, width / 2, 100);
    check(webView->property("backCount").toInt() == 2, "left-edge swipe goes back");
    touchEvent("pressed", 2, width, 100);
    touchEvent("released", 2, width / 2, 100);
    check(webView->property("forwardCount").toInt() == 2, "right-edge swipe goes forward");
    touchEvent("pressed", 6, width / 2, 100);
    touchEvent("released", 6, width, 100);
    check(webView->property("backCount").toInt() == 3, "center swipe goes back");
    touchEvent("pressed", 3, 0, 100);
    touchEvent("released", 3, width / 2, width);
    check(webView->property("backCount").toInt() == 3, "vertical swipe does not navigate");
    touchEvent("pressed", 4, 0, 100);
    touchEvent("pressed", 5, 1, 100);
    touchEvent("released", 4, width / 2, 100);
    check(webView->property("backCount").toInt() == 3, "multitouch does not navigate");
    touchEvent("pressed", 7, width / 2, 100);
    touchEvent("released", 7, width / 2 + 5, 100);
    check(webView->property("backCount").toInt() == 3, "short swipe does not navigate");

    const QPointF position = qobject_cast<QQuickItem *>(webView)->mapToScene(QPointF(width / 2, 100));
    QWheelEvent wheel(position, position, QPoint(), QPoint(0, -120), -120, Qt::Vertical,
                      Qt::NoButton, Qt::NoModifier, Qt::NoScrollPhase);
    QCoreApplication::sendEvent(&window, &wheel);
    check(webView->property("wheelCount").toInt() == 1, "mouse wheel reaches WebView input");
    auto mouseClick = [&window, &position](Qt::MouseButton button) {
        QMouseEvent press(QEvent::MouseButtonPress, position, button, button, Qt::NoModifier);
        QMouseEvent release(QEvent::MouseButtonRelease, position, button, Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(&window, &press);
        QCoreApplication::sendEvent(&window, &release);
    };
    mouseClick(Qt::BackButton);
    mouseClick(Qt::ForwardButton);
    check(webView->property("backCount").toInt() == 4, "mouse back button navigates");
    check(webView->property("forwardCount").toInt() == 3, "mouse forward button navigates");

    QJSEngine page;
    QJSValue setup = page.evaluate(R"(
var location = { hostname: 'akniga.org' };
var navigator = { userAgent: 'Mozilla Android', serviceWorker: {} };
var window = { offlineDownloadAvailable: function() { return false; } };
var showDownloadContainer = false;
var downloadButton = null;
var hlsSupport = 'true';
var forceHlsTransport = false;
var forceMp3Transport = false;
var _nativeHls = false;
var _mseAac = false;
var Hls = { isSupported: function() { return true; } };
var initCount = 0;
window.initOfflineDownload = function() { initCount++; };
function getComputedStyle() { return { display: 'none' }; }
var clicks = '';
var placeholder = { paused: true, currentTime: 0, duration: NaN };
var audio = { paused: false, currentTime: 50, duration: 300, error: null };
var active = {
    getAttribute: function() { return '42'; },
    querySelector: function() { return audio; }
};
audio.parentNode = active;
var article = {
    getAttribute: function() { return '99'; },
    querySelector: function() { return { click: function() { clicks = 'article'; } }; }
};
var bar = {
    getAttribute: function() { return '42'; },
    querySelector: function() { return { click: function() { clicks = 'bar'; } }; }
};
var bookData = { '42': { titleonly: 'Active book', author: 'Author', preview: 'cover.jpg' } };
var document = {
    body: { classList: { contains: function() { return true; }, toggle: function() {} } },
    querySelector: function(selector) {
        if (selector === '.book--page[data-bid]') return article;
        if (selector === '.jpl.player[data-bid]') return active;
        if (selector === '.player__wrapper--bar[data-bid]') return bar;
        if (selector === '#hls-download-button-container')
            return showDownloadContainer ? { querySelector: function() { return downloadButton; } } : null;
        if (selector === 'audio') return placeholder;
        return null;
    },
    querySelectorAll: function(selector) {
        if (selector === '.jpl[data-bid]:not(.empty) audio') return [audio];
        if (selector === '.jpl[data-bid]:not(.empty)') return active ? [active] : [];
        return [];
    }
};
function playerForward(bid) { clicks = 'forward:' + bid; }
function playerRewind(bid) { clicks = 'back:' + bid; }
)");
    check(!setup.isError(), "prepare page fixture");
    root->setProperty("pageLoaded", true);
    check(QMetaObject::invokeMethod(root.data(), "syncPlayer"), "invoke synchronization");
    QJSValue state = page.evaluate(webView->property("lastScript").toString());
    check(!state.isError(), "execute synchronization script");
    QJSValue callback = webView->property("successCallback").value<QJSValue>();
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(root->property("hasBook").toBool(), "detect active book");
    check(root->property("isPlaying").toBool(), "read active audio, not placeholder");
    check(root->property("bookTitle").toString() == "Active book", "use active book metadata");
    check(root->property("currentTime").toDouble() == 50, "read active position");
    check(root->property("duration").toDouble() == 300, "read active duration");
    page.evaluate("showDownloadContainer=true; navigator.userAgent='Mozilla Linux';");
    state = page.evaluate(webView->property("lastScript").toString());
    check(!state.isError(), "execute offline diagnostic");
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(root->property("pageStatus").toString().contains("User-Agent"), "report unrecognized user agent");
    page.evaluate("navigator.userAgent='Mozilla Android'; delete navigator.serviceWorker;");
    state = page.evaluate(webView->property("lastScript").toString());
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(root->property("pageStatus").toString().contains("Service Worker"), "report missing service worker");
    page.evaluate("navigator.serviceWorker={};");
    state = page.evaluate(webView->property("lastScript").toString());
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(root->property("pageStatus").toString().contains(QString::fromUtf8("офлайн")), "report unavailable site offline mode");
    page.evaluate("window.offlineDownloadAvailable=function(){return true;};");
    state = page.evaluate(webView->property("lastScript").toString());
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(!root->property("pageStatus").toString().contains(QString::fromUtf8("офлайн")), "clear diagnostic when available");
    page.evaluate("downloadButton={};");
    state = page.evaluate(webView->property("lastScript").toString());
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(root->property("pageStatus").toString().contains("HLS"), "report unsupported HLS audio");
    check(!page.globalObject().property("forceHlsTransport").toBool(), "do not force unsupported HLS");
    page.evaluate("_mseAac=true;");
    state = page.evaluate(webView->property("lastScript").toString());
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(page.globalObject().property("forceHlsTransport").toBool(), "enable supported HLS");
    check(page.globalObject().property("initCount").toInt() == 1, "refresh site download button");
    state = page.evaluate(webView->property("lastScript").toString());
    check(page.globalObject().property("initCount").toInt() == 1, "do not repeatedly refresh download button");
    page.evaluate("forceHlsTransport=false; _mseAac=false;");
    page.evaluate("hlsSupport='false';");
    state = page.evaluate(webView->property("lastScript").toString());
    callback.call(QJSValueList() << QJSValue(state.toString()));
    check(root->property("pageStatus").toString().contains("HLS"), "report missing HLS support");

    check(QMetaObject::invokeMethod(root.data(), "togglePlayback"), "invoke playback action");
    check(!page.evaluate(webView->property("lastScript").toString()).isError(), "execute playback action");
    check(page.globalObject().property("clicks").toString() == "bar", "control active book, not other page");

    check(QMetaObject::invokeMethod(root.data(), "seekBy", Q_ARG(QVariant, 15)), "invoke forward action");
    check(!page.evaluate(webView->property("lastScript").toString()).isError(), "execute forward action");
    check(page.globalObject().property("clicks").toString() == "forward:42", "use site forward action");

    check(QMetaObject::invokeMethod(root.data(), "seekBy", Q_ARG(QVariant, -15)), "invoke backward action");
    check(!page.evaluate(webView->property("lastScript").toString()).isError(), "execute backward action");
    check(page.globalObject().property("clicks").toString() == "back:42", "use site backward action");

    check(QMetaObject::invokeMethod(root.data(), "seekToFraction", Q_ARG(QVariant, 0.5)), "invoke seek");
    check(!page.evaluate(webView->property("lastScript").toString()).isError(), "execute seek");
    check(page.globalObject().property("audio").property("currentTime").toNumber() == 150, "seek active audio");

    page.evaluate("active=null; clicks='';");
    check(QMetaObject::invokeMethod(root.data(), "togglePlayback"), "invoke action during player transition");
    check(!page.evaluate(webView->property("lastScript").toString()).isError(), "execute transition action");
    check(page.globalObject().property("clicks").toString() == "bar", "find playing audio without player class");

    page.evaluate("audio.paused=true; clicks='';");
    check(QMetaObject::invokeMethod(root.data(), "togglePlayback"), "invoke first play");
    check(!page.evaluate(webView->property("lastScript").toString()).isError(), "execute first play");
    check(page.globalObject().property("clicks").toString() == "article", "start book from its page");

    page.evaluate("article=null; location.hostname='example.org';");
    check(QMetaObject::invokeMethod(root.data(), "togglePlayback"), "invoke action on external page");
    check(!page.evaluate(webView->property("lastScript").toString()).toBool(), "ignore external page");
    std::puts("Player bridge checks passed");
    return 0;
}
