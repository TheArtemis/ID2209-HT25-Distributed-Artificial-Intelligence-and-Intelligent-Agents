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

1.  **The Habitat Dome (Safe Zone):** Contains the *Greenhouse* (Food) and *Oxygen Generator* (Air).
2.  **The Wasteland (Danger Zone):** Agents wander here to find "Raw Materials" (Points/Cash). It has no oxygen (drains `oxygen_level` faster).
3.  **The Med-Bay:** Where Medics hang out.
4.  **The Landing Pad:** Where new agents spawn.

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

### 9. Implementation Roadmap

1.  **Step 1 (Map & Physics):** Create the map, the 3 zones, and the 5 species. Give them `energy` and movement.
2.  **Step 2 (Survival BDI):** Implement the simple BDI. Make them die if they don't eat/breathe.
3.  **Step 3 (Continuous Loop):** Implement the "Shuttle" reflex to respawn agents when they die.
4.  **Step 4 (Interaction & Parasites):** Code the "Trade" action. Make Parasites steal.
5.  **Step 5 (RL Logic):** Add the `trust_memory` map. Add the logic: `if trust < 0, do not trade`.
6.  **Step 6 (FIPA):** Add the Commander and the Dust Storm event.
7.  **Step 7 (UI):** Add the charts.
