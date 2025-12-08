/**
* Name: MarsColony
* Based on the internal empty template. 
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags: 
*/


model MarsColony

// Mars Colony is a model that simulates a colony on Mars.

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
    int desired_number_of_engineers <- 2;
    int desired_number_of_medics <- 2;
    int desired_number_of_scavengers <- 2;
    int desired_number_of_parasites <- 2;
    int desired_number_of_commanders <- 1;

    int current_number_of_engineers <- 0;
    int current_number_of_medics <- 0;
    int current_number_of_scavengers <- 0;
    int current_number_of_parasites <- 0;
    int current_number_of_commanders <- 0;

    // === HEALTH ===
    float oxygen_decrease_rate <- 0.5;
    float oxygen_decrease_factor_in_wasteland <- 1.2;
    float energy_decrease_rate <- 0.2;
    float energy_decrease_rate_when_moving <- 1.0;
    float health_decrease_rate <- 1.0;

    float oxygen_level_threshold <- max_oxygen_level * 0.2;
    float energy_level_threshold <- max_energy_level * 0.2;
    float health_level_threshold <- max_health_level * 0.5;


    // === RANDOMNESS ===
    float oxygen_generator_break_probability <- 0.1;
    float scavenger_mission_probability <- 0.2;

    // === REFILL ===
    float oxygen_refill_rate <- 50.0;
    float energy_refill_rate <- 50.0;
    float facility_proximity <- 5.0; // Distance to be considered "at" a facility

    // === ETA ===
    int retirement_age <- 1000;
    float eta_increment <- 1.0;

    // === MOVEMENT ===
    float movement_speed <- 10.0;

    // === VISUALIZATION ===

    // === CONFIGURATION ===
    bool enable_supply_shuttle <- true;
    bool enable_retirement <- true;

    // === SIMULATION STATE ===
    bool first_shuttle_arrived <- false;

    init {
        create HabitatDome number: 1 returns: domes;
        habitat_dome <- domes[0];
        
        create Wasteland number: 1 returns: wastelands;
        wasteland <- wastelands[0];
        
        create LandingPad number: 1 returns: pads;
        landing_pad <- pads[0];
        
        create RockMine number: 1 returns: mines;
        rock_mine <- mines[0];
        
        // Initialize agent lists
        engineers <- [];
        medics <- [];
        scavengers <- [];
        parasites <- [];
        commanders <- [];
    }

    reflex supply_shuttle when: enable_supply_shuttle or not first_shuttle_arrived {
        first_shuttle_arrived <- true;
        
        int delta_engineers <- desired_number_of_engineers - current_number_of_engineers;
        int delta_medics <- desired_number_of_medics - current_number_of_medics;
        int delta_scavengers <- desired_number_of_scavengers - current_number_of_scavengers;
        int delta_parasites <- desired_number_of_parasites - current_number_of_parasites;
        int delta_commanders <- desired_number_of_commanders - current_number_of_commanders;

        if (delta_engineers > 0) {
            create Engineer number: delta_engineers returns: new_engineers;
            ask new_engineers {
                location <- landing_pad.location;
            }
            engineers <- engineers + new_engineers;
        }
        if (delta_medics > 0) {
            create Medic number: delta_medics returns: new_medics;
            ask new_medics {
                location <- landing_pad.location;
            }
            medics <- medics + new_medics;
        }
        if (delta_scavengers > 0) {
            create Scavenger number: delta_scavengers returns: new_scavengers;
            ask new_scavengers {
                location <- landing_pad.location;
            }
            scavengers <- scavengers + new_scavengers;
        }
        if (delta_parasites > 0) {
            create Parasite number: delta_parasites returns: new_parasites;
            ask new_parasites {
                location <- landing_pad.location;
            }
            parasites <- parasites + new_parasites;
        }
        if (delta_commanders > 0) {
            create Commander number: delta_commanders returns: new_commanders;
            ask new_commanders {
                location <- landing_pad.location;
            }
            commanders <- commanders + new_commanders;
        }

        current_number_of_engineers <- current_number_of_engineers + delta_engineers;
        current_number_of_medics <- current_number_of_medics + delta_medics;
        current_number_of_scavengers <- current_number_of_scavengers + delta_scavengers;
        current_number_of_parasites <- current_number_of_parasites + delta_parasites;
        current_number_of_commanders <- current_number_of_commanders + delta_commanders;
    }
}


