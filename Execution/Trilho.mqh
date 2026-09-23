//+------------------------------------------------------------------+
//| Execution/Trilho.mqh                                             |
//| Saida em tres fatias iguais, por cima da gestao atual.           |
//|                                                                  |
//| Depende de: Execution/VirtualTrades.mqh (CloseVirtual,           |
//| TrailStop, ReversalExitSignal), UI/Draw.mqh, Core/Utils.mqh.     |
//| Incluido DEPOIS de VirtualTrades.mqh.                            |
//|                                                                  |
//| Fatia 1: ganho fixo em pontos. Fatia 2: recuo de uma fracao do   |
//| extremo atingido depois dessa saida, confirmado no fechamento    |
//| M1 seguinte. Fatia 3: stop, alvo, reversao, tempo e zeragem de   |
//| sempre. Rejeitados tambem percorrem o trilho. O estudo compara   |
//| a saida, nao so a entrada.                                       |
//|                                                                  |
//| Na mesma barra, o stop vem antes do alvo. Entre o recuo e o      |
//| stop, vale o que o preco encontra primeiro ao voltar do extremo. |
//| A barra da primeira saida nao confirma a queda.                  |
//+------------------------------------------------------------------+
#ifndef __ICSM_TRILHO_MQH__
#define __ICSM_TRILHO_MQH__

//+------------------------------------------------------------------+
//| Ligado so com volume inteiro multiplo de 3 e pontos positivos.   |
//| Contrato de WIN nao fecha terco fracionario.                     |
//+------------------------------------------------------------------+
bool TrilhoLigado()
{
   if(!InpTrilhoSaida) return false;
   if(InpTrilhoPts <= 0 || InpTrilhoRecuo < 0) return false;
   int lots = (int)MathRound(InpLots);
   if(MathAbs(InpLots - lots) > 0.001) return false;
   return (lots >= 3 && lots % 3 == 0);
}

//+------------------------------------------------------------------+
void TrilhoAvisar()
{
   if(!InpTrilhoSaida) return;
   if(TrilhoLigado())
   {
      PrintFormat("Trilho de saida ligado: %d contratos | 1/3 aos %.0f pts | recuo %.0f%%.",
                  (int)MathRound(InpLots), InpTrilhoPts, InpTrilhoRecuo * 100.0);
      return;
   }
   Print("ICS Modular: trilho de saida pedido, mas desligado. InpLots precisa ser multiplo de 3 e a primeira saida precisa ter pontos positivos.");
}

//+------------------------------------------------------------------+
void TrilhoZerar(int k)
{
   g_vt[k].trilhoFase   = TrilhoLigado() ? 1 : 0;
   g_vt[k].trilhoSaida1 = 0;
   g_vt[k].trilhoPico   = 0;
   g_vt[k].trilhoAlvo2  = 0;
   g_vt[k].trilhoPx1    = 0;
   g_vt[k].trilhoPx2    = 0;
   g_vt[k].trilhoPx3    = 0;
   g_vt[k].trilhoWhy1   = "";
   g_vt[k].trilhoWhy2   = "";
   g_vt[k].trilhoWhy3   = "";
   g_vt[k].trilhoSeq1   = -1;
   g_vt[k].trilhoSeq2   = -1;
   g_vt[k].trilhoSeq3   = -1;
}

//+------------------------------------------------------------------+
double TrilhoNoTick(double px)
{
   if(g_tick <= 0) return px;
   return MathRound(px / g_tick) * g_tick;
}

//+------------------------------------------------------------------+
string TrilhoMotivoStop(int dir, double entry, double stop)
{
   double moved = (stop - entry) * dir;
   if(moved > g_tick) return "TRAILING";
   if(moved >= 0)     return "ZERO_A_ZERO";
   return "STOP";
}

