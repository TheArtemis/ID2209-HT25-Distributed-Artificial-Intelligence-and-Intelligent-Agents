/**
* Name: MarsColony
* Based on the internal empty template.
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags:
*/

model MarsColony

global {
    // === MAP ===
    int map_width <- 400;
    int map_height <- 400;
    geometry shape <- rectangle(map_width, map_height);

    // === AGENTS ===
    float max_oxygen_level <- 100.0;
    float max_energy_level <- 100.0;
    float max_health_level <- 100.0;

    // === COLORS ===
    rgb habitat_dome_color <- rgb(0, 255, 0);
    rgb habitat_dome_border_color <- rgb(0, 128, 0);

    rgb wasteland_color <- rgb(128, 0, 0);
    rgb wasteland_border_color <- rgb(64, 0, 0);

    rgb med_bay_color <- rgb(255, 0, 0);
    rgb med_bay_border_color <- rgb(128, 0, 0);
    rgb med_bay_queue_color <- rgb(255, 165, 0);
    rgb med_bay_queue_border_color <- rgb(168, 92, 0);
    rgb med_bay_text_color <- rgb(255, 255, 255);

    rgb landing_pad_color <- rgb(128, 128, 128);
    rgb landing_pad_border_color <- rgb(0, 0, 0);

    rgb greenhouse_color <- rgb(0, 255, 0);
    rgb greenhouse_border_color <- rgb(0, 128, 0);

    rgb oxygen_generator_color <- rgb(0, 0, 255);
    rgb oxygen_generator_border_color <- rgb(0, 0, 128);

    rgb human_color <- rgb(0, 0, 0);
    rgb human_border_color <- rgb(0, 0, 0);

    rgb engineer_color <- rgb(0, 128, 0);
    rgb engineer_border_color <- rgb(0, 64, 0);

    rgb medic_color <- rgb(255, 0, 0);
    rgb medic_border_color <- rgb(128, 0, 0);

    rgb scavenger_color <- rgb(0, 0, 255);
    rgb scavenger_border_color <- rgb(0, 0, 128);

    rgb parasite_color <- rgb(128, 128, 0);
    rgb parasite_border_color <- rgb(64, 64, 0);

    rgb commander_color <- rgb(128, 0, 128);
    rgb commander_border_color <- rgb(64, 0, 64);

    rgb mine_color <- rgb(0, 0, 0);
    rgb mine_color_border <- rgb(0, 0, 0);

    // === PLACES ===
    HabitatDome habitat_dome;
    Wasteland wasteland;
    LandingPad landing_pad;
    RockMine rock_mine;

    // === AGENTS ===
    list<Engineer> engineers;
    list<Medic> medics;
    list<Scavenger> scavengers;
    list<Parasite> parasites;
    list<Commander> commanders;

    list<Human> all_humans {
        return list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander);
    }

    // === GLOBAL VARIABLES ===
    int desired_number_of_engineers <- 16;
    int desired_number_of_medics <- 10;
    int desired_number_of_scavengers <- 8;
    int desired_number_of_parasites <- 12;
    int desired_number_of_commanders <- 4;

    // Cap the total number of agents in the colony
    int max_colony_size <- 60;

    int current_number_of_engineers <- 0;
    int current_number_of_medics <- 0;
    int current_number_of_scavengers <- 0;
    int current_number_of_parasites <- 0;
    int current_number_of_commanders <- 0;

    // === HEALTH ===
    float oxygen_decrease_rate <- 0.01;
    float oxygen_decrease_factor_in_wasteland <- 1.2;

    float energy_decrease_rate <- 0.005;
    float energy_decrease_rate_when_moving <- 0.01;
    float health_decrease_rate <- 1.0;

    float oxygen_level_threshold <- max_oxygen_level * 0.2;
    float energy_level_threshold <- max_energy_level * 0.2;
    float health_level_threshold <- max_health_level * 0.5;

    // === RANDOMNESS ===
    float oxygen_generator_break_probability <- 0.05;
    float scavenger_mission_probability <- 0.2;

    // === REFILL ===
    float oxygen_refill_rate <- 50.0;
    float energy_refill_rate <- 50.0;
    float facility_proximity <- 5.0;

    // === ETA ===
    int retirement_age <- 2000;
    float eta_increment <- 1.0;

    // === MOVEMENT ===
    float movement_speed <- 10.0;

    // === CONFIGURATION ===
    bool enable_supply_shuttle <- true;
    bool enable_retirement <- true;

    // === SIMULATION STATE ===
    bool first_shuttle_arrived <- false;

    // === LEARNING METRICS (aggregated) ===
    float avg_trust_to_parasites <- 0.0;
    float avg_trust_to_non_parasites <- 0.0;
    float precision <- 0.0; // TP / (TP + FP)
    float recall <- 0.0;    // TP / (TP + FN)
    int total_trades <- 0;

    init {
        create HabitatDome number: 1 returns: domes;
        habitat_dome <- domes[0];

        create Wasteland number: 1 returns: wastelands;
        wasteland <- wastelands[0];

        create LandingPad number: 1 returns: pads;
        landing_pad <- pads[0];

        create RockMine number: 1 returns: mines;
        rock_mine <- mines[0];

        engineers <- [];
        medics <- [];
        scavengers <- [];
        parasites <- [];
        commanders <- [];
    }

    reflex supply_shuttle when: enable_supply_shuttle {
        int total_colonists <- length(list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander));

        map<string, list<float>> q_sums <- map([]);
        map<string, int> q_counts <- map([]);
        map<string, float> trust_sums <- map([]);
        map<string, int> trust_counts <- map([]);

        loop survivor over: (list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander)) {
            loop k over: keys(survivor.Q) {
                list<float> vals <- survivor.Q[k];
                list<float> acc <- (q_sums contains_key k ? q_sums[k] : [0.0, 0.0]);
                acc[0] <- acc[0] + vals[0];
                acc[1] <- acc[1] + vals[1];
                q_sums[k] <- acc;
                int c <- (q_counts contains_key k ? q_counts[k] : 0);
                q_counts[k] <- c + 1;
            }

            loop tk over: keys(survivor.trust_memory) {
                float tv <- survivor.trust_memory[tk];
                float acc_t <- (trust_sums contains_key tk ? trust_sums[tk] : 0.0);
                trust_sums[tk] <- acc_t + tv;
                int ct <- (trust_counts contains_key tk ? trust_counts[tk] : 0);
                trust_counts[tk] <- ct + 1;
            }
        }

        map<string, list<float>> q_avg <- map([]);
        loop k over: keys(q_sums) {
            list<float> s <- q_sums[k];
            float c <- float(q_counts[k]);
            q_avg[k] <- [s[0] / c, s[1] / c];
        }

        map<string, float> trust_avg <- map([]);
        loop tk over: keys(trust_sums) {
            float s <- trust_sums[tk];
            float c <- float(trust_counts[tk]);
            trust_avg[tk] <- s / c;
        }

        if (not first_shuttle_arrived) {
            first_shuttle_arrived <- true;
        }

        bool deficit_mode <- (current_number_of_engineers < desired_number_of_engineers) or
                              (current_number_of_medics < desired_number_of_medics) or
                              (current_number_of_scavengers < desired_number_of_scavengers) or
                              (current_number_of_parasites < desired_number_of_parasites) or
                              (current_number_of_commanders < desired_number_of_commanders);

        if (deficit_mode) {
            int max_to_spawn <- max_colony_size - total_colonists;

            int delta_engineers <- desired_number_of_engineers - current_number_of_engineers;
            int delta_medics <- desired_number_of_medics - current_number_of_medics;
            int delta_scavengers <- desired_number_of_scavengers - current_number_of_scavengers;
            int delta_parasites <- desired_number_of_parasites - current_number_of_parasites;
            int delta_commanders <- desired_number_of_commanders - current_number_of_commanders;

            if (delta_engineers > 0 and max_to_spawn > 0) {
                int to_spawn <- min(delta_engineers, max_to_spawn);
                create Engineer number: to_spawn returns: new_engineers;
                ask new_engineers { location <- habitat_dome.location; oxygen_level <- max_oxygen_level; energy_level <- max_energy_level; }
                engineers <- engineers + new_engineers;
                current_number_of_engineers <- current_number_of_engineers + to_spawn;
                max_to_spawn <- max_to_spawn - to_spawn;
            }
            if (delta_medics > 0 and max_to_spawn > 0) {
                int to_spawn <- min(delta_medics, max_to_spawn);
                create Medic number: to_spawn returns: new_medics;
                ask new_medics { location <- habitat_dome.location; oxygen_level <- max_oxygen_level; energy_level <- max_energy_level; }
                medics <- medics + new_medics;
                current_number_of_medics <- current_number_of_medics + to_spawn;
                max_to_spawn <- max_to_spawn - to_spawn;
            }
            if (delta_scavengers > 0 and max_to_spawn > 0) {
                int to_spawn <- min(delta_scavengers, max_to_spawn);
                create Scavenger number: to_spawn returns: new_scavengers;
                ask new_scavengers { location <- habitat_dome.location; oxygen_level <- max_oxygen_level; energy_level <- max_energy_level; }
                scavengers <- scavengers + new_scavengers;
                current_number_of_scavengers <- current_number_of_scavengers + to_spawn;
                max_to_spawn <- max_to_spawn - to_spawn;
            }
            if (delta_parasites > 0 and max_to_spawn > 0) {
                int to_spawn <- min(delta_parasites, max_to_spawn);
                create Parasite number: to_spawn returns: new_parasites;
                ask new_parasites { location <- habitat_dome.location; oxygen_level <- max_oxygen_level; energy_level <- max_energy_level; }
                parasites <- parasites + new_parasites;
                current_number_of_parasites <- current_number_of_parasites + to_spawn;
                max_to_spawn <- max_to_spawn - to_spawn;
            }
            if (delta_commanders > 0 and max_to_spawn > 0) {
                int to_spawn <- min(delta_commanders, max_to_spawn);
                create Commander number: to_spawn returns: new_commanders;
                ask new_commanders { location <- habitat_dome.location; oxygen_level <- max_oxygen_level; energy_level <- max_energy_level; }
                commanders <- commanders + new_commanders;
                current_number_of_commanders <- current_number_of_commanders + to_spawn;
                max_to_spawn <- max_to_spawn - to_spawn;
            }
        }
    }

    // Aggregate trust and detection metrics each tick
    reflex update_learning_metrics {
        int total_agents <- length(list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander));
        int trades_this_tick <- total_trades;
        total_trades <- 0;
        
        map<string, bool> is_parasite_by_id <- map([]);
        loop h over: (list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander)) {
            is_parasite_by_id["id:" + h.name] <- (h is Parasite);
        }

        float sum_par <- 0.0; int cnt_par <- 0;
        float sum_non <- 0.0; int cnt_non <- 0;
        int tp0 <- 0; int fp0 <- 0; int fn0 <- 0; int tn0 <- 0;

        loop h over: (list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander)) {
            loop k over: keys(h.trust_memory) {
                float v <- h.trust_memory[k];
                bool gt_par <- ((is_parasite_by_id contains_key k) ? is_parasite_by_id[k] : false);
                if (gt_par) { sum_par <- sum_par + v; cnt_par <- cnt_par + 1; }
                else { sum_non <- sum_non + v; cnt_non <- cnt_non + 1; }

                bool pred_par <- v < 0.0;
                if (pred_par and gt_par) { tp0 <- tp0 + 1; }
                else if (pred_par and not gt_par) { fp0 <- fp0 + 1; }
                else if ((not pred_par) and gt_par) { fn0 <- fn0 + 1; }
                else { tn0 <- tn0 + 1; }
            }
        }

        avg_trust_to_parasites <- (cnt_par > 0 ? sum_par / float(cnt_par) : 0.0);
        avg_trust_to_non_parasites <- (cnt_non > 0 ? sum_non / float(cnt_non) : 0.0);
        precision <- ((tp0 + fp0) > 0 ? float(tp0) / float(tp0 + fp0) : 0.0);
        recall <- ((tp0 + fn0) > 0 ? float(tp0) / float(tp0 + fn0) : 0.0);
    }
}


