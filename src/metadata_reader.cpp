#include "metadata_reader.h"
#include "tag_autocomplete.h"
#include <QFileInfo>
#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>
#include <QJsonArray>
#include <climits>
#include <QImageReader>
#include <QtEndian>
#include <zlib.h>
#include <functional>
#include <QSet>
#include <limits>

int MetadataReader::inferTagCategory(const QString& rawTag)
{
    return TagAutocomplete::lookupCategory(rawTag);
}

ImageMetadata MetadataReader::read(const QString& filePath, const QString& rootDir)
{
    ImageMetadata meta;
    meta.filePath = QDir::cleanPath(QFileInfo(filePath).absoluteFilePath());
    QFileInfo fi(filePath);
    meta.fileName = fi.fileName();
    meta.fileSize = fi.size();
    meta.modifiedDate = fi.lastModified();

    if (!rootDir.isEmpty()) {
        QString rel = QDir(rootDir).relativeFilePath(fi.path());
        if (rel.isEmpty() || rel == ".") {
            meta.relativeDir = "Root";
        } else {
            meta.relativeDir = rel.replace('\\', '/');
        }
    } else {
        meta.relativeDir = fi.dir().dirName();
    }

    QString suffix = fi.suffix().toLower();
    if (suffix == "png") {
        parsePngChunks(filePath, meta);
    }

    QString txtPath = fi.path() + "/" + fi.completeBaseName() + ".txt";
    QFileInfo sidecar(txtPath);
    if (sidecar.exists()) {
        meta.sidecarSize = sidecar.size();
        meta.sidecarModifiedMSecs = sidecar.lastModified().toMSecsSinceEpoch();
        parseSidecarTxt(txtPath, meta);
    }

    // Fallback image dimensions if PNG chunks didn't supply them
    if (meta.dimensions.isEmpty()) {
        QImageReader reader(filePath);
        meta.dimensions = reader.size();
        if (meta.dimensions.width() > 0 && meta.dimensions.height() > 0) {
            meta.aspectRatio = static_cast<qreal>(meta.dimensions.width()) / static_cast<qreal>(meta.dimensions.height());
        }
    }

    extractTagsFromPrompt(meta);

    // If still no tags and prompt is empty, extract tokens from base filename
    if (meta.tags.isEmpty() && meta.prompt.isEmpty()) {
        QString base = fi.completeBaseName();
        int lastDash = base.lastIndexOf('-');
        if (lastDash != -1 && lastDash < base.length() - 3) {
            base = base.mid(lastDash + 1);
        }
        QStringList tokens = base.split(QRegularExpression(R"([\s_]+)"), Qt::SkipEmptyParts);
        for (const QString& t : tokens) {
            QString cl = t.trimmed();
            if (cl.length() >= 2 && !meta.tags.contains(cl, Qt::CaseInsensitive)) {
                meta.tags.append(cl);
            }
        }
    }

    return meta;
}


