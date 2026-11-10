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

## 3) Çalışan hesapları
Her çalışan için Supabase → Authentication → Users → Add user ile ayrı bir kullanıcı oluştur. Her birinin UUID'sini al ve şu sorguyu çalışan başına çalıştır:

```sql
insert into public.profiles(id, business_id, full_name, role)
values ('CALISAN_AUTH_UUID', 'BUSINESS_UUID', 'Çalışan Adı', 'staff');
```

Çalışan e-posta ve parolalarını güvenli şekilde kendilerine ilet. Bir çalışanı sistemden çıkarmak için `profiles.active=false` yap; kayıtlarını silme.

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
