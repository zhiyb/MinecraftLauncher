#ifndef BACKEND_H
#define BACKEND_H

#include <QObject>
#include <QNetworkAccessManager>

class BackEnd : public QObject
{
	Q_OBJECT
public:
	explicit BackEnd(QObject *parent = nullptr);

	Q_INVOKABLE bool postJson(const QString &url, const QString &data, const int id);
	Q_INVOKABLE bool download(const QUrl &url, const QString &path,
				  const bool get = false, const int id = 0,
				  const QString &sha1 = QString::null);
	Q_INVOKABLE bool exec(const QString &cmd, const QStringList &args,
			      const QString &dir = QString::null);

signals:
	void ready(const QString &content,  const int &id);
	void done(const int &id);

public slots:

private slots:
	void finished(QNetworkReply *reply);

private:
	QNetworkAccessManager manager;
};

#endif // BACKEND_H
