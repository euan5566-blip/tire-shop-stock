# ระบบจัดการร้านยาง — FINAL

ระบบเว็บสต็อก/ขายสำหรับร้านยางและน้ำมันเครื่อง

## ฟังก์ชัน
- Login Supabase
- Dashboard ยอดขาย/ต้นทุน/กำไร
- สินค้าและสต็อก เพิ่ม/แก้ไข/ลบ
- รับสินค้าเข้า + ประวัติ Stock Movement
- ขายสินค้า + ตัดสต็อกอัตโนมัติ
- ลูกค้า + ทะเบียนรถ
- ใบเสร็จพิมพ์ได้
- ประวัติการขาย + เปิดใบเสร็จเก่า
- ค่าใช้จ่าย
- รายงานกำไร
- Export CSV
- ปิดยอดประจำวัน
- พนักงานและ Role
- Audit Log
- ตั้งค่าข้อมูลร้าน
- Responsive มือถือ/iPad/คอมพิวเตอร์

## ติดตั้ง
1. `npm install`
2. คัดลอก `.env.example` เป็น `.env`
3. ใส่ Supabase URL และ Anon Key
4. รัน `supabase/schema.sql` ใน Supabase SQL Editor
5. สร้างบัญชีผู้ใช้ใน Supabase Authentication
6. `npm run dev`

## สร้าง production
`npm run build`

โฟลเดอร์ `dist` ที่ได้สามารถนำไป deploy บนบริการ static hosting ได้

## ภาษา
- เลือกภาษาได้จากมุมขวาบน: ไทย / ລາວ / English
- ภาษาที่เลือกจะถูกจำไว้ในเครื่องนั้น

## หมายเหตุฐานข้อมูล
- เวอร์ชันนี้ใช้ `bigint` สำหรับ `customers.id`, `cars.id`, `cars.customer_id`, `sales.customer_id` และ `sales.car_id` เพื่อให้ตรงกับฐานข้อมูลที่ใช้งานจริง
- หากฐานข้อมูลปัจจุบันใช้งานได้แล้ว ไม่ต้องรัน `schema.sql` ซ้ำทับฐานข้อมูลเดิม

## V3
- Multi-currency: LAK / THB / USD with configurable exchange rates
- Thai / Lao / English UI
- Product edit and currency
- Daily / monthly / yearly sales and profit reports
- Employee roles and password-reset links via Supabase Auth
