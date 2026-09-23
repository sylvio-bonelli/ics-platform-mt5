//+------------------------------------------------------------------+
//| Execution/RealOrders.mqh                                         |
//| Envio e gestao da posicao real no MetaTrader.                    |
//|                                                                  |
//| Depende de: Core/Globals.mqh (g_trade), Core/Utils.mqh,          |
//|             Execution/VirtualTrades.mqh (TrailStop),             |
//|             Execution/Logger.mqh (LogOrder).                     |
//|                                                                  |
//| TRAVA DE SEGURANCA: nada aqui e executado ao vivo sem            |
//| InpLiveOrders = true (ver OrdersAllowed em Core/Utils.mqh).      |
//| No testador as ordens sao sempre permitidas.                     |
//|                                                                  |
//| A gestao da posicao real espelha a das operacoes virtuais        |
//| (mesma funcao TrailStop), para que o estudo e o real nao         |
//| divirjam. Com o trilho ligado, o volume real segue as fatias    |
//| que TrilhoBarra ja fechou na virtual do mesmo sinal.             |
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
bool SendOrder(int dir, double sl, double tp, int sigId)
{
   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string cmt   = "ICS|" + IntegerToString(sigId);
   if(price <= 0)
   {
      PrintFormat("Ordem nao enviada: sem preco de %s (bid/ask = 0) em %s. No WIN_ICS, rode o arquivador v1.01 com 'Regravar' = true.",
                  dir > 0 ? "compra (ask)" : "venda (bid)", _Symbol);
      LogOrder("FAIL", sigId, 0, 0, 0, 0, sl, tp);
      return false;
   }
   if(dir > 0 && (price <= sl || price >= tp))
   {
      PrintFormat("Ordem cancelada: preco %.0f ja fora do intervalo stop %.0f / alvo %.0f", price, sl, tp);
      LogOrder("FAIL", sigId, 0, 0, price, 0, sl, tp);
      return false;
   }
   if(dir < 0 && (price >= sl || price <= tp))
   {
      PrintFormat("Ordem cancelada: preco %.0f ja fora do intervalo stop %.0f / alvo %.0f", price, sl, tp);
      LogOrder("FAIL", sigId, 0, 0, price, 0, sl, tp);
      return false;
   }
   bool ok = (dir > 0) ? g_trade.Buy(InpLots, _Symbol, 0, sl, tp, cmt)
                       : g_trade.Sell(InpLots, _Symbol, 0, sl, tp, cmt);
   uint   rc     = g_trade.ResultRetcode();
   ulong  ticket = g_trade.ResultOrder();
   double fill   = g_trade.ResultPrice();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
   {
      PrintFormat("Falha na ordem: %u %s", rc, g_trade.ResultRetcodeDescription());
      LogOrder("FAIL", sigId, ticket, rc, price, fill, sl, tp);
      return false;
   }
   LogOrder("SEND", sigId, ticket, rc, price, fill, sl, tp);
   g_realSignalId = sigId;
   g_realRisk  = (price - sl) * dir;
   g_realBest  = price;
   g_realBE    = false;
   double atr5 = ATRArr(g_m5, 14);
   g_realTrail = InpTrailATR * atr5;
   return true;
}

//+------------------------------------------------------------------+
//| Teto de prejuizo em R$: marca o dia e zera a posicao se houver.  |
//| Chamado a cada tick (nao so na virada do minuto) porque o        |
//| flutuante pode estourar o orcamento intra-barra.                 |
//+------------------------------------------------------------------+
void EnforceDailyLossLimit()
{
   if(g_replay || !DailyLossBreached()) return;
   if(!g_dayLossHalt)
   {
      g_dayLossHalt = true;
      PrintFormat("ICS Modular: limite de prejuizo do dia (R$ %.2f). PnL R$ %.2f. Sem novas entradas.",
                  InpMaxLossDayBRL, DayPnlBRL());
   }
   if(HasRealPosition()) CloseRealPosition("limite de prejuizo do dia");
}

