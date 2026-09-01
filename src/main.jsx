import React from "react";
import { createRoot } from "react-dom/client";
import "./style.css";

function App() {
  return (
    <div className="app">
      <header className="header">
        <h1>ร้านยางของฉัน</h1>
        <p>ระบบจัดการสต็อกสินค้าและการขาย</p>
      </header>

      <main className="container">
        <div className="cards">
          <div className="card">
            <h2>สต็อกยาง</h2>
            <strong>0</strong>
            <p>รายการ</p>
          </div>

          <div className="card">
            <h2>ลูกค้า</h2>
            <strong>0</strong>
            <p>รายชื่อ</p>
          </div>

          <div className="card">
            <h2>ยอดขายวันนี้</h2>
            <strong>฿0</strong>
            <p>บาท</p>
          </div>
        </div>

        <section className="menu">
          <button>📦 สต็อกสินค้า</button>
          <button>🛒 ขายสินค้า</button>
          <button>👥 ลูกค้า</button>
          <button>🚗 ทะเบียนรถ</button>
          <button>💰 ค่าใช้จ่าย</button>
          <button>📊 รายงานกำไร</button>
        </section>
      </main>
    </div>
  );
}

createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