namespace {
constexpr qsizetype MaxMetadataBytes = 20 * 1024 * 1024;

QByteArray inflateText(const QByteArray& compressed) {
    z_stream stream{};
    stream.next_in = reinterpret_cast<Bytef*>(const_cast<char*>(compressed.constData()));
    stream.avail_in = static_cast<uInt>(compressed.size());
    if (inflateInit(&stream) != Z_OK) return {};
    QByteArray result;
    char buffer[16384];
    int status = Z_OK;
    while (status == Z_OK) {
        stream.next_out = reinterpret_cast<Bytef*>(buffer);
        stream.avail_out = sizeof(buffer);
        status = inflate(&stream, Z_NO_FLUSH);
        qsizetype produced = sizeof(buffer) - stream.avail_out;
        if (result.size() + produced > MaxMetadataBytes) {
            inflateEnd(&stream);
            return {};
        }
        result.append(buffer, produced);
    }
    inflateEnd(&stream);
    return status == Z_STREAM_END ? result : QByteArray{};
}

void parseGenerationText(const QString& text, ImageMetadata& meta) {
    QString params = text.trimmed();
    const QJsonDocument doc = QJsonDocument::fromJson(params.toUtf8());
    if (doc.isObject()) {
        const QJsonObject graph = doc.object();
        if (graph.contains("prompt") && graph.contains("uc")) {
            meta.prompt = graph.value("prompt").toString().trimmed();
            meta.negativePrompt = graph.value("uc").toString().trimmed();
            meta.otherParams = params;
            return;
        }
        bool isComfy = false;
        QStringList positives, negatives;
        auto appendUnique = [](QStringList& list, const QString& value) {
            if (!value.trimmed().isEmpty() && !list.contains(value.trimmed())) list.append(value.trimmed());
        };
        // Follow conditioning links from the sampler. Node IDs and insertion order do not identify polarity.
        std::function<QStringList(const QJsonValue&, QSet<QString>)> collect;
        collect = [&](const QJsonValue& link, QSet<QString> visited) -> QStringList {
            if (!link.isArray() || link.toArray().isEmpty()) return {};
            QString id = link.toArray().first().toVariant().toString();
            if (visited.contains(id) || visited.size() >= 256) return {};
            visited.insert(id);
            const QJsonObject inputs = graph.value(id).toObject().value("inputs").toObject();
            QStringList found;
            for (const QString& key : {"text", "text_g", "text_l"}) {
                auto value = inputs.value(key);
                if (value.isString()) appendUnique(found, value.toString());
                else if (value.isArray()) {
                    for (const auto& item : collect(value, visited)) appendUnique(found, item);
                }
            }
            // ConditioningCombine/Average, reroutes and custom conditioning nodes.
            for (auto it = inputs.begin(); it != inputs.end(); ++it) {
                if (it.value().isArray()) {
                    for (const auto& item : collect(it.value(), visited)) appendUnique(found, item);
                } else if ((it.key() == "value" || it.key() == "string") && it.value().isString()) {
                    appendUnique(found, it.value().toString());
                }
            }
            return found;
        };
        for (auto it = graph.begin(); it != graph.end(); ++it) {
            const QJsonObject node = it.value().toObject();
            if (!node.contains("class_type")) continue;
            isComfy = true;
            const QJsonObject inputs = node.value("inputs").toObject();
            for (const auto& text : collect(inputs.value("positive"), {})) appendUnique(positives, text);
            for (const auto& text : collect(inputs.value("negative"), {})) appendUnique(negatives, text);
            if (inputs.value("ckpt_name").isString())
                meta.modelName = MetadataReader::cleanModelName(inputs.value("ckpt_name").toString());
        }
        if (isComfy) {
            // Without polarity links, only a single text node can be used unambiguously.
            if (positives.isEmpty() && negatives.isEmpty()) {
                QStringList texts;
                for (auto it = graph.begin(); it != graph.end(); ++it) {
                    const auto node = it.value().toObject();
                    if (node.value("class_type").toString().startsWith("CLIPTextEncode")) {
                        const auto inputs = node.value("inputs").toObject();
                        for (const auto& key : {"text", "text_g", "text_l"})
                            appendUnique(texts, inputs.value(key).toString());
                    }
                }
                if (texts.size() == 1) positives = texts;
            }
            meta.prompt = positives.join("\n");
            meta.negativePrompt = negatives.join("\n");
            meta.otherParams = params;
            return;
        }
    }
    int neg = params.indexOf("Negative prompt:");
    int steps = params.indexOf("Steps:");
    if (neg >= 0) {
        meta.prompt = params.left(neg).trimmed();
        meta.negativePrompt = (steps > neg ? params.mid(neg + 16, steps - neg - 16) : params.mid(neg + 16)).trimmed();
    } else {
        meta.prompt = (steps >= 0 ? params.left(steps) : params).trimmed();
    }
    if (steps >= 0) meta.otherParams = params.mid(steps).trimmed();
    static const QRegularExpression modelRegex(R"(Model:\s*([^,\n]+))");
    const auto match = modelRegex.match(meta.otherParams);
    if (match.hasMatch()) meta.modelName = MetadataReader::cleanModelName(match.captured(1).trimmed());
}
}

