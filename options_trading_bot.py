"""
AI Stock Options Trading Bot
A simulation-based options trading system using historical data for backtesting.
"""

import pandas as pd
import numpy as np
import yfinance as yf
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import logging
from dataclasses import dataclass
from abc import ABC, abstractmethod
import warnings
warnings.filterwarnings('ignore')

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

@dataclass
class Option:
    """Represents an options contract"""
    symbol: str
    strike: float
    expiry: datetime
    option_type: str  # 'call' or 'put'
    premium: float
    underlying_price: float
    
@dataclass
class Trade:
    """Represents a trade execution"""
    timestamp: datetime
    action: str  # 'buy' or 'sell'
    option: Option
    quantity: int
    total_cost: float
    
@dataclass
class Position:
    """Represents a current position"""
    option: Option
    quantity: int
    entry_price: float
    entry_date: datetime
    current_value: float = 0.0

class TradingStrategy(ABC):
    """Abstract base class for trading strategies"""
    
    def __init__(self, name: str):
        self.name = name
        
    @abstractmethod
    def should_buy(self, data: pd.DataFrame, current_price: float, date: datetime) -> Tuple[bool, Dict]:
        """Determine if we should buy options"""
        pass
    
    @abstractmethod
    def should_sell(self, position: Position, current_price: float, date: datetime) -> bool:
        """Determine if we should sell a position"""
        pass

class MomentumStrategy(TradingStrategy):
    """Simple momentum-based options trading strategy"""
    
    def __init__(self, rsi_period: int = 14, rsi_oversold: float = 30, rsi_overbought: float = 70):
        super().__init__("Momentum Strategy")
        self.rsi_period = rsi_period
        self.rsi_oversold = rsi_oversold
        self.rsi_overbought = rsi_overbought
        
    def calculate_rsi(self, prices: pd.Series, period: int = 14) -> pd.Series:
        """Calculate RSI indicator"""
        delta = prices.diff()
        gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
        loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
        rs = gain / loss
        rsi = 100 - (100 / (1 + rs))
        return rsi
    
    def should_buy(self, data: pd.DataFrame, current_price: float, date: datetime) -> Tuple[bool, Dict]:
        """Buy calls when oversold, puts when overbought"""
        if len(data) < self.rsi_period:
            return False, {}
            
        rsi = self.calculate_rsi(data['Close'])
        current_rsi = rsi.iloc[-1]
        
        # Calculate price momentum
        price_change_5d = (current_price - data['Close'].iloc[-6]) / data['Close'].iloc[-6] if len(data) >= 6 else 0
        
        signal_info = {
            'rsi': current_rsi,
            'price_change_5d': price_change_5d,
            'current_price': current_price
        }
        
        # Buy calls when RSI is oversold and showing upward momentum
        if current_rsi < self.rsi_oversold and price_change_5d > -0.05:
            signal_info['signal_type'] = 'buy_call'
            return True, signal_info
            
        # Buy puts when RSI is overbought and showing downward momentum
        elif current_rsi > self.rsi_overbought and price_change_5d < 0.05:
            signal_info['signal_type'] = 'buy_put'
            return True, signal_info
            
        return False, signal_info
    
    def should_sell(self, position: Position, current_price: float, date: datetime) -> bool:
        """Sell based on profit/loss thresholds and time decay"""
        days_held = (date - position.entry_date).days
        profit_loss = (position.current_value - position.entry_price) / position.entry_price
        
        # Sell if profit > 50% or loss > 30%
        if profit_loss > 0.5 or profit_loss < -0.3:
            return True
            
        # Sell if holding for more than 30 days (time decay)
        if days_held > 30:
            return True
            
        return False

