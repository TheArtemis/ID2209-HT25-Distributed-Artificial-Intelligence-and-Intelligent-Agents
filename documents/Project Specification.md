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

## 12. Known Gaps / Future Work (not implemented)
- Supply shuttle computes averaged Q/trust across survivors, but does not yet seed new agents with those averages.
- `patience` is defined for agents but not currently used in the learning or decision logic.
- `get_oxygen` and `get_energy` BDI plans are intentionally stubbed/disabled to prioritize learning interactions.
- Death handling exists but is currently disabled (the `death` reflex is set to `when: false`).
  - Dome: `oxygen_decrease_rate` (0.01)
  - Outside dome: multiplied by `oxygen_decrease_factor_in_wasteland` (1.2)
  - During dust storms in the wasteland: oxygen decrease is doubled again.
- Energy decreases every tick:
  - Moving states: `energy_decrease_rate_when_moving` (0.01)
  - Otherwise: `energy_decrease_rate` (0.005)
  - During dust storms in the wasteland: additional -1.0 per tick.
- Health decreases when oxygen or energy reaches 0.

**Note (important implementation detail):** `get_oxygen` and `get_energy` BDI plans are currently disabled. Oxygen/energy can still be affected by trade outcomes and by being near the Med-Bay (see next).

### Med-Bay immunity zone
When an agent is within `facility_proximity` distance of the Med-Bay, its oxygen and energy are restored to max to prevent dying while waiting. This applies to all roles.

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
- A “death reflex” exists but is currently disabled (set to `when: false`).

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

## 12. Known Gaps / Future Work (not implemented)
- Supply shuttle computes averaged Q/trust across survivors, but does not yet seed new agents with those averages.
- `patience` is defined but not currently used in learning.
- `get_oxygen` and `get_energy` plans are stubbed/disabled.
  - Trust calculation: `trust = (Q[TRADE] - Q[IGNORE]) / 4.0`, clamped to [-1.0, 1.0]
- Trade decision: Agents choose TRADE or IGNORE based on Q-values (or random if epsilon)
- Learning metrics: Global tracking of `avg_trust_to_parasites`, `avg_trust_to_non_parasites`, `precision`, `recall`
- Detection metrics: Precision (TP/(TP+FP)) and Recall (TP/(TP+FN)) for parasite identification (trust < 0 = predicted parasite)

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

**Step 7 (UI):** ✅ MOSTLY COMPLETE
- Charts for trust evolution implemented:
  - "Avg Trust & Detection" chart with 4 series:
    - Avg trust (parasites)
    - Avg trust (non-parasites)
    - Precision
    - Recall
- Agent state inspector: Table showing agent attributes (name, role, presented_role, location, happiness, oxygen_level, energy_level, health_level, state, raw_amount, trust_memory)
- Main display: All species and places rendered with appropriate colors
- ⏳ TODO: Additional charts for survival rate or death tracking (currently death is disabled)

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
2.  **Re-enable death system:** Death reflex is currently disabled (`when: false`) to allow learning. Consider re-enabling with proper death handling.
3.  **Re-enable oxygen/energy refill plans:** `get_oxygen` and `get_energy` plans are currently disabled (marked "Temporarily disabled to prioritize learning"). Consider re-enabling if needed for full survival simulation.
4.  **Additional UI charts:** Could add charts for:
    - Total trades over time
    - Colony population over time
    - Happiness levels
    - Death/retirement rates (when death is re-enabled)

### 12. Desire Priority System ✅ COMPLETE

**All desires are ranked via rule strengths (higher = higher priority):**

1. **`escape_storm` (200.0)** - Highest priority
   - Triggered by: `storm_warning_belief` (from FIPA message)
   - Affects: All agents in wasteland during dust storm

2. **`has_oxygen` (100.0)** - High priority
   - Triggered by: `suffocating_belief` (oxygen < 20%)
   - Affects: All agents
   - Note: Plan is currently disabled to prioritize learning

3. **`has_energy` (25.0)** - Medium priority
   - Triggered by: `starving_belief` (energy < 20%)
   - Affects: All agents
   - Note: Plan is currently disabled to prioritize learning

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

8. **`mine_resources` (5.0)** - Low-medium priority (Scavenger only)
   - Triggered by: `mission_time_belief` (20% probability per cycle)
   - Affects: Scavengers for resource collection missions

9. **`wander` (default/lowest)** - Lowest priority
   - Default idle behavior
   - Affects: All agents when no other desires are active

**Priority order is critical:** Changing these values significantly influences agent behavior. Current values ensure survival needs (storms, oxygen) are handled before job-specific tasks. 
