# Project Design Document
## Title: Mars Colony - The Evolution of Trust
**Theme:** Social Evolution & Cultural Survival in a Hostile Environment

### 1. Project Overview
This simulation models a Mars Colony struggling to survive. The agents (Colonists) must manage their biological needs (Oxygen, Hunger, Health) while interacting with a complex social ecosystem. The simulation is **continuous**: as colonists die or retire, a "Supply Shuttle" brings new agents.

**The Goal:** To demonstrate how a population uses **Reinforcement Learning (RL)** to "evolve" a social immunity against "Parasite" agents who try to steal resources.

---

### 2. The Agents (5 Types)
*Requirement: 5 Guest Types, 3 Personal Traits.*

**Shared Traits:**
*   `oxygen_level` (0.0 - 100.0): Decreases constantly. Refilled at Oxygen Gen.
*   `energy_level` (0.0 - 100.0): Decreases with movement. Refilled at Greenhouse.
*   `health` (0.0 - 100.0): Decreases if Oxygen/Energy is 0. Refilled by Medics.
*   `trust_memory` (Map): The **RL component**. Stores values of how much they trust other agent types.

**The Species:**
1.  **The Engineer:** Can repair broken Oxygen Generators. Essential for colony survival.
2.  **The Medic:** The only agent that can restore `health` to others.
3.  **The Scavenger:** Ventures into the dangerous "Wasteland" to find raw materials (credits).
4.  **The Parasite (Antagonist):** Does not work. Approaches other agents to "trade" but steals their resources.
5.  **The Commander:** High authority. Stays in the base and broadcasts alerts using **FIPA**.

---

### 3. The Environment (Places)
*Requirement: 2+ Types of Places.*

1.  **The Habitat Dome (Safe Zone):** 
    *   Size: 250x250 units (large safe zone)
    *   Contains the *Greenhouse* (Food), *Oxygen Generator* (Air), and *Med-Bay* (Health)
    *   Facilities are spread out (80 units from center) for better visualization
    *   Located at center of 400x400 map
2.  **The Wasteland (Danger Zone):** 
    *   Scavengers venture here to mine at the Rock Mine for raw materials
    *   Oxygen drains 1.2x faster than in dome (0.012 rate vs 0.01)
    *   **Dust Storms:** Random events (1% probability per cycle) that last 15 cycles
    *   During storms: Oxygen drains 2x faster (0.024 rate), energy drains +1.0 per cycle
    *   Visual feedback: Wasteland turns orange during storms
    *   Commander sends FIPA "Return to Base" messages to agents in wasteland during storms
    *   Size: 100x100 units
3.  **The Med-Bay:** Where Medics hang out. Features:
    *   Queue system for injured agents
    *   Visual feedback: Changes color (orange) when patients are waiting
    *   Displays queue count and medic presence status
    *   Automatic cleanup of dead agents from queue
4.  **The Landing Pad:** Where new agents spawn.
5.  **The Rock Mine:** A place inside the wasteland where the 
    * Scavenger go to obtain new materials. Each trip to the wasteland
    * guarantees 5 credits for the scavenger

---

### 4. Challenge 1 Implementation: BDI Agents
*Requirement: Belief, Desire, Intention logic.*

We use the **Simple BDI** architecture to handle biological survival.

*   **Beliefs (Sensors):**
    *   `suffocating_belief` (Triggered when Oxygen < 20%).
    *   `starving_belief` (Triggered when Energy < 20%).
    *   `injured_belief` (Triggered when Health < 50%).
    *   `should_retire_belief` (Triggered when ETA >= 2000 cycles).
    *   `storm_warning_belief` (Triggered by FIPA message from Commander).
    *   `generator_broken_belief` (Engineer only, when oxygen generator is broken).
    *   `patients_waiting_belief` (Medic only, when med bay queue has patients).
    *   `mission_time_belief` (Scavenger only, 20% probability per cycle).
*   **Desires (Goals):** Ranked by rule strengths (see Section 12)
    *   `escape_storm` (200.0) - Highest priority
    *   `has_oxygen` (100.0) - High priority
    *   `has_energy` (25.0) - Medium priority
    *   `be_healthy` (12.0) - Medium-low priority
    *   `fix_generator` (9.0) - Engineer only
    *   `heal_patients` (7.0) - Medic only
    *   `retire` (6.0) - Low priority
    *   `mine_resources` (5.0) - Scavenger only
    *   `wander` (default) - Lowest priority
*   **Intentions (Plans):**
    *   `escape_storm` -> Move to habitat dome
    *   `be_healthy` -> Queue at med bay, wait for medic
    *   `retire` -> Move to landing pad and despawn
    *   `fix_generator` -> Move to oxygen generator and repair
    *   `heal_patients` -> Move to med bay and heal queued patients
    *   `mine_resources` -> Move to rock mine, mine for 5 seconds, return to dome
    *   `wander_around` -> Wander within dome when idle

---

### 5. Challenge 2 Implementation: Reinforcement Learning (RL)
*Requirement: Agents learn and improve behavior over time.*

