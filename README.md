# همیار زندگی 🤍

اپلیکیشن شخصی مدیریت زندگی، کارها، اهداف و رابطه — تک‌فایل، Mobile-First، تیره، فارسی و RTL.
Backend آن Supabase است (Auth + Database + Storage + Realtime) و برای انتشار روی GitHub Pages آماده است.

## ساختار پروژه

```
hamyar-zendegi/
├── index.html      ← کل اپ (HTML+CSS+JS) در همین یک فایل
├── supabase.sql    ← اسکریپت کامل ساخت دیتابیس، RLS و Storage
├── manifest.json   ← PWA
├── sw.js           ← Service Worker (کش Shell برنامه)
└── README.md
```

## ۱) ساخت پروژه Supabase

1. به [supabase.com](https://supabase.com) بروید و یک حساب/پروژه جدید بسازید (منطقه نزدیک به کاربران را انتخاب کنید).
2. صبر کنید تا Provisioning پروژه تمام شود.

## ۲) اجرای `supabase.sql`

1. در پنل Supabase به بخش **SQL Editor** بروید.
2. یک Query جدید باز کنید، تمام محتوای فایل `supabase.sql` را در آن Paste کنید.
3. روی **Run** بزنید. این اسکریپت به‌صورت خودکار:
   - همه جدول‌ها (profiles, relationships, tasks, subtasks, tags, goals, moods, memories, challenges, cycles, pomodoro_sessions, activity_logs و ...) را می‌سازد.
   - Row Level Security را روی همه جدول‌ها فعال و Policyهای لازم را تعریف می‌کند.
   - توابع کمکی (ساخت/اتصال رابطه، محاسبه Streak) و Trigger ساخت خودکار پروفایل را می‌سازد.
   - دو Storage Bucket به نام `memory-images` و `avatars` می‌سازد و Policyهای آن‌ها را تنظیم می‌کند.
   - جدول‌های `moods`, `memories`, `challenges` را برای Realtime فعال می‌کند.

اگر پیام خطایی درباره `alter publication supabase_realtime add table ...` گرفتید (چون از قبل اضافه شده)، بدون مشکل است و می‌توانید آن خط را نادیده بگیرید یا حذف کنید و بقیه اسکریپت را اجرا کنید.

## ۳) بررسی Storage Bucketها

به بخش **Storage** بروید و مطمئن شوید دو Bucket با نام‌های `memory-images` و `avatars` ساخته شده‌اند (اسکریپت این کار را خودکار انجام می‌دهد، اما بهتر است چک کنید).

## ۴) تنظیم Auth

1. به **Authentication → Providers** بروید و مطمئن شوید **Email** فعال است.
2. اگر می‌خواهید کاربران بدون تأیید ایمیل مستقیم وارد شوند (برای تست سریع‌تر)، در **Authentication → Settings** گزینه `Confirm email` را خاموش کنید. برای Production توصیه می‌شود روشن بماند.
3. در **Authentication → URL Configuration**، آدرس GitHub Pages نهایی‌تان (مثلاً `https://username.github.io/hamyar-zendegi/`) را به‌عنوان `Site URL` و در `Redirect URLs` اضافه کنید تا لینک بازیابی رمز عبور درست کار کند.

## ۵) گرفتن Supabase URL و Anon Key

در **Project Settings → API**:
- مقدار **Project URL** را کپی کنید.
- مقدار **anon public key** را کپی کنید (⚠️ هرگز `service_role key` را جایی در Frontend استفاده نکنید).

## ۶) قرار دادن Keyها در `index.html`

فایل `index.html` را باز کنید، نزدیک انتهای فایل این دو خط را پیدا کنید:

```js
const SUPABASE_URL = "YOUR_SUPABASE_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

و مقادیر واقعی خودتان را جایگزین کنید:

```js
const SUPABASE_URL = "https://xxxxxxxx.supabase.co";
const SUPABASE_ANON_KEY = "eyJhbGciOi...";
```

## ۷) اجرای Local

چون اپ فقط از یک فایل HTML ساخته شده، کافی است آن را با یک سرور استاتیک ساده اجرا کنید (باز کردن مستقیم فایل با `file://` ممکن است به‌خاطر محدودیت‌های Service Worker/CORS به‌درستی کار نکند):

```bash
npx serve .
# یا
python3 -m http.server 8080
```

سپس آدرس نمایش داده‌شده را در مرورگر باز کنید.

## ۸) آپلود روی GitHub

```bash
git init
git add .
git commit -m "همیار زندگی - نسخه اول"
git branch -M main
git remote add origin https://github.com/USERNAME/hamyar-zendegi.git
git push -u origin main
```

## ۹) فعال‌کردن GitHub Pages

1. در ریپازیتوری روی GitHub به **Settings → Pages** بروید.
2. در بخش **Source**، شاخه `main` و پوشه `/ (root)` را انتخاب کنید.
3. بعد از چند دقیقه، آدرسی شبیه `https://USERNAME.github.io/hamyar-zendegi/` فعال می‌شود.
4. این آدرس را در تنظیمات Redirect URLs پروژه Supabase (مرحله ۴) هم اضافه/تأیید کنید.

## ۱۰) استفاده از اپ

1. اپ را روی موبایل یا دسکتاپ باز کنید.
2. ثبت‌نام کنید (پروفایل به‌صورت خودکار ساخته می‌شود).
3. از تب «رابطه»، یک کد دعوت بسازید و به پارتنرتان بدهید، یا کد او را وارد کنید.
4. تسک، هدف، Mood، خاطره و چالش اضافه کنید و Pomodoro را امتحان کنید.
5. برای نصب PWA روی موبایل: در مرورگر گزینه «Add to Home Screen» را بزنید.

## نکات امنیتی

- فقط از **Anon Key** در Frontend استفاده شده؛ `service_role key` هرگز نباید در کد Frontend قرار بگیرد.
- تمام محافظت داده‌ها در سطح دیتابیس با **Row Level Security** پیاده‌سازی شده، نه فقط با مخفی‌کردن UI.
- اطلاعات Cycle Tracker به‌صورت پیش‌فرض خصوصی است و فقط با روشن‌کردن گزینه Share برای پارتنر قابل مشاهده می‌شود.
- Mood هر روز پیش‌فرض خصوصی است مگر کاربر گزینه «اشتراک با پارتنر» را فعال کند.
- عکس خاطرات در Supabase Storage ذخیره می‌شوند، نه به‌صورت Base64 در دیتابیس.
- اگر تصمیم گرفتید ایمیل‌های واقعی و Production داشته باشید، حتماً `Confirm email` را در Supabase Auth روشن نگه دارید و از HTTPS (که GitHub Pages به‌صورت پیش‌فرض فراهم می‌کند) استفاده کنید.

## تم و حالت روشن/تیره

پالت رنگی اپ به یک تم لوکس با لهجه طلایی (Gold) به‌جای بنفش قبلی تغییر کرده و یک سوییچ «تیره / روشن» به بخش تنظیمات اضافه شده است. انتخاب کاربر در `localStorage` (کلید `hamyar_prefs`, فیلد `theme`) ذخیره می‌شود — این مطابق با قانون کلی پروژه است که فقط تنظیمات ظاهری اجازه دارند در LocalStorage بمانند و داده‌های اصلی همیشه در Supabase ذخیره می‌شوند.

## یک تصمیم طراحی مهم که باید بدانید

طبق خواسته پروژه، تمام **نمایش** تاریخ‌ها در سراسر اپ به تقویم شمسی تبدیل می‌شود (کارت‌ها، Badgeها، هدر Today، تقویم هفتگی و غیره) و در دیتابیس همه‌چیز استاندارد میلادی/ISO ذخیره می‌شود. برای **وارد کردن** تاریخ (مثلاً هنگام ساخت تسک یا هدف) از `<input type="date">` استاندارد مرورگر استفاده شده تا از یک انتخابگر تاریخ سفارشی پیچیده که نگهداری آن دشوارتر است پرهیز شود؛ در بیشتر مرورگرهای فارسی/موبایل، همین ورودی با فرمت بومی دستگاه نمایش داده می‌شود. اگر تمایل دارید یک تقویم شمسی کاملاً سفارشی برای وارد کردن تاریخ هم اضافه شود، این قابل توسعه است.

## عیب‌یابی سریع

| مشکل | راه‌حل احتمالی |
|---|---|
| «اتصال به سرور برقرار نیست» همیشه نمایش داده می‌شود | مقدار `SUPABASE_URL` و `SUPABASE_ANON_KEY` را دوباره چک کنید |
| بعد از ثبت‌نام وارد اپ نمی‌شوید | تنظیم `Confirm email` را در Supabase Auth بررسی کنید |
| آپلود عکس خاطره کار نمی‌کند | مطمئن شوید Bucket با نام `memory-images` ساخته شده و Policyهای آن اجرا شده‌اند |
| پارتنر خاطرات/چالش‌ها را نمی‌بیند | مطمئن شوید هر دو کاربر واقعاً با کد دعوت به هم متصل شده‌اند (هر دو `user1_id` و `user2_id` در جدول relationships پر باشد) |
