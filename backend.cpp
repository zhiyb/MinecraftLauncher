#include <QtCore>
#include <QtNetwork>
#include <unzipper.h>
#include "backend.h"

using namespace zipper;

BackEnd::BackEnd(QObject *parent) : QObject(parent)
{
	connect(&manager, &QNetworkAccessManager::finished, this, &BackEnd::finished);
}

bool BackEnd::postJson(const QString &url, const QString &data, const int id)
{
	QNetworkRequest request(url);
	request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
	auto reply = manager.post(request, data.toLocal8Bit());
	reply->setProperty("id", id);
	reply->setProperty("post", true);
	return true;
}

bool BackEnd::download(const QUrl &url, const QString &path,
		       const bool get, const int id, const QString &sha1)
{
	// Skip if file integrity check passed
	if (sha1 != QString::null && QFileInfo(path).exists()) {
		QFile f(path);
		if (!f.open(QIODevice::ReadOnly))
			goto download;
		QByteArray data;
		QCryptographicHash hash(QCryptographicHash::Sha1);
		if (get) {
			data = f.readAll();
			hash.addData(data);
		} else {
			if (!hash.addData(&f))
				goto download;
		}
		if (QString(hash.result().toHex()) != sha1)
			goto download;
		if (get)
			emit ready(data, id);
		else
			emit done(id);
		return true;
	}

download:
	auto reply = manager.get(QNetworkRequest(url));
	reply->setProperty("id", id);
	reply->setProperty("get", get);
	reply->setProperty("path", path);
	reply->setProperty("sha1", sha1);
	return true;
}

bool BackEnd::extract(const QString &src, const QString &dst, const QStringList &excludes)
{
	Unzipper unzip(src.toLocal8Bit().data());
	unzip.extract(dst.toLocal8Bit().data());
	unzip.close();
	return true;
}

bool BackEnd::exec(const QString &cmd, const QStringList &args, const QString &dir)
{
	QProcess proc;
	proc.setProgram(cmd);
	proc.setArguments(args);
	proc.setWorkingDirectory(dir);
	// Won't work in detached mode
	//proc.setProcessChannelMode(QProcess::ForwardedChannels);
	QTextStream(stdout) << QString("cd %2; %1 %3\n").arg(cmd, dir, QString(args.join(' ')));
	return proc.startDetached();
}

bool BackEnd::copy(const QString &src, const QString &dst)
{
	QString dir = QFileInfo(dst).path();
	if (!QDir().mkpath(dir)) {
		qDebug() << "Cannot create" << dir;
		return false;
	}

	QFile::remove(dst);
	if (!QFile::copy(src, dst)) {
		qDebug() << "Error copying" << src << "to" << dst;
		return false;
	}

	return true;
}

void BackEnd::finished(QNetworkReply *reply)
{
	QByteArray data = reply->readAll();
	int id = reply->property("id").toInt();

	// POST transfer
	if (reply->property("post").isValid()) {
		emit ready(QString(data), id);
		return;
	}

	// Check file integrity
	QString sha1 = reply->property("sha1").toString();
	if (sha1 != QString::null) {
		if (sha1 != QCryptographicHash::hash(data, QCryptographicHash::Sha1).toHex())
			qDebug() << "Download unsuccessful:" << reply->url().toString();
	}

	if (reply->property("get").toBool())
		emit ready(QString(data), id);
	else
		emit done(id);

	QString path = reply->property("path").toString();
	QString dir = QFileInfo(path).path();
	if (!QDir().mkpath(dir)) {
		qDebug() << "Cannot create" << dir;
		return;
	}

	QFile file(path);
	if (!file.open(QIODevice::WriteOnly)) {
		qDebug() << "Cannot write to file" << path;
		return;
	}

	file.write(data);
	file.close();
}
