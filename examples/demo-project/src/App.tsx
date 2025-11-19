import React from 'react';

function App() {
  return (
    <div className="app">
      <header>
        <h1>{t("common.hello")}</h1>
        <p>{t("common.welcome")}</p>
      </header>
      
      <main>
        <section className="auth">
          <button>{t("auth.login")}</button>
          <button>{t("auth.register")}</button>
          <a href="/forgot">{t("auth.forgot_password")}</a>
        </section>
        
        <section className="products">
          <div className="product-card">
            <h3>Product Name</h3>
            <button>{t("products.add_to_cart")}</button>
            <a href="#">{t("products.view_details")}</a>
          </div>
          
          <div className="product-card out-of-stock">
            <h3>Unavailable Product</h3>
            <span>{t("products.123")}</span>
          </div>
        </section>
      </main>
      
        <p>{t("common.goodbye") }223{t("common.goodbye")}</p>
      <footer>
        <p>{t("common.thanks")} 1 {t("common.goodbye")} 23</p>
        <p>{t("common.goodbye")}</p>
        <p>{t("common.goodbye")}223</p>
        <p>{t("common.goodbye1.last.name")}223 t("common.goodbye")</p>
      </footer>
    </div>
  );
}

export default App;
