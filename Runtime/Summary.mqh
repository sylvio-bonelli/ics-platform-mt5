//+------------------------------------------------------------------+
//| Runtime/Summary.mqh                                              |
//| Funil do setup e resumo estatistico impressos no fim do teste.   |
//|                                                                  |
//| Depende de: Core/Stats.mqh (CountOf),                            |
//|             Runtime/BarProcessor.mqh (PrintDataDiag).            |
//|                                                                  |
//| O FUNIL e a ferramenta de diagnostico mais util do projeto:      |
//| mostra em que etapa os candidatos estao morrendo. Se ha 50 zonas |
//| e zero rompimentos, o problema esta no filtro de rompimento, nao |
//| na marcacao de area.                                             |
//|                                                                  |
//| O resumo compara EXECUTADOS x REJEITADOS: se os rejeitados       |
//| tiverem R medio parecido ou melhor, os filtros estao custando    |
//| dinheiro em vez de proteger.                                     |
//+------------------------------------------------------------------+
#ifndef __ICSM_SUMMARY_MQH__
#define __ICSM_SUMMARY_MQH__

//+------------------------------------------------------------------+
//| Funil: quantos candidatos sobreviveram a cada etapa              |
//+------------------------------------------------------------------+
void PrintFunnel()
{
   Print("--- Funil do setup ---");
   PrintFormat("Zonas criadas: %d | ajustes: %d | absorcoes: %d | testes: %d",
               CountOf(g_evName, g_evCnt, "ZONA_CRIADA"), CountOf(g_evName, g_evCnt, "ZONA_AJUSTADA"),
               CountOf(g_evName, g_evCnt, "ABSORCAO"),
               CountOf(g_evName, g_evCnt, "TESTE_FUNDO") + CountOf(g_evName, g_evCnt, "TESTE_TOPO"));
   PrintFormat("Rompimentos com fluxo: %d | armadilhas: %d | rompimentos falhos: %d",
               CountOf(g_evName, g_evCnt, "ROMPIMENTO"), CountOf(g_evName, g_evCnt, "ARMADILHA"),
               CountOf(g_evName, g_evCnt, "ROMPIMENTO_FALHOU"));
   PrintFormat("Entradas no rompimento avaliadas: %d | entradas por aceitacao: %d",
               CountOf(g_evName, g_evCnt, "ENTRADA_ROMPIMENTO"), CountOf(g_evName, g_evCnt, "ACEITACAO"));
   PrintFormat("Deslocamentos confirmados: %d | pullbacks sem gatilho: %d | gatilhos de pullback: %d",
               CountOf(g_evName, g_evCnt, "DESLOCAMENTO"), CountOf(g_evName, g_evCnt, "PULLBACK_SEM_GATILHO"),
               CountOf(g_evName, g_evCnt, "GATILHO"));
   for(int i = 0; i < ArraySize(g_retName); i++)
      PrintFormat("  zona encerrada por '%s': %d", g_retName[i], g_retCnt[i]);
}

//+------------------------------------------------------------------+
//| Resumo completo do teste                                         |
//+------------------------------------------------------------------+
void PrintSummary()
{
   PrintFormat("=== ICS Modular resumo [%s] %s ===", InpBaseline ? "BASELINE" : "COMPLETO", _Symbol);
   PrintFormat("Gatilhos avaliados: %d | executados: %d | rejeitados: %d", g_signals, g_tkN, g_rjN);
   if(g_tkN > 0)
      PrintFormat("Executados (simulados): acerto %.1f%% | R medio %.2f | total %.0f pts | R$ %.2f | fator de lucro %.2f",
                  100.0 * g_tkWins / g_tkN, g_tkSumR / g_tkN, g_tkSumPts, g_tkSumBRL,
                  g_tkGrossLoss > 0 ? g_tkGrossWin / g_tkGrossLoss : 0.0);
   if(g_rjN > 0)
      PrintFormat("Rejeitados (simulados): acerto %.1f%% | R medio %.2f", 100.0 * g_rjWins / g_rjN, g_rjSumR / g_rjN);
   string kn[3] = {"PULLBACK", "ROMPIMENTO", "ACEITACAO"};
   for(int kd = 0; kd < 3; kd++)
   {
      if(g_kAll[kd] == 0) continue;
      PrintFormat("Setup %s | todos os sinais simulados: %d, acerto %.0f%%, total %.2f R, R$ %.2f | executados: %d, total %.2f R",
                  kn[kd], g_kAll[kd], 100.0 * g_kWin[kd] / g_kAll[kd], g_kR[kd], g_kBRL[kd], g_kTkN[kd], g_kTkR[kd]);
   }
   for(int i = 0; i < ArraySize(g_rsnName); i++)
      PrintFormat("  motivo de rejeicao '%s': %d", g_rsnName[i], g_rsnCnt[i]);
   PrintFunnel();
   PrintDataDiag();
   if(g_files)
      Print("CSV em: ", TerminalInfoString(TERMINAL_COMMONDATA_PATH), "\\Files");
}

#endif // __ICSM_SUMMARY_MQH__
//+------------------------------------------------------------------+
