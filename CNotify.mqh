//+------------------------------------------------------------------+
//|  CNotify.mqh — 3 Katmanlı Bildirim Modülü                       |
//|  Katman 1 BİLGİ  → Journal (Print)                              |
//|  Katman 2 DİKKAT → Comment + SendNotification + ses             |
//|  Katman 3 ACİL   → Alert + SendNotification + ses(×3)           |
//+------------------------------------------------------------------+
#ifndef CNOTIFY_MQH
#define CNOTIFY_MQH

//====================================================================
//  KATMAN SABİTLERİ
//====================================================================
#define NOTIFY_BILGI    1    // Mavi/yeşil — yalnızca Journal
#define NOTIFY_DIKKAT   2    // Sarı/turuncu — Comment + telefon
#define NOTIFY_ACIL     3    // Kırmızı — Alert + telefon

//====================================================================
//  SOĞUTMA SÜRELERİ (saniye)
//====================================================================
#define SOGUTMA_DIKKAT   300    //  5 dakika
#define SOGUTMA_ACIL    1800    // 30 dakika

//====================================================================
//  GÜNLÜK BİLDİRİM LİMİTİ
//  SendNotification() günde maks 10 çağrıya izin verir
//====================================================================
#define TELEFON_GUNLUK_LIMIT 10

//====================================================================
//  HATA KODU ÇEVIRICI
//  Ham MT5 hata kodlarını Türkçe açıklamaya dönüştürür
//====================================================================
string HataMetni(int kod)
{
   switch(kod)
   {
      case 134:  return "Yeterli bakiye yok";
      case 133:  return "Otomatik işlem kapalı — MT5 araç çubuğunu kontrol edin";
      case 130:  return "Stop seviyesi çok yakın — broker minimumunu kontrol edin";
      case 135:  return "Fiyat değişti — yeniden deneyin";
      case 136:  return "Fiyat alınamadı — bağlantıyı kontrol edin";
      case 138:  return "Requote — fiyat değişti";
      case 146:  return "İşlem sistemi meşgul — kısa süre bekleyin";
      case 4109: return "Otomatik işleme izin verilmiyor";
      case 4756: return "İşlem gönderim hatası";
      default:  return "Hata kodu " + IntegerToString(kod);
   }
}

//====================================================================
//  CNotify
//====================================================================
class CNotify
{
private:
   //--- Soğutma zamanları: her mesaj anahtarı için son gönderim anı
   //    Anahtar: katman + "_" + kısa mesaj özeti
   //    Basit implementasyon: sabit sayıda slot (maks 32 farklı uyarı türü)
   static const int  SLOT_SAYISI = 32;
   string   m_anahtarlar[SLOT_SAYISI];
   datetime m_zamanlar  [SLOT_SAYISI];
   int      m_slotSayisi;

   //--- Günlük telefon bildirimi sayacı
   int      m_telefonSayaci;
   datetime m_telefonGunBaslangici;

   //--- Son Comment metni (birikmeli gösterim için)
   string   m_sonComment;

   //------------------------------------------------------------------
   // YARDIMCI: Soğutma kontrolü
   // Döndürür: true → gönderilebilir, false → soğutma süresinde
   //------------------------------------------------------------------
   bool SogutmaGecti(string anahtar, int sogutmaSaniye)
   {
      datetime simdi = TimeCurrent();

      // Mevcut slotu bul
      for(int i = 0; i < m_slotSayisi; i++)
      {
         if(m_anahtarlar[i] == anahtar)
         {
            if((simdi - m_zamanlar[i]) >= sogutmaSaniye)
            {
               m_zamanlar[i] = simdi;  // Zamanı güncelle
               return true;
            }
            return false;  // Soğutmada
         }
      }

      // Yeni anahtar — ekle
      if(m_slotSayisi < SLOT_SAYISI)
      {
         m_anahtarlar[m_slotSayisi] = anahtar;
         m_zamanlar  [m_slotSayisi] = simdi;
         m_slotSayisi++;
      }
      else
      {
         // Slot doldu — en eski girişin üzerine yaz (FIFO)
         int enEski = 0;
         for(int i = 1; i < SLOT_SAYISI; i++)
            if(m_zamanlar[i] < m_zamanlar[enEski]) enEski = i;
         m_anahtarlar[enEski] = anahtar;
         m_zamanlar  [enEski] = simdi;
      }
      return true;
   }

