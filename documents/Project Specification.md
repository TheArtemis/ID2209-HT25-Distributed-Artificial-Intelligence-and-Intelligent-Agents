# Project Specification
## Title: Mars Colony — Trust, Trade, and Deception

This document describes the **current implementation** in `src/project/models/MarsColony.gaml` (as-built specification).

---

## 1. Overview
The simulation models a Mars colony where multiple agent roles coexist, trade resources, and learn whom to trust over time. A hidden adversarial role (“Parasite”) attempts to exploit trades. Agents are implemented as **Simple BDI** agents with **FIPA** messaging, and they apply a lightweight **Q-learning** mechanism to decide whether to trade or ignore specific partners.

The simulation is designed to run continuously by keeping a target population size (via a supply shuttle) and optionally retiring agents.

---

## 2. Requirements Coverage (Minimum Pass)

**At least 5 agent types:** ✅ Engineer, Medic, Scavenger, Parasite, Commander.

**Different interaction rules per type:** ✅ Implemented inside the trade mechanism (see “Interactions & Trade”).

**≥ 3 personal traits that affect interactions:** ✅
- `curiosity` influences whether agents seek trades and whether they explore (`epsilon`) in action selection.
- `sociability` is the per-agent learning rate (`alpha`) used for Q updates.
- `raw_amount` (Scavenger inventory) affects whether a Scavenger can provide resources when trading (and what Parasites can steal).

**≥ 2 meeting places (roaming excluded):** ✅ Trades only occur inside **Common Area** and **Recreation Area**.

**≥ 50 agents:** ✅ Default desired population totals 50 (16+10+8+12+4), capped at 60.

**Continuously running:** ✅ Supply shuttle maintains desired counts; optional retirement removes agents.

**FIPA long-distance messaging:** ✅ Commander sends FIPA propose messages during dust storms.

**Global value chart + informative graph:** ✅ A chart tracks trust and detection metrics (Avg trust parasites/non-parasites, precision, recall).

---

## 3. Map and Places

### 3.1 World
- Map size: 400×400.

### 3.2 Habitat Dome (safe interior)
- A large rectangle zone centered at (200, 200) with internal points of interest:
  - **Greenhouse** (visual landmark)
  - **Oxygen Generator** (can break; Engineers repair)
  - **Med-Bay** (queue system + healing)
  - **Common Area** (meeting/trading zone; circle radius 50)
  - **Recreation Area** (meeting/trading zone; circle radius 50)

### 3.3 Wasteland (hazard zone)
- Rectangle zone located at (50, 50).
- Can enter a **dust storm**:
  - Storm starts with probability 1% per cycle.
  - Storm lasts 15 cycles.
  - During storms, agents in the wasteland suffer extra biological drain (see “Biological Dynamics”).

### 3.4 Rock Mine
- A point of interest at (50, 50).
- Scavengers travel here to mine and return with `raw_amount += 5` after 5 seconds of mining.

In addition, the implementation includes a second monitoring chart for behavioral signals aggregated across the population:
- **BehavioralMetrics** chart “Sociability, Happiness & Generosity” with series:
  - `avg_sociability` (average learning rate parameter across agents)
  - `avg_happiness` (average accumulated reward from social interactions)
  - `avg_generosity` (average giving/receiving balance tracked during trades)

### 3.5 Landing Pad

## 4. Biological Dynamics

### 4.1 Oxygen System
- **Dome:** `oxygen_decrease_rate` (0.1 per cycle)
- **Outside dome:** Multiplied by `oxygen_decrease_factor_in_wasteland` (1.2) = 0.12 per cycle
- **During dust storms in wasteland:** Oxygen decrease is doubled again (0.24 per cycle)
- **Replenishment:** 
  - Oxygen Generator provides `replenish_rate` (0.3 per cycle) when agent is within `facility_proximity` (5.0 units)
  - Only works when generator is not broken
  - Agents can use `get_oxygen` BDI plan to navigate to generator and refill

