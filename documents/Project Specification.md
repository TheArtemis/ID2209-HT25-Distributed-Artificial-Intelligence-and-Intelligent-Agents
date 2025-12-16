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
    *   Agents wander here to find "Raw Materials" (Points/Cash)
    *   It has no oxygen (drains `oxygen_level` 1.2x faster than in dome)
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
    *   `has_belief("suffocating")` (Triggered when Oxygen < 20%).
    *   `has_belief("starving")` (Triggered when Energy < 20%).
    *   `has_belief("injured")` (Triggered when Health < 50%).
*   **Desires (Goals):**
    *   `maintain_life` (Highest Priority).
    *   `perform_job` (Lower Priority - e.g., Scavenger goes to Wasteland).
*   **Intentions (Plans):**
    *   If `suffocating` -> `intention: goto_target(oxygen_generator)`.
    *   If `injured` -> `intention: find_medic`.

---

### 5. Challenge 2 Implementation: Reinforcement Learning (RL)
*Requirement: Agents learn and improve behavior over time.*

**The Scenario:**
Resource exchange is necessary. Scavengers have materials, Medics have health, Engineers have repairs. They must "Trade."

**The Problem:**
The **Parasite** agent looks like a normal agent. It asks to trade, takes the item, and gives nothing back.

**The Q-Learning Implementation:**
1.  **State:** Meeting an agent of type X (e.g., Meeting a Parasite).
2.  **Action:** `Trade` OR `Ignore`.
3.  **Reward:**
    *   Successful Trade: +10 Happiness.
    *   Scammed by Parasite: -20 Happiness.
4.  **The Evolution:**
    *   Initially, agents interact randomly. Parasites thrive and get rich.
    *   Over time, the `trust_memory` for "Parasite" drops to -1.
    *   Agents stop interacting with Parasites.
    *   Parasites effectively "starve" (socially) or are forced to change behavior (if you code that complexity).

---

### 6. Continuous Running Logic
*Requirement: Simulation continuously running + 50 Guests.*

To ensure the simulation never ends:
1.  **Death:** Agents die if `health` <= 0.
2.  **Retirement:** Agents leave the simulation (Despawn) after 2000 cycles (simulating a completed tour of duty).
3.  **The Supply Shuttle:**
    *   A global `reflex` checks the population count.
    *   `if length(agents) < 20`: The "Supply Shuttle" arrives.
    *   It creates 30 new agents at the `Landing Pad`.
    *   **The Evolutionary Link:** New agents inherit the *average Q-Table* of the current survivors. This represents "Training" received from the previous generation.

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
  - **Beliefs:** `suffocating` (Oxygen < 20%), `starving` (Energy < 20%), `injured` (Health < 50%)
  - **Belief Management:** Dynamic belief system that adds/removes beliefs based on current state
  - **Desires:** Priority system TODO
  - **Intentions:** State-based behavior (going_to_oxygen, going_to_greenhouse, going_to_med_bay, waiting_at_med_bay, healing, refilling_oxygen, refilling_energy, retiring, idle)
- Agents automatically seek resources when beliefs are triggered
- Priority system: Injured agents prioritize med bay over other needs
- Death system when health reaches 0 with death reason tracking
- Energy system: Decreases with movement (higher rate) or at rest (lower rate)

**Step 3 (Continuous Loop):** ✅ COMPLETE
- Supply Shuttle system implemented with configurable desired population counts per agent type
- Retirement system: Agents retire after 1000 cycles (configurable via `retirement_age`)
- ETA (Estimated Time of Arrival) tracking for retirement
- Automatic respawning maintains population levels
- Death tracking and counter updates for all agent types
- Configurable flags: `enable_supply_shuttle` and `enable_retirement`

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
- Random breaking mechanism (10% probability per cycle, configurable)
- Engineer agents detect broken generator and repair it
- Belief system: Engineers get `oxygen_generator_broken` belief
- Visual feedback: Generator turns red when broken
- Engineers prioritize repair over other tasks when generator is broken

**Agent Movement & Behavior:** ✅ COMPLETE
- Wandering behavior when agents are idle and healthy
- Movement to dome when outside safe zone
- State-based movement prevents agents from wandering when they have urgent needs
- Continuous movement to med bay when injured

**State Management:** ✅ COMPLETE
- Comprehensive state system: `idle`, `going_to_oxygen`, `going_to_greenhouse`, `going_to_med_bay`, `waiting_at_med_bay`, `healing`, `refilling_oxygen`, `refilling_energy`, `retiring`
- State transitions prevent agents from wandering when they have urgent needs

#### 🚧 In Progress / TODO

**Step 4 (Interaction & Parasites):** ⏳ TODO
- Scavenger must have a measure of the credits it contains
- Trade action not yet implemented
- Parasite stealing behavior not yet implemented

**Step 5 (RL Logic):** ⏳ TODO
- `trust_memory` map structure exists but marked as TODO
- Q-Learning logic for trust evolution not yet implemented

**Step 6 (FIPA):** ⏳ TODO
- Commander FIPA skills exist but communication events not yet implemented
- Dust Storm event not yet implemented

**Step 7 (UI):** ⏳ TODO
- Charts for trust evolution and survival rate not yet implemented
- Agent beliefs inspector exists in experiment

**Step 8 :** TODO
- Rank the desires



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

1.  **Step 4 (Interaction & Parasites):** Code the "Trade" action. Make Parasites steal.
2.  **Step 5 (RL Logic):** Add the `trust_memory` map. Add the logic: `if trust < 0, do not trade`.
3.  **Step 6 (FIPA):** Add the Commander and the Dust Storm event.
4.  **Step 7 (UI):** Add the charts.

### 12. Very important
1. We need to **rank the beliefs** so that there is a definite order of priorities
2. The beliefs to be ranked (as far as now) are:
- oxygen
- healthy
- starving
- retiring
- fix generator (for the engineer)
- healing patients (for the medic)
- mine (for the scavenger)
3. This are very important as changing the value highly influences the behaviour of the agents 
