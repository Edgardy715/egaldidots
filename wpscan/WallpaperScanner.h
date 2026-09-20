#pragma once
#include <QObject>
#include <QJsonArray>
#include <QString>
#include <qqml.h>
#include <QQmlEngine>
#include <QJSEngine>

class WallpaperScanner : public QObject {
    Q_OBJECT
    QML_ELEMENT
public:
    explicit WallpaperScanner(QObject *parent = nullptr);

    bool isScanning() const { return m_scanSerial != m_doneSerial; }

public slots:
    void startScan(const QString &wallDir, const QString &cacheDir,
                   int thumbW = 320, int thumbH = 120, int quality = 70);
    void generateThumb(const QString &sourcePath, const QString &cachePath,
                       int thumbW = 320, int thumbH = 120, int quality = 70);

signals:
    void scanDone(const QJsonArray &items);
    void scanFinished();
    void thumbReady(const QString &sourcePath, const QString &cachePath,
                    bool cacheAvailable, bool updated, const QString &errorString);

private:
    int m_scanSerial = 0;
    int m_doneSerial = 0;
};
