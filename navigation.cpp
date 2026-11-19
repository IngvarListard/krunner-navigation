#include <QCoreApplication>
#include <QEvent>
#include <QKeyEvent>
#include <QObject>

#include <cstdlib>

class NavigationFilter final : public QObject {
    bool eventFilter(QObject *receiver, QEvent *event) override {
        if (event->type() != QEvent::KeyPress && event->type() != QEvent::KeyRelease)
            return false;

        auto *key = static_cast<QKeyEvent *>(event);
        // X11 and Wayland use the same native scan codes for physical J and K,
        // regardless of whether the active layout is English or Russian.
        if (key->modifiers() != Qt::AltModifier ||
            (key->nativeScanCode() != 44 && key->nativeScanCode() != 45))
            return false;

        QKeyEvent arrow(event->type(), key->nativeScanCode() == 44 ? Qt::Key_Down : Qt::Key_Up,
                        Qt::NoModifier, QString(), key->isAutoRepeat(), key->count());
        QCoreApplication::sendEvent(receiver, &arrow);
        return true;
    }
};

static void installNavigationFilter() {
    // KRunner's children must not load this KRunner-specific filter.
    unsetenv("LD_PRELOAD");
    QCoreApplication::instance()->installEventFilter(new NavigationFilter);
}
Q_COREAPP_STARTUP_FUNCTION(installNavigationFilter)