species Human skills: [moving, fipa] {
    float oxygen_level <- max_oxygen_level;
    float energy_level <- max_energy_level;
    float health_level <- max_health_level;
    
    float eta <- 0.0;
    int raw_amount <- 0;
    
    // TODO: trust_memory

    string state <- 'idle';
    
    // === BELIEFS ===
    map<string, bool> beliefs <- [];
    
    bool is_ok <- true;
    
    bool has_belief(string belief_name) {
        if (not (beliefs contains_key(belief_name))) {
            return false;
        }
        return beliefs[belief_name];
    }
    
    action add_belief(string belief_name) {
        beliefs[belief_name] <- true;
    }
    
    action remove_belief(string belief_name) {
        beliefs[belief_name] <- false;
    }


    // === RETIREMENT ===

    reflex update_eta {
        // If retirement is disabled, don't update eta
        if (not enable_retirement) {
            return;
        }
        eta <- eta + eta_increment;
    }

    reflex retire when: eta >= retirement_age {
        state <- 'retiring';
        do goto target: landing_pad.location speed: movement_speed;        
    }

    reflex handle_retiring when: state = 'retiring' {
        if (location distance_to landing_pad.location) <= facility_proximity {
            write 'Agent ' + name + ' retired';
            do die_and_update_counter;
        }
    }
    
    reflex update_beliefs {
        // Suffocating belief: triggered when Oxygen < 20%
        if (oxygen_level < oxygen_level_threshold) {
            if (not has_belief("suffocating")) {
                do add_belief("suffocating");
            }
        } else {
            if (has_belief("suffocating")) {
                do remove_belief("suffocating");
            }
        }
        
        // Starving belief: triggered when Energy < 20%
        if (energy_level < energy_level_threshold) {
            if (not has_belief("starving")) {
                do add_belief("starving");
            }
        } else {
            if (has_belief("starving")) {
                do remove_belief("starving");
            }
        }
        
        // Injured belief: triggered when Health < 50%
        if (health_level < health_level_threshold) {
            if (not has_belief("injured")) {
                do add_belief("injured");
            }
        } else {
            if (has_belief("injured")) {
                do remove_belief("injured");
            }
        }
        
        // Update is_ok after updating all beliefs
        is_ok <- not has_belief("suffocating") and not has_belief("starving") and not has_belief("injured");
    }

    // === HEALTH ===

    reflex update_oxygen {
        if (habitat_dome.shape covers location) {
            oxygen_level <- max(0, oxygen_level - oxygen_decrease_rate);
        } else {
            oxygen_level <- max(0, oxygen_level - oxygen_decrease_rate * oxygen_decrease_factor_in_wasteland);
        }
    }

    reflex update_energy {
        if (state = 'going_to_oxygen' or state = 'going_to_greenhouse' or state = 'going_to_med_bay' or state = 'going_to_oxygen_generator' or state = 'retiring') {
            energy_level <- max(0, energy_level - energy_decrease_rate_when_moving);
        } else {
            energy_level <- max(0, energy_level - energy_decrease_rate);
        }
    }

    reflex update_health when: oxygen_level <= 0 or energy_level <= 0 {
            health_level <- max(0, health_level - health_decrease_rate);
        }

    action die_and_update_counter {
        if (self is Engineer) {
            current_number_of_engineers <- max(0, current_number_of_engineers - 1);
        } else if (self is Medic) {
            current_number_of_medics <- max(0, current_number_of_medics - 1);
        }
        if (self is Scavenger) {
            current_number_of_scavengers <- max(0, current_number_of_scavengers - 1);
        }
        if (self is Parasite) {
            current_number_of_parasites <- max(0, current_number_of_parasites - 1);
        }
        if (self is Commander) {
            current_number_of_commanders <- max(0, current_number_of_commanders - 1);
        }

        do die;
    }

    reflex death when: health_level <= 0 {
        string death_reason <- "";
        if (oxygen_level <= 0) {
            death_reason <- "suffocation";
        } else if (energy_level <= 0) {
            death_reason <- "starvation";
        } else {
            death_reason <- "health depletion";
        }
        write 'Agent ' + name + ' died from ' + death_reason;
        do die_and_update_counter;
    }   

    reflex handle_idle when: state = 'idle' and is_ok {
        if (not (habitat_dome.shape covers location)) {
            do move_to_dome;
        } else {
            do wander_in_dome;
        }
    }
    
    reflex go_to_med_bay_continuous when: state = 'going_to_med_bay' {
        if ((location distance_to habitat_dome.med_bay.location) > facility_proximity) {
            do goto target: habitat_dome.med_bay.location speed: movement_speed;
        }
    }
    
    reflex stay_at_med_bay_when_queued when: state = 'waiting_at_med_bay' {
        if ((location distance_to habitat_dome.med_bay.location) > facility_proximity) {
            do goto target: habitat_dome.med_bay.location speed: movement_speed;
        }
    }

    action move_to_dome {
        do goto target: habitat_dome.location speed: movement_speed;
    }

    action wander_in_dome {
        do wander amplitude: 50.0 speed: movement_speed;
    } 

    reflex refill_oxygen when: state = 'refilling_oxygen' and (location distance_to habitat_dome.oxygen_generator.location) <= facility_proximity and oxygen_level < max_oxygen_level {
        oxygen_level <- min(max_oxygen_level, oxygen_level + oxygen_refill_rate);
    }
    
    reflex refill_energy when: state = 'refilling_energy' and (location distance_to habitat_dome.greenhouse.location) <= facility_proximity and energy_level < max_energy_level {
        energy_level <- min(max_energy_level, energy_level + energy_refill_rate);
    }
    
    reflex prioritize_med_bay when: has_belief("injured") and state != 'waiting_at_med_bay' and state != 'healing' and state != 'going_to_med_bay' {
        state <- 'going_to_med_bay';
    }
    
    reflex handle_urgent_needs when: state != 'refilling_oxygen' and state != 'refilling_energy' and state != 'waiting_at_med_bay' and state != 'healing' and state != 'going_to_med_bay' and not has_belief("injured") {
        if (has_belief("suffocating") and oxygen_level < max_oxygen_level) {
            if ((location distance_to habitat_dome.oxygen_generator.location) <= facility_proximity) {
                state <- 'refilling_oxygen';
            } else {
                state <- 'going_to_oxygen';
                do goto target: habitat_dome.oxygen_generator.location speed: movement_speed;
            }
            return;
        }
        
        if (has_belief("starving") and energy_level < max_energy_level) {
            if ((location distance_to habitat_dome.greenhouse.location) <= facility_proximity) {
                state <- 'refilling_energy';
            } else {
                state <- 'going_to_greenhouse';
                do goto target: habitat_dome.greenhouse.location speed: movement_speed;
            }
            return;
        }
    }
    
    reflex arrive_at_med_bay when: state = 'going_to_med_bay' and (location distance_to habitat_dome.med_bay.location) <= facility_proximity {
        state <- 'waiting_at_med_bay';
        Human agent_to_queue <- self;
        ask habitat_dome.med_bay {
            do add_to_queue(agent_to_queue);
        }
    }
    
    reflex leave_med_bay when: state = 'waiting_at_med_bay' and not has_belief("injured") {
        Human agent_to_remove <- self;
        ask habitat_dome.med_bay {
            do remove_from_queue(agent_to_remove);
        }
        state <- 'idle';
    }
    
    reflex return_to_idle when: (state = 'refilling_oxygen' and oxygen_level >= max_oxygen_level) or (state = 'refilling_energy' and energy_level >= max_energy_level) {
        state <- 'idle';
    }    
    
    aspect base {
        draw circle(3) color: human_color border: human_border_color;
    }

}

