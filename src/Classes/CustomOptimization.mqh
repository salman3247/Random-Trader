//+------------------------------------------------------------------+
//|                                           CustomOptimization.mqh |
//|                                                Salman Soltaniyan |
//|                   https://www.mql5.com/en/users/salmansoltaniyan |
//+------------------------------------------------------------------+
#property copyright "Salman Soltaniyan"
#property link      "https://www.mql5.com/en/users/salmansoltaniyan"
#property version   "1.00"
#property strict
class CCustomOptimization
  {
private:
   double  m_minMargin_level;
public:
                     CCustomOptimization();
                    ~CCustomOptimization();
   double                  On_Tester(int tester_method);
   int               On_Init();
   void              On_Tick();

  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCustomOptimization::CCustomOptimization()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CCustomOptimization::~CCustomOptimization()
  {
  }
//+------------------------------------------------------------------+

// OnInit: Initialize the minimum margin level
int CCustomOptimization:: On_Init()
  {
   m_minMargin_level = DBL_MAX; // Reset the value at the start of the test
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// OnTick: Update the minimum margin level at each tick
void CCustomOptimization::On_Tick()
  {
// Calculate the current margin level
 //  double equity = AccountEquity();
  // double margin = AccountMargin();
 //  double marginLevel = (margin > 0) ? (equity / margin) * 100 : DBL_MAX;

// Update the minimum margin level
 //  if(marginLevel < m_minMargin_level)
 //     m_minMargin_level = marginLevel;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// OnTester: Return the minimum margin level for the Strategy Tester
double CCustomOptimization::On_Tester(int tester_method=3)
  {
   //return minMarginLevel; // Return the minimum margin level for optimization

   //int tester_method= 3;
   double ret=0.0;
 //  Print("min margin level = ", m_minMargin_level);

   if(TesterStatistics(STAT_MIN_MARGINLEVEL) <100)  //margin become close to call margin.
     {
      return -1001;
     }

   switch(tester_method)
     {
      case 1 :
         ret= TesterStatistics(STAT_SHARPE_RATIO);  //Goal
         if(TesterStatistics(STAT_TRADES)< 100 || TesterStatistics(STAT_PROFIT_FACTOR) <1.5)   //Constraints
            ret= -1000;
         break;
      case 2 :
         ret = -TesterStatistics(STAT_EQUITY_DDREL_PERCENT);
         if(TesterStatistics(STAT_TRADES)< 50 || TesterStatistics(STAT_PROFIT_FACTOR) <1.2)  //Constraints
            ret= -1000;
         break;

      case 3 :
        {
         double recovery_factor = TesterStatistics(STAT_EQUITY_DD_RELATIVE)!=0 ? TesterStatistics(STAT_PROFIT)/ TesterStatistics(STAT_EQUITY_DD_RELATIVE): 1e8;
         ret = TesterStatistics(STAT_TRADES);
         if(TesterStatistics(STAT_PROFIT_FACTOR) <1.5 || recovery_factor <1)   //Constraints
            ret= -1000;
         break;
        }
      case 4 :// goal 3 but constrained are incorporated in the goal
        {
         double recovery_factor = TesterStatistics(STAT_PROFIT)/ TesterStatistics(STAT_EQUITY_DD_RELATIVE);
         double profit_factor_penalty= TesterStatistics(STAT_PROFIT_FACTOR)>1.5?0 : (1.5- TesterStatistics(STAT_PROFIT_FACTOR));
         double recovery_factor_penalty= recovery_factor>1 ?0 : (1-recovery_factor);
         ret= TesterStatistics(STAT_TRADES) - 200*profit_factor_penalty -200*recovery_factor_penalty ;
         break;
        }
      case 5 :

         break;
      case 6 :

         break;
      case 7 :

         break;

     }

   return(ret);  //it's called custom max
  }
//+------------------------------------------------------------------+