//+------------------------------------------------------------------+
//| Zera a posicao real                                              |
//+------------------------------------------------------------------+
void CloseRealPosition(string why)
{
   if(g_replay) return;
   if(!PositionSelect(_Symbol)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
   ulong  ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   double sl     = PositionGetDouble(POSITION_SL);
   double tp     = PositionGetDouble(POSITION_TP);
   double px     = PositionGetDouble(POSITION_PRICE_CURRENT);
   if(g_trade.PositionClose(_Symbol))
   {
      PrintFormat("Posicao zerada: %s", why);
      LogOrder("CLOSE", g_realSignalId, ticket, g_trade.ResultRetcode(),
               px, g_trade.ResultPrice(), sl, tp);
   }
   else
   {
      PrintFormat("Falha ao zerar (%s): %u", why, g_trade.ResultRetcode());
      LogOrder("FAIL", g_realSignalId, ticket, g_trade.ResultRetcode(), px, 0, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| A posicao real deste sinal, se houver                             |
//+------------------------------------------------------------------+
int VirtualPorSinal(int sigId)
{
   if(sigId <= 0) return -1;
   for(int i = ArraySize(g_vt) - 1; i >= 0; i--)
      if(g_vt[i].id == sigId) return i;
   return -1;
}

//+------------------------------------------------------------------+
//| Fecha so uma fatia. O estudo ja decidiu o preco; aqui o fill e   |
//| a mercado, na virada do minuto.                                   |
//+------------------------------------------------------------------+
bool CloseRealPartial(double volume, string why)
{
   if(g_replay) return false;
   if(!PositionSelect(_Symbol)) return false;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return false;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 1;
   volume = MathFloor(volume / step + 1e-9) * step;
   if(volume <= 0) return false;
   ulong  ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   double sl     = PositionGetDouble(POSITION_SL);
   double tp     = PositionGetDouble(POSITION_TP);
   double px     = PositionGetDouble(POSITION_PRICE_CURRENT);
   if(!g_trade.PositionClosePartial(_Symbol, volume))
   {
      PrintFormat("Falha na parcial (%s): %u", why, g_trade.ResultRetcode());
      LogOrder("FAIL", g_realSignalId, ticket, g_trade.ResultRetcode(), px, 0, sl, tp);
      return false;
   }
   PrintFormat("Parcial trilho: %s | vol %.0f", why, volume);
   LogOrder("PARTIAL", g_realSignalId, ticket, g_trade.ResultRetcode(),
            px, g_trade.ResultPrice(), sl, tp);
   return true;
}

//+------------------------------------------------------------------+
//| Iguala o volume real as fatias que o estudo ainda tem abertas    |
//| e copia o stop que TrailStop ja calculou na virtual.             |
//+------------------------------------------------------------------+
void EspelharTrilho(int k)
{
   if(!PositionSelect(_Symbol)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
   int fechadas = 0;
   if(g_vt[k].trilhoSeq1 >= 0) fechadas++;
   if(g_vt[k].trilhoSeq2 >= 0) fechadas++;
   if(g_vt[k].trilhoSeq3 >= 0) fechadas++;
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0) step = 1;
   double desejado = (3 - fechadas) * (InpLots / 3.0);
   double vol      = PositionGetDouble(POSITION_VOLUME);
   if(vol > desejado + step * 0.5)
   {
      string why = g_vt[k].trilhoWhy3;
      if(why == "") why = g_vt[k].trilhoWhy2;
      if(why == "") why = g_vt[k].trilhoWhy1;
      if(why == "") why = "trilho";
      if(desejado <= step * 0.5)
      {
         CloseRealPosition(why);
         return;
      }
      CloseRealPartial(vol - desejado, why);
      if(!HasRealPosition()) return;
   }
   if(!g_vt[k].active || InpExitMode != ICS_EXIT_TRAIL) return;
   if(!PositionSelect(_Symbol)) return;
   double curSL = PositionGetDouble(POSITION_SL);
   double curTP = PositionGetDouble(POSITION_TP);
   double newSL = g_vt[k].stop;
   if(MathAbs(newSL - curSL) < g_tick / 2.0) return;
   int    dir = g_vt[k].dir;
   double px  = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                           : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(px > 0 && (px - newSL) * dir <= 0)
   {
      CloseRealPosition("trailing (preco ja alem do novo stop)");
      return;
   }
   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   if(!g_trade.PositionModify(_Symbol, newSL, curTP))
   {
      PrintFormat("Falha ao mover stop para %.0f: %u", newSL, g_trade.ResultRetcode());
      LogOrder("FAIL", g_realSignalId, ticket, g_trade.ResultRetcode(), 0, 0, newSL, curTP);
      return;
   }
   LogOrder("MODIFY", g_realSignalId, ticket, g_trade.ResultRetcode(), 0, 0, newSL, curTP);
}

//+------------------------------------------------------------------+
//| Gestao da posicao real a cada barra M1: zeragem, reversao,       |
//| stop de tempo, breakeven e trailing                              |
//+------------------------------------------------------------------+
void ManageRealPosition(const IcsBar &b)
{
   if(!PositionSelect(_Symbol)) return;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagic) return;
   int kt = VirtualPorSinal(g_realSignalId);
   if(kt >= 0 && g_vt[kt].trilhoFase > 0)
   {
      EspelharTrilho(kt);
      return;
   }
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
   ulong ticket = (ulong)PositionGetInteger(POSITION_TICKET);
   if(!g_trade.PositionModify(_Symbol, newSL, curTP))
   {
      PrintFormat("Falha ao mover stop para %.0f: %u", newSL, g_trade.ResultRetcode());
      LogOrder("FAIL", g_realSignalId, ticket, g_trade.ResultRetcode(), 0, 0, newSL, curTP);
      return;
   }
   LogOrder("MODIFY", g_realSignalId, ticket, g_trade.ResultRetcode(), 0, 0, newSL, curTP);
}

#endif // __ICSM_REALORDERS_MQH__
//+------------------------------------------------------------------+
