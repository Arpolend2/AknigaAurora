#include <auroraapp.h>
#include <webenginecontext.h>

#include <QCoreApplication>
#include <QEvent>
#include <QGuiApplication>
#include <QQuickView>
#include <QScopedPointer>
#include <QTimer>
#include <QUrl>

namespace AW = Aurora::WebView;

class ShutdownObserver : public QObject
{
public:
    bool eventFilter(QObject *, QEvent *event) override
    {
        if (event->type() == AW::WebEngineContext::ReadyToClose::readyToCloseEventType) {
            QCoreApplication::exit(result);
            return true;
        }
        return false;
    }

    int result = 0;
};

int main(int argc, char **argv)
{
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QScopedPointer<QGuiApplication> app(Aurora::Application::application(argc, argv));
    app->setOrganizationName(QStringLiteral("ru.arpolend"));
    app->setApplicationName(QStringLiteral("akniga"));
    app->setQuitOnLastWindowClosed(false);

    AW::WebEngineContext::InitBrowser(
        argc, argv, {"--autoplay-policy=no-user-gesture-required"});

    ShutdownObserver observer;
    app->installEventFilter(&observer);
    QScopedPointer<QQuickView> view(Aurora::Application::createView());
    view->setResizeMode(QQuickView::SizeRootObjectToView);

    bool stopping = false;
    auto shutdown = [&]() {
        if (stopping)
            return;
        stopping = true;
        view->setSource(QUrl());
        AW::WebEngineContext::Shutdown();
        QTimer::singleShot(10000, app.data(), []() {
            qCritical("WebView shutdown timed out");
            QCoreApplication::exit(1);
        });
    };

    QObject::connect(app.data(), &QGuiApplication::lastWindowClosed, app.data(), shutdown);
    view->setSource(QUrl(QStringLiteral("qrc:/AknigaWindow.qml")));
    if (view->status() == QQuickView::Error) {
        qCritical("Cannot load Akniga interface");
        observer.result = 1;
        QTimer::singleShot(0, app.data(), shutdown);
    } else {
        view->showFullScreen();
    }

    return app->exec();
}