   //------------------------------------------------------------------
   // YARDIMCI: Soğutma anahtarı üret (mesajın ilk 40 karakteri)
   //------------------------------------------------------------------
   string Anahtar(int katman, string mesaj)
   {
      string oz = StringSubstr(mesaj, 0, 40);
      return IntegerToString(katman) + "_" + oz;
   }

   //------------------------------------------------------------------
   // YARDIMCI: Günlük telefon limitini kontrol et ve sayacı güncelle
   //------------------------------------------------------------------
   bool TelefonGonderilebirMi()
   {
      // Yeni gün geldi mi? Sayacı sıfırla
      datetime simdi = TimeCurrent();
      MqlDateTime md;
      TimeToStruct(simdi, md);
      md.hour = 0; md.min = 0; md.sec = 0;
      datetime bugun = StructToTime(md);

      if(m_telefonGunBaslangici < bugun)
      {
         m_telefonSayaci      = 0;
         m_telefonGunBaslangici = bugun;
      }

      if(m_telefonSayaci >= TELEFON_GUNLUK_LIMIT)
      {
         Print("CNotify: Günlük telefon bildirimi limiti (", TELEFON_GUNLUK_LIMIT,
               ") doldu — yalnızca Journal'a yazılıyor.");
         return false;
      }

      m_telefonSayaci++;
      return true;
   }

   //------------------------------------------------------------------
   // YARDIMCI: Comment alanını güncelle (son 5 mesajı tut)
   //------------------------------------------------------------------
   void CommentGuncelle(string yeniSatir)
   {
      // Yeni satırı en üste ekle, eski satırları kaydır
      string satirlar[];
      StringSplit(m_sonComment, '\n', satirlar);

      string yeni = yeniSatir;
      int limit = MathMin(ArraySize(satirlar), 4);
      for(int i = 0; i < limit; i++)
         if(satirlar[i] != "") yeni += "\n" + satirlar[i];

      m_sonComment = yeni;
      Comment(m_sonComment);
   }

   //------------------------------------------------------------------
   // KATMAN 1: BİLGİ
   //------------------------------------------------------------------
   void GonderBilgi(string mesaj)
   {
      Print(mesaj);
      // Panel OlayEkle çağrısı CKernel üzerinden yönetilir — burada sadece Journal
   }

   //------------------------------------------------------------------
   // KATMAN 2: DİKKAT
   //------------------------------------------------------------------
   void GonderDikkat(string mesaj, bool sesli)
   {
      // Comment + Journal
      CommentGuncelle(mesaj);
      Print(mesaj);

      // Ses
      if(sesli) PlaySound("alert.wav");

      // Telefon (limit kontrolü)
      if(TelefonGonderilebirMi())
         SendNotification(mesaj);
   }

   //------------------------------------------------------------------
   // KATMAN 3: ACİL
   //------------------------------------------------------------------
   void GonderAcil(string mesaj, bool sesli)
   {
      // Alert popup + Journal
      Alert(mesaj);
      Print(mesaj);

      // Ses × 3
      if(sesli)
      {
         PlaySound("news.wav");
         Sleep(800);
         PlaySound("news.wav");
         Sleep(800);
         PlaySound("news.wav");
      }

      // Telefon (limit kontrolü)
      if(TelefonGonderilebirMi())
         SendNotification(mesaj);
   }

public:
   //------------------------------------------------------------------
   // Kurucu
   //------------------------------------------------------------------
   CNotify()
      : m_slotSayisi(0),
        m_telefonSayaci(0),
        m_telefonGunBaslangici(0),
        m_sonComment("")
   {
      for(int i = 0; i < SLOT_SAYISI; i++)
      {
         m_anahtarlar[i] = "";
         m_zamanlar[i]   = 0;
      }
   }

