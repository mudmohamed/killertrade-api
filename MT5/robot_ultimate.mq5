//+------------------------------------------------------------------+
//| WINNER ROBOT HH - ULTIMATE EDITION | AUTO-START + WIN BOOST     |
//| Max win rate, auto execution, elite entry refined                |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

input double FixedLot = 0.03;
input int Slippage = 3;
input double RiskATRMultiplier = 1.5;
input double RewardATRMultiplier = 3.0;
input bool UseTrailing = true;
input int TrailingStart = 200;
input int TrailingStep = 30;
input bool UseBreakEven = true;
input int BreakEvenPips = 200;
input int ATR_Period = 14;
input double ATR_Threshold = 50.0;
input bool UseNewsFilter = true;
input bool UseSmartSession = true;
input bool CloseOnOppositeSignal = true;

int magicID = 20250509;
bool autoStarted = false;

int OnInit() {
   Print("✅ ULTIMATE ROBOT INIT - AUTO START & WIN RATE BOOST READY");
   autoStarted = true;
   return INIT_SUCCEEDED;
}

void OnTick() {
   if (!autoStarted) return;
   if (UseNewsFilter && IsHighImpactNews()) return;
   if (UseSmartSession && !IsInSession()) return;
   if (!IsVolatilityOk()) return;

   if (CloseOnOppositeSignal) CheckCloseOnOpposite();

   if (PositionsTotal() == 0) {
      if (UltraBuySignal()) OpenTrade(ORDER_TYPE_BUY);
      else if (UltraSellSignal()) OpenTrade(ORDER_TYPE_SELL);
   } else {
      if (UseTrailing) ManageTrailing();
      if (UseBreakEven) ManageBreakEven();
   }
}

bool IsHighImpactNews() {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   return (now.hour == 13 || now.hour == 14);
}

bool IsInSession() {
   MqlDateTime tm;
   TimeToStruct(TimeCurrent(), tm);
   int hour = tm.hour;
   return (hour >= 7 && hour <= 11) || (hour >= 14 && hour <= 18);
}

bool IsVolatilityOk() {
   int atrHandle = iATR(_Symbol, _Period, ATR_Period);
   double atr[];
   if (CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return false;
   return atr[0] > ATR_Threshold * _Point;
}

bool UltraBuySignal() {
   return iClose(_Symbol, _Period, 1) > iOpen(_Symbol, _Period, 1) &&
          iClose(_Symbol, _Period, 2) < iOpen(_Symbol, _Period, 2) &&
          iLow(_Symbol, _Period, 1) > iLow(_Symbol, _Period, 2) &&
          iClose(_Symbol, _Period, 1) > iHigh(_Symbol, _Period, 2); // extra breakout check
}

bool UltraSellSignal() {
   return iClose(_Symbol, _Period, 1) < iOpen(_Symbol, _Period, 1) &&
          iClose(_Symbol, _Period, 2) > iOpen(_Symbol, _Period, 2) &&
          iHigh(_Symbol, _Period, 1) < iHigh(_Symbol, _Period, 2) &&
          iClose(_Symbol, _Period, 1) < iLow(_Symbol, _Period, 2); // extra breakdown check
}

void OpenTrade(ENUM_ORDER_TYPE type) {
   int atrHandle = iATR(_Symbol, _Period, ATR_Period);
   double atr[];
   if (CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return;

   double atrPips = atr[0];
   double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = (type == ORDER_TYPE_BUY) ? price - atrPips * RiskATRMultiplier : price + atrPips * RiskATRMultiplier;
   double tp = (type == ORDER_TYPE_BUY) ? price + atrPips * RewardATRMultiplier : price - atrPips * RewardATRMultiplier;

   trade.SetExpertMagicNumber(magicID);
   trade.SetDeviationInPoints(Slippage);

   if (type == ORDER_TYPE_BUY)
      trade.Buy(FixedLot, _Symbol, price, sl, tp);
   else
      trade.Sell(FixedLot, _Symbol, price, sl, tp);
}

void ManageTrailing() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (!PositionGetTicket(i)) continue;
      if (!PositionSelect(PositionGetSymbol(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != magicID) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                     ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double newSL;

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && (price - open) >= TrailingStart * _Point) {
         newSL = price - TrailingStep * _Point;
         if (newSL > sl)
            trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
      }
      else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && (open - price) >= TrailingStart * _Point) {
         newSL = price + TrailingStep * _Point;
         if (sl == 0 || newSL < sl)
            trade.PositionModify(PositionGetTicket(i), newSL, PositionGetDouble(POSITION_TP));
      }
   }
}

void ManageBreakEven() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (!PositionGetTicket(i)) continue;
      if (!PositionSelect(PositionGetSymbol(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != magicID) continue;

      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                     ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                     : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && (price - open) >= BreakEvenPips * _Point && sl < open)
         trade.PositionModify(PositionGetTicket(i), open, PositionGetDouble(POSITION_TP));
      else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && (open - price) >= BreakEvenPips * _Point && (sl == 0 || sl > open))
         trade.PositionModify(PositionGetTicket(i), open, PositionGetDouble(POSITION_TP));
   }
}

void CheckCloseOnOpposite() {
   for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (!PositionGetTicket(i)) continue;
      if (!PositionSelect(PositionGetSymbol(i))) continue;
      if (PositionGetInteger(POSITION_MAGIC) != magicID) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if ((type == POSITION_TYPE_BUY && UltraSellSignal()) || (type == POSITION_TYPE_SELL && UltraBuySignal())) {
         trade.PositionClose(PositionGetTicket(i));
         Print("📉 Closed on opposite signal");
      }
   }
}
//+------------------------------------------------------------------+
