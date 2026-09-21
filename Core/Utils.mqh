//+------------------------------------------------------------------+
//| Core/Utils.mqh                                                   |
//| Funcoes utilitarias puras: tempo, arredondamento, formatacao,    |
//| geometria de candle, acesso ao historico M1 por numero           |
//| sequencial e ATR generico.                                       |
//|                                                                  |
//| Depende de: Config/Inputs.mqh, Core/Globals.mqh.                 |
//| NAO chama nenhum outro modulo do projeto.                        |
//+------------------------------------------------------------------+
#ifndef __ICSM_UTILS_MQH__
#define __ICSM_UTILS_MQH__

//--- inicio do dia (00:00) do timestamp
datetime DayStart(datetime t)  { return (datetime)(((long)t / 86400) * 86400); }

//--- minuto do dia (0-1439)
int      MinOfDay(datetime t)  { return (int)(((long)t % 86400) / 60); }

//--- limita a 0..1
double   Clamp01(double x)     { return (x < 0.0) ? 0.0 : ((x > 1.0) ? 1.0 : x); }

//--- geometria de uma IcsBar (OHLC)
double   BarBody(const IcsBar &b)   { return MathAbs(b.c - b.o); }
double   BarWickUp(const IcsBar &b) { return b.h - MathMax(b.o, b.c); }
double   BarWickDn(const IcsBar &b) { return MathMin(b.o, b.c) - b.l; }

//--- arredonda para baixo / cima no multiplo do tick do simbolo
double   RoundDn(double p)     { return MathFloor(p / g_tick + 1e-9) * g_tick; }
double   RoundUp(double p)     { return MathCeil(p / g_tick - 1e-9) * g_tick; }

//--- timestamp legivel para CSV e tooltips
string   TS(datetime t)        { return TimeToString(t, TIME_DATE | TIME_MINUTES); }

//--- booleano em portugues
string   B(bool v)             { return v ? "sim" : "nao"; }

//--- ordens reais liberadas? (no testador sempre; ao vivo so com a trava aberta)
bool     OrdersAllowed()       { return InpTradeEnabled && (g_isTester || InpLiveOrders); }

//--- PnL da conta desde o snapshot do dia (inclui flutuante e custo real)
double   DayPnlBRL()           { return AccountInfoDouble(ACCOUNT_EQUITY) - g_dayStartEquity; }

//--- teto de prejuizo em R$ estourou? (0 = desligado)
bool     DailyLossBreached()
{
   return (InpMaxLossDayBRL > 0 && DayPnlBRL() <= -InpMaxLossDayBRL);
}

//+------------------------------------------------------------------+
//| Numero formatado para o CSV (virgula decimal opcional)           |
//+------------------------------------------------------------------+
string F(double x, int digits)
{
   string s = DoubleToString(x, digits);
   if(InpCommaDecimal) StringReplace(s, ".", ",");
   return s;
}

//+------------------------------------------------------------------+
//| "HH:MM" -> minutos do dia. Retorna -1 se invalido.               |
//+------------------------------------------------------------------+
int ParseHM(string s)
{
   string p[];
   ushort sep = StringGetCharacter(":", 0);
   if(StringSplit(s, sep, p) != 2) return -1;
   int h = (int)StringToInteger(p[0]);
   int m = (int)StringToInteger(p[1]);
   if(h < 0 || h > 23 || m < 0 || m > 59) return -1;
   return h * 60 + m;
}

//+------------------------------------------------------------------+
//| Acumula motivos de rejeicao separados por " | "                  |
//+------------------------------------------------------------------+
void AddReason(string &s, string r)
{
   if(s != "") s += " | ";
   s += r;
}

//+------------------------------------------------------------------+
//| Indice em g_m1 a partir do numero sequencial global.             |
//| Retorna -1 se a barra ja saiu da janela deslizante.              |
//+------------------------------------------------------------------+
int IdxOf(long seq)
{
   long i = seq - g_m1First;
   if(i < 0 || i >= ArraySize(g_m1)) return -1;
   return (int)i;
}

//+------------------------------------------------------------------+
//| Escrita segura em arquivo (ignora handle invalido)               |
//+------------------------------------------------------------------+
void WriteLine(int h, string s)
{
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, s + "\r\n");
}

//+------------------------------------------------------------------+
//| ATR simples sobre um array de IcsBar (serve para M1 e M5)        |
//+------------------------------------------------------------------+
double ATRArr(const IcsBar &a[], int period)
{
   int n = ArraySize(a);
   if(n < 2) return 0;
   double s = 0;
   int    cnt = 0;
   for(int i = n - 1; i >= 1 && cnt < period; i--)
   {
      double tr = MathMax(a[i].h, a[i - 1].c) - MathMin(a[i].l, a[i - 1].c);
      s += tr;
      cnt++;
   }
   return (cnt > 0) ? s / cnt : 0;
}

#endif // __ICSM_UTILS_MQH__
//+------------------------------------------------------------------+