species Human skills: [moving, fipa] control: simple_bdi {

    float oxygen_level <- max_oxygen_level;
    float energy_level <- max_energy_level;
    float health_level <- max_health_level;

    float eta <- 0.0;
    int raw_amount <- 0;

    // === IDENTITY / APPEARANCE ===
    string role <- "Human";
    string presented_role <- "Human";

    // === LEARNING / TRUST (Q-Learning) ===
    float happiness <- 0.0;

    float sociability <- 0.2;  // Learning rate: how much agents learn from interactions
    float patience <- 0.0;     // Discount factor: how much they value future rewards
    float curiosity <- 0.20;   // Exploration rate: how often they try new interactions

    map<string, list<float>> Q <- map([]);
    map<string, float> trust_memory <- map([]);

    int trade_cooldown <- 0;
    int trade_cooldown_max <- 10;
    float meet_distance <- 300.0;

    string state <- "idle";
    string received_message <- nil;

    // === BDI PREDICATES ===
    predicate suffocating_belief <- new_predicate("suffocating");
    predicate starving_belief <- new_predicate("starving");
    predicate injured_belief <- new_predicate("injured");
    predicate should_retire_belief <- new_predicate("should_retire");
    predicate storm_warning_belief <- new_predicate("storm_warning");

    predicate has_oxygen_desire <- new_predicate("has_oxygen");
    predicate has_energy_desire <- new_predicate("has_energy");
    predicate be_healthy_desire <- new_predicate("be_healthy");
    predicate wander_desire <- new_predicate("wander");
    predicate retire_desire <- new_predicate("retire");
    predicate escape_storm_desire <- new_predicate("escape_storm");

    init {
        do add_desire(wander_desire);
    }

    reflex receive_message when: !empty(mailbox) {
        message msg <- first(mailbox);
        mailbox <- mailbox - msg;
        string msg_contents <- string(msg.contents);
        if (msg_contents contains "Return to Base") {
            if (not has_belief(storm_warning_belief)) { do add_belief(storm_warning_belief); }
        }
    }

    reflex update_eta {
        if (not enable_retirement) { return; }
        eta <- eta + eta_increment;
        if (eta >= retirement_age) { do add_belief(should_retire_belief); }
    }

    // === PERCEPTION ===
    reflex perception {
        if (oxygen_level < oxygen_level_threshold) {
            if (not has_belief(suffocating_belief)) { do add_belief(suffocating_belief); }
        } else {
            if (has_belief(suffocating_belief)) { do remove_belief(suffocating_belief); }
        }

        if (energy_level < energy_level_threshold) {
            if (not has_belief(starving_belief)) { do add_belief(starving_belief); }
        } else {
            if (has_belief(starving_belief)) { do remove_belief(starving_belief); }
        }

        if (health_level < health_level_threshold) {
            if (not has_belief(injured_belief)) { do add_belief(injured_belief); }
        } else {
            if (has_belief(injured_belief)) { do remove_belief(injured_belief); }
        }
    }

    // Keep agents topped up while inside the med-bay zone so they do not die while waiting
    reflex med_bay_immunity when: (location distance_to habitat_dome.med_bay.location) <= facility_proximity {
        oxygen_level <- max_oxygen_level;
        energy_level <- max_energy_level;
        if (has_belief(suffocating_belief)) { do remove_belief(suffocating_belief); }
        if (has_belief(starving_belief)) { do remove_belief(starving_belief); }
    }

    // === RULES ===
    rule belief: storm_warning_belief new_desire: escape_storm_desire strength: 200.0;
    rule belief: suffocating_belief new_desire: has_oxygen_desire strength: 100.0;
    rule belief: starving_belief new_desire: has_energy_desire strength: 25.0;
    rule belief: injured_belief new_desire: be_healthy_desire strength: 12.0;
    rule belief: should_retire_belief new_desire: retire_desire strength: 6.0;

    // === PLANS ===

    plan escape_storm intention: escape_storm_desire {
        state <- "escaping_storm";
        do goto target: habitat_dome.location speed: movement_speed;

        if (habitat_dome.shape covers location) {
            do remove_belief(storm_warning_belief);
            do remove_intention(escape_storm_desire, true);
            state <- "idle";
        }
    }

    plan do_retire intention: retire_desire {
        state <- "retiring";
        do goto target: landing_pad.location speed: movement_speed;

        if ((location distance_to landing_pad.location) <= facility_proximity) {
            do die_and_update_counter;
        }
    }

    plan get_health intention: be_healthy_desire finished_when: health_level >= max_health_level {
        if ((location distance_to habitat_dome.med_bay.location) <= facility_proximity) {
            state <- "waiting_at_med_bay";
            ask habitat_dome.med_bay { do add_to_queue(myself); }
        } else {
            state <- "going_to_med_bay";
            do goto target: habitat_dome.med_bay.location speed: movement_speed;
        }

        if (health_level >= max_health_level) {
            ask habitat_dome.med_bay { do remove_from_queue(myself); }
            do remove_belief(injured_belief);
        }
    }

    plan get_oxygen intention: has_oxygen_desire finished_when: false
    {
        // Temporarily disabled to prioritize learning
    }

    plan get_energy intention: has_energy_desire finished_when: false {
        // Temporarily disabled to prioritize learning
    }

    plan wander_around intention: wander_desire {
        state <- 'idle';
        if (not (habitat_dome.shape covers location)) {
            do goto target: habitat_dome.location speed: movement_speed;
        } else {
            do wander amplitude: 50.0 speed: movement_speed;
        }
    }

    // === Biological reflexes ===

    reflex update_oxygen{
        if (habitat_dome.shape covers location)
        {
            oxygen_level <- max(0, oxygen_level - oxygen_decrease_rate);
        }
        else
        {
            float decrease <- oxygen_decrease_rate * oxygen_decrease_factor_in_wasteland;
            if (wasteland.dust_storm and (wasteland.shape covers location)) {
                 decrease <- decrease * 2.0; // Faster reduction
            }
            oxygen_level <- max(0, oxygen_level - decrease);
        }
    }

    reflex update_energy{
        if (state in ['going_to_oxygen', 'going_to_greenhouse', 'going_to_med_bay', 'going_to_oxygen_generator', 'retiring', 'going_to_mine', 'returning_to_dome', 'escaping_storm']) {
            energy_level <- max(0, energy_level - energy_decrease_rate_when_moving);
        } else {
            energy_level <- max(0, energy_level - energy_decrease_rate);
        }

        if (wasteland.dust_storm and (wasteland.shape covers location)) {
             energy_level <- max(0, energy_level - 1.0); // Extra drain
        }
    }

    reflex update_health when: oxygen_level <= 0 or energy_level <= 0{
        health_level <- max(0, health_level - health_decrease_rate);
    }

    action die_and_update_counter {
        if (self is Engineer) { current_number_of_engineers <- max(0, current_number_of_engineers - 1); }
        else if (self is Medic) { current_number_of_medics <- max(0, current_number_of_medics - 1); }
        else if (self is Scavenger) { current_number_of_scavengers <- max(0, current_number_of_scavengers - 1); }
        else if (self is Parasite) { current_number_of_parasites <- max(0, current_number_of_parasites - 1); }
        else if (self is Commander) { current_number_of_commanders <- max(0, current_number_of_commanders - 1); }
        do die;
    }

    reflex death when: false {
        // Disabled temporarily to allow learning to happen
    }

    // =========================================================
    // Q-LEARNING TRADE + PARASITE DISTINGUISHING (PER-AGENT)
    // =========================================================

    action ensure_state_exists(string s) {
        if (!(Q contains_key s)) { Q[s] <- [0.0, 0.0]; }
        if (!(trust_memory contains_key s)) { trust_memory[s] <- 0.0; }
    }

    action choose_action(string s) {
        if (flip(curiosity)) { return (flip(0.5) ? "TRADE" : "IGNORE"); }
        list<float> qs <- Q[s];
        return (qs[0] >= qs[1] ? "TRADE" : "IGNORE");
    }

    action update_q(string s, string a, float r) {
        do ensure_state_exists(s);
        int idx <- (a = "TRADE" ? 0 : 1);

        list<float> qs <- Q[s];
        float old <- qs[idx];
        float updated <- old + sociability * (r - old);
        qs[idx] <- updated;
        Q[s] <- qs;

        float pref <- Q[s][0] - Q[s][1];
        trust_memory[s] <- max(-1.0, min(1.0, pref / 4.0));
        
        if (cycle mod 200 = 0) {
            write name + " update_q: s=" + s + ", a=" + a + ", r=" + r + ", old_q=" + old + ", new_q=" + updated + ", trust=" + trust_memory[s];
        }
    }

    reflex update_trade_cooldown when: trade_cooldown > 0 {
        trade_cooldown <- trade_cooldown - 1;
    }
    
    reflex debug_state when: cycle mod 1000 = 0 {
        write name + " [cycle " + cycle + "] role=" + role + ", location=" + location + ", cooldown=" + trade_cooldown + ", inside_dome=" + (habitat_dome.shape covers location) + ", Q_entries=" + length(keys(Q)) + ", trust_entries=" + length(keys(trust_memory));
    }

    // Trade with minimal gating to enable learning
    reflex learn_and_trade when:
        trade_cooldown = 0
        and (habitat_dome.shape covers location)
        and not has_belief(storm_warning_belief)
    {
        list<Human> all_humans <- list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander);
        list<Human> nearby <- [];
        
        loop h over: all_humans {
            if (h != self) {
                float dist <- h.location distance_to location;
                if (dist <= meet_distance) {
                    nearby <- nearby + [h];
                }
            }
        }
        
        if (empty(nearby)) { 
            return; 
        }

        Human partner <- one_of(nearby);

        string s <- "id:" + partner.name;
        do ensure_state_exists(s);

        string a <- choose_action(s);
        if (a = "IGNORE") {
            do update_q(s, a, 0.0);
            trade_cooldown <- trade_cooldown_max;
            return;
        }

        float reward <- attempt_trade(partner);
        do update_q(s, a, reward);
        happiness <- happiness + reward;
        
        total_trades <- total_trades + 1;
        
        if (cycle mod 100 = 0) {
            write "[TRADE] " + name + " traded with " + partner.name + " (role=" + self.role + ", partner_role=" + partner.role + "), reward=" + reward + ", trust=" + trust_memory[s];
        }

        trade_cooldown <- trade_cooldown_max;
    }

    action attempt_trade(Human partner) {
        bool i_gave <- false;
        bool partner_gave <- false;

        if (!(self is Parasite)) {
            if (self is Scavenger and raw_amount > 0) {
                raw_amount <- raw_amount - 1;
                i_gave <- true;
                ask partner { energy_level <- min(max_energy_level, energy_level + 20.0); }
            }

            // Medic agents don't heal other agents outside of the medbay area

            if (self is Engineer and habitat_dome.oxygen_generator.is_broken) {
                i_gave <- true;
                habitat_dome.oxygen_generator.is_broken <- false;
            } else if (self is Engineer) {
                i_gave <- true;
                ask partner { oxygen_level <- min(max_oxygen_level, oxygen_level + 10.0); }
            }

            if (self is Commander) {
                i_gave <- true;
                ask partner {
                    oxygen_level <- min(max_oxygen_level, oxygen_level + 10.0);
                    energy_level <- min(max_energy_level, energy_level + 10.0);
                }
            }
        }

        if (partner is Parasite) {
            partner_gave <- false;
        } else {
            if (partner is Scavenger) {
                int their_raw <- 0;
                ask partner { their_raw <- raw_amount; }
                if (their_raw > 0) {
                    ask partner { raw_amount <- raw_amount - 1; }
                    energy_level <- min(max_energy_level, energy_level + 20.0);
                    partner_gave <- true;
                } else {
                    // Scavenger offers small assistance even without raw (at personal energy cost)
                    ask partner { energy_level <- max(0, energy_level - 5.0); }
                    energy_level <- min(max_energy_level, energy_level + 10.0);
                    partner_gave <- true;
                }
            }

            // Medic healing disabled - only happens at medbay

            if (partner is Engineer and habitat_dome.oxygen_generator.is_broken) {
                habitat_dome.oxygen_generator.is_broken <- false;
                partner_gave <- true;
            } else if (partner is Engineer) {
                oxygen_level <- min(max_oxygen_level, oxygen_level + 10.0);
                partner_gave <- true;
            }

            if (partner is Commander) {
                oxygen_level <- min(max_oxygen_level, oxygen_level + 10.0);
                energy_level <- min(max_energy_level, energy_level + 10.0);
                partner_gave <- true;
            }
        }

        if (self is Parasite) {
            // Parasite performs a harmful, one-sided interaction (steal/drain)
            // Mark as actor "gave" harm and partner did NOT give back.
            i_gave <- true;
            partner_gave <- false;

            int their_raw2 <- 0;
            ask partner { their_raw2 <- raw_amount; }
            if (their_raw2 > 0) {
                // Steal a raw resource if available
                ask partner { raw_amount <- raw_amount - 1; }
                raw_amount <- raw_amount + 1;
            } else {
                // Otherwise drain some energy from the partner
                ask partner { energy_level <- max(0, energy_level - 10.0); }
                energy_level <- min(max_energy_level, energy_level + 10.0);
            }
        }

        if (i_gave and partner_gave) { return 20.0; }
        if (i_gave and !partner_gave) { return ((partner is Parasite) ? -20.0 : -1.0); }
        return 0.0;
    }

    rgb get_color_for_presented_role {
        if (presented_role = "Engineer") { return engineer_color; }
        if (presented_role = "Medic") { return medic_color; }
        if (presented_role = "Scavenger") { return scavenger_color; }
        if (presented_role = "Commander") { return commander_color; }
        if (presented_role = "Parasite") { return parasite_color; }
        return human_color;
    }

    rgb get_border_for_presented_role {
        if (presented_role = "Engineer") { return engineer_border_color; }
        if (presented_role = "Medic") { return medic_border_color; }
        if (presented_role = "Scavenger") { return scavenger_border_color; }
        if (presented_role = "Commander") { return commander_border_color; }
        if (presented_role = "Parasite") { return parasite_border_color; }
        return human_border_color;
    }

    aspect base {
        draw circle(3) color: human_color border: human_border_color;
    }
}


