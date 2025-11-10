/**
* Name: Festival Simulation
* Author: Lorenzo
* Tags: 
*/

model festival_simulation

global {
    int num_guests <- 15;
    int num_stores <- 4;

    // Metrics
    float total_distance_no_memory <- 0.0;
    float total_distance_with_memory <- 0.0;
    
    // Decays
    float hunger_decay_rate <- 0.5;
    float thirst_decay_rate <- 0.7;
}

experiment festival type: gui {
    output {
        display main_display {
            species info_center aspect: default;
            species store aspect: default;
            species guest aspect: default;
            species security_guard aspect: default;
        }

        monitor "Number of Guests" value: count(guest);
        monitor "Killed Guests" value: count(guest where eacheach.alive = false);
    }

    init {
        create info_center number: 1;
        create store number: num_stores;
        create guest number: num_guests;
        create security_guard number: 1;

        // Assign info_center reference to all guests
        ask guest { info <- one_of(info_center); }
    }
}

species info_center {
    list stores <- all_of(store);
    security_guard guard <- one_of(security_guard);

    aspect default {
        draw triangle(6) color: rgb('white') border: rgb('green');
    }

    action ask_for_store(guest g) {
        string need <- (g.hunger < g.thirst ? "FOOD" : "WATER");
        list<store> candidates <- stores where (type = need);

        store chosen;

        if (length(g.memory) > 0 and rnd(100) < 70) {
            // 70% chance to revisit a known store
            chosen <- one_of(stores where (g.memory contains location));
        } else {
            chosen <- one_of(candidates);
            if (chosen != nil) {
                g.memory <- g.memory union [chosen.location];
            }
        }

        if (chosen != nil) {
            ask g to go_to(chosen.location);
            if (need = "FOOD") {
                ask g to replenish_food;
            } else {
                ask g to replenish_water;
            }
        }
    }

    action report_bad_guest(guest bad) {
        ask guard to handle_bad_guest(bad);
    }
}

species guest skills: [moving] {

    float hunger <- rnd(100.0);
    float thirst <- rnd(100.0);
    bool bad_guest <- rnd(10) < 2; // ~20% chance of being a bad guest
    bool alive <- true;

    list<point> memory <- [];
    float distance_traveled <- 0.0;

    info_center info; // reference to an info_center agent

    aspect default {
        if (bad_guest) {
            draw circle(3) color: rgb("red");
        } else {
            draw circle(3) color: (alive ? rgb("green") : rgb("gray"));
        }
    }

    reflex live_everywhere when: alive {
        hunger <- hunger - rnd(2);
        thirst <- thirst - rnd(2);

        if (hunger < 30 or thirst < 30) {
            if (info != nil) {
                ask info to ask_for_store(self);
            }
        } else {
            do wander_away;
        }

        // occasionally misbehave
        if (bad_guest and rnd(100) < 1) {
            if (info != nil) {
                ask info to report_bad_guest(self);
            }
        }
    }

    action go_to(point target) {
        float dist <- distance(self.location, target);
        do move target: target;
        distance_traveled <- distance_traveled + dist;
    }

    action replenish_food {
        hunger <- 100.0;
    }

    action replenish_water {
        thirst <- 100.0;
    }

    action die {
        alive <- false;
    }

    action wander_away {
        do move target: any_location_in(world);
    }
}

species store {
    string type <- (rnd_bool(0.5) ? "FOOD" : "WATER");

    aspect default {
        if (type = "FOOD") {
            draw square(4) color: rgb('brown');
        } else {
            draw square(4) color: rgb('cyan');
        }
    }
}

species security_guard skills: [moving] {
    guest target <- nil;

    aspect default {
        draw star(5) color: rgb('blue');
    }

    action handle_bad_guest(guest g) {
        target <- g;
        do move target: g.location;
        ask g to die;
    }
}
