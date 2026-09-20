#include "WallpaperScanner.h"
#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QSaveFile>
#include <QtConcurrent/QtConcurrent>
#include <QSet>
#include <algorithm>

static QString thumbMetadataPath(const QString &cachePath) {
    return cachePath + QStringLiteral(".meta.json");
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

    if (QFileInfo::exists(dst)) {
        r.cacheAvailable = true;
        r.updated = false;
        r.errorString = QStringLiteral("");
        return r;
    }

    QDir().mkpath(QFileInfo(dst).absolutePath());

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

    r.cacheAvailable = true;
    r.updated = true;
    r.errorString = QStringLiteral("");
    return r;
}

WallpaperScanner::WallpaperScanner(QObject *parent) : QObject(parent) {}

void WallpaperScanner::startScan(const QString &wallDir, const QString &cacheDir,
                                 int thumbW, int thumbH, int quality) {
    const int serial = ++m_scanSerial;

    QDir().mkpath(cacheDir);

    QStringList images;
    QDirIterator it(wallDir, QDir::Files | QDir::Readable);
    while (it.hasNext()) {
        it.next();
        if (isValidImage(it.filePath()))
            images.append(it.filePath());
    }
    images.sort(Qt::CaseInsensitive);

    QJsonArray result;
    for (const auto &abs : images) {
        QFileInfo fi(abs);
        QString thumbFile = cacheDir + "/" + scanHash(abs) + ".jpg";

        QJsonObject rec;
        rec.insert("path", abs);
        rec.insert("name", fi.fileName());
        rec.insert("baseName", fi.completeBaseName());
        rec.insert("thumb", thumbFile);
        rec.insert("thumbReady", QFileInfo::exists(thumbFile));
        result.append(rec);
    }

    emit scanDone(result);

    if (serial == m_scanSerial)
        emit scanFinished();
}

void WallpaperScanner::generateThumb(const QString &sourcePath,
                                     const QString &cachePath,
                                     int thumbW, int thumbH, int quality) {
    QtConcurrent::run([this, sourcePath, cachePath, thumbW, thumbH, quality]() {
        ThumbResult r = generateThumbnail(sourcePath, cachePath, thumbW, thumbH, quality);
        emit thumbReady(r.sourcePath, r.cachePath, r.cacheAvailable, r.updated, r.errorString);
    });
}