### 4.2 Energy System
- **Moving states:** `energy_decrease_rate_when_moving` (0.1 per cycle)
- **Otherwise:** `energy_decrease_rate` (0.05 per cycle)
- **During dust storms in wasteland:** Additional -1.0 per cycle
- **Replenishment:**
  - Greenhouse provides `replenish_rate` (0.5 per cycle) when agent is within `facility_proximity`
  - Agents can use `get_energy` BDI plan to navigate to greenhouse and refill

### 4.3 Health System
- Health decreases when oxygen or energy reaches 0: `health_decrease_rate` (1.0 per cycle)
- Health also decreases gradually when oxygen or energy is below threshold: `health_decrease_rate * 0.5` (0.5 per cycle)
- Health is restored to max at Med-Bay by Medics

### 4.4 Death System
- **Death is ENABLED:** Agents die when `health_level <= 0`
- Death tracking: `total_deaths` and `total_age_at_death` are tracked for survival metrics
- When agents die, their lifespan (eta) is recorded for calculating average dead agent lifespan

### 4.5 Facility Replenishment
- **Greenhouse:** Automatically replenishes energy (0.5 per cycle) for agents within proximity
- **Oxygen Generator:** Automatically replenishes oxygen (0.3 per cycle) for agents within proximity when not broken
- **Med-Bay immunity:** Currently DISABLED (`med_bay_immunity` reflex set to `when: false`)
  - Previously, agents at med-bay were immune to oxygen/energy drain while waiting
  - Now disabled to allow full biological dynamics during treatment

### 4.6 Med-Bay System
- **Queue System:** Injured agents (health < 50%) automatically queue at med bay
- **Medic AI:** Medics check queue and navigate to med bay to heal patients
- **Healing:** Medics fully restore health, oxygen, and energy of queued patients
- **Visual Feedback:** Med bay changes color (orange) when queue has patients
- **Queue Display:** Shows queue count and medic presence status
- **Dead Agent Cleanup:** Automatic removal of dead agents from queue

---

## 10. Continuous Running / Population Control

### 10.1 Supply shuttle
- Enabled by `enable_supply_shuttle`.
- Maintains a desired population mix:
  - Engineers: 16
  - Medics: 10
  - Scavengers: 8
  - Parasites: 12
  - Commanders: 4
- Max colony size: 60.
- New agents spawn at `habitat_dome.location`.

### 10.2 Retirement
- Enabled by `enable_retirement`.
- ETA increases each cycle; when it reaches `retirement_age` (default 2000), agents plan to retire and despawn at the Landing Pad.

### 10.3 Death
- **Death is ENABLED:** Agents die when `health_level <= 0`
- Death tracking: Lifespan metrics are recorded (`total_deaths`, `total_age_at_death`)
- Average dead agent lifespan is calculated and displayed in SurvivalMetrics chart

---

## 11. Outputs (UI)
The GUI experiment provides:
- A main display drawing all places and agent types.
- An “Agent State” inspector table with:
  `name`, `role`, `presented_role`, `location`, `happiness`, `oxygen_level`, `energy_level`, `health_level`, `state`, `raw_amount`, `trust_memory`.
- A chart “Avg Trust & Detection” with series:
  - Avg trust (parasites)
  - Avg trust (non-parasites)
  - Precision
  - Recall

---

## 5. Q-Learning and Trust System

### 5.1 Q-Learning Implementation
- **State:** Agent ID (e.g., "id:agent_name") - Each agent tracks trust per individual partner
- **Actions:** `TRADE` or `IGNORE`
- **Learning Parameters:**
  - `sociability` (learning rate `alpha`): Default 0.35 (increased from 0.2 for faster convergence)
  - `curiosity` (exploration rate `epsilon`): Default 0.20, adaptively adjusted based on trust levels
  - `patience` (discount factor `gamma`): Defined but not currently used (set to 0.0)
- **Q-value Update:** `Q(s,a) = Q(s,a) + sociability * (reward - Q(s,a))`
- **Trust Calculation:** `trust = (Q[TRADE] - Q[IGNORE]) / 100.0`, clamped to [-1.0, 1.0]
  - Normalized by max expected difference (100.0) to handle larger reward range
- **Action Selection:** Epsilon-greedy - `curiosity`% random exploration, otherwise choose action with higher Q-value