   //====================================================================
   //  ANA BİLDİRİM FONKSİYONU
   //
   //  katman  — NOTIFY_BILGI / NOTIFY_DIKKAT / NOTIFY_ACIL
   //  mesaj   — Gönderilecek metin (şablon kullan veya doğrudan ver)
   //  sesli   — true → ses çal (katman 1'de etkisizdir)
   //====================================================================
   void Bildir(int katman, string mesaj, bool sesli = false)
   {
      string anahtar;

      switch(katman)
      {
         //--------------------------------------------------------------
         case NOTIFY_BILGI:
            GonderBilgi(mesaj);
            break;

         //--------------------------------------------------------------
         case NOTIFY_DIKKAT:
            anahtar = Anahtar(NOTIFY_DIKKAT, mesaj);
            if(!SogutmaGecti(anahtar, SOGUTMA_DIKKAT))
            {
               // Soğutmada — yalnızca Journal
               Print("CNotify [soğutma/DIKKAT]: ", mesaj);
               break;
            }
            GonderDikkat(mesaj, sesli);
            break;

         //--------------------------------------------------------------
         case NOTIFY_ACIL:
            anahtar = Anahtar(NOTIFY_ACIL, mesaj);
            if(!SogutmaGecti(anahtar, SOGUTMA_ACIL))
            {
               Print("CNotify [soğutma/ACİL]: ", mesaj);
               break;
            }
            GonderAcil(mesaj, sesli);
            break;

         //--------------------------------------------------------------
         default:
            Print("CNotify UYARI: Bilinmeyen katman — ", katman, " — ", mesaj);
            break;
      }
   }

   //====================================================================
   //  HAZIR MESAJ ŞABLONLARı
   //  Her şablon doğru katmanı ve formatı otomatik seçer
   //====================================================================

   //------------------------------------------------------------------
   // Katman 1 — İşlem açıldı
   //------------------------------------------------------------------
   void IslemAcildi(string sembol, string yon, string saat)
   {
      Bildir(NOTIFY_BILGI,
             "✅ Yeni işlem açıldı — " + sembol + " " + yon + " " + saat);
   }

   //------------------------------------------------------------------
   // Katman 1 — Koruma devreye girdi (stop-loss tetiklendi)
   //------------------------------------------------------------------
   void KorumaDevreye(string sembol, double zarar, string para)
   {
      string zararTxt = DoubleToString(zarar, 2);
      Bildir(NOTIFY_BILGI,
             "🛡️ Koruma devreye girdi — zarar sınırlandırıldı.\n"
             + sembol + " işlemi " + zararTxt + " " + para + " ile kapandı.");
   }

   //------------------------------------------------------------------
   // Katman 1 — Kâr hedefine ulaşıldı
   //------------------------------------------------------------------
   void KarHedefi(string sembol, double kar, string para)
   {
      string karTxt = "+" + DoubleToString(kar, 2);
      Bildir(NOTIFY_BILGI,
             "🎯 Kâr hedefine ulaşıldı! " + sembol + " " + karTxt + " " + para + " kârla kapandı.");
   }

