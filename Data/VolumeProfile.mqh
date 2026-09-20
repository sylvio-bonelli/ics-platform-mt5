//+------------------------------------------------------------------+
//| Data/VolumeProfile.mqh                                           |
//| Volume Profile do dia: POC, Value Area e HVNs.                   |
//|                                                                  |
//| Depende de: Config/Defines.mqh (PROF_SIZE), Config/Inputs.mqh,   |
//|             Core/Globals.mqh.                                    |
//|                                                                  |
//| O histograma e um vetor fixo de PROF_SIZE niveis de InpProfileStep|
//| pontos. A base (g_profBase) e ancorada no primeiro preco do dia, |
//| centralizando a faixa, e zerada a cada virada de dia.            |
//|                                                                  |
//| ProfAdd      -> um negocio (tick) no preco exato                 |
//| ProfAddRange -> uma barra sem ticks: distribui o volume na faixa |
//+------------------------------------------------------------------+
#ifndef __ICSM_VOLUMEPROFILE_MQH__
#define __ICSM_VOLUMEPROFILE_MQH__

//+------------------------------------------------------------------+
//| Zera o perfil (virada de dia)                                    |
//+------------------------------------------------------------------+
void ProfReset()
{
   ArrayInitialize(g_prof, 0.0);
   g_profInit = false;
}

//+------------------------------------------------------------------+
//| Indice do nivel para um preco. Ancora a base no primeiro uso.    |
//| Retorna -1 se o preco caiu fora da faixa coberta.                |
//+------------------------------------------------------------------+
int ProfIdx(double p)
{
   if(!g_profInit)
   {
      g_profBase = MathFloor(p / InpProfileStep) * InpProfileStep - (PROF_SIZE / 2) * InpProfileStep;
      g_profInit = true;
   }
   int i = (int)MathFloor((p - g_profBase) / InpProfileStep);
   if(i < 0 || i >= PROF_SIZE) return -1;
   return i;
}

//+------------------------------------------------------------------+
//| Adiciona volume em um preco                                      |
//+------------------------------------------------------------------+
void ProfAdd(double p, double v)
{
   int i = ProfIdx(p);
   if(i >= 0) g_prof[i] += v;
}

//+------------------------------------------------------------------+
//| Distribui volume uniformemente entre dois precos (barra sem tick)|
//+------------------------------------------------------------------+
void ProfAddRange(double lo, double hi, double v)
{
   int a = ProfIdx(lo), b = ProfIdx(hi);
   if(a < 0 || b < 0 || b < a) return;
   int n = b - a + 1;
   for(int i = a; i <= b; i++) g_prof[i] += v / n;
}

//+------------------------------------------------------------------+
//| POC + Value Area de 70%, expandindo a partir do POC para o lado  |
//| de maior volume ate cobrir 70% do total                          |
//+------------------------------------------------------------------+
bool ProfValueArea(double &poc, double &vah, double &val)
{
   int    pi = -1;
   double mx = 0, tot = 0;
   for(int i = 0; i < PROF_SIZE; i++)
   {
      tot += g_prof[i];
      if(g_prof[i] > mx) { mx = g_prof[i]; pi = i; }
   }
   if(pi < 0 || tot <= 0) return false;
   int    a = pi, b = pi;
   double acc = g_prof[pi];
   while(acc < 0.7 * tot)
   {
      double up = (b + 1 < PROF_SIZE) ? g_prof[b + 1] : -1;
      double dn = (a - 1 >= 0) ? g_prof[a - 1] : -1;
      if(up < 0 && dn < 0) break;
      if(up >= dn) { b++; acc += g_prof[b]; }
      else         { a--; acc += g_prof[a]; }
   }
   double st = InpProfileStep;
   poc = g_profBase + pi * st + st / 2.0;
   val = g_profBase + a * st;
   vah = g_profBase + (b + 1) * st;
   return true;
}

//+------------------------------------------------------------------+
//| HVN (High Volume Nodes): picos locais do histograma suavizado    |
//| com volume >= InpHvnFactor x a media dos niveis nao vazios.      |
//| Sao os "obstaculos" candidatos a alvo.                           |
//+------------------------------------------------------------------+
int ProfHVN(double &lv[])
{
   ArrayResize(lv, 0);
   if(!g_profInit) return 0;
   double tot = 0;
   int    nz = 0;
   for(int i = 0; i < PROF_SIZE; i++)
      if(g_prof[i] > 0) { tot += g_prof[i]; nz++; }
   if(nz < 5) return 0;
   double mean = tot / nz;
   for(int i = 2; i < PROF_SIZE - 2; i++)
   {
      double s  = (g_prof[i - 1] + g_prof[i] + g_prof[i + 1]) / 3.0;
      double sp = (g_prof[i - 2] + g_prof[i - 1] + g_prof[i]) / 3.0;
      double sn = (g_prof[i] + g_prof[i + 1] + g_prof[i + 2]) / 3.0;
      if(s > sp && s >= sn && s >= InpHvnFactor * mean)
      {
         int k = ArraySize(lv);
         ArrayResize(lv, k + 1);
         lv[k] = g_profBase + i * InpProfileStep + InpProfileStep / 2.0;
      }
   }
   return ArraySize(lv);
}

#endif // __ICSM_VOLUMEPROFILE_MQH__
//+------------------------------------------------------------------+