// ================== ROLES ==================

species Engineer parent: Human {
    predicate generator_broken_belief <- new_predicate("generator_broken");
    predicate fix_generator_desire <- new_predicate("fix_generator");

    init {
        do add_desire(wander_desire);
        role <- "Engineer";
        presented_role <- "Engineer";
    }

    reflex check_generator {
        if (habitat_dome.oxygen_generator.is_broken) {
            if (not has_belief(generator_broken_belief)) { do add_belief(generator_broken_belief); }
        }
    }

    rule belief: generator_broken_belief new_desire: fix_generator_desire strength: 9.0;

    plan fix_generator intention: fix_generator_desire {
        if ((location distance_to habitat_dome.oxygen_generator.location) <= facility_proximity) {
            habitat_dome.oxygen_generator.is_broken <- false;
            do remove_belief(generator_broken_belief);
            do remove_intention(fix_generator_desire, true);
            state <- "idle";
        } else {
            state <- "going_to_oxygen_generator";
            do goto target: habitat_dome.oxygen_generator.location speed: movement_speed;
        }
    }

    aspect base {
        draw circle(3) color: engineer_color border: engineer_border_color;
    }
}

species Medic parent: Human {
    Human current_patient <- nil;

    predicate patients_waiting_belief <- new_predicate("patients_waiting");
    predicate heal_patients_desire <- new_predicate("heal_patients");

    init {
        do add_desire(wander_desire);
        role <- "Medic";
        presented_role <- "Medic";
    }

    reflex update_medic_biologicals {
        if ((location distance_to habitat_dome.med_bay.location) <= facility_proximity) {
            if (has_belief(starving_belief)) { do remove_belief(starving_belief); }
        }
    }

    reflex check_queue {
        if (not empty(habitat_dome.med_bay.waiting_queue)) {
            if (not has_belief(patients_waiting_belief)) { do add_belief(patients_waiting_belief); }
        } else {
            if (has_belief(patients_waiting_belief)) { do remove_belief(patients_waiting_belief); }
        }
    }

    rule belief: patients_waiting_belief new_desire: heal_patients_desire strength: 7.0;

    plan heal_others intention: heal_patients_desire {
        if ((location distance_to habitat_dome.med_bay.location) > facility_proximity) {
            state <- "going_to_med_bay";
            do goto target: habitat_dome.med_bay.location speed: movement_speed;
        } else {
            state <- "healing";

            if (current_patient = nil and not empty(habitat_dome.med_bay.waiting_queue)) {
                Human potential_patient <- habitat_dome.med_bay.waiting_queue[0];
                if (potential_patient != nil and not dead(potential_patient)) {
                    current_patient <- potential_patient;
                } else {
                    ask habitat_dome.med_bay { do remove_from_queue(potential_patient); }
                }
            }

            if (current_patient != nil) {
                ask current_patient {
                    health_level <- max_health_level;
                    oxygen_level <- max_oxygen_level;
                    energy_level <- max_energy_level;
                }
                Human healed <- current_patient;
                ask habitat_dome.med_bay { do remove_from_queue(healed); }
                current_patient <- nil;

            } else {
                do remove_belief(patients_waiting_belief);
                do remove_intention(heal_patients_desire, true);
            }
        }
    }

    aspect base {
        draw circle(3) color: medic_color border: medic_border_color;
    }
}