   //------------------------------------------------------------------
   // Katman 2 — Haber saati yakın
   //------------------------------------------------------------------
   void HaberSaatiYakin(int dakika = 15)
   {
      Bildir(NOTIFY_DIKKAT,
             "⚠️ DİKKAT: " + IntegerToString(dakika) +
             " dakika sonra önemli ekonomik veri açıklanacak.\n"
             "Piyasada ani hareketler olabilir. EA güvenlik için beklemeye geçti.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 2 — Yetersiz bakiye
   //------------------------------------------------------------------
   void YetersizBakiye()
   {
      Bildir(NOTIFY_DIKKAT,
             "⚠️ DİKKAT: Hesabınızda yeni işlem açmak için yeterli\n"
             "para kalmadı. Mevcut işlemler korunmaya devam ediyor.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 2 — Drawdown uyarısı (%30+)
   //------------------------------------------------------------------
   void DrawdownUyarisi(double yuzde)
   {
      Bildir(NOTIFY_DIKKAT,
             "⚠️ DİKKAT: Hesap değer kaybı %" +
             DoubleToString(yuzde, 1) + " seviyesine ulaştı.\n"
             "EA risk limitlerini uygulayarak pozisyonları izliyor.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 2 — Yüksek spread
   //------------------------------------------------------------------
   void YuksekSpread(string sembol, double spreadPip)
   {
      Bildir(NOTIFY_DIKKAT,
             "⚠️ DİKKAT: " + sembol + " spread normalin üzerinde (" +
             DoubleToString(spreadPip, 1) + " pip).\n"
             "EA yeni limit emirlerini askıya aldı.",
             false);
   }

   //------------------------------------------------------------------
   // Katman 2 — Bağlantı kararsız
   //------------------------------------------------------------------
   void BaglantiKararsiz()
   {
      Bildir(NOTIFY_DIKKAT,
             "⚠️ DİKKAT: Sunucuyla bağlantı kesildi.\n"
             "Yeniden bağlanılmaya çalışılıyor...\n"
             "İşlemleriniz broker tarafında güvende.",
             false);
   }

   //------------------------------------------------------------------
   // Katman 2 — Art arda 3 kayıp
   //------------------------------------------------------------------
   void UcArdasiKayip()
   {
      Bildir(NOTIFY_DIKKAT,
             "⚠️ DİKKAT: Art arda 3 işlem zararda kapandı.\n"
             "EA pozisyon büyüklüğünü koruyarak izlemeye devam ediyor.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 3 — 5 ardışık kayıp → EA durdu
   //------------------------------------------------------------------
   void BesArdasiKayip()
   {
      Bildir(NOTIFY_ACIL,
             "🛑 ACİL: Art arda 5 işlem zararda kapandı.\n"
             "EA güvenliğiniz için otomatik durdu.\n"
             "Piyasa sakinleşince yeniden başlayabilirsiniz.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 3 — Drawdown %50+
   //------------------------------------------------------------------
   void KritikDrawdown(double yuzde)
   {
      Bildir(NOTIFY_ACIL,
             "🛑 ACİL: Hesap değer kaybı kritik seviyede — %" +
             DoubleToString(yuzde, 1) + ".\n"
             "EA tüm işlemleri durdurdu. Lütfen hesabınızı kontrol edin.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 3 — Margin tehlikeli
   //------------------------------------------------------------------
   void MarginTehlike(double marjinYuzde)
   {
      Bildir(NOTIFY_ACIL,
             "🛑 ACİL: Teminat seviyesi tehlikeli — %" +
             DoubleToString(marjinYuzde, 1) + ".\n"
             "Broker otomatik kapatma yapabilir. Acilen müdahale edin.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 3 — Bağlantı uzun süre kopuk (10+ dakika)
   //------------------------------------------------------------------
   void BaglantiKopuk(int dakika)
   {
      Bildir(NOTIFY_ACIL,
             "🛑 ACİL: Sunucuyla bağlantı " + IntegerToString(dakika) +
             " dakikadır kopuk.\n"
             "İşlemlerinizi broker web arayüzünden kontrol edin.",
             true);
   }

   //------------------------------------------------------------------
   // Katman 1/2 — MT5 hata kodu bildirimi (ham kod gösterme)
   //------------------------------------------------------------------
   void HataKodu(int kod, string ek = "")
   {
      string aciklama = HataMetni(kod);
      if(ek != "") aciklama += " — " + ek;

      // Kritik hatalar katman 2, genel hatalar katman 1
      int katman = (kod == 134 || kod == 4756) ? NOTIFY_DIKKAT : NOTIFY_BILGI;
      bool sesli = (katman == NOTIFY_DIKKAT);

      Bildir(katman, "⚠️ " + aciklama, sesli);
   }

   //------------------------------------------------------------------
   // Günlük özet (katman 1)
   //------------------------------------------------------------------
   void GunlukOzet(int islemSayisi, double netKar, string para)
   {
      string isaret = (netKar >= 0) ? "+" : "";
      Bildir(NOTIFY_BILGI,
             "📊 Günlük özet: " + IntegerToString(islemSayisi) +
             " işlem — Net: " + isaret + DoubleToString(netKar, 2) + " " + para);
   }

   //------------------------------------------------------------------
   // Kalan telefon bildirimi kotasını sorgula
   //------------------------------------------------------------------
   int KalanTelefonKotasi() const
   {
      return TELEFON_GUNLUK_LIMIT - m_telefonSayaci;
   }
};
#endif // CNOTIFY_MQH
