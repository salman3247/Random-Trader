
1. Method Overview

Random Trader EA is an automated trading system for MetaTrader 5 that initiates trades with a randomly chosen buy or sell direction. Despite the random entry, the EA incorporates robust risk management, dynamic position sizing, and sophisticated exit strategies. This unique approach serves as a valuable tool for research, portfolio diversification, and as a foundational template for developing and evaluating risk management techniques within algorithmic trading.
2. Key Features

    Randomized Trade Entry: Opens trades randomly as either buy or sell for unbiased market engagement.
    Advanced Risk Management: Calculates position size based on user-defined risk percentage and stop loss distance, with an option for maximum margin utilization.
    Flexible Stop Loss: Offers a choice between dynamic ATR-based or fixed pip-based stop loss calculation.
    Take Profit & Reward/Risk: Sets take profit as a multiple of the stop loss, based on the specified reward/risk ratio.
    Trailing Stop Options: Includes breakeven and step-wise trailing stop functionalities, with an optional partial close at each step.
    Time & Spread Filters: Allows restriction of trading to specific hours and avoidance of trading during high-spread conditions.
    Weekend Protection: Provides an option to automatically close all positions before the weekend to mitigate gap risk.
    Magic Number: Tags all trades with a unique identifier for seamless multi-EA operation and portfolio management.

3. Input Parameters

Trade Identification

    magic_number: Unique identifier for EA trades.

Risk Management

    risk_percent_per_trade : Percentage of account balance to risk per trade.
    reward_risk_ratio : Take profit multiple of the stop loss.
    use_max_margin : Enable to use the maximum allowable lot size based on margin.

Stop Loss Configuration

    loss : Stop loss calculation method ( ATR or PIP ).
    loss_atr : ATR multiplier for stop loss (if loss is ATR ).
    loss_pip : Fixed pip distance for stop loss (if loss is PIP ).

Trailing Stop Settings

    trail_mode : Trailing stop mode ( NONE , BREAKEVEN , or STEPWISE ).
    breakeven_distance : Pips to move stop loss to breakeven (if trail_mode is BREAKEVEN ).
    trail_steps : Number of steps for step-wise trailing stop (if trail_mode is STEPWISE ).
    use_partial_close : Enable partial position closure at each trail step.
    partial_close_percent : Percentage of the position to close at each step.

Trading Time Settings

    use_time_filter : Enable/disable trading time restrictions.
    start_hour : Trading session start hour (0-23).
    start_minute : Trading session start minute (0-59).
    duration : Trading session duration in hours (can span across midnight).
    close_at_end_time : Close all positions at the end of the trading session.

Market Condition Filters

    use_spread_filter : Enable/disable the maximum spread limit.
    max_spread : Maximum allowable spread (in points) for trade entry.

Weekend Protection

    close_before_weekend : Enable closing positions before the weekend.
    friday_close_hour : Hour on Friday to close positions (0-23).
    friday_close_minute : Minute on Friday to close positions (0-59).


4. Important Disclaimer

This Expert Advisor is intended for research and educational purposes only. Random Trader EA does not guarantee profitability and should not be considered a standalone trading solution for live trading accounts. The inherent randomness of the entry method is not designed for profit generation. Its primary function is to demonstrate and facilitate the testing of risk management, position sizing, and exit strategies. Always test thoroughly on a demo account and fully understand the associated risks before using with real funds.