species Scavenger parent: Human {
    float mining_start_time <- 0.0;

    predicate mission_time_belief <- new_predicate("mission_time");
    predicate mine_desire <- new_predicate("mine_resources");

    init {
        do add_desire(wander_desire);
        role <- "Scavenger";
        presented_role <- "Scavenger";
    }

    reflex trigger_mission {
        if (flip(scavenger_mission_probability) and not has_belief(mission_time_belief)) {
            do add_belief(mission_time_belief);
        }
    }

    rule belief: mission_time_belief new_desire: mine_desire strength: 5.0;

    plan perform_mining intention: mine_desire {
        if ((location distance_to rock_mine.location) > facility_proximity and mining_start_time = 0.0) {
            state <- "going_to_mine";
            do goto target: rock_mine.location speed: movement_speed;
        } else {
            if (mining_start_time = 0.0) {
                mining_start_time <- time;
                state <- "mining";
            }

            if (time - mining_start_time >= 5.0) {
                state <- "returning_to_dome";
                do goto target: habitat_dome.location speed: movement_speed;

                if ((location distance_to habitat_dome.location) <= facility_proximity) {
                    raw_amount <- raw_amount + 5;
                    mining_start_time <- 0.0;
                    do remove_belief(mission_time_belief);
                    do remove_intention(mine_desire, true);
                    state <- "idle";
                }
            } else {
                state <- "mining";
            }
        }
    }

    aspect base {
        draw circle(3) color: scavenger_color border: scavenger_border_color;
    }
}

