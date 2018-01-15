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
#if 0
	if (!get) {
		emit done(id);
		return true;
	}
#endif
	auto reply = manager.get(QNetworkRequest(url));
	reply->setProperty("id", id);
	reply->setProperty("get", get);
	reply->setProperty("path", path);
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
