#include "WallpaperScanner.h"
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QFile>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QSaveFile>
#include <QtConcurrent/QtConcurrent>
#include <QSet>
#include <QFutureWatcher>
#include <QPointer>
#include <algorithm>

static QString thumbMetadataPath(const QString &cachePath) {
    return cachePath + QStringLiteral(".meta.json");
}

static QJsonObject thumbSignature(const QFileInfo &source, const QFileInfo &cache,
                                  int width, int height, int quality) {
    return {{"source", source.absoluteFilePath()},
            {"sourceSize", static_cast<double>(source.size())},
            {"sourceModified", static_cast<double>(source.lastModified().toMSecsSinceEpoch())},
            {"cacheSize", static_cast<double>(cache.size())},
            {"cacheModified", static_cast<double>(cache.lastModified().toMSecsSinceEpoch())},
            {"width", width}, {"height", height}, {"quality", quality}};
}

static bool isCurrentThumbnail(const QString &sourcePath, const QString &cachePath,
                               int width, int height, int quality) {
    QFileInfo source(sourcePath), cache(cachePath);
    if (!source.isFile() || !cache.isFile() || cache.size() <= 0) return false;
    QFile metadata(thumbMetadataPath(cachePath));
    if (!metadata.open(QIODevice::ReadOnly)) return false;
    const auto stored = QJsonDocument::fromJson(metadata.readAll());
    if (!stored.isObject() || stored.object() != thumbSignature(source, cache, width, height, quality))
        return false;
    QImageReader reader(cachePath);
    return reader.canRead() && reader.size() == QSize(width, height);
}

static bool isValidImage(const QString &path) {
    const QString low = path.toLower();
    return low.endsWith(".jpg") || low.endsWith(".jpeg")
        || low.endsWith(".png") || low.endsWith(".webp")
        || low.endsWith(".gif") || low.endsWith(".avif")
        || low.endsWith(".bmp");
}

static QString scanHash(const QString &path) {
    uint32_t h = 5381;
    const QByteArray utf = path.toUtf8();
    for (int i = 0; i < utf.size(); ++i)
        h = ((h << 5) - h) + static_cast<uint8_t>(utf[i]);
    return QString::number(h, 16);
}

struct ThumbResult {
    QString sourcePath;
    QString cachePath;
    bool cacheAvailable = false;
    bool updated = false;
    QString errorString;
};

static ThumbResult generateThumbnail(const QString &src, const QString &dst,
                                     int tw, int th, int q) {
    ThumbResult r;
    r.sourcePath = src;
    r.cachePath = dst;

    QFileInfo fi(src);
    if (!fi.exists()) { r.errorString = QStringLiteral("source not found"); return r; }

    if (isCurrentThumbnail(src, dst, tw, th, q)) {
        r.cacheAvailable = true;
        r.updated = false;
        r.errorString = QStringLiteral("");
        return r;
    }

    QDir().mkpath(QFileInfo(dst).absolutePath());
    const QFileInfo sourceBefore(src);

    QImageReader reader(src);
    reader.setAutoTransform(true);
    QSize orig = reader.size();
    if (orig.isValid()) {
        QSize decode = orig.scaled(QSize(tw, th), Qt::KeepAspectRatioByExpanding);
        if ((qint64)(decode.width()) * decode.height()
            < (qint64)(orig.width()) * orig.height())
            reader.setScaledSize(decode);
    }

    QImage img = reader.read();
    if (img.isNull()) { r.errorString = reader.errorString(); return r; }

    QImage scaled = img.scaled(tw, th, Qt::KeepAspectRatioByExpanding,
                               Qt::SmoothTransformation);
    int cx = std::max(0, (scaled.width() - tw) / 2);
    int cy = std::max(0, (scaled.height() - th) / 2);
    QImage crop = scaled.copy(cx, cy, tw, th);

    QSaveFile out(dst);
    if (!out.open(QIODevice::WriteOnly)) { r.errorString = out.errorString(); return r; }

    QImageWriter writer(&out, "jpg");
    writer.setQuality(std::clamp(q, 1, 100));
    if (!writer.write(crop)) {
        r.errorString = writer.errorString();
        out.cancelWriting();
        return r;
    }
    if (!out.commit()) { r.errorString = out.errorString(); return r; }

    const QFileInfo sourceAfter(src);
    if (!sourceAfter.isFile() || sourceAfter.size() != sourceBefore.size()
        || sourceAfter.lastModified() != sourceBefore.lastModified()) {
        QFile::remove(dst);
        r.errorString = QStringLiteral("source changed during thumbnail generation");
        return r;
    }
    QSaveFile metadata(thumbMetadataPath(dst));
    if (!metadata.open(QIODevice::WriteOnly)
        || metadata.write(QJsonDocument(thumbSignature(sourceAfter, QFileInfo(dst), tw, th, q))
                          .toJson(QJsonDocument::Compact)) < 0
        || !metadata.commit()) {
        r.errorString = metadata.errorString();
        QFile::remove(dst);
        return r;
    }

    r.cacheAvailable = true;
    r.updated = true;
    r.errorString = QStringLiteral("");
    return r;
}

