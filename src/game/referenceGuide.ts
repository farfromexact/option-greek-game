import type { LucideIcon } from "lucide-react";
import {
  Activity,
  AlertTriangle,
  BookOpen,
  CircleDollarSign,
  CloudLightning,
  Crosshair,
  Dices,
  Eraser,
  FastForward,
  Fuel,
  Gauge,
  HelpCircle,
  Layers3,
  Pause,
  Play,
  Plus,
  Radio,
  RefreshCw,
  RotateCcw,
  Save,
  Send,
  Shield,
  ShieldCheck,
  StepForward,
  Target,
  Trash2,
  Trophy,
  Wind,
} from "lucide-react";

export type GuideEntry = {
  label: string;
  detail: string;
  read?: string;
  icon?: LucideIcon;
  visual?: string;
};

export type GuideSection = {
  id: string;
  title: string;
  summary: string;
  entries: GuideEntry[];
};

export const guideSections: GuideSection[] = [
  {
    id: "icons",
    title: "Icons",
    summary: "Every recurring icon in the game is a shortcut for an action, risk, or panel.",
    entries: [
      {
        label: "Tutorial",
        detail: "Opens the pre-game teaching path. Use it when you want the recommended 1.0 route.",
        icon: BookOpen,
      },
      {
        label: "Guide",
        detail: "Opens this reference guide. It explains the interface without restarting the tutorial.",
        icon: HelpCircle,
      },
      {
        label: "P&L",
        detail: "Shows current live profit and loss for the active run.",
        icon: CircleDollarSign,
      },
      {
        label: "Save local run",
        detail: "Stores best score, completion, leaderboard entry, tutorial state, and calibration history in this browser.",
        read: "It is localStorage, not a cloud save.",
        icon: Save,
      },
      {
        label: "Jane Street Trials",
        detail: "Opens the capstone missions that combine Greeks, surface, probability, and market making.",
        icon: Trophy,
      },
      {
        label: "Challenge seed launch",
        detail: "Creates a generated mission from the text in the seed box.",
        read: "The same seed text creates the same mission again.",
        icon: Dices,
      },
      {
        label: "Run / Pause",
        detail: "Starts or stops automatic market steps.",
        icon: Play,
      },
      {
        label: "Pause",
        detail: "Stops the running path so you can hedge, edit legs, or inspect the replay.",
        icon: Pause,
      },
      {
        label: "Step",
        detail: "Advances one market day. Use this when learning a new setup.",
        icon: StepForward,
      },
      {
        label: "Speed",
        detail: "Cycles simulation speed through 1x, 2x, and 4x.",
        icon: FastForward,
      },
      {
        label: "Restart",
        detail: "Restarts the selected mission and restores its scripted starting weather.",
        icon: RotateCcw,
      },
      {
        label: "Delta wind",
        detail: "Directional exposure to spot movement.",
        read: "Positive Delta likes spot up; negative Delta likes spot down.",
        icon: Wind,
      },
      {
        label: "Gamma spring",
        detail: "How quickly Delta changes when spot moves.",
        read: "High Gamma can help in movement but often costs Theta.",
        icon: Activity,
      },
      {
        label: "Theta fuel",
        detail: "Time decay. Long options usually leak it; short premium collects it with tail risk.",
        icon: Fuel,
      },
      {
        label: "Vega storm",
        detail: "Sensitivity to implied volatility changes.",
        icon: CloudLightning,
      },
      {
        label: "P&L energy",
        detail: "Shows current run P&L as a gain/loss energy bar.",
        icon: Gauge,
      },
      {
        label: "Risk shield",
        detail: "Shows how much room remains before sponsor limits are stressed.",
        icon: Shield,
      },
      {
        label: "Risk warning",
        detail: "Marks drawdown and stress sources that may break the mission.",
        icon: AlertTriangle,
      },
      {
        label: "Limit check",
        detail: "Marks liquidity/event pressure inside sponsor limits.",
        icon: ShieldCheck,
      },
      {
        label: "Add part",
        detail: "Adds an option leg, stock hedge, or cash part to the portfolio.",
        icon: Plus,
      },
      {
        label: "Delta hedge",
        detail: "Adds stock to offset the current portfolio Delta.",
        icon: Crosshair,
      },
      {
        label: "Buy wing",
        detail: "Buys an out-of-the-money put as tail protection.",
        icon: Shield,
      },
      {
        label: "Clear",
        detail: "Resets the workshop to cash only.",
        icon: Eraser,
      },
      {
        label: "Remove leg",
        detail: "Deletes one option, stock, or cash row from the portfolio.",
        icon: Trash2,
      },
      {
        label: "Vol surface layers",
        detail: "Marks the volatility surface map and bucketed Vega panel.",
        icon: Layers3,
      },
      {
        label: "Replay",
        detail: "Marks the debrief panel where P&L is split into causes.",
        icon: Radio,
      },
      {
        label: "Refresh customer",
        detail: "Generates a new market-maker customer order.",
        icon: RefreshCw,
      },
      {
        label: "Quote",
        detail: "Sends your bid/ask quote to the current customer flow.",
        icon: Send,
      },
      {
        label: "Probability target",
        detail: "Marks the Probability Pit, where forecasts are scored by Brier score.",
        icon: Target,
      },
    ],
  },
  {
    id: "patterns",
    title: "Visual Patterns",
    summary: "These shapes are the game language for risk, price path, volatility, and debrief evidence.",
    entries: [
      {
        label: "Green / amber / red status pill",
        detail: "Green means controlled, amber means attention, red means stress or limit danger.",
        visual: "pill",
      },
      {
        label: "Force meter with center line",
        detail: "The middle is neutral. Fill to the right is positive exposure; fill to the left is negative exposure.",
        visual: "force",
      },
      {
        label: "Delta arrow",
        detail: "Direction and length show how spot movement pushes the portfolio.",
        visual: "arrow",
      },
      {
        label: "Gamma spring bars",
        detail: "Wider and taller bars mean the book reacts more sharply when spot moves.",
        visual: "spring",
      },
      {
        label: "P&L energy bar",
        detail: "Green means live profit; red means live loss.",
        visual: "energy",
      },
      {
        label: "Shield fill",
        detail: "Remaining risk capacity. A shrinking shield means the run is becoming fragile.",
        visual: "shield",
      },
      {
        label: "Market weather map",
        detail: "Amber line is spot path, teal bubble is IV pressure, red core is event risk, magenta dashed curve is skew/front risk.",
        visual: "weather",
      },
      {
        label: "Liquidity / Event / Skew meters",
        detail: "Small gauges under weather. Low liquidity means higher friction; high event/skew means more jump or surface risk.",
        visual: "meters",
      },
      {
        label: "Payoff line",
        detail: "Expiry P&L shape across final spot prices. Flat caps or steep cliffs reveal strategy structure.",
        visual: "payoff",
      },
      {
        label: "Dashed spot line",
        detail: "Current spot inside payoff or scenario charts.",
        visual: "dashed",
      },
      {
        label: "Scenario heat grid",
        detail: "Green cells are profitable stress cases, red cells are losing stress cases, opacity shows severity.",
        visual: "heat",
      },
      {
        label: "Vol surface cells",
        detail: "Each cell is an IV point by strike and expiry. Brighter/higher cells are richer volatility.",
        visual: "surface",
      },
      {
        label: "Vega bucket bars",
        detail: "Shows where Vega is concentrated by expiry/wing. Magenta bars are short Vega buckets.",
        visual: "bucket",
      },
      {
        label: "Replay timeline",
        detail: "Each bar is one run step. Green/red shows P&L sign, height shows size, outline marks selected replay step.",
        visual: "timeline",
      },
      {
        label: "Long / short chips",
        detail: "Green chips are long exposure, red chips are short exposure, amber is stock, teal is cash.",
        visual: "chips",
      },
    ],
  },
  {
    id: "operations",
    title: "Operations",
    summary: "Use this as a checklist for what each action changes in the game state.",
    entries: [
      {
        label: "Select level group",
        detail: "Switches the left mission picker between Core path, Jane Street finals, generated missions, and custom challenge runs.",
      },
      {
        label: "Select a mission",
        detail: "Loads that level's initial market, portfolio, constraints, and score target.",
      },
      {
        label: "Save local run",
        detail: "Records the current score and completion if the result qualifies. It also updates the local leaderboard.",
      },
      {
        label: "Type a Challenge seed",
        detail: "Any text works. Use memorable labels like market-open-001 or crash-wing-2026.",
      },
      {
        label: "Launch seed",
        detail: "Builds a new generated challenge from the seed and places it in the Challenge group.",
      },
      {
        label: "Training override weather",
        detail: "Changes the market regime for sandbox practice. It is not the mission's original scripted weather.",
      },
      {
        label: "Add an option part",
        detail: "Click or drag Long Call, Short Call, Long Put, Short Put, Stock Hedge, or Cash into the book.",
      },
      {
        label: "Edit a leg",
        detail: "Side controls long/short, Type controls call/put, Strike sets price level, Expiry sets days, IV sets implied vol, Qty sets size.",
      },
      {
        label: "Delta hedge",
        detail: "Adds stock in the opposite direction of current Delta. It reduces directional wind but may add cost.",
      },
      {
        label: "Buy wing",
        detail: "Adds a protective put wing. It costs premium but helps left-tail survival.",
      },
      {
        label: "Clear book",
        detail: "Removes current construction and leaves cash only.",
      },
      {
        label: "Run / Step",
        detail: "Moves the market path forward. Step is better for learning; Run is better after your book is ready.",
      },
      {
        label: "Replay scrubber",
        detail: "Moves through prior steps to see what the market, portfolio, and P&L looked like at that time.",
      },
      {
        label: "Refresh customer order",
        detail: "Creates a new market-maker flow ticket without filling the current one.",
      },
      {
        label: "Set Bid / Ask",
        detail: "Bid is what you pay to buy from the customer. Ask is what you charge when selling to the customer.",
      },
      {
        label: "Quote customer",
        detail: "If your quote is attractive enough, the customer fills and leaves an option position in your book.",
      },
      {
        label: "Probability sliders",
        detail: "Set your odds before or during a run. Use them to train calibration, not just direction guessing.",
      },
      {
        label: "Score forecast",
        detail: "Scores your probabilities against outcomes. Lower Brier score means better calibration.",
      },
    ],
  },
  {
    id: "panels",
    title: "Panels",
    summary: "What each area is for when you are deciding what to do next.",
    entries: [
      {
        label: "Mission briefing",
        detail: "Read goal, constraints, learning point, current score, and why the run is not yet cleared.",
      },
      {
        label: "v1.0 systems",
        detail: "Start Jane Street finals, launch challenge seeds, and inspect local leaderboard entries.",
      },
      {
        label: "Mission weather",
        detail: "Watch spot, IV, liquidity, event risk, skew, and the current market path.",
      },
      {
        label: "Greek forces",
        detail: "Your cockpit. Use it to see Delta, Gamma, Theta, Vega, live P&L, and remaining risk shield.",
      },
      {
        label: "Sponsor limits",
        detail: "Shows which risk limit is currently consuming the most budget.",
      },
      {
        label: "Payoff",
        detail: "Shows final expiry shape. Use it before running to see where the portfolio breaks.",
      },
      {
        label: "Scenario P&L",
        detail: "Shows seven-day stress under spot and IV shocks. Use it to catch near-term fragility.",
      },
      {
        label: "Vol surface cartographer",
        detail: "Shows skew, term, surface shock, and bucketed Vega concentration.",
      },
      {
        label: "Options workshop",
        detail: "Build and edit the risk machine.",
      },
      {
        label: "Market maker arena",
        detail: "Practice quoting customer flow and managing the inventory left after fills.",
      },
      {
        label: "Prediction Pit",
        detail: "Practice probability calibration with Brier score feedback.",
      },
      {
        label: "Debrief",
        detail: "Explains the run after actions happen. This is where you learn whether P&L came from edge or hidden risk.",
      },
    ],
  },
];