species Parasite parent: Human {
    init {
        do add_desire(wander_desire);
        role <- "Parasite";
        presented_role <- one_of(["Engineer", "Medic", "Scavenger", "Commander"]);
        // Inherit meet_distance and trade_cooldown from parent for consistent trading
    }

    aspect base {
        draw circle(3) color: parasite_color border: parasite_border_color;
    }
}

species Commander parent: Human {
    init {
        do add_desire(wander_desire);
        role <- "Commander";
        presented_role <- "Commander";
    }

    reflex check_storm {
        if (wasteland.dust_storm) {
            list<Human> agents_in_wasteland <- Human where (wasteland.shape covers each.location);
            if (!empty(agents_in_wasteland)) {
                do start_conversation to: agents_in_wasteland protocol: "fipa-propose"
                   performative: "propose" contents: ["Return to Base"];
            }
        }
    }

    aspect base {
        draw circle(3) color: commander_color border: commander_border_color;
    }
}


// ================== PLACES ==================

species HabitatDome {
    geometry shape <- rectangle(250, 250);

    Greenhouse greenhouse;
    OxygenGenerator oxygen_generator;
    MedBay med_bay;

    init {
        location <- point(200, 200);
        shape <- shape at_location location;

        point dome_center <- location;

        create Greenhouse number: 1 returns: greenhouses;
        greenhouse <- greenhouses[0];
        ask greenhouse { location <- dome_center + point(-80, 0); }

        create OxygenGenerator number: 1 returns: generators;
        oxygen_generator <- generators[0];
        ask oxygen_generator { location <- dome_center + point(80, 0); }

        create MedBay number: 1 returns: med_bays;
        med_bay <- med_bays[0];
        ask med_bay { location <- dome_center + point(0, -80); }
    }

    aspect base {
        draw shape color: habitat_dome_color border: habitat_dome_border_color;
        draw "Habitat Dome" at: location color: #black;
    }
}

