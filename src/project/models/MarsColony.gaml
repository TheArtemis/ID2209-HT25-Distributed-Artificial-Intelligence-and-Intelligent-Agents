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
    int desired_number_of_engineers <- 16;
    int desired_number_of_medics <- 10;
    int desired_number_of_scavengers <- 8;
    int desired_number_of_parasites <- 12;
    int desired_number_of_commanders <- 4;

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


species Human skills: [moving, fipa] control: simple_bdi{
    float oxygen_level <- max_oxygen_level;
    float energy_level <- max_energy_level;
    float health_level <- max_health_level;
    
    float eta <- 0.0;
    int raw_amount <- 0;
    
    // TODO: trust_memory

    string state <- 'idle';
    string received_message <- nil;

    reflex receive_message when: !empty(mailbox) {
		message msg <- first(mailbox);
        mailbox <- mailbox - msg;
		string msg_contents <- string(msg.contents);
		if (msg_contents contains "Return to Base") {
            write name + " received storm warning! Adding escape desire.";
            if (not has_belief(storm_warning_belief)) {
                 do add_belief(storm_warning_belief);
            }
        }
	}
    
    // === BDI PREDICATES ===
    // Beliefs
    predicate suffocating_belief <- new_predicate("suffocating");
    predicate starving_belief <- new_predicate("starving");
    predicate injured_belief <- new_predicate("injured");
    predicate should_retire_belief <- new_predicate("should_retire");
    predicate storm_warning_belief <- new_predicate("storm_warning");

    // Desires
    predicate has_oxygen_desire <- new_predicate("has_oxygen");
    predicate has_energy_desire <- new_predicate("has_energy");
    predicate be_healthy_desire <- new_predicate("be_healthy");
    predicate wander_desire <- new_predicate("wander");
    predicate retire_desire <- new_predicate("retire");
    predicate escape_storm_desire <- new_predicate("escape_storm");

    init{
        do add_desire(wander_desire); //Initial desire for everyone
    }
   

    // === RETIREMENT ===

    reflex update_eta {
        // If retirement is disabled, don't update eta
        if (not enable_retirement) {
            return;
        }
        eta <- eta + eta_increment;

        if (eta >= retirement_age)
        {
            do add_belief(should_retire_belief);
        }
    }

    // === PERCEPTION ===
    reflex perception {
        // Oxygen
        if (oxygen_level < oxygen_level_threshold)
        {
           if (not has_belief(suffocating_belief)) 
            { 
                do add_belief(suffocating_belief); 
            }

        }
        else
        {
            if (has_belief(suffocating_belief))
            {
                do remove_belief(suffocating_belief);
            }
        }

        //Energy
        if (energy_level < energy_level_threshold)
        {
            if (not has_belief(starving_belief))
            {
                do add_belief(starving_belief);
            }
        }
        else
        {
            if (has_belief(starving_belief))
            {
                do remove_belief(starving_belief);
            }
        }

        // Health
        if (health_level < health_level_threshold)
        {
            if (not has_belief(injured_belief))
            {
                do add_belief(injured_belief);
            }
        }
        else
        {
            if (has_belief(injured_belief))
            {
                do remove_belief(injured_belief);
            }
        }
    }

    // === RULES (Belief -> Desire) === 
    
    //Max Priority 100
    rule belief: storm_warning_belief new_desire: escape_storm_desire strength: 200.0; // Most important
    rule belief: suffocating_belief new_desire: has_oxygen_desire strength: 100.0;
    rule belief: starving_belief new_desire: has_energy_desire strength: 25.0;
    rule belief: injured_belief new_desire: be_healthy_desire strength: 12.0;
    rule belief: should_retire_belief new_desire: retire_desire strength: 6.0;

    // === PLANS ===

    plan escape_storm intention: escape_storm_desire {
        state <- "escaping_storm";
        do goto target: habitat_dome.location speed: movement_speed;
        
        if (habitat_dome.shape covers location) {
            write name + " escaped the storm.";
            do remove_belief(storm_warning_belief);
            do remove_intention(escape_storm_desire, true);
            state <- "idle";
        }
    }

    plan do_retire intention: retire_desire{
        state <- "retiring";
        do goto target: landing_pad.location speed: movement_speed;
        
        if (location distance_to landing_pad.location) <= facility_proximity {
            write 'Agent ' + name + ' retired';
            do die_and_update_counter;
        }

    }

    plan get_health intention: be_healthy_desire finished_when: health_level >= max_health_level {
        // If I am at medbay i wait and queue
        if (location distance_to habitat_dome.med_bay.location <= facility_proximity) {
            state <- 'waiting_at_med_bay';
            ask habitat_dome.med_bay { do add_to_queue(myself); }
        } else {
            state <- 'going_to_med_bay';
            do goto target: habitat_dome.med_bay.location speed: movement_speed;
        }

        // Clean the queue if we are done with the healing
        if (health_level >= max_health_level) {
             ask habitat_dome.med_bay { do remove_from_queue(myself); }
             do remove_belief(injured_belief);
        }
    }

    plan get_oxygen intention: has_oxygen_desire finished_when:oxygen_level >= max_oxygen_level
    {
        if (location distance_to habitat_dome.oxygen_generator.location <= facility_proximity) {
            state <- 'refilling_oxygen';
            oxygen_level <- min(max_oxygen_level, oxygen_level + oxygen_refill_rate);
        } else {
            state <- 'going_to_oxygen';
            do goto target: habitat_dome.oxygen_generator.location speed: movement_speed;
        }
        
        if (oxygen_level >= max_oxygen_level) {
            do remove_belief(suffocating_belief);
        }
    } 

    plan get_energy intention: has_energy_desire finished_when: energy_level >= max_energy_level {
        if (location distance_to habitat_dome.greenhouse.location <= facility_proximity) {
            state <- 'refilling_energy';
            energy_level <- min(max_energy_level, energy_level + energy_refill_rate);
        } else {
            state <- 'going_to_greenhouse';
            do goto target: habitat_dome.greenhouse.location speed: movement_speed;
        }
        
        if (energy_level >= max_energy_level) {
            do remove_belief(starving_belief);
        }
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
    // Run every step regardless of the plan

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
        // If moving -> drain more
        if (state in ['going_to_oxygen', 'going_to_greenhouse', 'going_to_med_bay', 'going_to_oxygen_generator', 'retiring', 'going_to_mine', 'returning_to_dome', 'escaping_storm']) {
            energy_level <- max(0, energy_level - energy_decrease_rate_when_moving);
        } else {
            energy_level <- max(0, energy_level - energy_decrease_rate);
        }
        
        // Add storm effect
        if (wasteland.dust_storm and (wasteland.shape covers location)) {
             energy_level <- max(0, energy_level - 1.0); // Extra drain
        }
    }

    reflex update_health when: oxygen_level <= 0 or energy_level <= 0{
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

    aspect base {
        draw circle(3) color: human_color border: human_border_color;
    }

}

species Engineer parent: Human {
    
    predicate generator_broken_belief <- new_predicate("generator_broken");
    predicate fix_generator_desire <- new_predicate("fix_generator");

    reflex check_generator {
        if (habitat_dome.oxygen_generator.is_broken) {
            if (not has_belief(generator_broken_belief)) 
                { 
                    do add_belief(generator_broken_belief);
                }
        }
    }

    rule belief: generator_broken_belief new_desire: fix_generator_desire strength: 9.0;

    plan fix_generator intention: fix_generator_desire {
        if (location distance_to habitat_dome.oxygen_generator.location <= facility_proximity) {
            habitat_dome.oxygen_generator.is_broken <- false;
            do remove_belief(generator_broken_belief);
            do remove_intention(fix_generator_desire, true); // Done
            state <- 'idle';
        } else {
             state <- 'going_to_oxygen_generator';
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

    reflex update_medic_biologicals {
         // Medic at medbay does not lose hunger/oxygen (optional rule from spec)
         if (location distance_to habitat_dome.med_bay.location <= facility_proximity) {
            if (has_belief(starving_belief)) 
                { 
                    do remove_belief(starving_belief); 
                }
            // Could also stop oxygen drain, but let's keep it simple
            // TODO
         }
    }
    
    reflex check_queue {
        if (not empty(habitat_dome.med_bay.waiting_queue)) {
             if (not has_belief(patients_waiting_belief)) { do add_belief(patients_waiting_belief); }
        } else {
             if (has_belief(patients_waiting_belief)) { do remove_belief(patients_waiting_belief); }
        }
    }

    // Need to fit the value of all this beliefs so that we have a ranking
    rule belief: patients_waiting_belief new_desire: heal_patients_desire strength: 7.0;
    
    plan heal_others intention: heal_patients_desire {
        // Go to medbay
        if (location distance_to habitat_dome.med_bay.location > facility_proximity) {
            state <- 'going_to_med_bay';
            do goto target: habitat_dome.med_bay.location speed: movement_speed;
        } else {
            // At medbay
            state <- 'healing';
            
            // Pick a patient and heal
            if (current_patient = nil and not empty(habitat_dome.med_bay.waiting_queue)) {
                Human potential_patient <- habitat_dome.med_bay.waiting_queue[0];
                if (potential_patient != nil and not dead(potential_patient)) {
                    current_patient <- potential_patient;
                } else {
                    // Clean dead
                    ask habitat_dome.med_bay { do remove_from_queue(potential_patient); }
                }
            }
            
            if (current_patient != nil) {
                 // Heal them
                 ask current_patient {
                    health_level <- max_health_level;
                    oxygen_level <- max_oxygen_level;
                    energy_level <- max_energy_level;
                 }
                 write 'Medic ' + name + ' healed ' + current_patient.name;
                 ask habitat_dome.med_bay { do remove_from_queue(myself.current_patient); }
                 current_patient <- nil;
            } else {
                // Queue empty
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

    //Variables 
    float mining_start_time;

    predicate mission_time_belief <- new_predicate("mission_time");
    predicate mine_desire <- new_predicate("mine_resources");

    reflex trigger_mission {
        // Randomly decide to go on a mission if idle
        if (flip(scavenger_mission_probability) and not has_belief(mission_time_belief)) {
            do add_belief(mission_time_belief);
        }
    }

    // TO FIT
    rule belief: mission_time_belief new_desire: mine_desire strength: 5.0;

    plan perform_mining intention: mine_desire {
        if (location distance_to rock_mine.location > facility_proximity and mining_start_time = 0.0) {
            state <- 'going_to_mine';
            do goto target: rock_mine.location speed: movement_speed;
        } else {
            // At mine
            if (mining_start_time = 0.0) {
                mining_start_time <- time;
                state <- 'mining';
            }
            
            if (time - mining_start_time >= 5.0) {
                // Done mining
                state <- 'returning_to_dome';
                do goto target: habitat_dome.location speed: movement_speed;
                
                if (location distance_to habitat_dome.location <= facility_proximity) {
                     raw_amount <- raw_amount + 5;
                     mining_start_time <- 0.0; // Reset
                     do remove_belief(mission_time_belief);
                     do remove_intention(mine_desire, true);
                     state <- 'idle';
                }
            } else {
                state <- 'mining';
            }
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

species Commander parent: Human{

    reflex check_storm {
        if (wasteland.dust_storm) {
            list<Human> agents_in_wasteland <- Human where (wasteland.shape covers each.location);
            if (!empty(agents_in_wasteland)) {
                do start_conversation to: agents_in_wasteland protocol: 'fipa-propose' performative: 'propose' contents: ['Return to Base'];
                write "Commander sent 'Return to Base' to " + length(agents_in_wasteland) + " agents.";
            }
        }
    }

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
    bool dust_storm <- false;
    int storm_timer <- 0;
    
    init {
        location <- point(50, 50); // Positioned away from safe zone
        shape <- shape at_location location; // Position the shape at location
    }

    reflex manage_storm {
        if (dust_storm) {
            storm_timer <- storm_timer - 1;
            if (storm_timer <= 0) {
                dust_storm <- false;
                write "Dust storm ended.";
            }
        } else {
            if (flip(0.01)) { // 1/100 probability
                dust_storm <- true;
                storm_timer <- 15;
                write "Dust storm started in Wasteland!";
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