void MetadataReader::parsePngChunks(const QString& filePath, ImageMetadata& meta)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly) || file.read(8) != QByteArray("\x89PNG\r\n\x1a\n", 8)) return;
    QMap<QString, QString> texts;
    while (!file.atEnd()) {
        const auto header = file.read(8);
        if (header.size() != 8) break;
        const quint32 length = qFromBigEndian<quint32>(reinterpret_cast<const uchar*>(header.constData()));
        const auto type = header.mid(4);
        if (length > static_cast<quint64>(file.size() - file.pos()) ||
            file.size() - file.pos() - length < 4) break;
        if (type == "IDAT" || (type != "IHDR" && type != "tEXt" && type != "zTXt" && type != "iTXt")) {
            if (!file.seek(file.pos() + length + 4)) break;
            if (type == "IEND") break;
            continue;
        }
        if (length > MaxMetadataBytes) {
            if (!file.seek(file.pos() + length + 4)) break;
            continue;
        }
        const auto data = file.read(length);
        const auto crcBytes = file.read(4);
        if (data.size() != length || crcBytes.size() != 4) break;
        uLong crc = crc32(0, reinterpret_cast<const Bytef*>(type.constData()), 4);
        crc = crc32(crc, reinterpret_cast<const Bytef*>(data.constData()), data.size());
        if (crc != qFromBigEndian<quint32>(reinterpret_cast<const uchar*>(crcBytes.constData()))) continue;
        if (type == "IHDR") {
            if (length != 13) continue;
            auto width = qFromBigEndian<quint32>(reinterpret_cast<const uchar*>(data.constData()));
            auto height = qFromBigEndian<quint32>(reinterpret_cast<const uchar*>(data.constData() + 4));
            if (width && height && width <= INT_MAX && height <= INT_MAX) {
                meta.dimensions = QSize(width, height);
                meta.aspectRatio = qreal(width) / height;
            }
            continue;
        }
        const int separator = data.indexOf('\0');
        if (separator < 1 || separator > 79) continue;
        const QString keyword = QString::fromLatin1(data.left(separator)).toLower();
        QByteArray payload;
        bool utf8 = false;
        if (type == "tEXt") payload = data.mid(separator + 1);
        else if (type == "zTXt") {
            if (separator + 2 >= data.size() || data[separator + 1] != 0) continue;
            payload = inflateText(data.mid(separator + 2));
        } else {
            if (separator + 3 >= data.size()) continue;
            int flag = static_cast<unsigned char>(data[separator + 1]);
            if (flag > 1 || data[separator + 2] != 0) continue;
            int languageEnd = data.indexOf('\0', separator + 3);
            int translatedEnd = languageEnd < 0 ? -1 : data.indexOf('\0', languageEnd + 1);
            if (translatedEnd < 0) continue;
            payload = data.mid(translatedEnd + 1);
            if (flag) payload = inflateText(payload);
            utf8 = true;
        }
        if (payload.size() > MaxMetadataBytes) continue;
        QString decoded = utf8 ? QString::fromUtf8(payload) : QString::fromLatin1(payload);
        // A1111 commonly writes UTF-8 into tEXt despite the PNG Latin-1 encoding.
        if (!utf8 && QString::fromUtf8(payload).toUtf8() == payload) decoded = QString::fromUtf8(payload);
        texts.insert(keyword, decoded);
    }
    for (const auto& key : {"description", "comment", "prompt", "parameters"})
        if (texts.contains(key)) parseGenerationText(texts.value(key), meta);
}