species Greenhouse {
    point location;

    aspect base {
        draw circle(5) color: greenhouse_color border: greenhouse_border_color;
        draw "Greenhouse" at: location color: #black;
    }
}

species OxygenGenerator {
    point location;
    bool is_broken <- false;

    aspect base {
        if (is_broken) {
            draw circle(5) color: #red border: #darkred;
            draw "O2 Gen (BROKEN)" at: location color: #red;
        } else {
            draw circle(5) color: oxygen_generator_color border: oxygen_generator_border_color;
            draw "O2 Generator" at: location color: #black;
        }
    }

    reflex break_oxygen_generator when: rnd(0.0, 1.0) < oxygen_generator_break_probability {
        is_broken <- true;
    }
}

species Wasteland {
    geometry shape <- rectangle(100, 100);
    bool dust_storm <- false;
    int storm_timer <- 0;

    init {
        location <- point(50, 50);
        shape <- shape at_location location;
    }

    reflex manage_storm {
        if (dust_storm) {
            storm_timer <- storm_timer - 1;
            if (storm_timer <= 0) {
                dust_storm <- false;
            }
        } else {
            if (flip(0.01)) {
                dust_storm <- true;
                storm_timer <- 15;
            }
        }
    }

    aspect base {
        if (dust_storm) {
            draw shape color: #orange border: wasteland_border_color;
            draw "Wasteland (STORM)" at: location color: #black;
        } else {
            draw shape color: wasteland_color border: wasteland_border_color;
            draw "Wasteland" at: location color: #white;
        }
    }
}