**The Scenario:**
Resource exchange is necessary. Scavengers have materials, Medics have health, Engineers have repairs. They must "Trade."

**The Problem:**
The **Parasite** agent looks like a normal agent. It asks to trade, takes the item, and gives nothing back.

**The Q-Learning Implementation:**
1.  **State:** Agent ID (e.g., "id:agent_name") - Each agent tracks trust per individual, not per type
2.  **Action:** `TRADE` OR `IGNORE` (selected via epsilon-greedy: 20% random, 80% based on Q-values)
3.  **Reward:**
    *   Successful mutual trade: +20.0
    *   Scammed by Parasite: -20.0
    *   One-sided trade (non-parasite): -1.0
    *   Ignore action: 0.0
4.  **The Learning:**
    *   Q-value update: `Q(s,a) = Q(s,a) + alpha * (reward - Q(s,a))` where `alpha = 0.2`
    *   Trust calculation: `trust = (Q[TRADE] - Q[IGNORE]) / 4.0`, clamped to [-1.0, 1.0]
    *   Trust < 0 indicates predicted parasite (used for precision/recall metrics)
5.  **The Evolution:**
    *   Initially, agents interact randomly (epsilon = 20%). Parasites thrive and get rich.
    *   Over time, Q-values for parasite interactions decrease (negative rewards)
    *   Trust values drop toward -1.0 for parasites
    *   Agents learn to IGNORE agents with negative trust values
    *   Learning metrics track average trust to parasites vs non-parasites, plus precision/recall

---

### 6. Continuous Running Logic
*Requirement: Simulation continuously running + 50 Guests.*

To ensure the simulation never ends:
1.  **Death:** Currently disabled (`death` reflex set to `when: false`) to allow learning. When enabled, agents die if `health` <= 0.
2.  **Retirement:** Agents leave the simulation (Despawn) after 2000 cycles (configurable via `retirement_age`, simulating a completed tour of duty).
3.  **The Supply Shuttle:**
    *   A global `reflex` checks population counts per agent type.
    *   Operates in "deficit mode" when any agent type is below desired count.
    *   Desired counts: Engineers (16), Medics (10), Scavengers (8), Parasites (12), Commanders (4)
    *   Max colony size: 60 agents total
    *   New agents spawn at `habitat_dome.location` (not landing pad).
    *   **The Evolutionary Link:** Supply shuttle aggregates Q-tables and trust_memory from all survivors, calculating averages. Currently calculated but not yet applied to new agents (TODO: initialize new agents with averaged Q-tables).

---

### 7. Communication (FIPA)
*Requirement: Long distance messaging.*

*   **Sender:** The **Commander**.
*   **Trigger:** Random "Dust Storm" event in the Wasteland.
*   **Message:** `propose` message "Return to Base" sent to all agents in the Wasteland.
*   **Receiver:** Agents receive the message. BDI logic processes it -> Adds desire `escape_storm`.

---

### 8. Graphs and Monitors
*Requirement: 1 Global Value, 1 Graph, 1 Conclusion.*

**Chart 1: The Evolution of Wisdom**
*   **X-Axis:** Time.
*   **Y-Axis:** Average "Trust Score" towards Parasites.
*   **Expectation:** Starts high (0.5), drops rapidly to 0 as scams happen.

**Chart 2: Colony Survival Rate**
*   **X-Axis:** Time.
*   **Y-Axis:** Number of "Unnatural Deaths" (Starvation/Scams).
*   **Expectation:** High at the start, decreases as RL helps them manage resources and avoid thieves.

**Interesting Conclusion (Hypothesis):**
"We demonstrated that a population utilizing Reinforcement Learning can develop a 'Social Immune System,' effectively identifying and isolating malicious actors (Parasites) without centralized police control, simply through individual negative experiences."

---

### 9. Implementation Status

#### ✅ Completed Features

**Step 1 (Map & Physics):** ✅ COMPLETE
- Created 400x400 map with 3 zones (Habitat Dome, Wasteland, Landing Pad)
- Implemented all 5 species (Engineer, Medic, Scavenger, Parasite, Commander)
- Energy and oxygen systems with movement-based energy drain
- Health system that decreases when oxygen/energy reaches 0

**Step 2 (Survival BDI):** ✅ COMPLETE
- Full BDI architecture implemented:
  - **Beliefs:** `suffocating` (Oxygen < 20%), `starving` (Energy < 20%), `injured` (Health < 50%), `should_retire` (ETA >= 2000), `storm_warning` (from FIPA messages)
  - **Belief Management:** Dynamic belief system that adds/removes beliefs based on current state
  - **Desires:** Fully implemented with priority system via rule strengths:
    - `escape_storm` (strength: 200.0) - Highest priority
    - `has_oxygen` (strength: 100.0) - High priority
    - `has_energy` (strength: 25.0) - Medium priority
    - `be_healthy` (strength: 12.0) - Medium-low priority
    - `retire` (strength: 6.0) - Low priority
    - `fix_generator` (Engineer, strength: 9.0) - Medium priority
    - `heal_patients` (Medic, strength: 7.0) - Medium priority
    - `mine_resources` (Scavenger, strength: 5.0) - Low-medium priority
  - **Intentions:** State-based behavior (idle, going_to_med_bay, waiting_at_med_bay, retiring, escaping_storm, going_to_oxygen_generator, healing, going_to_mine, mining, returning_to_dome)