species Engineer parent: Human {
    reflex update_oxygen_generator_belief when: habitat_dome.oxygen_generator.is_broken {
        if (not has_belief("oxygen_generator_broken")) {
            do add_belief("oxygen_generator_broken");
        }
    }

    reflex handle_oxygen_generator_broken when: has_belief("oxygen_generator_broken") {
        state <- 'going_to_oxygen_generator';
        do goto target: habitat_dome.oxygen_generator.location speed: movement_speed;
    }


    reflex repair_oxygen_generator when: state = 'going_to_oxygen_generator' and (location distance_to habitat_dome.oxygen_generator.location) <= facility_proximity and habitat_dome.oxygen_generator.is_broken {
        //write 'Agent ' + name + ' repaired the oxygen generator';
        habitat_dome.oxygen_generator.is_broken <- false;
        do remove_belief("oxygen_generator_broken");
        state <- 'idle';
    }

    aspect base {
        draw circle(3) color: engineer_color border: engineer_border_color;
    }
}

species Medic parent: Human {
    Human current_patient <- nil;
    
    reflex update_oxygen {
        bool at_med_bay <- (location distance_to habitat_dome.med_bay.location) <= facility_proximity;
        if (not at_med_bay) {
            if (habitat_dome.shape covers location) {
                oxygen_level <- max(0, oxygen_level - oxygen_decrease_rate);
            } else {
                oxygen_level <- max(0, oxygen_level - oxygen_decrease_rate * oxygen_decrease_factor_in_wasteland);
            }
        }
    }
    
    reflex ignore_hunger_when_at_med_bay when: state = 'healing' or state = 'going_to_med_bay' or state = 'waiting_at_med_bay' or (location distance_to habitat_dome.med_bay.location) <= facility_proximity {
        if (has_belief("starving")) {
            do remove_belief("starving");
        }
    }
    
    reflex handle_urgent_needs when: state != 'refilling_oxygen' and state != 'refilling_energy' and state != 'waiting_at_med_bay' and state != 'healing' and state != 'going_to_med_bay' and not has_belief("injured") {
        bool at_med_bay <- (location distance_to habitat_dome.med_bay.location) <= facility_proximity;
        
        if (has_belief("suffocating") and oxygen_level < max_oxygen_level and not at_med_bay) {
            if ((location distance_to habitat_dome.oxygen_generator.location) <= facility_proximity) {
                state <- 'refilling_oxygen';
            } else {
                state <- 'going_to_oxygen';
                do goto target: habitat_dome.oxygen_generator.location speed: movement_speed;
            }
            return;
        }
        
        if (has_belief("starving") and energy_level < max_energy_level and not at_med_bay) {
            if ((location distance_to habitat_dome.greenhouse.location) <= facility_proximity) {
                state <- 'refilling_energy';
            } else {
                state <- 'going_to_greenhouse';
                do goto target: habitat_dome.greenhouse.location speed: movement_speed;
            }
            return;
        }
    }
    
    reflex check_med_bay_queue when: state != 'healing' and state != 'going_to_med_bay' and state != 'waiting_at_med_bay' {
        if (not empty(habitat_dome.med_bay.waiting_queue)) {
            // Find first alive patient in queue
            Human first_alive_patient <- nil;
            list<Human> queue <- habitat_dome.med_bay.waiting_queue;
            loop i from: 0 to: length(queue) - 1 {
                Human patient <- queue[i];
                // Check if patient is still alive by checking their health
                if (patient != nil) {
                    bool is_alive <- false;
                    ask patient {
                        if (health_level > 0) {
                            is_alive <- true;
                        }
                    }
                    if (is_alive) {
                        first_alive_patient <- patient;
                        break;
                    }
                }
            }
            
            if (first_alive_patient != nil) {
                current_patient <- first_alive_patient;
                state <- 'going_to_med_bay';
                do goto target: habitat_dome.med_bay.location speed: movement_speed;
            }
        }
    }
    
    reflex arrive_at_med_bay when: state = 'going_to_med_bay' and (location distance_to habitat_dome.med_bay.location) <= facility_proximity {
        if (current_patient != nil) {
            // Medic is going to heal someone else
            state <- 'healing';
        } else if (has_belief("injured")) {
            // Medic is injured and going for themselves - queue up
            state <- 'waiting_at_med_bay';
            Human agent_to_queue <- self;
            ask habitat_dome.med_bay {
                do add_to_queue(agent_to_queue);
            }
        }
    }
    
    reflex stay_at_med_bay_for_healing when: state = 'healing' {
        if ((location distance_to habitat_dome.med_bay.location) > facility_proximity) {
            do goto target: habitat_dome.med_bay.location speed: movement_speed;
        }
    }
    
    reflex heal_patient when: state = 'healing' and current_patient != nil and (location distance_to habitat_dome.med_bay.location) <= facility_proximity {
        // Check if patient is still in queue (might have been removed by another medic)
        if (habitat_dome.med_bay.waiting_queue contains current_patient) {
            Human patient_to_heal <- current_patient;
            
            // Check if patient is still alive by checking their health
            bool patient_alive <- false;
            if (patient_to_heal != nil) {
                ask patient_to_heal {
                    if (health_level > 0) {
                        patient_alive <- true;
                    }
                }
            }
            
            if (patient_alive) {
                string patient_name <- "";
                ask patient_to_heal {
                    patient_name <- name;
                }
                
                // Heal the patient: restore health, oxygen, and energy
                ask patient_to_heal {
                    health_level <- max_health_level;
                    oxygen_level <- max_oxygen_level;
                    energy_level <- max_energy_level;
                }
                
                write 'Medic ' + name + ' healed ' + patient_name;
                
                // Remove patient from queue
                ask habitat_dome.med_bay {
                    do remove_from_queue(patient_to_heal);
                }
            } else {
                // Patient died, just remove from queue
                ask habitat_dome.med_bay {
                    do remove_from_queue(patient_to_heal);
                }
            }
        }
        current_patient <- nil;
        state <- 'idle';
    }
    
    aspect base {
        draw circle(3) color: medic_color border: medic_border_color;
    }
}