species MedBay {
    point location;
    list<Human> waiting_queue <- [];

    action add_to_queue(Human human) {
        if (human != nil and not (waiting_queue contains human)) {
            waiting_queue <- waiting_queue + [human];
        }
    }

    action remove_from_queue(Human human) {
        if (human != nil and waiting_queue contains human) {
            waiting_queue <- waiting_queue - [human];
        }
    }

    reflex cleanup_dead_agents {
        list<Human> dead_agents <- [];
        loop patient over: waiting_queue {
            bool alive <- false;
            if (patient != nil) {
                ask patient { alive <- (health_level > 0); }
                if (not alive) { dead_agents <- dead_agents + [patient]; }
            } else {
                dead_agents <- dead_agents + [patient];
            }
        }
        loop dead_agent over: dead_agents {
            waiting_queue <- waiting_queue - [dead_agent];
        }
    }

    aspect base {
        int queue_size <- length(waiting_queue);
        rgb display_color <- med_bay_color;
        rgb display_border_color <- med_bay_border_color;

        bool medic_present <- false;
        loop medic over: list(Medic) {
            if ((medic.location distance_to location) <= facility_proximity) {
                medic_present <- true;
                break;
            }
        }

        if (queue_size > 0) {
            display_color <- med_bay_queue_color;
            display_border_color <- med_bay_queue_border_color;
        }

        draw square(10) color: display_color border: display_border_color;
        draw "Med-Bay" at: location color: med_bay_text_color;
        if (queue_size > 0) { draw "Queue: " + queue_size at: location + {0, -15} color: med_bay_text_color; }
        draw (medic_present ? "Medic: Present" : "Medic: None") at: location + {0, -30} color: med_bay_text_color;
    }
}

