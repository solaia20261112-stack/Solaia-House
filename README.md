# 義式餐廳 POS 安裝說明

這是依照原點餐系統製作的獨立版本，內建 60 筆紙本菜單品項。四吋巴斯克乳酪蛋糕暫設 NT$480。店主登入後，可以在菜單管理新增品項、調整價格、上傳照片及上下架。

## 1. 建立新店的資料庫

1. 為新店建立一個全新的 Supabase 專案。
2. 在新專案的 SQL Editor 貼上並執行 `database/install.sql` 的完整內容。安裝檔包含餐廳資料表、權限、儲存空間及初始菜單，供新專案第一次安裝使用。
3. 在該專案的 Authentication 建立第一位店主帳號。
4. 把下方的 `owner@example.com` 換成剛建立的店主信箱，在同一個新專案的 SQL Editor 執行。應看到一筆 `owner` 結果。

```sql
INSERT INTO public.restaurant_staff (user_id, role)
SELECT id, 'owner'
FROM auth.users
WHERE lower(email) = lower('owner@example.com')
RETURNING user_id, role;
```

5. 如需從後台管理員工帳號，在同一專案部署 `supabase/functions/restaurant-staff/index.ts`，函式名稱為 `restaurant-staff`。使用函式內建的登入身分與店主權限驗證，部署時關閉閘道的舊版 JWT 驗證。若以 Supabase CLI 部署，可在解壓後的根目錄執行 `supabase functions deploy restaurant-staff --project-ref 新店的專案代碼 --no-verify-jwt`。函式從伺服器的環境變數讀取服務金鑰。

## 2. 設定並上傳網頁

1. 開啟 `restaurant-config.js`，填入正式店名、**新專案**的 Project URL 和 Publishable key。網頁設定只使用 Publishable key。
2. 把 `index.html`、`restaurant-config.js` 和整個 `assets/` 資料夾放在同一個靜態網站目錄，透過 HTTPS 開啟。網址後加 `?view=menu` 可開啟客用菜單。設定留空時，首頁會顯示內建菜單預覽。
3. 店主登入後可編輯菜單，並依員工職務設定權限。可在工作台為各桌產生專屬 QR Code。
4. 營業前以測試桌確認客人送單、店員審單、廚房出餐和結帳，再核對訂位設定。這版沿用樣版的時段限制，週一不開放訂位、午餐 11:30–14:30、晚餐 17:30–21:00，開放未來 30 天，單筆 1–8 位。若新店時段不同，需同步調整網頁與資料庫規則後再開放訂位。

菜單上的「限內用」顯示於品名，櫃台依店內規則核對。包內初始菜單用於首次安裝，日常更改請在後台操作。
