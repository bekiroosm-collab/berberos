# BerberOS — GitHub + Vercel + Supabase kurulum rehberi

Bu proje Vite + React + TypeScript + Supabase kullanır. Veriler gerçek Supabase veritabanında tutulur; kullanıcı girişi Supabase Auth ile yapılır. Vercel yalnızca web arayüzünü yayınlar.

## 1) Supabase veritabanı
1. https://supabase.com adresinden yeni bir proje aç.
2. Sol menüden **SQL Editor → New query** bölümüne gir.
3. `supabase/schema.sql` dosyasının tamamını yapıştırıp **Run** de.
4. Supabase **Project Settings → API** bölümünden Project URL ve `anon` / publishable key değerlerini al. `service_role` anahtarını asla Vercel'in `VITE_` değişkenine koyma.

## 2) Ergün patron hesabı
1. Supabase → Authentication → Users → Add user bölümünden Ergün için e-posta ve geçici parola ile kullanıcı oluştur. İstersen “Auto Confirm User” seç.
2. Oluşan kullanıcının UUID'sini kopyala.
3. SQL Editor'de aşağıdaki komutları çalıştır. UUID ve işletme adını kendine göre değiştir:

```sql
insert into public.businesses(name, owner_id)
values ('Ergün Erkek Kuaförü', 'ERGUN_AUTH_UUID')
returning id;
```

Dönen business `id` değerini kopyala, sonra:

```sql
insert into public.profiles(id, business_id, full_name, role)
values ('ERGUN_AUTH_UUID', 'BUSINESS_UUID', 'Ergün', 'owner');
```

## 3) Çalışan hesaplarını patron panelinden oluşturma

Çalışan hesabı oluşturma özelliği Supabase Edge Function üzerinden çalışır. Supabase'in **service_role** anahtarı yalnızca sunucuda kalır; Vercel ortam değişkenlerine `VITE_` önekiyle eklenmez.

1. Supabase projesinde **Edge Functions** bölümünü aç veya bilgisayarında Supabase CLI kurup projeye bağlan.
2. Bu depodaki `supabase/functions/create-employee/index.ts` fonksiyonunu `create-employee` adıyla deploy et.
3. Supabase → **Project Settings → API** bölümündeki Project URL, anon/publishable key ve service_role key değerlerinin projeye ait olduğunu doğrula. Edge Functions ortamında `SUPABASE_URL`, `SUPABASE_ANON_KEY` ve `SUPABASE_SERVICE_ROLE_KEY` değişkenlerinin tanımlı olması gerekir. Supabase, yeni projelerde `SUPABASE_PUBLISHABLE_KEYS` ve `SUPABASE_SECRET_KEYS` değişkenlerini otomatik sağlar; fonksiyon bu yeni anahtarları kullanır ve eski `ANON_KEY` / `SERVICE_ROLE_KEY` ortam değişkenlerini de geriye dönük destekler. Bu anahtarları GitHub'a veya Vercel'in `VITE_` değişkenlerine ekleme.
4. Fonksiyonun JWT doğrulaması açık kalmalı. Fonksiyon ayrıca oturumu doğrular ve yalnızca aktif `owner` rolüne izin verir.
5. Vercel yeni commit'i yayınladıktan sonra Ergün hesabıyla giriş yap → **Çalışanlar → Çalışan ekle**. Ad soyad, e-posta ve en az 8 karakterli geçici şifreyi gir.

Örnek CLI komutları:

```bash
supabase login
supabase link --project-ref PROJE_REF
supabase functions deploy create-employee
```

Supabase Dashboard üzerinden deploy ediyorsan fonksiyon klasöründeki `index.ts` içeriğini `create-employee` fonksiyonuna ekle. Çalışan hesabı oluşturulunca profil otomatik olarak Ergün'ün işletmesine `staff` rolüyle bağlanır. Parola profiles tablosuna yazılmaz; Supabase Auth tarafından yönetilir. Bir çalışanı sistemden çıkarmak için `profiles.active=false` yap; kayıtlarını silme.


## 4) Yerelde çalıştırma
1. Bu klasörü GitHub reposuna yükle.
2. `.env.example` dosyasını `.env` olarak kopyala.
3. `.env` içine Supabase Project URL ve anon/publishable key değerlerini gir:

```env
VITE_SUPABASE_URL=https://PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=SUPABASE_ANON_OR_PUBLISHABLE_KEY
```

4. Terminal:

```bash
npm install
npm run dev
```

## 5) Vercel yayınlama
1. GitHub reposunu Vercel'e import et.
2. Framework Preset: **Vite**; Build Command: `npm run build`; Output Directory: `dist`.
3. Vercel → Project Settings → Environment Variables içine `VITE_SUPABASE_URL` ve `VITE_SUPABASE_ANON_KEY` ekle.
4. Redeploy yap.
5. Domainini Vercel → Settings → Domains bölümünden ekle; Vercel'in verdiği DNS kayıtlarını domain sağlayıcında tanımla.
6. Supabase → Authentication → URL Configuration bölümünde Site URL olarak kendi domainini, Redirect URLs listesine `https://SENIN-DOMAININ/**` ekle.

## İş mantığı ve önemli notlar
- Çalışanların işlem fiyatı sabit değildir; her işlemde serbest fiyat girilir.
- Çalışan işlemlerinde varsayılan paylaşım %50 çalışan / %50 dükkân olarak kaydedilir.
- Ergün'ün kendi işlemi %100 Ergün olarak değerlendirilir.
- Paylaşım oranı işlem kaydına yazılır; geçmiş işlemlerin oranı sonradan değişmez.
- Tahsil edilen tutar, hizmet tutarından ayrı kaydedilir. Ödenmeyen tutar kasaya girmiş gibi sayılmaz.
- Çalışanlar yalnızca kendi randevu ve işlem kayıtlarını görür; patron tüm çalışan kayıtlarını görür. Bu erişim Supabase RLS politikalarıyla uygulanır.
- İlk sürümde randevu çakışma kontrolü, müşteri kartı ekranı, otomatik WhatsApp bildirimleri, sesli AI komutları ve tam muhasebe/ödeme mutabakatı henüz yoktur. Bunlar canlı kullanımdan önce sonraki geliştirme adımlarıdır.
- Kullanıcı oluşturma şu an Supabase panelinden yapılır. İleride güvenli Edge Function ile patron paneline alınabilir.

## Canlıya almadan önce
Gerçek müşteri verisi girmeden önce yedekleme, test kullanıcıları, randevu çakışma kontrolü, kasa mutabakatı ve çalışan/işletme ile paylaşım oranının Ergün tarafından teyit edilmesi gerekir. Bu sürüm bir çalışan içi operasyon MVP'sidir; vergi/muhasebe yazılımı değildir.