WallpaperScanner::WallpaperScanner(QObject *parent) : QObject(parent) {}

void WallpaperScanner::startScan(const QString &wallDir, const QString &cacheDir,
                                 int thumbW, int thumbH, int quality) {
    m_pendingScan = {wallDir, cacheDir, thumbW, thumbH, quality, ++m_scanSerial};
    if (!m_scanRunning)
        startPendingScan();
}

void WallpaperScanner::startPendingScan() {
    const auto request = m_pendingScan;
    m_scanRunning = true;
    auto *watcher = new QFutureWatcher<QJsonArray>(this);
    connect(watcher, &QFutureWatcher<QJsonArray>::finished, this, [this, watcher, serial = request.serial]() {
        const auto result = watcher->result();
        watcher->deleteLater();
        m_scanRunning = false;
        if (serial != m_scanSerial) {
            startPendingScan();
            return;
        }
        m_doneSerial = serial;
        const QPointer<WallpaperScanner> guard(this);
        emit scanDone(result);
        if (guard && serial == m_scanSerial)
            emit scanFinished();
    });
    watcher->setFuture(QtConcurrent::run([request]() {
        QDir().mkpath(request.cacheDir);

        QStringList images;
        QDirIterator it(request.wallDir, QDir::Files | QDir::Readable);
        while (it.hasNext()) {
            it.next();
            if (isValidImage(it.filePath()))
                images.append(it.filePath());
        }
        images.sort(Qt::CaseInsensitive);

        QJsonArray result;
        for (const auto &abs : images) {
            QFileInfo fi(abs);
            QString thumbFile = request.cacheDir + "/" + scanHash(abs) + ".jpg";

            QJsonObject rec;
            rec.insert("path", abs);
            rec.insert("name", fi.fileName());
            rec.insert("baseName", fi.completeBaseName());
            rec.insert("thumb", thumbFile);
            rec.insert("thumbReady", isCurrentThumbnail(abs, thumbFile, request.thumbW,
                                                       request.thumbH, request.quality));
            result.append(rec);
        }
        return result;
    }));
}

void WallpaperScanner::generateThumb(const QString &sourcePath,
                                     const QString &cachePath,
                                     int thumbW, int thumbH, int quality) {
    auto *watcher = new QFutureWatcher<ThumbResult>(this);
    connect(watcher, &QFutureWatcher<ThumbResult>::finished, this, [this, watcher]() {
        const auto r = watcher->result();
        emit thumbReady(r.sourcePath, r.cachePath, r.cacheAvailable, r.updated, r.errorString);
        watcher->deleteLater();
    });
    watcher->setFuture(QtConcurrent::run([sourcePath, cachePath, thumbW, thumbH, quality]() {
        return generateThumbnail(sourcePath, cachePath, thumbW, thumbH, quality);
    }));
}