//+------------------------------------------------------------------+
void TrilhoMarca(int k, int fatia, double px, string why, long seq)
{
   if(fatia == 1 && g_vt[k].trilhoSeq1 < 0)
   {
      g_vt[k].trilhoPx1  = px;
      g_vt[k].trilhoWhy1 = why;
      g_vt[k].trilhoSeq1 = seq;
   }
   if(fatia == 2 && g_vt[k].trilhoSeq2 < 0)
   {
      g_vt[k].trilhoPx2  = px;
      g_vt[k].trilhoWhy2 = why;
      g_vt[k].trilhoSeq2 = seq;
   }
   if(fatia == 3 && g_vt[k].trilhoSeq3 < 0)
   {
      g_vt[k].trilhoPx3  = px;
      g_vt[k].trilhoWhy3 = why;
      g_vt[k].trilhoSeq3 = seq;
   }
}

//+------------------------------------------------------------------+
void TrilhoFechaAbertas(int k, double px, string why, long seq)
{
   TrilhoMarca(k, 1, px, why, seq);
   TrilhoMarca(k, 2, px, why, seq);
   TrilhoMarca(k, 3, px, why, seq);
}

//+------------------------------------------------------------------+
void TrilhoAjustarStop(int k)
{
   double best = g_vt[k].entry + g_vt[k].dir * g_vt[k].mfe;
   bool   be   = g_vt[k].be;
   g_vt[k].stop = TrailStop(g_vt[k].dir, g_vt[k].entry, g_vt[k].risk, best, g_vt[k].stop, g_vt[k].trail, be);
   g_vt[k].be   = be;
}

//+------------------------------------------------------------------+
bool TrilhoEncerrar(int k, datetime t)
{
   CloseVirtual(k, t, g_vt[k].trilhoPx3, g_vt[k].trilhoWhy3);
   return true;
}

//+------------------------------------------------------------------+
//| Alvo, reversao, tempo e zeragem das fatias ainda abertas.        |
//| O stop e tratado antes, porque disputa com o recuo.              |
//+------------------------------------------------------------------+
bool TrilhoSaidaComum(int k, const IcsBar &b, bool hitTgt)
{
   int dir = g_vt[k].dir;
   if(hitTgt)
   {
      TrilhoFechaAbertas(k, g_vt[k].target, "ALVO", b.seq);
      return TrilhoEncerrar(k, b.t);
   }
   if(ReversalExitSignal(dir, g_vt[k].startSeq))
   {
      TrilhoFechaAbertas(k, b.c - dir * InpSlipPts, "REVERSAO", b.seq);
      return TrilhoEncerrar(k, b.t);
   }
   if(!g_vt[k].be && g_vt[k].bars >= InpTimeStopBars &&
      (b.c - g_vt[k].entry) * dir < InpTimeStopMinR * g_vt[k].risk)
   {
      TrilhoFechaAbertas(k, b.c - dir * InpSlipPts, "TEMPO", b.seq);
      return TrilhoEncerrar(k, b.t);
   }
   if(MinOfDay(b.t) + 1 >= g_flat)
   {
      TrilhoFechaAbertas(k, b.c - dir * InpSlipPts, "FIM_DIA", b.seq);
      return TrilhoEncerrar(k, b.t);
   }
   TrilhoAjustarStop(k);
   return false;
}

//+------------------------------------------------------------------+
void TrilhoDesenhar(int k, const IcsBar &b, double px, color clr, string tip)
{
   if(!g_vt[k].taken) return;
   DrawLevel(b.t, b.t + (datetime)InpTimeStopBars * 60, px, clr, STYLE_DASH, tip);
}

//+------------------------------------------------------------------+
double TrilhoMeio(int k)
{
   int dir = g_vt[k].dir;
   return TrilhoNoTick(g_vt[k].trilhoSaida1 + dir * InpTrilhoRecuo *
                       MathAbs(g_vt[k].trilhoPico - g_vt[k].trilhoSaida1));
}

