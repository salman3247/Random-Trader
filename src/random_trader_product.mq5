//+------------------------------------------------------------------+
//|                                      random_trader_product.mq5     |
//|                                                 SalmanSoltaniyan   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "SalmanSoltaniyan"
#property link      "https://www.mql5.com/en/users/salmansoltaniyan"
#property version   "1.09"
#property description "Random Trader EA with advanced risk management features"

//--- Include required files
#include <Trade\Trade.mqh>
#include "Classes\TradeValidation.mqh"
#include "Classes\CustomOptimization.mqh"
//--- Create trade object
CTrade mytrade;

//--- Create validation object
CTradeValidation *validation;
CCustomOptimization opt;

//--- Enums
enum ENUM_LOSS {
   ATR,    // ATR-based stop loss
   PIP     // Fixed pip-based stop loss
};

enum ENUM_TRAIL_MODE {
   NONE,           // No trailing stop
   BREAKEVEN,      // Only breakeven
   STEPWISE        // Step-wise trailing stop
};

//--- Input parameters
input group "Trade Identification"
input ulong magic_number = 123456;            // Magic number for trade identification

input group "Risk Management"
input double risk_percent_per_trade = 1;      // Risk percent per trade
input double reward_risk_ratio = 2;           // Reward/Risk ratio
input bool use_max_margin = true;             // Use maximum available margin if required margin is not enough

input group "Stop Loss Configuration"
input ENUM_LOSS loss = PIP;                   // Loss based on distance(PIP) or ATR
input double loss_atr = 5;                    // ATR multiplier for stop loss
input double loss_pip = 20;                   // Fixed pip distance for stop loss

input group "Trailing Stop Settings"
input ENUM_TRAIL_MODE trail_mode = BREAKEVEN; // Trailing stop mode
input double breakeven_distance = 10;         // Distance in pips to activate breakeven
input int trail_steps = 3;                    // Number of steps till take profit
input bool use_partial_close = false;         // Use partial close in trail steps
input double partial_close_percent = 50;      // Percent of position to close in each step

input group "Trading Time Settings"
input bool use_time_filter = false;           // Enable time filter
input int start_hour = 8;                     // Start hour (0-23)
input int start_minute = 0;                   // Start minute (0-59)
input double duration = 8;                    // Trading duration in hours (e.g., 8 = 8 hours)
input bool close_at_end_time = false;         // Close positions at end time

input group "Market Condition Filters"
input bool use_spread_filter = false;         // Enable spread filter
input double max_spread = 10;                 // Maximum allowed spread in points

input group "Weekend Protection"
input bool close_before_weekend = false;      // Close positions before weekend
input int friday_close_hour = 21;            // Hour to close on Friday (0-23)
input int friday_close_minute = 0;           // Minute to close on Friday (0-59)

