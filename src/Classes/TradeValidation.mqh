//+------------------------------------------------------------------+
//|                                                TradeValidation.mqh |
//|                                                 SalmanSoltaniyan   |
//|                                             https://www.mql5.com   |
//+------------------------------------------------------------------+
#property copyright "SalmanSoltaniyan"
#property link      "https://www.mql5.com/en/users/salmansoltaniyan"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Validation class for trading operations                           |
//+------------------------------------------------------------------+
class CTradeValidation
  {
private:
   string            symbol;
   double            point;
  // double            min_stop_level;
   double            pip_point;
   double            stop_level;    // Added stop level
   double            freeze_level;  // Added freeze level

public:
   //--- Constructor
                     CTradeValidation(string _symbol, bool use_max_level = false)
     {
      symbol = _symbol;
      point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      //--- Initialize pip value based on symbol digits
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(digits == 2 || digits == 3) // JPY pairs or crypto
         pip_point = point;
      else
         if(digits == 4 || digits == 5) // Standard Forex pairs
            pip_point = point * 10;
            
      //--- Initialize stop level and freeze level from symbol
      freeze_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point+ (10 * point);;
      stop_level = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point+ (10 * point);;
   
      //--- If use_max_level is true, set freeze level to max of freeze level and stop level
      if(use_max_level)
      {
         freeze_level = MathMax(freeze_level, stop_level);
      stop_level = freeze_level;
      }
      
     }

   //--- Get stop level
   double            GetStopLevel() { return stop_level; }
   
   //--- Get freeze level
   double            GetFreezeLevel() { return freeze_level; }


   //--- Calculate and validate lot size
   double            CalculateValidLot(double sl_price, double entry_price, double risk_percent)
     {
      double sl_points = MathAbs(sl_price - entry_price) / point;
      double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      //double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double max_lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_LIMIT);
      if(max_lot==0)
         max_lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      //--- Calculate lot size based on risk
      double lot_size = (AccountInfoDouble(ACCOUNT_BALANCE) * risk_percent / 100) / (sl_points * tick_value);

      //--- Round lot size to symbol lot step
      lot_size = MathFloor(lot_size / lot_step) * lot_step;

      //--- Validate lot size
      if(lot_size < min_lot)
         lot_size = min_lot;
      if(lot_size > max_lot)
         lot_size = max_lot;

      return lot_size;
     }

   //--- Check if there is enough margin for the position
   bool              CheckMargin(double &lot_size, ENUM_ORDER_TYPE order_type, bool use_max_margin0 = true)
     {
      //--- Get required margin for the position
      double margin_required;
      double price = (order_type == ORDER_TYPE_BUY) ?
                     SymbolInfoDouble(symbol, SYMBOL_ASK) :
                     SymbolInfoDouble(symbol, SYMBOL_BID);

      if(!OrderCalcMargin(order_type, symbol, lot_size, price, margin_required))
        {
         return false;
        }

      //--- Get available margin
      double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

      //--- Add 10% buffer to required margin for safety
      margin_required *= 1.1;

      //--- Check if we have enough margin
      if(free_margin < margin_required)
        {
         if(use_max_margin0)
           {
            //--- Calculate maximum possible lot size based on available margin
            double max_lot = CalculateMaxLot(order_type, free_margin);
            if(max_lot > 0)
              {
               lot_size = max_lot;
               return true;
              }
           }
         return false;
        }

      return true;
     }

   //--- Calculate maximum possible lot size based on available margin
   double            CalculateMaxLot(ENUM_ORDER_TYPE order_type, double available_margin)
     {
      double price = (order_type == ORDER_TYPE_BUY) ?
                     SymbolInfoDouble(symbol, SYMBOL_ASK) :
                     SymbolInfoDouble(symbol, SYMBOL_BID);

      double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double max_lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_LIMIT);
      if(max_lot==0)
         max_lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
      double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

      //--- Calculate maximum possible lot size
      double margin_per_lot;
      if(!OrderCalcMargin(order_type, symbol, 1.0, price, margin_per_lot))
        {
         return 0;
        }

      //--- Calculate maximum lot size (with 10% buffer)
      double max_possible_lot = (available_margin / 1.1) / margin_per_lot;

      //--- Round to lot step
      max_possible_lot = MathFloor(max_possible_lot / lot_step) * lot_step;

      //--- Validate against symbol limits
      if(max_possible_lot < min_lot)
         return 0;
      if(max_possible_lot > max_lot)
         max_possible_lot = max_lot;

      return max_possible_lot;
     }

   //--- Get pip point value
   double            GetPipPoint() { return pip_point; }

 

   //--- Normalize price to tick size
   double            Round2Ticksize(double price)
     {
      double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      return (MathRound(price / tick_size) * tick_size);
     }
  //--- Validate placing a position
   bool              ValidateOrderPlacement(ENUM_ORDER_TYPE order_type, double sl_price, double tp_price, double open_price=0)
     {
      //--- Normalize prices
      open_price = Round2Ticksize(open_price);
      sl_price = Round2Ticksize(sl_price);
      tp_price = Round2Ticksize(tp_price);
      
      //--- Get current market prices
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      //--- Validate based on order type
      switch(order_type) {
         case ORDER_TYPE_BUY:
            // For market orders, use bid/ask instead of open price
            return (bid - sl_price >= stop_level && tp_price - bid >= stop_level);
            
         case ORDER_TYPE_SELL:
            // For market orders, use bid/ask instead of open price
            return (sl_price - ask >= stop_level && ask - tp_price >= stop_level);
            
         case ORDER_TYPE_BUY_LIMIT:
            return (ask - open_price >= stop_level && 
                   open_price - sl_price >= stop_level && 
                   tp_price - open_price >= stop_level);
            
         case ORDER_TYPE_SELL_LIMIT:
            return (open_price - bid >= stop_level && 
                   sl_price - open_price >= stop_level && 
                   open_price - tp_price >= stop_level);
            
         case ORDER_TYPE_BUY_STOP:
            return (open_price - ask >= stop_level && 
                   open_price - sl_price >= stop_level && 
                   tp_price - open_price >= stop_level);
            
         case ORDER_TYPE_SELL_STOP:
            return (bid - open_price >= stop_level && 
                   sl_price - open_price >= stop_level && 
                   open_price - tp_price >= stop_level);
      }
      
      return false;
     }
   //--- Validate SL modification
   bool              ValidateSLModify(ENUM_ORDER_TYPE order_type, double old_sl, double new_sl, double open_price = 0)
     {
         /*
      stopLoss/TakeProfit of a pending order cannot be placed closer to the requested order open price than at the minimum distance StopLevel.
      The positions of StopLoss and TakeProfit of pending orders are not limited by the freeze distance FreezeLevel.
      Market Orders StopLoss and TakeProfit cannot be placed closer to the market price than at the minimum distance.
      Market  order cannot be modified, if the execution price of its StopLoss or TakeProfit ranges within the freeze distance from the market price.
      
      */ 
      //--- Normalize prices
      old_sl = Round2Ticksize(old_sl);
      new_sl = Round2Ticksize(new_sl);
      open_price = Round2Ticksize(open_price);
      
      //--- Get current market prices
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      //--- First validate old SL (only for market orders)
      if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL) {
         if(order_type == ORDER_TYPE_BUY) {
            if(bid - old_sl <= freeze_level) return false;
         }
         else if(order_type == ORDER_TYPE_SELL) {
            if(old_sl - ask <= freeze_level) return false;
         }
      }
      
      //--- Then validate new SL based on order type
      switch(order_type) {
         case ORDER_TYPE_BUY:
            return (bid - new_sl >= stop_level);
            
         case ORDER_TYPE_SELL:
            return (new_sl - ask >= stop_level);
            
         case ORDER_TYPE_BUY_LIMIT:
         case ORDER_TYPE_BUY_STOP:
            return (open_price - new_sl >= stop_level);
            
         case ORDER_TYPE_SELL_LIMIT:
         case ORDER_TYPE_SELL_STOP:
            return (new_sl - open_price >= stop_level);
      }
      
      return false;
     }

   //--- Validate TP modification
   bool              ValidateTPModify(ENUM_ORDER_TYPE order_type, double old_tp, double new_tp, double open_price = 0)
     {
      /*
      stopLoss/TakeProfit of a pending order cannot be placed closer to the requested order open price than at the minimum distance StopLevel.
      The positions of StopLoss and TakeProfit of pending orders are not limited by the freeze distance FreezeLevel.
      Market Orders StopLoss and TakeProfit cannot be placed closer to the market price than at the minimum distance.
      Market  order cannot be modified, if the execution price of its StopLoss or TakeProfit ranges within the freeze distance from the market price.
      */ 
      //--- Normalize prices
      old_tp = Round2Ticksize(old_tp);
      new_tp = Round2Ticksize(new_tp);
      open_price = Round2Ticksize(open_price);
      
      //--- Get current market prices
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      //--- First validate old TP (only for market orders)
      if(order_type == ORDER_TYPE_BUY || order_type == ORDER_TYPE_SELL) {
         if(order_type == ORDER_TYPE_BUY) {
            if(old_tp - bid <= freeze_level) return false;
         }
         else if(order_type == ORDER_TYPE_SELL) {
            if(ask - old_tp <= freeze_level) return false;
         }
      }
      
      //--- Then validate new TP based on order type
      switch(order_type) {
         case ORDER_TYPE_BUY:
            return (new_tp - bid >= stop_level);
            
         case ORDER_TYPE_SELL:
            return (ask - new_tp >= stop_level);
            
         case ORDER_TYPE_BUY_LIMIT:
         case ORDER_TYPE_BUY_STOP:
            return (new_tp - open_price >= stop_level);
            
         case ORDER_TYPE_SELL_LIMIT:
         case ORDER_TYPE_SELL_STOP:
            return (open_price - new_tp >= stop_level);
      }
      
      return false;
     }

   //--- Validate open price modification for pending orders
   bool              ValidateOpenPriceModify(ENUM_ORDER_TYPE order_type, double old_open_price, double new_open_price)
     {
      /*
      Pending orders BuyLimit and BuyStop cannot be placed closer to the market price Ask than at the minimum distance StopLevel.
      Pending orders SellLimit and SellStop cannot be placed closer to the market price Bid than at the minimum distance StopLevel.

      Pending orders BuyLimit and BuyStop cannot be modified, if the requested order open price ranges within the freeze distance from the market price Ask.
      Pending orders SellLimit and SellStop cannot be modified, if the requested order open price ranges within the freeze distance from the market price Bid.

      */
      //--- Normalize prices
      old_open_price = Round2Ticksize(old_open_price);
      new_open_price = Round2Ticksize(new_open_price);
      
      //--- Get current market prices
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      //--- First validate old open price
      switch(order_type) {
         case ORDER_TYPE_BUY_LIMIT:
            if(ask - old_open_price <= freeze_level) return false;
            break;
            
         case ORDER_TYPE_SELL_LIMIT:
            if(old_open_price - bid <= freeze_level) return false;
            break;
            
         case ORDER_TYPE_BUY_STOP:
            if(old_open_price - ask <= freeze_level) return false;
            break;
            
         case ORDER_TYPE_SELL_STOP:
            if(bid - old_open_price <= freeze_level) return false;
            break;
            
         default:
            return false; // Not a pending order
      }
      
      //--- Then validate new open price
      switch(order_type) {
         case ORDER_TYPE_BUY_LIMIT:
            return (ask - new_open_price >= stop_level);
            
         case ORDER_TYPE_SELL_LIMIT:
            return (new_open_price - bid >= stop_level);
            
         case ORDER_TYPE_BUY_STOP:
            return (new_open_price - ask >= stop_level);
            
         case ORDER_TYPE_SELL_STOP:
            return (bid - new_open_price >= stop_level);
      }
      
      return false;
     }

   //--- Validate if position can be closed
   bool              ValidateClosePosition(ENUM_ORDER_TYPE order_type, double sl_price, double tp_price)
     {
      /*
      Position cannot be closed, if the execution price of its StopLoss or TakeProfit is within the range of freeze distance from the market price. 
      Buy: Bid-SL > FreezeLevel 	TP-Bid > FreezeLevel
      Sell: SL-Ask > FreezeLevel 	Ask-TP > FreezeLevel 
      */
      //--- Normalize prices
      sl_price = Round2Ticksize(sl_price);
      tp_price = Round2Ticksize(tp_price);
      
      //--- Get current market prices
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      //--- Validate based on order type
      switch(order_type) {
         case ORDER_TYPE_BUY:
            // For BUY positions, check if SL or TP is within freeze level of bid
            if(bid - sl_price <= freeze_level) return false;
            if(tp_price - bid <= freeze_level) return false;
            return true;
            
         case ORDER_TYPE_SELL:
            // For SELL positions, check if SL or TP is within freeze level of ask
            if(sl_price - ask <= freeze_level) return false;
            if(ask - tp_price <= freeze_level) return false;
            return true;
            
         default:
            return false; // Not a market order
      }
     }

   //--- Validate if pending order can be deleted
   bool              ValidateDeletePendingOrder(ENUM_ORDER_TYPE order_type, double open_price)
     {
      /*
      Pending orders cannot be deleted if the requested open price is within the range of freeze distance from the market price.
      BuyLimit: Ask-OpenPrice > FreezeLevel
      SellLimit: OpenPrice-Bid > FreezeLevel
      BuyStop: OpenPrice-Ask > FreezeLevel
      SellStop: Bid-OpenPrice > FreezeLevel
      */
      
      //--- Normalize price
      open_price = Round2Ticksize(open_price);
      
      //--- Get current market prices
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      //--- Validate based on order type
      switch(order_type) {
         case ORDER_TYPE_BUY_LIMIT:
            return (ask - open_price > freeze_level);
            
         case ORDER_TYPE_SELL_LIMIT:
            return (open_price - bid > freeze_level);
            
         case ORDER_TYPE_BUY_STOP:
            return (open_price - ask > freeze_level);
            
         case ORDER_TYPE_SELL_STOP:
            return (bid - open_price > freeze_level);
            
         default:
            return false; // Not a pending order
      }
     }
  };
//+------------------------------------------------------------------+
