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
    int map_width <- 250;
    int map_height <- 250;
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
    
    // === PLACES ===
    HabitatDome habitat_dome;
    Wasteland wasteland;
    LandingPad landing_pad;

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
    float oxygen_decrease_rate <- 1.0;
    float oxygen_decrease_factor_in_wasteland <- 1.2;
    float energy_decrease_rate <- 1.0;
    float health_decrease_rate <- 1.0;

    float oxygen_level_threshold <- max_oxygen_level * 0.2;
    float energy_level_threshold <- max_energy_level * 0.2;
    float health_level_threshold <- max_health_level * 0.5;

    // === REFILL ===
    float oxygen_refill_rate <- 50.0;
    float energy_refill_rate <- 50.0;
    float facility_proximity <- 5.0; // Distance to be considered "at" a facility

    // === MOVEMENT ===
    float movement_speed <- 10.0;

    // === VISUALIZATION ===
    bool show_beliefs <- true;

    // === CONFIGURATION ===
    bool enable_supply_shuttle <- false;

    // === SIMULATION STATE ===
    bool first_shuttle_arrived <- false;

    init {
        create HabitatDome number: 1 returns: domes;
        habitat_dome <- domes[0];
        
        create Wasteland number: 1 returns: wastelands;
        wasteland <- wastelands[0];
        
        create LandingPad number: 1 returns: pads;
        landing_pad <- pads[0];
        
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
    
    // TODO: trust_memory

    string state <- 'idle';
    
    // === BELIEFS ===
    map<string, bool> beliefs <- [];
    
    bool is_ok {
        return not has_belief("suffocating") and not has_belief("starving") and not has_belief("injured");
    }

    
    bool has_belief(string belief_name) {
        return beliefs contains belief_name and beliefs[belief_name] = true;
    }
    
    action add_belief(string belief_name) {
        beliefs[belief_name] <- true;
    }
    
    action remove_belief(string belief_name) {
        beliefs[belief_name] <- false;
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
    }

    // === HEALTH ===

    reflex update_oxygen {
        if (habitat_dome.shape covers location) {
            oxygen_level <- max(0, oxygen_level - oxygen_decrease_rate);
        } else {
            oxygen_level <- max(0, oxygen_level - oxygen_decrease_rate * oxygen_decrease_factor_in_wasteland);
        }
    } 

    reflex update_health when: oxygen_level <= 0 or energy_level <= 0 {
            health_level <- max(0, health_level - health_decrease_rate);
        }

    reflex death when: health_level <= 0 {
        write 'Agent died';
        
        // Update the appropriate counter based on species
        if (self is Engineer) {
            current_number_of_engineers <- max(0, current_number_of_engineers - 1);
        } else if (self is Medic) {
            current_number_of_medics <- max(0, current_number_of_medics - 1);
        } else if (self is Scavenger) {
            current_number_of_scavengers <- max(0, current_number_of_scavengers - 1);
        } else if (self is Parasite) {
            current_number_of_parasites <- max(0, current_number_of_parasites - 1);
        } else if (self is Commander) {
            current_number_of_commanders <- max(0, current_number_of_commanders - 1);
        }
        
        do die;
    }

    reflex move_to_dome when: state = 'idle' and not (habitat_dome.shape covers location) {
        do goto target: habitat_dome.location speed: movement_speed;
    }

    reflex wander_in_dome when: state = 'idle' and (habitat_dome.shape covers location) {
        do wander amplitude: 50.0 speed: movement_speed;
    }    

    reflex handle_suffocating when: has_belief("suffocating") and oxygen_level < max_oxygen_level {
        // Only move if not already at the oxygen generator
        if ((location distance_to habitat_dome.oxygen_generator.location) > facility_proximity) {
            do goto target: habitat_dome.oxygen_generator.location speed: movement_speed;
        }
    }

    reflex refill_oxygen when: (location distance_to habitat_dome.oxygen_generator.location) <= facility_proximity and oxygen_level < max_oxygen_level {
        // Stop moving and refill
        state <- 'refilling_oxygen';
        oxygen_level <- min(max_oxygen_level, oxygen_level + oxygen_refill_rate);
    }

    reflex handle_starving when: has_belief("starving") and energy_level < max_energy_level {
        // Only move if not already at the greenhouse
        if ((location distance_to habitat_dome.greenhouse.location) > facility_proximity) {
            do goto target: habitat_dome.greenhouse.location speed: movement_speed;
        }
    }

    reflex refill_energy when: (location distance_to habitat_dome.greenhouse.location) <= facility_proximity and energy_level < max_energy_level {
        // Stop moving and refill
        state <- 'refilling_energy';
        energy_level <- min(max_energy_level, energy_level + energy_refill_rate);
    }

    reflex handle_injured when: has_belief("injured") {
        do goto target: habitat_dome.med_bay.location speed: movement_speed;
    }
    
    reflex return_to_idle when: (state = 'refilling_oxygen' and oxygen_level >= max_oxygen_level) or (state = 'refilling_energy' and energy_level >= max_energy_level) {
        state <- 'idle';
    }    
    
    aspect base {
        draw circle(3) color: human_color border: human_border_color;
    }

}

species Engineer parent: Human {
    aspect base {
        draw circle(3) color: engineer_color border: engineer_border_color;
    }
}

species Medic parent: Human {
    aspect base {
        draw circle(3) color: medic_color border: medic_border_color;
    }
}

species Scavenger parent: Human {
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
    geometry shape <- rectangle(100, 100); // Safe zone area
    
    // Facilities within the dome
    Greenhouse greenhouse;
    OxygenGenerator oxygen_generator;
    MedBay med_bay;
    
    init {
        location <- point(50, 50); // Center of the dome
        shape <- shape at_location location; // Position the shape at location
        
        point dome_center <- location; // Store dome center for facility positioning
        
        // Create facilities inside the dome
        create Greenhouse number: 1 returns: greenhouses;
        greenhouse <- greenhouses[0];
        ask greenhouse {
            location <- dome_center + point(-40, 0); // Position relative to dome center
        }
        
        create OxygenGenerator number: 1 returns: generators;
        oxygen_generator <- generators[0];
        ask oxygen_generator {
            location <- dome_center + point(40, 0); // Position relative to dome center
        }
        
        create MedBay number: 1 returns: med_bays;
        med_bay <- med_bays[0];
        ask med_bay {
            location <- dome_center + point(0, -40); // Position relative to dome center
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
}

// Wasteland: Dangerous zone with no oxygen, but has raw materials
species Wasteland {
    geometry shape <- rectangle(100, 100); // Large dangerous area
    
    init {
        location <- point(150, 150); // Positioned away from safe zone
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
    
    aspect base {
        draw square(10) color: med_bay_color border: med_bay_border_color;
        draw "Med-Bay" at: location color: #white;
    }
}

// Landing Pad: Where new agents spawn
species LandingPad {
    point location <- point(150, 50); // Positioned away from main activity
    
    aspect base {
        draw rectangle(15, 15) color: landing_pad_color border: landing_pad_border_color;
        draw "Landing Pad" at: location color: #black;
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
	    }
	    
	    inspect "Agent Beliefs" type: table value: (list(Engineer) + list(Medic) + list(Scavenger) + list(Parasite) + list(Commander)) attributes: ['name', 'species', 'beliefs', 'oxygen_level', 'energy_level', 'health_level', 'state'];
	}
}