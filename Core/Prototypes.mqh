//+------------------------------------------------------------------+
//| Core/Prototypes.mqh                                              |
//| Declaracoes antecipadas (forward declarations).                  |
//|                                                                  |
//| Depende de: Config/Defines.mqh (tipos usados nas assinaturas).   |
//|                                                                  |
//| POR QUE ESTE ARQUIVO EXISTE                                      |
//| O #include do MQL5 e inclusao textual: tudo vira UMA unica       |
//| unidade de compilacao. Existem algumas chamadas "para frente"    |
//| inevitaveis entre modulos (por exemplo StateMachine chama        |
//| EvaluateTrigger, que vive em Trigger.mqh, incluido depois).      |
//| Declarar as assinaturas aqui elimina qualquer duvida de ordem    |
//| e documenta, em um so lugar, quais sao os pontos de acoplamento  |
//| cruzado do projeto.                                              |
//|                                                                  |
//| Se voce criar uma nova chamada entre modulos que aponta "para    |
//| frente" na ordem de include, adicione o prototipo aqui.          |
//+------------------------------------------------------------------+
#ifndef __ICSM_PROTOTYPES_MQH__
#define __ICSM_PROTOTYPES_MQH__

//--- Execution/VirtualTrades.mqh
void   CloseAllVirtual(string reason);

//--- Execution/RealOrders.mqh
void   CloseRealPosition(string why);

//--- Execution/Logger.mqh
void   LogEvent(string type, datetime t, double price, int dir, string info);

//--- Core/Stats.mqh
void   CountIn(string &names[], int &cnts[], string key);

//--- UI/Draw.mqh
void   DrawZone(bool isFinal);

//--- Analysis/Zone.mqh
void   RetireZone(string reason);

//--- Analysis/ZoneDetector.mqh
void   OnM5Close();

//--- Analysis/Trigger.mqh
void   EvaluateTrigger(const IcsBar &b, int kind);

//--- Analysis/Reject.mqh
void   UpdateRejectWatch(const IcsBar &b, int dir, double volRatio, double dpct);
void   CancelRejectWatch();

#endif // __ICSM_PROTOTYPES_MQH__
//+------------------------------------------------------------------+
