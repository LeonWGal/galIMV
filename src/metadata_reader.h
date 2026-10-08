#pragma once

#include <QString>
#include <QStringList>
#include <QSize>
#include <QDateTime>
#include <QDataStream>

struct ImageMetadata {
    QString filePath;
    QString fileName;
    QString relativeDir; // subfolder name relative to library root
    QString modelName;   // e.g. SDXL, anime_v1.5, etc.
    qint64 fileSize = 0;
    QDateTime modifiedDate;
    qint64 sidecarSize = -1;
    qint64 sidecarModifiedMSecs = 0;
    QSize dimensions;
    qreal aspectRatio = 1.0;
    
    QString prompt;
    QString negativePrompt;
    QString otherParams; // steps, sampler, seed, cfg, model, etc.
    QStringList tags;
};

inline QDataStream& operator<<(QDataStream& out, const ImageMetadata& meta) {
    out << meta.filePath
        << meta.fileName
        << meta.relativeDir
        << meta.modelName
        << meta.fileSize
        << meta.modifiedDate
        << meta.dimensions
        << meta.aspectRatio
        << meta.prompt
        << meta.negativePrompt
        << meta.otherParams
        << meta.tags;
    out << meta.sidecarSize << meta.sidecarModifiedMSecs;
    return out;
}

inline QDataStream& operator>>(QDataStream& in, ImageMetadata& meta) {
    in >> meta.filePath
       >> meta.fileName
       >> meta.relativeDir
       >> meta.modelName
       >> meta.fileSize
       >> meta.modifiedDate
       >> meta.dimensions
       >> meta.aspectRatio
       >> meta.prompt
       >> meta.negativePrompt
       >> meta.otherParams
       >> meta.tags;
    in >> meta.sidecarSize >> meta.sidecarModifiedMSecs;
    return in;
}

class MetadataReader {
public:
    static ImageMetadata read(const QString& filePath, const QString& rootDir = QString());
    static int inferTagCategory(const QString& tag);
    static void extractTagsFromPrompt(ImageMetadata& meta);
    static QString cleanModelName(const QString& model);

private:
    static void parsePngChunks(const QString& filePath, ImageMetadata& meta);
    static void parseSidecarTxt(const QString& filePath, ImageMetadata& meta);
};