species LandingPad {
    point location <- point(50, 200);

    aspect base {
        draw rectangle(15, 15) color: landing_pad_color border: landing_pad_border_color;
        draw "Landing Pad" at: location color: #black;
    }
}

species RockMine {
    point location <- point(50, 50);

    aspect base {
        draw rectangle(20, 20) color: mine_color border: mine_color_border;
        draw "Mine" at: location color: #black;
    }
}


// ================== EXPERIMENT ==================

experiment MarsColony type: gui {
    output {
        display TheMarsColony {
            species LandingPad aspect: base;
            species HabitatDome aspect: base;
            species Greenhouse aspect: base;
            species OxygenGenerator aspect: base;
            species Wasteland aspect: base;
            species MedBay aspect: base;
            species Engineer aspect: base;
            species Medic aspect: base;
            species Scavenger aspect: base;
            species Parasite aspect: base;
            species Commander aspect: base;
            species RockMine aspect: base;
        }

        inspect "Agent State" type: table
            value: (list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander))
            attributes: ['name','role','presented_role','location','happiness','oxygen_level','energy_level','health_level','state','raw_amount','trust_memory'];

        display LearningMetrics {
            chart "Avg Trust & Detection" type: series {
                data 'Avg trust (parasites)' value: avg_trust_to_parasites;
                data 'Avg trust (non-parasites)' value: avg_trust_to_non_parasites;
                data 'Precision' value: precision;
                data 'Recall' value: recall;
            }
        }
    }
}