//+------------------------------------------------------------------+
//| Avanca o trilho uma barra M1. true = operacao encerrada.         |
//+------------------------------------------------------------------+
bool TrilhoBarra(int k, const IcsBar &b, double prevClose, bool temPrev)
{
   int  dir     = g_vt[k].dir;
   bool hitStop = (dir > 0) ? (b.l <= g_vt[k].stop) : (b.h >= g_vt[k].stop);
   bool hitTgt  = (dir > 0) ? (b.h >= g_vt[k].target) : (b.l <= g_vt[k].target);

   if(g_vt[k].trilhoFase == 1)
   {
      double n110   = TrilhoNoTick(g_vt[k].entry + dir * InpTrilhoPts);
      bool   hit110 = (dir > 0) ? (b.h >= n110) : (b.l <= n110);
      if(hitStop)
      {
         TrilhoFechaAbertas(k, g_vt[k].stop - dir * InpSlipPts,
                            TrilhoMotivoStop(dir, g_vt[k].entry, g_vt[k].stop), b.seq);
         return TrilhoEncerrar(k, b.t);
      }
      if(hit110)
      {
         TrilhoMarca(k, 1, n110, "TRILHO_110", b.seq);
         g_vt[k].trilhoSaida1 = n110;
         g_vt[k].trilhoPico   = (dir > 0) ? b.h : b.l;
         g_vt[k].trilhoFase   = 2;
         TrilhoDesenhar(k, b, n110, clrGold, "trilho 110");
         if(hitTgt)
         {
            TrilhoFechaAbertas(k, g_vt[k].target, "ALVO", b.seq);
            return TrilhoEncerrar(k, b.t);
         }
         TrilhoAjustarStop(k);
         return false;
      }
      return TrilhoSaidaComum(k, b, hitTgt);
   }

   if(g_vt[k].trilhoSeq2 < 0)
   {
      double extremo = (dir > 0) ? b.h : b.l;
      if((extremo - g_vt[k].trilhoPico) * dir > 0)
         g_vt[k].trilhoPico = extremo;

      if(g_vt[k].trilhoFase == 2 && temPrev)
      {
         bool queda = (dir > 0) ? (b.c < prevClose) : (b.c > prevClose);
         if(queda)
         {
            g_vt[k].trilhoAlvo2 = TrilhoMeio(k);
            g_vt[k].trilhoFase  = 3;
            TrilhoDesenhar(k, b, g_vt[k].trilhoAlvo2, clrOrange, "trilho 50");
         }
      }
      else if(g_vt[k].trilhoFase == 3)
      {
         double novo = TrilhoMeio(k);
         if(MathAbs(novo - g_vt[k].trilhoAlvo2) >= g_tick)
         {
            g_vt[k].trilhoAlvo2 = novo;
            TrilhoDesenhar(k, b, g_vt[k].trilhoAlvo2, clrOrange, "trilho 50");
         }
      }
   }

   bool   hitAlvo2 = false;
   double pxAlvo2  = g_vt[k].trilhoAlvo2;
   if(g_vt[k].trilhoFase == 3 && g_vt[k].trilhoSeq2 < 0)
   {
      bool cruzou = (dir > 0) ? (b.l <= g_vt[k].trilhoAlvo2) : (b.h >= g_vt[k].trilhoAlvo2);
      if(cruzou)
      {
         hitAlvo2 = true;
         if(dir > 0 && b.h < g_vt[k].trilhoAlvo2)      pxAlvo2 = b.h;
         else if(dir < 0 && b.l > g_vt[k].trilhoAlvo2) pxAlvo2 = b.l;
         else                                          pxAlvo2 = g_vt[k].trilhoAlvo2;
      }
   }

   if(hitStop)
   {
      bool   alem = (dir > 0) ? (b.h <= g_vt[k].stop) : (b.l >= g_vt[k].stop);
      bool   alvoPrimeiro = hitAlvo2 && !alem && (g_vt[k].trilhoAlvo2 - g_vt[k].stop) * dir > g_tick * 0.25;
      string why = TrilhoMotivoStop(dir, g_vt[k].entry, g_vt[k].stop);
      double px  = g_vt[k].stop - dir * InpSlipPts;
      if(alvoPrimeiro)
         TrilhoMarca(k, 2, pxAlvo2, "TRILHO_50", b.seq);
      TrilhoFechaAbertas(k, px, why, b.seq);
      return TrilhoEncerrar(k, b.t);
   }
   if(hitTgt)
      return TrilhoSaidaComum(k, b, true);
   if(hitAlvo2)
   {
      TrilhoMarca(k, 2, pxAlvo2, "TRILHO_50", b.seq);
      g_vt[k].trilhoFase = 4;
   }
   return TrilhoSaidaComum(k, b, false);
}

#endif // __ICSM_TRILHO_MQH__
//+------------------------------------------------------------------+
