import { RefreshCw, Send } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import type { CustomerType, MarketState, OptionLeg, PortfolioSnapshot } from "../types";
import { blackScholes } from "../engine/blackScholes";
import { createOptionLeg } from "../engine/portfolio";

type MarketMakerArenaProps = {
  market: MarketState;
  snapshot: PortfolioSnapshot;
  onFill: (leg: OptionLeg, description: string) => void;
};

type CustomerOrder = {
  customer: CustomerType;
  side: "buy" | "sell";
  optionType: "call" | "put";
  strike: number;
  expiryDays: number;
  quantity: number;
  toxicity: number;
};

const customers: CustomerType[] = ["retail", "hedge_fund", "vol_arb", "corporate", "event_trader", "panic"];

export function MarketMakerArena({ market, snapshot, onFill }: MarketMakerArenaProps) {
  const [orderSeed, setOrderSeed] = useState(1);
  const order = useMemo(() => generateOrder(market, orderSeed), [market, orderSeed]);
  const fair = blackScholes({
    spot: market.spot,
    strike: order.strike,
    timeToExpiry: order.expiryDays / 365,
    volatility: market.volatility + order.toxicity * 0.05,
    riskFreeRate: market.riskFreeRate,
    optionType: order.optionType,
  }).price;
  const [bid, setBid] = useState(() => Math.max(0.01, fair * 0.96).toFixed(2));
  const [ask, setAsk] = useState(() => Math.max(0.02, fair * 1.06).toFixed(2));
  const [message, setMessage] = useState("Quote the flow, then manage the inventory.");

  useEffect(() => {
    setBid(Math.max(0.01, fair * 0.96).toFixed(2));
    setAsk(Math.max(0.02, fair * 1.06).toFixed(2));
  }, [fair, orderSeed]);

  function refreshOrder() {
    setOrderSeed((seed) => seed + 1);
    setMessage("New customer flow.");
  }

  function quote() {
    const bidValue = Number.parseFloat(bid);
    const askValue = Number.parseFloat(ask);
    if (!Number.isFinite(bidValue) || !Number.isFinite(askValue) || bidValue >= askValue) {
      setMessage("Invalid market. Bid must be below ask.");
      return;
    }

    const toxicEdge = order.toxicity * fair * 0.18;
    const buyFill = order.side === "buy" && askValue <= fair + toxicEdge;
    const sellFill = order.side === "sell" && bidValue >= fair - toxicEdge;

    if (!buyFill && !sellFill) {
      setMessage("No fill. The quote was too wide for this flow.");
      setOrderSeed((seed) => seed + 1);
      return;
    }

    const side = order.side === "buy" ? "short" : "long";
    const leg = createOptionLeg(side, order.optionType, market, {
      strike: order.strike,
      expiryDays: order.expiryDays,
      quantity: order.quantity,
      iv: market.volatility,
    });
    const fillPrice = order.side === "buy" ? askValue : bidValue;
    const adverse = order.toxicity > 0.6 ? " toxic" : "";
    onFill(leg, `${order.customer}${adverse} ${order.side} filled at ${fillPrice.toFixed(2)}`);
    setMessage(`Filled ${order.quantity}x ${order.optionType} at ${fillPrice.toFixed(2)}.`);
    setOrderSeed((seed) => seed + 1);
  }

  return (
    <section className="panel maker-panel">
      <div className="panel-heading compact">
        <div>
          <span className="eyebrow">Market maker arena</span>
          <h2>Client flow</h2>
        </div>
        <button className="icon-button" onClick={refreshOrder} aria-label="Refresh customer order">
          <RefreshCw size={16} />
        </button>
      </div>

      <div className="order-ticket">
        <span className={`customer-chip ${order.customer}`}>{order.customer.replace("_", " ")}</span>
        <strong>{order.side.toUpperCase()} {order.quantity} {order.expiryDays}D {order.strike} {order.optionType}</strong>
        <small>Fair {fair.toFixed(2)} | toxicity {(order.toxicity * 100).toFixed(0)}%</small>
      </div>

      <div className="quote-grid">
        <label>
          Bid
          <input value={bid} onChange={(event) => setBid(event.target.value)} />
        </label>
        <label>
          Ask
          <input value={ask} onChange={(event) => setAsk(event.target.value)} />
        </label>
        <button className="primary-button quote-button" onClick={quote}>
          <Send size={16} />
          Quote
        </button>
      </div>
      <div className="maker-risk-strip">
        <span>Width {(Number(ask) - Number(bid)).toFixed(2)}</span>
        <span>Inv Δ {snapshot.delta.toFixed(1)}</span>
        <span>Inv V {snapshot.vega.toFixed(1)}</span>
      </div>
      <p className="maker-message">{message}</p>
    </section>
  );
}

function generateOrder(market: MarketState, seed: number): CustomerOrder {
  const customer = customers[Math.abs(Math.floor(Math.sin(seed * 2.11) * 1000)) % customers.length];
  const side = Math.sin(seed * 1.3 + market.day) > 0 ? "buy" : "sell";
  const optionType = Math.sin(seed * 0.7) > 0 ? "call" : "put";
  const moneyness = optionType === "call" ? 1.02 + (seed % 4) * 0.025 : 0.98 - (seed % 4) * 0.025;
  const baseToxicity =
    customer === "retail" ? 0.18 :
      customer === "corporate" ? 0.28 :
        customer === "panic" ? 0.5 :
          customer === "event_trader" ? 0.82 :
            customer === "vol_arb" ? 0.68 : 0.58;
  return {
    customer,
    side,
    optionType,
    strike: Math.round(market.spot * moneyness),
    expiryDays: 14 + (seed % 4) * 14,
    quantity: 1 + (seed % 3),
    toxicity: Math.max(0, Math.min(1, baseToxicity + market.eventRisk * 0.2)),
  };
}