species Scavenger parent: Human {

    //Variables 
    float mining_start_time;

    reflex start_mission when: state = 'idle' and flip(scavenger_mission_probability) {
        state <- 'going_to_mine';
    }

    reflex go_to_mine when: state = 'going_to_mine' {
        do goto target: rock_mine.location speed: movement_speed;
        if (location distance_to rock_mine.location <= facility_proximity) {
            state <- 'mining';
            mining_start_time <- time;
        }
    }

    reflex mine when: state = 'mining' {
        if (time - mining_start_time >= 5.0) {
            state <- 'returning_to_dome';
            raw_amount <-raw_amount + 5;
        }
    }

    reflex return_to_dome when: state = 'returning_to_dome' {
        do goto target: habitat_dome.location speed: movement_speed;
        if (location distance_to habitat_dome.location <= facility_proximity) {
            state <- 'idle';
        }
    }

    aspect base {
        draw circle(3) color: scavenger_color border: scavenger_border_color;
    }
}

species Parasite parent: Human {
    aspect base {
        draw circle(3) color: parasite_color border: parasite_border_color;
    }
}

species Commander parent: Human {
    aspect base {
        draw circle(3) color: commander_color border: commander_border_color;
    }
}

// ========== PLACES ==========

// Habitat Dome: Safe zone containing Greenhouse and Oxygen Generator
species HabitatDome {
    geometry shape <- rectangle(250, 250); // Safe zone area
    
    // Facilities within the dome
    Greenhouse greenhouse;
    OxygenGenerator oxygen_generator;
    MedBay med_bay;
    
    init {
        location <- point(200, 200); // Center of the dome
        shape <- shape at_location location; // Position the shape at location
        
        point dome_center <- location; // Store dome center for facility positioning
        
        // Create facilities inside the dome
        create Greenhouse number: 1 returns: greenhouses;
        greenhouse <- greenhouses[0];
        ask greenhouse {
            location <- dome_center + point(-80, 0); // Position relative to dome center
        }
        
        create OxygenGenerator number: 1 returns: generators;
        oxygen_generator <- generators[0];
        ask oxygen_generator {
            location <- dome_center + point(80, 0); // Position relative to dome center
        }
        
        create MedBay number: 1 returns: med_bays;
        med_bay <- med_bays[0];
        ask med_bay {
            location <- dome_center + point(0, -80); // Position relative to dome center
        }
    }
    
    aspect base {
        draw shape color: habitat_dome_color border: habitat_dome_border_color;
        draw "Habitat Dome" at: location color: #black;
    }
}

