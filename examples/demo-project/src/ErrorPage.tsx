import React from 'react';

interface ErrorPageProps {
  errorCode: 404 | 500 | 401;
}

function ErrorPage({ errorCode }: ErrorPageProps) {
  const getErrorMessage = () => {
    switch (errorCode) {
      case 404:
        return t("errors.not_found");
      case 500:
        return t("errors.server_error");
      case 401:
        return t("errors.unauthorized");
    }
  };

  return (
    <div className="error-page">
      <h1>{errorCode}</h1>
      <p>{getErrorMessage()}</p>
      <a href="/">{t("common.welcome")}</a>
    </div>
  );
}

export default ErrorPage;