- Agents automatically seek resources when beliefs are triggered
- Priority system: Rule strengths determine desire priority, with storm escape being highest
- Death system: Currently disabled to allow learning (death reflex set to `when: false`)
- Energy system: Decreases with movement (0.01 rate) or at rest (0.005 rate), extra drain during dust storms
- Oxygen system: Decreases in dome (0.01 rate), faster in wasteland (1.2x), 2x faster during dust storms

**Step 3 (Continuous Loop):** ✅ COMPLETE
- Supply Shuttle system implemented with configurable desired population counts per agent type:
  - Desired counts: Engineers (16), Medics (10), Scavengers (8), Parasites (12), Commanders (4)
  - Max colony size: 60 agents
  - Spawns agents at habitat dome location when population is below desired levels
- Retirement system: Agents retire after 2000 cycles (configurable via `retirement_age`)
- ETA (Estimated Time of Arrival) tracking for retirement (increments by 1.0 per cycle)
- Automatic respawning maintains population levels based on deficit mode
- Death tracking and counter updates for all agent types
- Configurable flags: `enable_supply_shuttle` and `enable_retirement`
- **Evolutionary Link:** Supply shuttle aggregates Q-tables and trust_memory from all survivors, calculating averages (though not yet applied to new agents)

**Med Bay System:** ✅ COMPLETE (Enhanced Feature)
- **Queue System:** Injured agents automatically queue at med bay
- **Medic AI:** Medics check queue and go to med bay to heal patients
- **Priority System:** Injured agents have highest priority, overriding other needs
- **Medic Immunity:** Medics at med bay are immune to oxygen drain and hunger
- **Visual Feedback:** Med bay changes color (orange) when queue has patients
- **Queue Display:** Shows queue count and medic presence status
- **Dead Agent Cleanup:** Automatic removal of dead agents from queue
- **Physical Queueing:** Agents physically go to and stay at med bay when queued

**Oxygen Generator System:** ✅ COMPLETE
- Random breaking mechanism (5% probability per cycle, configurable via `oxygen_generator_break_probability`)
- Engineer agents detect broken generator and repair it
- Belief system: Engineers get `generator_broken_belief` when generator is broken
- Visual feedback: Generator turns red when broken, displays "O2 Gen (BROKEN)" text
- Engineers prioritize repair over other tasks when generator is broken (strength: 9.0)
- Engineers can also repair generator during trades (if broken)

**Agent Movement & Behavior:** ✅ COMPLETE
- Wandering behavior when agents are idle and healthy
- Movement to dome when outside safe zone
- State-based movement prevents agents from wandering when they have urgent needs
- Continuous movement to med bay when injured

**State Management:** ✅ COMPLETE
- Comprehensive state system: `idle`, `going_to_med_bay`, `waiting_at_med_bay`, `retiring`, `escaping_storm`, `going_to_oxygen_generator`, `healing`, `going_to_mine`, `mining`, `returning_to_dome`
- State transitions prevent agents from wandering when they have urgent needs
- Trade cooldown system: Agents have 10-cycle cooldown between trades to prevent spam

**Step 4 (Interaction & Parasites):** ✅ COMPLETE
- Scavenger raw material tracking: `raw_amount` variable tracks collected materials
- Scavengers mine at RockMine location, gaining 5 raw materials per successful mining trip (5 seconds)
- Trade action fully implemented: `attempt_trade()` action handles all trade interactions
- Parasite stealing behavior fully implemented:
  - Parasites steal raw materials if partner has them
  - Otherwise, parasites drain 10 energy from partner and gain 10 energy themselves
  - Parasites use `presented_role` to disguise themselves (randomly presents as Engineer, Medic, Scavenger, or Commander)
- Trading mechanics:
  - Scavengers: Give raw materials (+20 energy to partner) or small assistance (+10 energy at -5 cost)
  - Medics: Heal partners (+30 health)
  - Engineers: Provide oxygen (+10) or repair broken generator
  - Commanders: Provide both oxygen (+10) and energy (+10)
  - Parasites: Always steal/drain, never give back
- Reward system: +20 for mutual trade, -20 for parasite scam, -1 for one-sided trade, 0 for no trade

**Step 5 (RL Logic):** ✅ COMPLETE
- `trust_memory` map fully implemented: Stores trust values per agent ID (key: "id:agent_name")
- Q-Learning logic fully implemented:
  - Q-table: `map<string, list<float>>` where each state (agent ID) has [Q(TRADE), Q(IGNORE)]
  - Learning parameters: `alpha = 0.2`, `gamma = 0.0`, `epsilon = 0.20`
  - Epsilon-greedy action selection: 20% random exploration, 80% exploitation
  - Q-value update: `Q(s,a) = Q(s,a) + alpha * (reward - Q(s,a))`
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
