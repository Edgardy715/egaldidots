#include "WallpaperScanner.h"
#include <QCoreApplication>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QJsonObject>
#include <QPointer>
#include <QSemaphore>
#include <QTemporaryDir>
#include <QThreadPool>
#include <QTimer>
#include <QtConcurrent>
#include <QElapsedTimer>
#include <QThread>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

static void check(bool condition) {
    if (!condition) qFatal("async scanner regression failed");
}

static void waitForScan(WallpaperScanner &scanner) {
    QEventLoop loop;
    QObject::connect(&scanner, &WallpaperScanner::scanFinished, &loop, &QEventLoop::quit);
    QTimer::singleShot(5000, &loop, [] { qFatal("async scanner timeout"); });
    loop.exec();
    check(!scanner.isScanning());
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QTemporaryDir fixture;
    check(fixture.isValid());
    for (const auto &name : {"A", "B", "C"}) {
        check(QDir().mkpath(fixture.filePath(name)));
        QFile image(fixture.filePath(QString(name) + "/" + name + ".png"));
        check(image.open(QIODevice::WriteOnly));
        image.write("fixture");
    }
    const auto cache = fixture.filePath("cache");
    auto *pool = QThreadPool::globalInstance();
    pool->setMaxThreadCount(1);
    QSemaphore started, release;
    auto blocker = QtConcurrent::run([&] { started.release(); release.acquire(); });
    started.acquire();
    WallpaperScanner scanner;
    int done = 0, finished = 0;
    QString thumbnail;
    auto connection = QObject::connect(&scanner, &WallpaperScanner::scanDone, &scanner,
        [&](const QJsonArray &items) {
            check(!scanner.isScanning());
            check(items.size() == 1 && items[0].toObject()["name"] == "C.png");
            thumbnail = items[0].toObject()["thumb"].toString();
            ++done;
        });
    QObject::connect(&scanner, &WallpaperScanner::scanFinished, &scanner, [&] { ++finished; });
    scanner.startScan(fixture.filePath("A"), cache);
    scanner.startScan(fixture.filePath("B"), fixture.filePath("unused-cache"));
    scanner.startScan(fixture.filePath("C"), cache);
    check(scanner.isScanning() && done == 0);
    check(scanner.findChildren<QObject *>().size() == 1);
    release.release();
    waitForScan(scanner);
    check(done == 1 && finished == 1);
    check(!QDir(fixture.filePath("unused-cache")).exists());
    QObject::disconnect(connection);

    done = finished = 0;
    connection = QObject::connect(&scanner, &WallpaperScanner::scanDone, &scanner,
        [&](const QJsonArray &items) {
            check(!scanner.isScanning());
            check(items[0].toObject()["name"] == (done == 0 ? "A.png" : "B.png"));
            if (++done == 1) {
                scanner.startScan(fixture.filePath("B"), cache);
                check(scanner.isScanning());
            }
        });
    scanner.startScan(fixture.filePath("A"), cache);
    waitForScan(scanner);
    check(done == 2 && finished == 1);
    QObject::disconnect(connection);

    // Deleting a scanner must neither wait for its queued job nor retain it.
    blocker = QtConcurrent::run([&] { started.release(); release.acquire(); });
    started.acquire();
    QPointer<WallpaperScanner> destroyed = new WallpaperScanner;
    destroyed->startScan(fixture.filePath("A"), cache);
    delete destroyed.data();
    check(destroyed.isNull());
    release.release();
    pool->waitForDone();
    QCoreApplication::processEvents();

    // Hold metadata reading open to delete the QObject while its worker runs.
    QFile thumb(thumbnail);
    check(thumb.open(QIODevice::WriteOnly));
    thumb.write("fixture");
    thumb.close();
    const auto metadata = QFile::encodeName(thumbnail + ".meta.json");
    check(::mkfifo(metadata.constData(), 0600) == 0);
    destroyed = new WallpaperScanner;
    destroyed->startScan(fixture.filePath("C"), cache);
    QElapsedTimer deadline;
    deadline.start();
    int writer = -1;
    while (writer < 0 && deadline.elapsed() < 5000) {
        writer = ::open(metadata.constData(), O_WRONLY | O_NONBLOCK);
        if (writer < 0) QThread::msleep(1);
    }
    check(writer >= 0);
    delete destroyed.data();
    check(destroyed.isNull());
    ::close(writer);
    pool->waitForDone();
    check(QFile::remove(QString::fromLocal8Bit(metadata)));

    // A consumer may also destroy the scanner while receiving scanDone.
    destroyed = new WallpaperScanner;
    bool deletedInCallback = false;
    QObject::connect(destroyed, &WallpaperScanner::scanDone, &app, [&] {
        delete destroyed.data();
        deletedInCallback = true;
    });
    QEventLoop deletionLoop;
    QTimer poll;
    QObject::connect(&poll, &QTimer::timeout, &deletionLoop, [&] {
        if (deletedInCallback) deletionLoop.quit();
    });
    QTimer::singleShot(5000, &deletionLoop, [] { qFatal("destruction timeout"); });
    poll.start(1);
    destroyed->startScan(fixture.filePath("C"), cache);
    deletionLoop.exec();
    check(destroyed.isNull());
    qInfo("PASS: async coalescing, stale results, reentry, state and destruction");
}
