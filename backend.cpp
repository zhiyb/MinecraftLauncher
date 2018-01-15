#include <QtCore>
#include <QtNetwork>
#include "backend.h"

BackEnd::BackEnd(QObject *parent) : QObject(parent)
{
	connect(&manager, &QNetworkAccessManager::finished, this, &BackEnd::finished);
}

bool BackEnd::download(const QUrl &url, const QString &path,
		       const bool get, const int id)
{
	QDir dir;
	if (!dir.mkpath(path)) {
		qDebug() << "Cannot create" << path;
		return false;
	}

	qDebug() << "Downloading" << url << "to" << path;

	auto reply = manager.get(QNetworkRequest(url));
	reply->setProperty("id", id);
	reply->setProperty("get", get);
	reply->setProperty("path", path);
	return true;
}

void BackEnd::finished(QNetworkReply *reply)
{
	QByteArray data = reply->readAll();

	int id = reply->property("id").toInt();
	if (reply->property("get").toBool())
		emit ready(QString(data), id);
	else
		emit done(id);

	QString path = reply->property("path").toString();
	if (!QDir().mkpath(path)) {
		qDebug() << "Cannot create" << path;
		return;
	}

	QUrl url = reply->url();
	QString file = QDir(path).filePath(QFileInfo(url.path()).fileName());
	if (path.isEmpty()) {
		qDebug() << "Cannot resolve basename from" << path << url;
		return;
	}

	QFile f(file);
	if (!f.open(QIODevice::WriteOnly)) {
		qDebug() << "Cannot write to file" << file;
		return;
	}

	f.write(data);
	f.close();
}