### 5.2 Reward System
- **Mutual cooperation:** +100.0 (both agents give resources)
- **Parasite scam (victim):** -80.0 (agent traded with parasite and was exploited)
- **Parasite scam (parasite):** -80.0 (parasite performed harmful action)
- **Altruistic giving:** +20.0 (non-parasite gave but partner didn't reciprocate)
- **Ignoring:** +2.0 (small positive reward for avoiding potentially bad interactions)
- **Neutral:** 0.0 (no interaction occurred)

### 5.3 Adaptive Learning
- **Curiosity Adaptation:** Agents adjust `curiosity` every 100 cycles based on average trust:
  - Low trust (< -0.2): Increase curiosity to 0.50 (more exploration needed)
  - Medium-low trust (< 0.0): Increase to 0.45
  - Medium trust (< 0.3): Keep at base (0.20)
  - Medium-high trust (< 0.6): Decrease to 0.15 (less exploration needed)
  - High trust (≥ 0.6): Decrease to 0.10 (exploit learned knowledge)
- **Sociability Recovery:** If `sociability` drops below 0.15, it gradually recovers (+0.01 per 100 cycles) to prevent agents from getting stuck in low-learning states

### 5.4 Trading Motivation
- Agents assess trading motivation when:
  - Trade cooldown is 0
  - Inside habitat dome
  - No storm warning
  - Don't already have `want_to_trade_belief`
- Probability: `0.5 + curiosity` (encourages frequent trading)
- When motivated, agents navigate to nearest trading area (Common Area or Recreation Area)

### 5.5 Learning Metrics
- **Global tracking:**
  - `avg_trust_to_parasites`: Average trust value for parasite interactions
  - `avg_trust_to_non_parasites`: Average trust value for non-parasite interactions
  - `precision`: TP / (TP + FP) - Accuracy of parasite detection
  - `recall`: TP / (TP + FN) - Completeness of parasite detection
  - Trust < 0.0 is considered a "predicted parasite"

## 6. Trading and Interactions

### 6.1 Trading Locations
- Trades only occur in **Common Area** or **Recreation Area** (within `facility_proximity` = 5.0 units)
- Agents must navigate to trading areas when they have `want_to_trade_belief`
- Trade cooldown: 5 cycles (reduced from 10) between trades

### 6.2 Trading Mechanics by Role
- **Scavenger:**
  - Gives: Raw materials (+20 energy to partner) if `raw_amount > 0`
  - Fallback: Small assistance (+10 energy at -5 personal cost) if no raw materials
- **Engineer:**
  - Gives: Oxygen (+10) to partner
  - Note: No longer repairs generator during trades (only via BDI plan)
- **Medic:**
  - Does not heal during trades (only at Med-Bay)
- **Commander:**
  - Gives: Both oxygen (+10) and energy (+10) to partner
- **Parasite:**
  - Steals: Raw materials if partner has them, otherwise drains 10 energy
  - Never gives back resources
  - Uses `presented_role` to disguise as other roles

### 6.3 Fallback Giving
- All non-parasite agents can offer a small energy boost (+10 to partner, -5 personal cost) if:
  - They haven't given specialized resources
  - Their energy level is above 20.0
- This ensures agents can always participate in trades even without role-specific resources

## 7. BDI Architecture

### 7.1 Beliefs
- `suffocating_belief`: Oxygen < 20% threshold
- `starving_belief`: Energy < 20% threshold
- `injured_belief`: Health < 50% threshold
- `should_retire_belief`: ETA >= 2000 cycles
- `storm_warning_belief`: Received FIPA "Return to Base" message
- `want_to_trade_belief`: Agent wants to seek trading opportunities
- `generator_broken_belief`: (Engineer only) Oxygen generator is broken
- `patients_waiting_belief`: (Medic only) Med bay queue has patients
- `mission_time_belief`: (Scavenger only) 20% probability per cycle

### 7.2 Desires and Plans
- **`escape_storm` (200.0):** Navigate to habitat dome when storm warning received
- **`has_oxygen` (100.0):** Navigate to oxygen generator, refill to 80% max
- **`has_energy` (25.0):** Navigate to greenhouse, refill to 80% max
- **`be_healthy` (12.0):** Queue at med bay, wait for medic
- **`seek_trading_area` (8.0):** Navigate to nearest trading area (Common or Recreation)
- **`fix_generator` (9.0):** (Engineer) Repair broken oxygen generator
- **`heal_patients` (7.0):** (Medic) Go to med bay and heal queued patients
- **`retire` (6.0):** Navigate to landing pad and despawn
- **`mine_resources` (5.0):** (Scavenger) Go to rock mine, mine for 5 seconds, return
- **`wander` (default):** Idle behavior within dome

**Note:** `get_oxygen` and `get_energy` plans are now **ENABLED** and functional. Agents will navigate to facilities and refill when beliefs are triggered.

## 12. Known Gaps / Future Work (not implemented)
- Supply shuttle computes averaged Q/trust across survivors, but does not yet seed new agents with those averages.
- `patience` (discount factor) is defined but not currently used in learning (gamma = 0.0).

**Step 6 (FIPA):** ✅ COMPLETE
- Commander FIPA communication fully implemented:
  - `check_storm` reflex monitors wasteland for dust storms
  - When storm detected, Commander sends FIPA `propose` message "Return to Base" to all agents in wasteland
  - Uses `start_conversation` with protocol "fipa-propose"
- Dust Storm event fully implemented:
  - Wasteland has `dust_storm` boolean and `storm_timer`
  - Random storm generation: 1% probability per cycle
  - Storms last 15 cycles
  - Visual feedback: Wasteland turns orange during storms
  - Effects: 2x oxygen drain, +1.0 energy drain per cycle
- Message reception: All agents have `receive_message` reflex that processes FIPA messages
- BDI integration: Receiving "Return to Base" message adds `storm_warning_belief`, triggering `escape_storm_desire` (highest priority: 200.0)

**Step 7 (UI):** ✅ COMPLETE
- Charts for trust evolution implemented:
  - "Avg Trust & Detection" chart with 4 series:
    - Avg trust (parasites)
    - Avg trust (non-parasites)
    - Precision
    - Recall
- Behavioral metrics chart:
  - "Sociability, Happiness & Generosity" with 3 series:
    - Avg Sociability (scaled to 0-100 range)
    - Avg Happiness
    - Avg Generosity
- Survival metrics chart:
  - "Agent Lifespan & Survival" with 2 series:
    - Avg Living Agent Age (current ETA of living agents)
    - Avg Dead Agent Lifespan (average lifespan of deceased agents)
- Agent state inspector: Table showing agent attributes (name, role, presented_role, location, happiness, oxygen_level, energy_level, health_level, state, raw_amount, trust_memory)
- Main display: All species and places rendered with appropriate colors

**Step 8 (Desire Ranking):** ✅ COMPLETE
- All desires are ranked via rule strengths:
  1. `escape_storm` (200.0) - Highest priority (dust storm warning)
  2. `has_oxygen` (100.0) - High priority (suffocating)
  3. `has_energy` (25.0) - Medium priority (starving)
  4. `be_healthy` (12.0) - Medium-low priority (injured)
  5. `fix_generator` (9.0) - Medium priority (Engineer only)
  6. `heal_patients` (7.0) - Medium priority (Medic only)
  7. `retire` (6.0) - Low priority (retirement age reached)
  8. `mine_resources` (5.0) - Low-medium priority (Scavenger only)
  9. `wander` (default) - Lowest priority (idle behavior)
- Priority system ensures agents handle urgent needs (storms, suffocation) before lower-priority tasks



---

### 10. Potential System Improvements

**Energy and Oxygen Mechanics - Alternative Designs:**

The current implementation has energy and oxygen decreasing continuously, but alternative designs could make the simulation more interesting and realistic:

**Energy System Alternatives:**
*   **Action-Based Energy Consumption:** Instead of energy decreasing with movement, energy could be consumed when performing specific actions:
    *   Engineers consume energy when repairing oxygen generators
    *   Medics consume energy when healing patients
    *   Scavengers consume energy when collecting materials in the wasteland
    *   This would make energy management more strategic and action-oriented
*   **Work-Based Energy:** Energy could only decrease when agents are "working" (performing their role-specific tasks), making idle time truly restful
*   **Variable Consumption Rates:** Different actions could have different energy costs, making some activities more "expensive" than others

**Oxygen System Alternatives:**
*   **Wasteland-Only Oxygen Consumption:** Oxygen could only decrease when agents are in the wasteland, making the habitat dome a true "safe zone" where oxygen is naturally available
    *   This would simplify dome life and make wasteland exploration more strategic
    *   Agents would need to plan expeditions carefully
*   **Oxygen Generator Dependency:** Oxygen could only be consumed when the oxygen generator is broken, making generator maintenance critical for survival
*   **Zone-Based Oxygen:** Different zones could have different oxygen levels, with the dome having infinite oxygen and wasteland having limited/no oxygen

**Benefits of These Changes:**
*   More strategic resource management
*   Clearer distinction between safe zones and danger zones
*   More meaningful choices about when to perform actions
*   Better simulation of a controlled environment (dome) vs. hostile environment (wasteland)

**Considerations:**
*   Would require rebalancing of consumption rates
*   Might need to adjust belief thresholds
*   Could change the urgency of certain needs (e.g., oxygen becomes less urgent in dome)

---

### 11. Implementation Roadmap (Remaining)

**All major features are complete!** Remaining items:

1.  **Apply Q-table inheritance:** Currently, supply shuttle calculates average Q-tables and trust from survivors, but new agents don't inherit these values. Should initialize new agents with averaged Q-tables.
2.  **Use patience parameter:** `patience` (discount factor gamma) is defined but set to 0.0. Could implement temporal discounting for future rewards.
3.  **Additional UI charts (optional):** Could add charts for:
    - Total trades over time
    - Colony population over time
    - Death/retirement rates over time

### 12. Desire Priority System ✅ COMPLETE

**All desires are ranked via rule strengths (higher = higher priority):**

1. **`escape_storm` (200.0)** - Highest priority
   - Triggered by: `storm_warning_belief` (from FIPA message)
   - Affects: All agents in wasteland during dust storm

2. **`has_oxygen` (100.0)** - High priority
   - Triggered by: `suffocating_belief` (oxygen < 20%)
   - Affects: All agents
   - Plan: Navigate to oxygen generator, refill to 80% max oxygen

3. **`has_energy` (25.0)** - Medium priority
   - Triggered by: `starving_belief` (energy < 20%)
   - Affects: All agents
   - Plan: Navigate to greenhouse, refill to 80% max energy

4. **`be_healthy` (12.0)** - Medium-low priority
   - Triggered by: `injured_belief` (health < 50%)
   - Affects: All agents
   - Active: Med bay queue system fully functional

5. **`fix_generator` (9.0)** - Medium priority (Engineer only)
   - Triggered by: `generator_broken_belief`
   - Affects: Engineers when oxygen generator is broken

6. **`heal_patients` (7.0)** - Medium priority (Medic only)
   - Triggered by: `patients_waiting_belief`
   - Affects: Medics when med bay queue has patients

7. **`retire` (6.0)** - Low priority
   - Triggered by: `should_retire_belief` (ETA >= 2000 cycles)
   - Affects: All agents when retirement age reached

8. **`seek_trading_area` (8.0)** - Medium-low priority
   - Triggered by: `want_to_trade_belief` (assessed with probability 0.5 + curiosity)
   - Affects: All agents when they want to trade
   - Plan: Navigate to nearest trading area (Common Area or Recreation Area)

9. **`mine_resources` (5.0)** - Low-medium priority (Scavenger only)
   - Triggered by: `mission_time_belief` (20% probability per cycle)
   - Affects: Scavengers for resource collection missions

10. **`wander` (default/lowest)** - Lowest priority
   - Default idle behavior
   - Affects: All agents when no other desires are active

**Priority order is critical:** Changing these values significantly influences agent behavior. Current values ensure survival needs (storms, oxygen) are handled before job-specific tasks. 