void MetadataReader::parseSidecarTxt(const QString& txtPath, ImageMetadata& meta)
{
    QFile file(txtPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    if (file.size() > MaxMetadataBytes) return;
    QString content = QString::fromUtf8(file.readAll()).trimmed();
    if (!content.isEmpty()) {
        if (meta.prompt.isEmpty()) {
            meta.prompt = content;
        } else {
            meta.otherParams += "\n[Sidecar Text]: " + content;
        }
    }
}

void MetadataReader::extractTagsFromPrompt(ImageMetadata& meta)
{
    if (meta.prompt.isEmpty()) return;

    QStringList tokens = meta.prompt.split(',', Qt::SkipEmptyParts);
    for (QString token : tokens) {
        token = token.trimmed();
        if (token.isEmpty()) continue;

        // 1. Remove SD prompt weighting like :1.2, :0.85, :1.1 at the end before outer closing brackets
        static const QRegularExpression weightSuffix(R"(:\s*[-+]?[0-9]*\.?[0-9]+\s*([\\\)\]\}]*)$)");
        auto match = weightSuffix.match(token);
        if (match.hasMatch()) {
            QString trailingBrackets = match.captured(1);
            token = token.left(match.capturedStart()) + trailingBrackets;
            token = token.trimmed();
        }

        // 2. Remove outer SD prompt weighting braces (e.g. ((tag)), [tag], {tag})
        // while preserving internal character tags like (pokemon), (re:zero), (fate)
        bool stripped = true;
        while (stripped && token.length() >= 2) {
            stripped = false;
            QChar first = token.front();
            QChar last = token.back();
            if ((first == '(' && last == ')') ||
                (first == '[' && last == ']') ||
                (first == '{' && last == '}')) {
                // Verify that first and last form an outer balanced pair
                int depth = 0;
                bool isOuter = true;
                for (int i = 0; i < token.length() - 1; ++i) {
                    QChar c = token[i];
                    if (c == '(' || c == '[' || c == '{') depth++;
                    else if (c == ')' || c == ']' || c == '}') {
                        depth--;
                        if (depth == 0) {
                            isOuter = false;
                            break;
                        }
                    }
                }
                if (isOuter) {
                    token = token.mid(1, token.length() - 2).trimmed();
                    stripped = true;
                }
            }
        }

        // 3. Remove any remaining leading emphasis brackets that might be unbalanced, e.g. "((tag"
        while (!token.isEmpty() && (token.startsWith('(') || token.startsWith('[') || token.startsWith('{'))) {
            int openP = token.count('('), closeP = token.count(')');
            int openB = token.count('['), closeB = token.count(']');
            int openC = token.count('{'), closeC = token.count('}');
            if (openP > closeP && token.startsWith('(')) token = token.mid(1).trimmed();
            else if (openB > closeB && token.startsWith('[')) token = token.mid(1).trimmed();
            else if (openC > closeC && token.startsWith('{')) token = token.mid(1).trimmed();
            else break;
        }

        // 4. Remove any remaining trailing emphasis brackets that might be unbalanced, e.g. "tag))"
        while (!token.isEmpty() && (token.endsWith(')') || token.endsWith(']') || token.endsWith('}'))) {
            int openP = token.count('('), closeP = token.count(')');
            int openB = token.count('['), closeB = token.count(']');
            int openC = token.count('{'), closeC = token.count('}');
            if (closeP > openP && token.endsWith(')')) token.chop(1), token = token.trimmed();
            else if (closeB > openB && token.endsWith(']')) token.chop(1), token = token.trimmed();
            else if (closeC > openC && token.endsWith('}')) token.chop(1), token = token.trimmed();
            else break;
        }

        // 5. Unescape WebUI/SD prompt-escaped parentheses and brackets (\( -> (, \) -> ), etc.)
        token.replace(R"(\()", "(")
             .replace(R"(\))", ")")
             .replace(R"(\[)", "[")
             .replace(R"(\])", "]")
             .replace(R"(\{)", "{")
             .replace(R"(\})", "}")
             .replace('\\', "");
        token = token.trimmed();

        // 6. Check again if outer brackets wrap the entire token after unescaping
        if (token.startsWith('(') && token.endsWith(')')) {
            int depth = 0;
            bool isOuter = true;
            for (int i = 0; i < token.length() - 1; ++i) {
                if (token[i] == '(') depth++;
                else if (token[i] == ')') {
                    depth--;
                    if (depth == 0) { isOuter = false; break; }
                }
            }
            if (isOuter && token.count('(') > 1) {
                token = token.mid(1, token.length() - 2).trimmed();
            }
        }

        if (token.isEmpty()) continue;

        // Register the tag with parentheses intact
        if (!meta.tags.contains(token, Qt::CaseInsensitive)) {
            meta.tags.append(token);
        }
    }
}

QString MetadataReader::cleanModelName(const QString& model)
{
    if (model.isEmpty()) return QString();
    QString clean = model.trimmed();
    if (clean.contains('/')) clean = clean.section('/', -1);
    if (clean.contains('\\')) clean = clean.section('\\', -1);
    if (clean.endsWith(".safetensors", Qt::CaseInsensitive)) clean.chop(12);
    if (clean.endsWith(".ckpt", Qt::CaseInsensitive)) clean.chop(5);
    if (clean.endsWith(".pt", Qt::CaseInsensitive)) clean.chop(3);
    return clean.trimmed();
}
