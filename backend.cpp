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
