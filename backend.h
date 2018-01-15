#ifndef BACKEND_H
#define BACKEND_H

#include <QObject>
#include <QNetworkAccessManager>

class BackEnd : public QObject
{
	Q_OBJECT
public:
	explicit BackEnd(QObject *parent = nullptr);

	Q_INVOKABLE bool download(const QUrl &url, const QString &path,
				  const bool get = false, const int id = 0);

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