// Greenhouse: Provides food/energy
species Greenhouse {
    point location;
    
    aspect base {
        draw circle(5) color: greenhouse_color border: greenhouse_border_color;
        draw "Greenhouse" at: location color: #black;
    }
}

// Oxygen Generator: Provides oxygen (can break and need repair)
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

// Wasteland: Dangerous zone with no oxygen, but has raw materials
species Wasteland {
    geometry shape <- rectangle(100, 100); // Large dangerous area
    
    init {
        location <- point(50, 50); // Positioned away from safe zone
        shape <- shape at_location location; // Position the shape at location
    }
    
    aspect base {
        draw shape color: wasteland_color border: wasteland_border_color;
        draw "Wasteland" at: location color: #white;
    }
}

// Med-Bay: Where medics work to restore health
species MedBay {
    point location;
    list<Human> waiting_queue <- [];
    
    action add_to_queue(Human human) {
        if (human != nil) {
            string agent_name <- "";
            ask human {
                agent_name <- name;
            }
            //write 'Agent ' + agent_name + ' added to the queue';
            if (not (waiting_queue contains human)) {
                waiting_queue <- waiting_queue + [human];
            }
        }
    }
    
    action remove_from_queue(Human human) {
        if (human != nil and waiting_queue contains human) {
            string agent_name <- "Unknown";
            bool is_alive <- false;
            ask human {
                if (health_level > 0) {
                    is_alive <- true;
                    agent_name <- name;
                }
            }
            if (is_alive) {
                //write 'Agent ' + agent_name + ' removed from the queue';
            } else {
                //write 'Dead agent removed from the queue';
            }
            waiting_queue <- waiting_queue - [human];
        }
    }
    
    reflex cleanup_dead_agents {
        list<Human> dead_agents <- [];
        loop patient over: waiting_queue {
            if (patient != nil) {
                bool is_alive <- false;
                ask patient {
                    is_alive <- (health_level > 0);
                }
                if (not is_alive) {
                    dead_agents <- dead_agents + [patient];
                }
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
        if (queue_size > 0) {
            draw "Queue: " + queue_size at: location + {0, -15} color: med_bay_text_color;
        }
        if (medic_present) {
            draw "Medic: Present" at: location + {0, -30} color: med_bay_text_color;
        } else {
            draw "Medic: None" at: location + {0, -30} color: med_bay_text_color;
        }
    }
}

// Landing Pad: Where new agents spawn
species LandingPad {
    point location <- point(50, 200); // Positioned away from main activity
    
    aspect base {
        draw rectangle(15, 15) color: landing_pad_color border: landing_pad_border_color;
        draw "Landing Pad" at: location color: #black;
    }
}

species RockMine{
    point location <- point(50,50); // Positioned in the middle of the Wasteland

	aspect base{
        draw rectangle(20,20) color: mine_color border: mine_color_border;
        draw "Mine" at: location color: #black;
    }
}

// ========== EXPERIMENT ==========

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
	    
        inspect "Agent Beliefs" type: table value: (list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander)) attributes: ['name', 'beliefs', 'oxygen_level', 'energy_level', 'health_level', 'state', 'is_ok', 'raw_amount'];
	
	}
	
}