//--- Global variables
ulong tiket = 0;                              // Position ticket
double sl_distance;                           // Stop loss distance
double tp_distance;                           // Take profit distance
int atr_handle;                               // ATR indicator handle
double atr_array[];                           // ATR values array
bool breakeven_activated = false;             // Breakeven status flag
int current_trail_step = 0;                   // Current trailing stop step

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit() {
   //--- Validate input parameters
   if(magic_number == 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(loss_atr <= 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(loss_pip <= 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(reward_risk_ratio <= 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(risk_percent_per_trade <= 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(trail_mode == BREAKEVEN && breakeven_distance <= 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(trail_mode == STEPWISE && trail_steps <= 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(use_partial_close && (partial_close_percent <= 0 || partial_close_percent >= 100)) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(use_time_filter) {
      if(start_hour < 0 || start_hour > 23 || start_minute < 0 || start_minute > 59) {
         return(INIT_PARAMETERS_INCORRECT);
      }
      if(duration <= 0) {
         return(INIT_PARAMETERS_INCORRECT);
      }
   }
   
   if(use_spread_filter && max_spread <= 0) {
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(close_before_weekend) {
      if(friday_close_hour < 0 || friday_close_hour > 23 || 
         friday_close_minute < 0 || friday_close_minute > 59) {
         return(INIT_PARAMETERS_INCORRECT);
      }
   }
   
   //--- Set magic number for trade object
   mytrade.SetExpertMagicNumber(magic_number);
   
   //--- Create validation object
   validation = new CTradeValidation(_Symbol);
   
   //--- Initialize stop loss and take profit distances based on selected mode
   if(loss == PIP) {
      sl_distance = loss_pip * validation.GetPipPoint();
      tp_distance = sl_distance * reward_risk_ratio;
   }
   if(loss == ATR) {
      atr_handle = iATR(_Symbol, PERIOD_CURRENT, 10);
      ArraySetAsSeries(atr_array, true);
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   //--- Clean up ATR handle if it was created
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   
   //--- Delete validation object
   if(validation != NULL) delete validation;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                      |
//+------------------------------------------------------------------+
bool IsTradingTime() {
   if(!use_time_filter) return true;
   
   datetime current_time = TimeCurrent();
   MqlDateTime time_struct;
   TimeToStruct(current_time, time_struct);
   
   //--- Convert start time to minutes since midnight
   int start_time_minutes = start_hour * 60 + start_minute;
   
   //--- Calculate end time in minutes since midnight
   double duration_minutes = duration * 60;
   int end_time_minutes = (start_time_minutes + (int)duration_minutes) % (24 * 60);
   
   //--- Convert current time to minutes since midnight
   int current_time_minutes = time_struct.hour * 60 + time_struct.min;
   
   //--- Handle overnight trading period
   if(start_time_minutes > end_time_minutes) {
      //--- Trading period crosses midnight
      if(current_time_minutes >= start_time_minutes || current_time_minutes < end_time_minutes) {
         return true;
      }
   }
   else {
      //--- Normal trading period within same day
      if(current_time_minutes >= start_time_minutes && current_time_minutes < end_time_minutes) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if current time is at end of trading session                 |
//+------------------------------------------------------------------+
bool IsEndTime() {
   if(!use_time_filter || !close_at_end_time) return false;
   
   datetime current_time = TimeCurrent();
   MqlDateTime time_struct;
   TimeToStruct(current_time, time_struct);
   
   //--- Convert start time to minutes since midnight
   int start_time_minutes = start_hour * 60 + start_minute;
   
   //--- Calculate end time in minutes since midnight
   double duration_minutes = duration * 60;
   int end_time_minutes = (start_time_minutes + (int)duration_minutes) % (24 * 60);
   
   //--- Convert current time to minutes since midnight
   int current_time_minutes = time_struct.hour * 60 + time_struct.min;
   
   //--- Handle overnight trading period
   if(start_time_minutes > end_time_minutes) {
      //--- Trading period crosses midnight
      //--- Check if we're after end time but before start time
      if(current_time_minutes >= end_time_minutes && 
         current_time_minutes < start_time_minutes) {
         return true;
      }
   }
   else {
      //--- Normal trading period within same day
      //--- Check if we're after end time
      if(current_time_minutes >= end_time_minutes) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if current spread is acceptable                              |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable() {
   if(!use_spread_filter) return true;
   
   double current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   return (current_spread <= max_spread * _Point);
}

//+------------------------------------------------------------------+
//| Count positions with current magic number                          |
//+------------------------------------------------------------------+
int CountMagicPositions() {
   int count = 0;
   int total_pos= PositionsTotal();
   for(int i =  total_pos- 1; i >= 0; i--) {
      if(PositionSelectByTicket(PositionGetTicket(i))) {
         if(PositionGetInteger(POSITION_MAGIC) == magic_number) {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if current time is near weekend                              |
//+------------------------------------------------------------------+
bool IsNearWeekend() {
   if(!close_before_weekend) return false;
   
   datetime current_time = TimeCurrent();
   MqlDateTime time_struct;
   TimeToStruct(current_time, time_struct);
   
   // Check if it's Friday
   if(time_struct.day_of_week == 5) {  // 5 = Friday
      int current_minutes = time_struct.hour * 60 + time_struct.min;
      int close_minutes = friday_close_hour * 60 + friday_close_minute;
      
      // Check if we should close positions
      if(current_minutes >= close_minutes) {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick() {
   //--- Check for trailing stop if position exists
   if(CountMagicPositions() > 0) {
      //--- Check if the position belongs to this EA
      if(PositionSelectByTicket(tiket) && PositionGetInteger(POSITION_MAGIC) == magic_number) {
         //--- Get position details for validation
         ENUM_POSITION_TYPE current_position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         double current_tp = PositionGetDouble(POSITION_TP);
         
         //--- Check if we should close position at end time
         if(IsEndTime()) {
            if(validation.ValidateClosePosition(current_position_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                             current_sl, current_tp)) {
               mytrade.PositionClose(tiket);
            }
            return;
         }
         
         //--- Check if we should close positions before weekend
         if(IsNearWeekend()) {
            if(validation.ValidateClosePosition(current_position_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,
                                             current_sl, current_tp)) {
               mytrade.PositionClose(tiket);
            }
            return;
         }
         
         if(trail_mode == BREAKEVEN) {
            CheckBreakeven();
         }
         else if(trail_mode == STEPWISE) {
            CheckStepwiseTrail();
         }
      }
   }
   
   //--- Open new position if none exists and within trading hours
   if(CountMagicPositions() == 0 && IsTradingTime() && IsSpreadAcceptable() && 
      !IsNearWeekend()) {
      OpenNewPosition();
   }
}

//+------------------------------------------------------------------+
//| Check and apply breakeven if conditions are met                    |
//+------------------------------------------------------------------+
void CheckBreakeven() {
   if(!PositionSelectByTicket(tiket)) return;
   
   ENUM_POSITION_TYPE current_position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double current_price = (current_position_type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Calculate breakeven activation distance in points using correct pip value
   double breakeven_activation_points = breakeven_distance * validation.GetPipPoint();
   
   //--- Check if breakeven should be activated
   if(!breakeven_activated) {
      if(current_position_type == POSITION_TYPE_BUY) {
         if(current_price - open_price >= breakeven_activation_points) {
            //--- Validate new stop loss distance
            double new_sl = validation.Round2Ticksize(open_price);
            if(validation.ValidateSLModify(ORDER_TYPE_BUY, current_sl, new_sl)) {
               mytrade.PositionModify(tiket, new_sl, current_tp);
               breakeven_activated = true;
            }
         }
      }
      else if(current_position_type == POSITION_TYPE_SELL) {
         if(open_price - current_price >= breakeven_activation_points) {
            //--- Validate new stop loss distance
            double new_sl = validation.Round2Ticksize(open_price);
            if(validation.ValidateSLModify(ORDER_TYPE_SELL, current_sl, new_sl)) {
               mytrade.PositionModify(tiket, new_sl, current_tp);
               breakeven_activated = true;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check and apply step-wise trailing stop                            |
//+------------------------------------------------------------------+
void CheckStepwiseTrail() {
   if(!PositionSelectByTicket(tiket)) return;
   
   ENUM_POSITION_TYPE current_position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   double current_tp = PositionGetDouble(POSITION_TP);
   double current_price = (current_position_type == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   //--- Calculate step distances
   double total_distance = (current_position_type == POSITION_TYPE_BUY) ? 
                          (current_tp - open_price) : 
                          (open_price - current_tp);
   double step_distance = total_distance / trail_steps;
   
   //--- Calculate current profit in points
   double current_profit = (current_position_type == POSITION_TYPE_BUY) ? 
                          (current_price - open_price) : 
                          (open_price - current_price);
   
   //--- Calculate required profit for next step
   double required_profit = (current_trail_step + 1) * step_distance;
   
   //--- Check if we should move to next step
   if(current_profit >= required_profit) {
      //--- Calculate new stop loss
      double new_sl;
      if(current_trail_step == 0) {
         //--- First step: move to breakeven
         new_sl = validation.Round2Ticksize(open_price);
      }
      else {
         //--- Subsequent steps: move up by step distance
         new_sl = (current_position_type == POSITION_TYPE_BUY) ? 
                  validation.Round2Ticksize(open_price + (current_trail_step * step_distance)) : 
                  validation.Round2Ticksize(open_price - (current_trail_step * step_distance));
      }
      
      //--- Validate new stop loss
      if(validation.ValidateSLModify(current_position_type == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, 
                                   current_sl, new_sl)) {
         //--- Handle partial close if enabled
         if(use_partial_close && current_trail_step >= 0) {
            double current_volume = PositionGetDouble(POSITION_VOLUME);
            double close_volume = NormalizeDouble(current_volume * partial_close_percent / 100, 2);
            
            if(close_volume > 0) {
               mytrade.PositionClosePartial(tiket, close_volume);
            }
         }
         
         //--- Check again if position is still open before modifying
         if(PositionSelectByTicket(tiket) && PositionGetDouble(POSITION_VOLUME) > 0) {
            mytrade.PositionModify(tiket, new_sl, current_tp);
            current_trail_step++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open new position                                                  |
//+------------------------------------------------------------------+
void OpenNewPosition() {
   //--- Reset flags for new position
   breakeven_activated = false;
   current_trail_step = 0;
   
   //--- Update ATR values if using ATR-based stops
   if(loss == ATR) {
      CopyBuffer(atr_handle, 0, 0, 5, atr_array);
      sl_distance = loss_atr * atr_array[0];
      tp_distance = sl_distance * reward_risk_ratio;
   }

   //--- Randomly choose position type
   double rand_buy_sell = MathMod(MathRand(), 2);
   
   if(rand_buy_sell == 0) {  // BUY
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = entry_price - sl_distance;
      double tp = entry_price + tp_distance;
      
      //--- Round prices first
      entry_price = validation.Round2Ticksize(entry_price);
      sl = validation.Round2Ticksize(sl);
      tp = validation.Round2Ticksize(tp);
      
      //--- Validate order placement
      if(!validation.ValidateOrderPlacement(ORDER_TYPE_BUY, sl, tp)) return;
      
      //--- Calculate and validate lot size
      double lot0 = validation.CalculateValidLot(sl, entry_price, risk_percent_per_trade);
      if(lot0 > 0) {
         //--- Check if we have enough margin for this position
         if(validation.CheckMargin(lot0, ORDER_TYPE_BUY, use_max_margin)) {
            mytrade.Buy(lot0, _Symbol, entry_price, sl, tp, "Random Trader EA");
            tiket = PositionGetTicket(0);
         }
      }
   }
   else {  // SELL
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = entry_price + sl_distance;
      double tp = entry_price - tp_distance;
      
      //--- Round prices first
      entry_price = validation.Round2Ticksize(entry_price);
      sl = validation.Round2Ticksize(sl);
      tp = validation.Round2Ticksize(tp);
      
      //--- Validate order placement
      if(!validation.ValidateOrderPlacement(ORDER_TYPE_SELL, sl, tp)) return;
      
      //--- Calculate and validate lot size
      double lot0 = validation.CalculateValidLot(sl, entry_price, risk_percent_per_trade);
      if(lot0 > 0) {
         //--- Check if we have enough margin for this position
         if(validation.CheckMargin(lot0, ORDER_TYPE_SELL, use_max_margin)) {
            mytrade.Sell(lot0, _Symbol, entry_price, sl, tp, "Random Trader EA");
            tiket = PositionGetTicket(0);
         }
      }
   }
}


double OnTester(void)
  {
   double ret=0.0;
  
   return( opt.On_Tester(3));
  }

//+------------------------------------------------------------------+
//| MIT License                                                       |
//|                                                                  |
//| Copyright (c) 2025 SalmanSoltaniyan                              |
//|                                                                  |
//| Permission is hereby granted, free of charge, to any person       |
//| obtaining a copy of this software and associated documentation    |
//| files (the "Software"), to deal in the Software without          |
//| restriction, including without limitation the rights to use,      |
//| copy, modify, merge, publish, distribute, sublicense, and/or sell |
//| copies of the Software, and to permit persons to whom the        |
//| Software is furnished to do so, subject to the following         |
//| conditions:                                                      |
//|                                                                  |
//| The above copyright notice and this permission notice shall be   |
//| included in all copies or substantial portions of the Software.  |
//|                                                                  |
//| THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,  |
//| EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES  |
//| OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND         |
//| NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT     |
//| HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,    |
//| WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING    |
//| FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR   |
//| OTHER DEALINGS IN THE SOFTWARE.                                 |
//+------------------------------------------------------------------+