class OptionsBot:
    """Main options trading bot class"""
    
    def __init__(self, initial_capital: float = 10000, strategy: TradingStrategy = None):
        self.initial_capital = initial_capital
        self.current_capital = initial_capital
        self.strategy = strategy or MomentumStrategy()
        self.positions: List[Position] = []
        self.trade_history: List[Trade] = []
        self.performance_history: List[Dict] = []
        
    def fetch_historical_data(self, symbol: str, period: str = "1y") -> pd.DataFrame:
        """Fetch historical stock data"""
        try:
            ticker = yf.Ticker(symbol)
            data = ticker.history(period=period)
            logger.info(f"Fetched {len(data)} days of data for {symbol}")
            return data
        except Exception as e:
            logger.error(f"Error fetching data for {symbol}: {e}")
            return pd.DataFrame()
    
    def calculate_option_premium(self, underlying_price: float, strike_price: float, 
                                days_to_expiry: int, option_type: str, volatility: float = 0.25) -> float:
        """Simplified Black-Scholes option pricing (for simulation)"""
        # This is a simplified model for simulation purposes
        # In reality, you'd use more sophisticated pricing models
        
        time_value = max(0, days_to_expiry / 365.0)
        intrinsic_value = 0
        
        if option_type == 'call':
            intrinsic_value = max(0, underlying_price - strike_price)
        else:  # put
            intrinsic_value = max(0, strike_price - underlying_price)
        
        # Simple time value calculation
        time_premium = underlying_price * volatility * np.sqrt(time_value) * 0.4
        
        return intrinsic_value + time_premium
    
    def generate_option_strikes(self, current_price: float, option_type: str) -> List[float]:
        """Generate reasonable strike prices for options"""
        if option_type == 'call':
            # For calls, use strikes slightly out of the money
            return [current_price * multiplier for multiplier in [1.02, 1.05, 1.10]]
        else:  # put
            # For puts, use strikes slightly out of the money
            return [current_price * multiplier for multiplier in [0.98, 0.95, 0.90]]
    
    def execute_trade(self, action: str, option: Option, quantity: int, date: datetime) -> bool:
        """Execute a trade (buy or sell)"""
        total_cost = option.premium * quantity * 100  # Options are in lots of 100
        
        if action == 'buy':
            if total_cost <= self.current_capital:
                self.current_capital -= total_cost
                
                # Create new position
                position = Position(
                    option=option,
                    quantity=quantity,
                    entry_price=option.premium,
                    entry_date=date,
                    current_value=option.premium
                )
                self.positions.append(position)
                
                # Record trade
                trade = Trade(date, action, option, quantity, total_cost)
                self.trade_history.append(trade)
                
                logger.info(f"Bought {quantity} {option.option_type} options at ${option.premium:.2f}")
                return True
            else:
                logger.warning(f"Insufficient capital for trade. Need ${total_cost:.2f}, have ${self.current_capital:.2f}")
                return False
                
        elif action == 'sell':
            # Find matching position to sell
            for i, position in enumerate(self.positions):
                if (position.option.symbol == option.symbol and 
                    position.option.strike == option.strike and
                    position.option.option_type == option.option_type and
                    position.quantity >= quantity):
                    
                    proceeds = option.premium * quantity * 100
                    self.current_capital += proceeds
                    
                    # Update position
                    position.quantity -= quantity
                    if position.quantity == 0:
                        self.positions.pop(i)
                    
                    # Record trade
                    trade = Trade(date, action, option, quantity, proceeds)
                    self.trade_history.append(trade)
                    
                    logger.info(f"Sold {quantity} {option.option_type} options at ${option.premium:.2f}")
                    return True
                    
        return False
    
    def update_positions(self, current_price: float, date: datetime, symbol: str):
        """Update current value of all positions"""
        for position in self.positions:
            if position.option.symbol == symbol:
                days_to_expiry = (position.option.expiry - date).days
                if days_to_expiry > 0:
                    current_premium = self.calculate_option_premium(
                        current_price, position.option.strike, days_to_expiry, 
                        position.option.option_type
                    )
                    position.current_value = current_premium
                else:
                    # Option expired
                    if position.option.option_type == 'call':
                        position.current_value = max(0, current_price - position.option.strike)
                    else:
                        position.current_value = max(0, position.option.strike - current_price)
    
    def get_portfolio_value(self) -> float:
        """Calculate total portfolio value"""
        positions_value = sum(pos.current_value * pos.quantity * 100 for pos in self.positions)
        return self.current_capital + positions_value
    
    def backtest(self, symbol: str, start_date: str = None, end_date: str = None):
        """Run backtest on historical data"""
        logger.info(f"Starting backtest for {symbol}")
        
        # Fetch historical data
        data = self.fetch_historical_data(symbol, "2y")  # Get 2 years of data
        if data.empty:
            logger.error("No data available for backtesting")
            return
        
        # Filter data by date range if provided
        if start_date:
            data = data[data.index >= start_date]
        if end_date:
            data = data[data.index <= end_date]
        
        # Run simulation day by day
        for i in range(30, len(data)):  # Start after 30 days for indicators
            current_date = data.index[i]
            current_price = data['Close'].iloc[i]
            historical_data = data.iloc[:i+1]
            
            # Update existing positions
            self.update_positions(current_price, current_date, symbol)
            
            # Check for sell signals
            positions_to_sell = []
            for position in self.positions:
                if self.strategy.should_sell(position, current_price, current_date):
                    positions_to_sell.append(position)
            
            # Execute sell orders
            for position in positions_to_sell:
                option = Option(
                    symbol=symbol,
                    strike=position.option.strike,
                    expiry=position.option.expiry,
                    option_type=position.option.option_type,
                    premium=position.current_value,
                    underlying_price=current_price
                )
                self.execute_trade('sell', option, position.quantity, current_date)
            
            # Check for buy signals
            should_buy, signal_info = self.strategy.should_buy(historical_data, current_price, current_date)
            
            if should_buy and len(self.positions) < 5:  # Limit to 5 concurrent positions
                option_type = signal_info.get('signal_type', '').replace('buy_', '')
                
                if option_type in ['call', 'put']:
                    strikes = self.generate_option_strikes(current_price, option_type)
                    best_strike = strikes[0]  # Use the first (closest to money) strike
                    
                    expiry_date = current_date + timedelta(days=30)  # 30-day options
                    premium = self.calculate_option_premium(
                        current_price, best_strike, 30, option_type
                    )
                    
                    option = Option(
                        symbol=symbol,
                        strike=best_strike,
                        expiry=expiry_date,
                        option_type=option_type,
                        premium=premium,
                        underlying_price=current_price
                    )
                    
                    # Risk management: limit position size to 10% of capital
                    max_cost = self.current_capital * 0.1
                    max_quantity = int(max_cost / (premium * 100))
                    
                    if max_quantity > 0:
                        self.execute_trade('buy', option, min(max_quantity, 1), current_date)
            
            # Record performance
            portfolio_value = self.get_portfolio_value()
            self.performance_history.append({
                'date': current_date,
                'portfolio_value': portfolio_value,
                'capital': self.current_capital,
                'positions_count': len(self.positions),
                'underlying_price': current_price
            })
        
        logger.info("Backtest completed")
        self.print_results()
    
    def print_results(self):
        """Print backtesting results"""
        if not self.performance_history:
            logger.warning("No performance data available")
            return
        
        final_value = self.performance_history[-1]['portfolio_value']
        total_return = (final_value - self.initial_capital) / self.initial_capital * 100
        
        print("\n" + "="*50)
        print("BACKTESTING RESULTS")
        print("="*50)
        print(f"Strategy: {self.strategy.name}")
        print(f"Initial Capital: ${self.initial_capital:,.2f}")
        print(f"Final Portfolio Value: ${final_value:,.2f}")
        print(f"Total Return: {total_return:.2f}%")
        print(f"Total Trades: {len(self.trade_history)}")
        print(f"Current Positions: {len(self.positions)}")
        
        if len(self.performance_history) > 1:
            returns = []
            for i in range(1, len(self.performance_history)):
                prev_val = self.performance_history[i-1]['portfolio_value']
                curr_val = self.performance_history[i]['portfolio_value']
                daily_return = (curr_val - prev_val) / prev_val
                returns.append(daily_return)
            
            if returns:
                volatility = np.std(returns) * np.sqrt(252) * 100  # Annualized volatility
                sharpe_ratio = (total_return / 100) / (volatility / 100) if volatility > 0 else 0
                
                print(f"Volatility (annualized): {volatility:.2f}%")
                print(f"Sharpe Ratio: {sharpe_ratio:.2f}")
        
        print("\nRecent Trades:")
        for trade in self.trade_history[-5:]:  # Show last 5 trades
            print(f"{trade.timestamp.strftime('%Y-%m-%d')}: {trade.action.upper()} "
                  f"{trade.quantity} {trade.option.option_type} ${trade.option.strike} "
                  f"@ ${trade.option.premium:.2f}")
        
        print("="*50)

# Example usage and testing
if __name__ == "__main__":
    # Create trading bot with momentum strategy
    strategy = MomentumStrategy(rsi_period=14, rsi_oversold=30, rsi_overbought=70)
    bot = OptionsBot(initial_capital=10000, strategy=strategy)
    
    # Run backtest on a popular stock
    symbol = "AAPL"  # Apple Inc.
    print(f"Running backtest for {symbol}...")
    
    # Run backtest for the last year
    end_date = datetime.now().strftime('%Y-%m-%d')
    start_date = (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d')
    
    bot.backtest(symbol, start_date=start_date, end_date=end_date)
