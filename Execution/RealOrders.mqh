//+------------------------------------------------------------------+
//| Execution/RealOrders.mqh                                         |
//| Envio e gestao da posicao real no MetaTrader.                    |
//|                                                                  |
//| Depende de: Core/Globals.mqh (g_trade), Core/Utils.mqh,          |
//|             Execution/VirtualTrades.mqh (TrailStop).             |
//|                                                                  |
//| TRAVA DE SEGURANCA: nada aqui e executado ao vivo sem            |
//| InpLiveOrders = true (ver OrdersAllowed em Core/Utils.mqh).      |
//| No testador as ordens sao sempre permitidas.                     |
//|                                                                  |
//| A gestao da posicao real espelha a das operacoes virtuais        |
//| (mesma funcao TrailStop), para que o estudo e o real nao         |
//| divirjam.                                                        |
//+------------------------------------------------------------------+
#ifndef __ICSM_REALORDERS_MQH__
#define __ICSM_REALORDERS_MQH__

//+------------------------------------------------------------------+
//| Existe posicao real deste EA no simbolo?                         |
//+------------------------------------------------------------------+
bool HasRealPosition()
{
   return PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagic;
}

//+------------------------------------------------------------------+
//| Existe operacao em curso (virtual executada OU posicao real)?    |
//| Usado como filtro de entrada: o ICS opera uma de cada vez.       |
//+------------------------------------------------------------------+
bool HasOpenTrade()
{
   for(int k = 0; k < ArraySize(g_vt); k++)
      if(g_vt[k].active && g_vt[k].taken) return true;
   if(!g_replay && PositionSelect(_Symbol) && PositionGetInteger(POSITION_MAGIC) == InpMagic) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Envia a ordem a mercado com stop e alvo ja definidos             |
//+------------------------------------------------------------------+
bool SendOrder(int dir, double sl, double tp)
{
   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(price <= 0)
   {
      PrintFormat("Ordem nao enviada: sem preco de %s (bid/ask = 0) em %s. No WIN_ICS, rode o arquivador v1.01 com 'Regravar' = true.",
                  dir > 0 ? "compra (ask)" : "venda (bid)", _Symbol);
      return false;
   }
   if(dir > 0 && (price <= sl || price >= tp))
   {
      PrintFormat("Ordem cancelada: preco %.0f ja fora do intervalo stop %.0f / alvo %.0f", price, sl, tp);
      return false;
   }
   if(dir < 0 && (price >= sl || price <= tp))
   {
      PrintFormat("Ordem cancelada: preco %.0f ja fora do intervalo stop %.0f / alvo %.0f", price, sl, tp);
      return false;
   }
   bool ok = (dir > 0) ? g_trade.Buy(InpLots, _Symbol, 0, sl, tp, "ICS_Mod")
                       : g_trade.Sell(InpLots, _Symbol, 0, sl, tp, "ICS_Mod");
   uint rc = g_trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
   {
      PrintFormat("Falha na ordem: %u %s", rc, g_trade.ResultRetcodeDescription());
      return false;
   }
   g_realRisk  = (price - sl) * dir;
   g_realBest  = price;
   g_realBE    = false;
   double atr5 = ATRArr(g_m5, 14);
   g_realTrail = InpTrailATR * atr5;
   return true;
}

//+------------------------------------------------------------------+
//| Zera a posicao real                                              |
//+------------------------------------------------------------------+
void CloseRealPosition(string why)
{
   if(g_replay) return;
   if(!PositionSelect(_Symbol)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
   if(g_trade.PositionClose(_Symbol))
      PrintFormat("Posicao zerada: %s", why);
   else
      PrintFormat("Falha ao zerar (%s): %u", why, g_trade.ResultRetcode());
}

//+------------------------------------------------------------------+
//| Gestao da posicao real a cada barra M1: zeragem, reversao,       |
//| stop de tempo, breakeven e trailing                              |
//+------------------------------------------------------------------+
void ManageRealPosition(const IcsBar &b)
{
   if(!PositionSelect(_Symbol)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
   int      dir  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   double   open = PositionGetDouble(POSITION_PRICE_OPEN);
   datetime pt   = (datetime)PositionGetInteger(POSITION_TIME);
   int      bars = (int)(((long)b.t - (long)pt) / 60) + 1;
   if(MinOfDay(b.t) + 1 >= g_flat)
   {
      CloseRealPosition("horario de zeragem");
      return;
   }
   if(InpReversalExit)
   {
      datetime entryMin = (datetime)(((long)pt / 60) * 60);
      long     minSeq   = 0;
      int      nM1      = ArraySize(g_m1);
      for(int i = 0; i < nM1; i++)
      {
         if(g_m1[i].t == entryMin)
         {
            minSeq = g_m1[i].seq;
            break;
         }
      }
      if(ReversalExitSignal(dir, minSeq))
      {
         CloseRealPosition("reversao");
         return;
      }
   }
   if(!g_realBE && bars >= InpTimeStopBars && (b.c - open) * dir < InpTimeStopMinR * g_realRisk)
   {
      CloseRealPosition("stop de tempo");
      return;
   }
   if(InpExitMode != ICS_EXIT_TRAIL) return;
   double ext = (dir > 0) ? b.h : b.l;
   if((ext - g_realBest) * dir > 0) g_realBest = ext;
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   bool   be    = g_realBE;
   double newSL = TrailStop(dir, open, g_realRisk, g_realBest, curSL, g_realTrail, be);
   g_realBE = be;
   if(MathAbs(newSL - curSL) < g_tick / 2) return;
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(px > 0 && (px - newSL) * dir <= 0)
   {
      CloseRealPosition("trailing (preco ja alem do novo stop)");
      return;
   }
   if(!g_trade.PositionModify(_Symbol, newSL, curTP))
      PrintFormat("Falha ao mover stop para %.0f: %u", newSL, g_trade.ResultRetcode());
}

#endif // __ICSM_REALORDERS_MQH__
//+------------------------------------------------------------------+
