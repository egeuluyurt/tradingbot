//+------------------------------------------------------------------+
//|  CTrade.mqh — Emir Açma / Kapama Modülü                         |
//|  Görev: Alış/Satış emirlerini açar, kapatır, yönetir             |
//+------------------------------------------------------------------+
#ifndef CTRADE_MQH
#define CTRADE_MQH

#include <Trade\Trade.mqh>   // MT5 yerleşik trade kütüphanesi

//====================================================================
//  CTrdr — Bizim emir yönetim sınıfımız
//  (MT5'in kendi CTrade sınıfıyla çakışmamak için CTrdr adı kullanılır)
//====================================================================
class CTrdr
{
private:
   CTrade m_trade;           // MT5 yerleşik trade nesnesi
   string    m_sembol;       // İşlem sembolü
   ulong     m_sihirliSayi;  // EA'ya özgü Magic Number (çakışma önler)
   int       m_kaymaTolerans;// Slippage — fiyat kayması toleransı (point)

public:
   //------------------------------------------------------------------
   // Kurucu
   //------------------------------------------------------------------
   CTrdr(string sembol, ulong sihirliSayi, int kaymaTolerans = 10)
      : m_sembol(sembol), m_sihirliSayi(sihirliSayi), m_kaymaTolerans(kaymaTolerans)
   {
      m_trade.SetExpertMagicNumber(m_sihirliSayi);
      m_trade.SetDeviationInPoints(m_kaymaTolerans);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
   }

   //------------------------------------------------------------------
   // Init: OnInit içinde çağrılır
   //------------------------------------------------------------------
   bool Init()
   {
      Print("CTrdr başlatıldı — Sihirli Sayı: ", m_sihirliSayi);
      return true;
   }

   //------------------------------------------------------------------
   // AlisAc: Piyasa fiyatından alış emri açar
   //------------------------------------------------------------------
   bool AlisAc(double lot, double stopLoss = 0, double takeProfit = 0,
               string yorum = "TradingBot Alis")
   {
      double fiyat = SymbolInfoDouble(m_sembol, SYMBOL_ASK);

      if(!m_trade.Buy(lot, m_sembol, fiyat, stopLoss, takeProfit, yorum))
      {
         Print("CTrdr HATA (Alis): ", m_trade.ResultRetcodeDescription(),
               " | Kod: ", m_trade.ResultRetcode());
         return false;
      }

      Print("CTrdr: Alis acildi — Lot: ", lot,
            " | Fiyat: ", fiyat,
            " | SL: ", stopLoss,
            " | TP: ", takeProfit);
      return true;
   }

   //------------------------------------------------------------------
   // SatisAc: Piyasa fiyatından satış emri açar
   //------------------------------------------------------------------
   bool SatisAc(double lot, double stopLoss = 0, double takeProfit = 0,
                string yorum = "TradingBot Satis")
   {
      double fiyat = SymbolInfoDouble(m_sembol, SYMBOL_BID);

      if(!m_trade.Sell(lot, m_sembol, fiyat, stopLoss, takeProfit, yorum))
      {
         Print("CTrdr HATA (Satis): ", m_trade.ResultRetcodeDescription(),
               " | Kod: ", m_trade.ResultRetcode());
         return false;
      }

      Print("CTrdr: Satis acildi — Lot: ", lot,
            " | Fiyat: ", fiyat,
            " | SL: ", stopLoss,
            " | TP: ", takeProfit);
      return true;
   }

   //------------------------------------------------------------------
   // PozisyonKapat: Belirtilen ticket numaralı pozisyonu kapatır
   //------------------------------------------------------------------
   bool PozisyonKapat(ulong ticket)
   {
      if(!m_trade.PositionClose(ticket))
      {
         Print("CTrdr HATA (Kapat): ", m_trade.ResultRetcodeDescription(),
               " | Ticket: ", ticket);
         return false;
      }

      Print("CTrdr: Pozisyon kapatildi — Ticket: ", ticket);
      return true;
   }

   //------------------------------------------------------------------
   // TumPozisyonlariKapat: Bu EA'ya ait tüm pozisyonları kapatır
   //------------------------------------------------------------------
   void TumPozisyonlariKapat()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

         if(PositionGetString(POSITION_SYMBOL) == m_sembol &&
            PositionGetInteger(POSITION_MAGIC) == (long)m_sihirliSayi)
         {
            PozisyonKapat(ticket);
         }
      }
   }

   //------------------------------------------------------------------
   // AcikPozisyonVar: Bu EA'nın açık pozisyonu var mı?
   //------------------------------------------------------------------
   bool AcikPozisyonVar()
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

         if(PositionGetString(POSITION_SYMBOL) == m_sembol &&
            PositionGetInteger(POSITION_MAGIC) == (long)m_sihirliSayi)
            return true;
      }
      return false;
   }

   //------------------------------------------------------------------
   // AcikPozisyonKari: Bu EA'nın tüm açık pozisyonlarının toplam kârı
   //------------------------------------------------------------------
   double AcikPozisyonKari()
   {
      double toplam = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

         if(PositionGetString(POSITION_SYMBOL) == m_sembol &&
            PositionGetInteger(POSITION_MAGIC) == (long)m_sihirliSayi)
            toplam += PositionGetDouble(POSITION_PROFIT);
      }
      return toplam;
   }

   //------------------------------------------------------------------
   // MevcutYon: Açık pozisyonun yönünü döndürür (1=AL, -1=SAT, 0=YOK)
   //------------------------------------------------------------------
   int MevcutYon()
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;

         if(PositionGetString(POSITION_SYMBOL) == m_sembol &&
            PositionGetInteger(POSITION_MAGIC) == (long)m_sihirliSayi)
         {
            ENUM_POSITION_TYPE tur = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            return (tur == POSITION_TYPE_BUY) ? 1 : -1;
         }
      }
      return 0;
   }
};
#endif // CTRADE_MQH
