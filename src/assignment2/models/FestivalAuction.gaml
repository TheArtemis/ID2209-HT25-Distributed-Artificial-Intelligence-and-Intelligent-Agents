/**
* Name: FestivalAuction
* Based on the internal empty template. 
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags: 
*/


model FestivalAuction


global {
    int numCenter <- 1;
    int numShop <- 4;
    int numGuests <- 10;
    int numAuctioneers <- 2;
    
    int maxHunger <- 1000;
    int maxThirst <- 1000;

    float reductionPerRound <- 100.0;
    
    int hungerThreshold <- 300;
    int thirstThreshold <- 300;
    
    float movingSpeed <- 0.75;
    float movingSpeedUnderAttack <- 1.50;
      
    // Display toggles
    bool show_distance <- false;
    bool show_memory <- false;
    bool display_favourites <- true;
    
    point infoCenterLocalization <- point(50,50);
    
    // Auction stuff
    list<string> all_items <- ["alcohol", "sugar", "astonishings"];
    float alcohol_price <- 1000.0;
    float sugar_price <- 1000.0;
    float astonishings_price <- 1000.0;    
    

    // Initialize the agents
        init {
            create InformationCenter number: numCenter returns: center;
            
            create Shop number: numShop returns: stores;        
            
            
            ask [stores[0], stores[2]]{
                set trait <- "food";
            }

            ask [stores[1], stores[3]]{
                set trait <- "water";
            }

            create Guest number: numGuests returns: guests;
            create SmartGuest number: 3 returns: smartGuests;
            create SecurityGuard number: 1 returns: guards;
            create BadApple number: 4 returns: badApples;

            // Asking to the information center
            ask center {
                set shops <- stores;
                set guard <- guards[0];
            }
            
            ask stores {
    			location <- rnd(point(100, 100));
			}
            
            ask guests {
            	infoCenter <- center[0];
        	}
        	
        	ask smartGuests {
        		infoCenter <- center[0];
        	}
        	
        	ask badApples {
        		guestsToAnnoy <- guests;
                smartToAnnoy <- smartGuests;
        		infoCenter <- center[0];
        	}
        	
        	
        	create Auctioneer number: numAuctioneers returns: auctioneers;       	
        	
        }
}

species Auctioneer skills: [fipa]{

    int auctioneer_id <- rnd(1, 1000000);
    rgb auctioneer_color <- #lightblue;

    float min_inc_coeff <- 1.1;
    float max_inc_coeff <- 1.5;
    float baseline_min_price_coeff <- 0.5;
	
	list<string> items <- all_items;

    // randomize the initial prices
    float auctioned_alcohol_price <- rnd(alcohol_price * min_inc_coeff, alcohol_price * max_inc_coeff);
    float auctioned_sugar_price <- rnd(sugar_price * min_inc_coeff, sugar_price * max_inc_coeff);
    float auctioned_astonishings_price <- rnd(astonishings_price * min_inc_coeff, astonishings_price * max_inc_coeff);  

    // this will be the price that the auctioneer will not accept to sell below
    float baseline_alcohol_price <- alcohol_price * baseline_min_price_coeff;
    float baseline_sugar_price <- sugar_price * baseline_min_price_coeff;
    float baseline_astonishings_price <- astonishings_price * baseline_min_price_coeff;    
	
    // Separate state for each auction (alcohol=0, sugar=1, astonishings=2)
    list<string> auction_state <- ["init","init","init"];
    list<float> current_auction_price <- [0.0, 0.0, 0.0];
    list<int> auction_iteration <- [0, 0, 0];
    list<string> auction_id <- [nil, nil, nil];
    float price_decrease_factor <- 0.9;

    int start_time <- rnd(15,150);
    
    // Store proposals for each item to avoid mailbox consumption issues
    map<string, list<message>> pending_proposals <- map(["alcohol"::[], "sugar"::[], "astonishings"::[]]);
    
    // Visual indicators for wins and aborts
    list<string> won_items <- [nil, nil, nil];
    list<int> won_timers <- [0, 0, 0];
    list<string> aborted_items <- [nil, nil, nil];
    list<int> aborted_timers <- [0, 0, 0];

    /* 
    
    auction_state:
    - init: the auction is not started
    - running: the auction is running
    - completed: the auction is completed
    - aborted: the auction is aborted   
    - idle: the auction is waiting to restart

    Index mapping:
    0 = alcohol
    1 = sugar
    2 = astonishings

     */

    // Start alcohol auction
    reflex start_alcohol_auction when: (auction_state[0] = "init" and time >= start_time) {
        auction_id[0] <- string(auctioneer_id) + "-alcohol-" + string(auction_iteration[0]);
        current_auction_price[0] <- auctioned_alcohol_price;
        auction_state[0] <- "running";
        
        write "Starting auction for alcohol";
        write "Initial price: " + current_auction_price[0];
        write "Auction ID: " + auction_id[0];
    }
    
    // Start sugar auction
    reflex start_sugar_auction when: (auction_state[1] = "init" and time >= start_time) {
        auction_id[1] <- string(auctioneer_id) + "-sugar-" + string(auction_iteration[1]);
        current_auction_price[1] <- auctioned_sugar_price;
        auction_state[1] <- "running";
        
        write "Starting auction for sugar";
        write "Initial price: " + current_auction_price[1];
        write "Auction ID: " + auction_id[1];
    }
    
    // Start astonishings auction
    reflex start_astonishings_auction when: (auction_state[2] = "init" and time >= start_time) {
        auction_id[2] <- string(auctioneer_id) + "-astonishings-" + string(auction_iteration[2]);
        current_auction_price[2] <- auctioned_astonishings_price;
        auction_state[2] <- "running";
        
        write "Starting auction for astonishings";
        write "Initial price: " + current_auction_price[2];
        write "Auction ID: " + auction_id[2];
    }

    // Restart idle auctions with probability
    reflex restart_idle_auctions {
        loop i from: 0 to: 2 {
            if (auction_state[i] = "idle") {
                if (flip(0.1)) { // 10% probability to restart per cycle
                    auction_state[i] <- "init";
                    write "Restarting auction " + i + " (transition from idle to init)";
                }
            }
        }
    }
    
    // Central proposal collection - runs ONCE per cycle to avoid mailbox consumption
    reflex collect_proposals when: !empty(proposes) {
        loop proposeMsg over: proposes {
            list contents_list <- list(proposeMsg.contents);
            string item <- string(contents_list[0]);

            // Add to the appropriate item's proposal list
            if (item = "alcohol") {
                add proposeMsg to: pending_proposals["alcohol"];
            } else if (item = "sugar") {
                add proposeMsg to: pending_proposals["sugar"];
            } else if (item = "astonishings") {
                add proposeMsg to: pending_proposals["astonishings"];
            }
        }
    }

    // Alcohol auction iteration
    reflex alcohol_auction_iteration when: (auction_state[0] = "running") {
        if (even(time)) {
            do auction_iteration_even(0, "alcohol", baseline_alcohol_price);
        } else {
            do auction_iteration_odd(0, "alcohol");
        }
    }
    
    // Sugar auction iteration
    reflex sugar_auction_iteration when: (auction_state[1] = "running") {
        if (even(time)) {
            do auction_iteration_even(1, "sugar", baseline_sugar_price);
        } else {
            do auction_iteration_odd(1, "sugar");
        }
    }
    
    // Astonishings auction iteration
    reflex astonishings_auction_iteration when: (auction_state[2] = "running") {
        if (even(time)) {
            do auction_iteration_even(2, "astonishings", baseline_astonishings_price);
        } else {
            do auction_iteration_odd(2, "astonishings");
        }
    }
    
    

    action auction_iteration_odd(int idx, string item) {
        // on odd rounds we receive the proposals for this auction from our stored map
        do receiveProposals(idx, item);

        // if we get here it means that no guest has won yet
        // so we lower the price for the next iteration
        current_auction_price[idx] <- current_auction_price[idx] * price_decrease_factor;
    }

    action auction_iteration_even(int idx, string item, float baseline_price) {
        // check if the current price is lower than the baseline price
        if (current_auction_price[idx] < baseline_price) {
            auction_state[idx] <- "abort";
            return;
        }

        // on even rounds we send the proposal
        write "Auction iteration for " + item;
        write "Current price: " + current_auction_price[idx];
        do sendProposalToGuests(item, current_auction_price[idx]);
    }

    action sendProposalToGuests(string item, float price) {
        write '(Time ' + time + '):' + name + ' sent a CFP for ' + item + ' at price ' + price;
        do start_conversation to: list(Guest) + list(SmartGuest) protocol: 'fipa-contract-net' performative: 'cfp' contents: [item, price];    
    }   

    action receiveProposals(int idx, string item) {
        // Get proposals for this specific item from our pending map
        list<message> item_proposes <- pending_proposals[item];
        
        write '(Time ' + time + '):' + name + ' found ' + length(item_proposes) + ' proposals for ' + item;
        
        if empty(item_proposes) {
            return;
        }

        // pick the first proposal as winner
        message winnerMsg <- item_proposes[0];
        Guest winner <- agent(winnerMsg.sender);
        
        write '(Time ' + time + '):' + name + ' received ' + length(item_proposes) + ' proposals for ' + item;
        write '(Time ' + time + '):' + name + ' selected winner: ' + winner.name;
        
        // accept the winner's proposal
        do accept_proposal message: winnerMsg contents: [item, current_auction_price[idx]];
        
        // reject all other proposals for this item (if there are any)
        if length(item_proposes) > 1 {
            loop proposeMsg over: item_proposes {
                if (proposeMsg != winnerMsg) {
                    do reject_proposal message: proposeMsg contents: ['Too late, item sold'];
                }
            }
        }
        
        // Clear the pending proposals for this item
        pending_proposals[item] <- [];
        
        auction_state[idx] <- "completed";
    }

    reflex completeAuction_alcohol when: (auction_state[0] = "completed") {
        write '(Time ' + time + '):' + name + ' completed the alcohol auction.';
        won_items[0] <- "alcohol";
        won_timers[0] <- 15;
        auction_state[0] <- "idle";
        auction_iteration[0] <- auction_iteration[0] + 1;
    }
    
    reflex completeAuction_sugar when: (auction_state[1] = "completed") {
        write '(Time ' + time + '):' + name + ' completed the sugar auction.';
        won_items[1] <- "sugar";
        won_timers[1] <- 15;
        auction_state[1] <- "idle";
        auction_iteration[1] <- auction_iteration[1] + 1;
    }
    
    reflex completeAuction_astonishings when: (auction_state[2] = "completed") {
        write '(Time ' + time + '):' + name + ' completed the astonishings auction.';
        won_items[2] <- "astonishings";
        won_timers[2] <- 15;
        auction_state[2] <- "idle";
        auction_iteration[2] <- auction_iteration[2] + 1;
    }

    reflex abortAuction_alcohol when: (auction_state[0] = "abort") {
        write '(Time ' + time + '):' + name + ' aborted the alcohol auction.';
        aborted_items[0] <- "alcohol";
        aborted_timers[0] <- 15;
        auction_state[0] <- "idle";
        auction_iteration[0] <- auction_iteration[0] + 1;
    }
    
    reflex abortAuction_sugar when: (auction_state[1] = "abort") {
        write '(Time ' + time + '):' + name + ' aborted the sugar auction.';
        aborted_items[1] <- "sugar";
        aborted_timers[1] <- 15;
        auction_state[1] <- "idle";
        auction_iteration[1] <- auction_iteration[1] + 1;
    }
    
    reflex abortAuction_astonishings when: (auction_state[2] = "abort") {
        write '(Time ' + time + '):' + name + ' aborted the astonishings auction.';
        aborted_items[2] <- "astonishings";
        aborted_timers[2] <- 15;
        auction_state[2] <- "idle";
        auction_iteration[2] <- auction_iteration[2] + 1;
    }
    
    // Update timers for win and abort displays
    reflex update_auction_status_timers {
        loop i from: 0 to: 2 {
            if (won_timers[i] > 0) {
                won_timers[i] <- won_timers[i] - 1;
                if (won_timers[i] = 0) {
                    won_items[i] <- nil;
                }
            }
            if (aborted_timers[i] > 0) {
                aborted_timers[i] <- aborted_timers[i] - 1;
                if (aborted_timers[i] = 0) {
                    aborted_items[i] <- nil;
                }
            }
        }
    }


	
	aspect base{
		draw square(5) color: auctioneer_color;
		draw "auctioneer" at: location color: #black;
		
		// Display current auctions and prices
		list<string> item_names <- ["alcohol", "sugar", "astonishings"];
		list<rgb> item_colors <- [#red, #blue, #purple];
		float y_offset <- -8.0;
		
		loop i from: 0 to: 2 {
			if (auction_state[i] = "running") {
				string item_name <- item_names[i];
				float price <- current_auction_price[i];
				rgb item_color <- item_colors[i];
				string auction_text <- item_name + ": " + with_precision(price, 1);
				draw auction_text at: location + {0, y_offset} color: item_color font: font("Arial", 10, #bold);
				y_offset <- y_offset - 2.5;
			}
			
			// Display won auctions
			if (won_items[i] != nil and won_timers[i] > 0) {
				string item_name <- item_names[i];
				rgb item_color <- item_colors[i];
				string win_text <- item_name + " SOLD!";
				draw win_text at: location + {0, y_offset} color: #green font: font("Arial", 11, #bold);
				y_offset <- y_offset - 2.5;
			}
			
			// Display aborted auctions
			if (aborted_items[i] != nil and aborted_timers[i] > 0) {
				string item_name <- item_names[i];
				rgb item_color <- item_colors[i];
				string abort_text <- item_name + " ABORTED";
				draw abort_text at: location + {0, y_offset} color: #orange font: font("Arial", 11, #bold);
				y_offset <- y_offset - 2.5;
			}
		}
	}
}

species InformationCenter{

	point location <- infoCenterLocalization;
	list<Shop> shops;
	bool notifiedAboutAttack <- false;

    SecurityGuard guard;

    aspect base{
        draw square(5) color: #black;
        draw "info center" at: location color: #black;
        
        if (notifiedAboutAttack) {
        	draw "BAD GUEST REPORTED" at: location + {0, -5} color: #red font: font("Arial", 10, #bold);
        }
    }
    
    Shop getShopFor(string need) {
        list<Shop> matching <- shops where (each.trait = need);
        if (length(matching) > 0) {
            return one_of(matching);
        } else {
            return nil;
        }
    }
    
    Shop getShopForSmart(string need, list<Shop> memory) {
        list<Shop> matching <- shops where (each.trait = need);
        
        if (length(matching) = 0) {
            return nil;
        }
        
        // Filter out shops that are in memory
        list<Shop> notInMemory <- matching where !(memory contains each);
        
        // If there are shops not in memory, return one of them
        if (length(notInMemory) > 0) {
            return one_of(notInMemory);
        } else {
            // All shops are in memory, return a random one
            return one_of(matching);
        }
    }
    
    action reportBadGuest(Guest attacker) {
    	write("Bad guest reported.");
    	notifiedAboutAttack <- true;
    	ask guard {
    		do orderToEliminate(attacker);
    	}
    }

}

species Shop{
    string trait <- nil;
    point location;

    aspect base{
        if (trait = "water")
        {
            draw triangle(5) color: #grey;
            draw "water shop" color: #black;

        }
        else
        {
            draw triangle(5) color: #brown;
            draw "food shop" color: #black;
        }
    }
    
    string getShopType(string need) {
    	return trait;
    }
}

species Guest skills:[moving, fipa]{

    int hunger <- 0;
    int thirsty <- 0;
    bool onTheWayToShop <- false;
    float distanceTravelled <- 0.0;
    bool beingAttacked <- false;
    BadApple attackerRef <- nil;
    string currentAction <- "";

    InformationCenter infoCenter <- nil;

    Shop targetShop;	
    Shop memory <- nil;

    string current_auction_id <- nil;  
    string current_auction_state <- "no_auction";
    string current_auction_item <- nil;
    list<string> skipped_auctions <- [];
    bool interested <- false;
    
    // Visual indicator for auction wins
    string won_auction_item <- nil;
    int won_auction_timer <- 0;

    /* 
        current_auction_state:
        - no_auction: we are not in an auction
        - busy: we are in an auction   
    
     */
	
	// We are interested only in the first two items
    list<string> interest_items <- first(2, shuffle(all_items));
    
    // this is the factor by which a guest will value a given item
    float min_value_factor <- 0.9;
    float max_value_factor <- 1.1;

    float alcohol_value <- rnd(alcohol_price * min_value_factor, alcohol_price * max_value_factor);
    float sugar_value <- rnd(sugar_price * min_value_factor, sugar_price * max_value_factor);
    float ashtonishings_value <- rnd(astonishings_price * min_value_factor, astonishings_price * max_value_factor);

    // Receive CFP messages from auctioneer - only participate when in wander state
    reflex receiveCFP when: !empty(cfps) and hunger < hungerThreshold and thirsty < thirstThreshold and onTheWayToShop = false and targetShop = nil and beingAttacked = false {
        loop cfpMsg over: cfps {
            list contents_list <- list(cfpMsg.contents);
            string auction_item <- string(contents_list[0]);
            float auction_price <- float(contents_list[1]);
            
            write '(Time ' + time + '):' + name + ' received CFP for ' + auction_item + ' at price ' + auction_price;
            
            // Check if interested in this item
            bool is_interested <- interest_items contains auction_item;
            
            if (!is_interested) {
                write '(Time ' + time + '):' + name + ' is not interested in ' + auction_item;
                do refuse message: cfpMsg contents: ['Not interested in this item'];
                continue;
            }
            
            // Check if price is acceptable
            float max_price;
            if (auction_item = 'alchol') {
                max_price <- alcohol_value;
            } else if (auction_item ='sugar') {
                max_price <- sugar_value;
            } else if (auction_item = 'ashtonishings') {
                max_price <- ashtonishings_value;
            }
            
            if (auction_price <= max_price) {
                write '(Time ' + time + '):' + name + ' accepts price ' + auction_price + ' for ' + auction_item + ' (max: ' + max_price + ')';
                current_auction_state <- "busy";
                current_auction_item <- auction_item;
                do propose message: cfpMsg contents: [auction_item, auction_price];
            } else {
                write '(Time ' + time + '):' + name + ' refuses price ' + auction_price + ' for ' + auction_item + ' (max: ' + max_price + ')';
                do refuse message: cfpMsg contents: ['Price too high'];
            }
        }
    }
    
    // Handle acception from auctioneer
    reflex handleAuctionResult when: !empty(accept_proposals) {
        loop acceptMsg over: accept_proposals {
            list contents_list <- list(acceptMsg.contents);
            string item <- string(contents_list[0]);
            float price <- float(contents_list[1]);
            write '(Time ' + time + '):' + name + ' WON auction for ' + item + ' at price ' + price;
            current_auction_state <- "no_auction";
            current_auction_item <- nil;
            // Set visual indicator
            won_auction_item <- item;
            won_auction_timer <- 20; // Show for 20 cycles
        }
    }
    
    // Handle rejection from auctioneer
    reflex handleRejection when: !empty(reject_proposals) {
        loop rejectMsg over: reject_proposals {
            list contents_list <- list(rejectMsg.contents);
            write '(Time ' + time + '):' + name + ' was rejected: ' + string(contents_list[0]);
            current_auction_state <- "no_auction";
            current_auction_item <- nil;
        }
    }
    
    
   
    aspect base{
        rgb peopleColor <- #green;
        draw circle(1) at: location color: #pink;
        draw "guest" at: location color: #black;
        
        // Display current action above the guest
        if (currentAction != "") {
            draw currentAction at: location + {0, 2} color: #orange font: font("Arial", 10, #bold);
        }
        
        // Display status below the guest name
        string status <- "";
        rgb statusColor <- #black;
        bool isHungry <- hunger >= hungerThreshold;
        bool isThirsty <- thirsty >= thirstThreshold;
        
        if (isHungry and isThirsty) {
            status <- "hungry & thirsty";
            statusColor <- #purple;  
        } else if (isHungry) {
            status <- "hungry";
            statusColor <- #red;
        } else if (isThirsty) {
            status <- "thirsty";
            statusColor <- #blue;
        }
        
        if (beingAttacked) {
        	status <- "UNDER ATTACK";
        	statusColor <- #red;
        }
        
        if (status != "") {
            draw status at: location + {0, -2} color: statusColor font: font("Arial", 10, #bold);
        }
        
        // Display distance travelled
        // draw "dist: " + with_precision(distanceTravelled, 1) at: location + {0, -4} color: #darkgreen font: font("Arial", 9, #plain);
        if (show_distance) {
            draw "dist: " + with_precision(distanceTravelled, 1) at: location + {0, -4} color: #darkgreen font: font("Arial", 9, #plain);
        }
        
        // Display favourites (interest items)
        if (display_favourites and length(interest_items) > 0) {
            string favourites_text <- "likes: " + string(interest_items);
            draw favourites_text at: location + {0, -6} color: #blue font: font("Arial", 9, #plain);
        }
        
        // Display auction win message
        if (won_auction_item != nil and won_auction_timer > 0) {
            draw "WON: " + won_auction_item + "!" at: location + {0, 2} color: #orange font: font("Arial", 12, #bold);
        }
    }
    
    reflex update_needs {
    	// Don't update needs if guest is participating in an auction
    	if (current_auction_state = "busy") {
    	    return;
    	}
    	hunger <- min(maxHunger, hunger + rnd(0, 1));
        thirsty <- min(maxThirst, thirsty + rnd(0, 1));
    }
    
    // Decrement timer for auction win display
    reflex update_auction_win_timer {
        if (won_auction_timer > 0) {
            won_auction_timer <- won_auction_timer - 1;
            if (won_auction_timer = 0) {
                won_auction_item <- nil;
            }
        }
    }

    action go_infocenter {
        if (beingAttacked = true)
        {
            do goto target: infoCenter.location speed: movingSpeedUnderAttack;
        }
        else
        {
            do goto target: infoCenter.location speed: movingSpeed;
            distanceTravelled <- distanceTravelled + movingSpeed;
        }
    }
    
    reflex manage_needs {
        if ((hunger >= hungerThreshold or thirsty >= thirstThreshold or beingAttacked = true) and onTheWayToShop = false and targetShop = nil) {
            currentAction <- "-> Info Center";
            do go_infocenter;
        } else if (hunger < hungerThreshold and thirsty < thirstThreshold) {
        	currentAction <- "";
        }
    }
    
    reflex wander when: hunger < hungerThreshold and thirsty < thirstThreshold and onTheWayToShop = false and targetShop = nil and beingAttacked = false {
        do wander speed: movingSpeed;
        distanceTravelled <- distanceTravelled + movingSpeed;
    }
    
    int prev_hunger <- hunger;
	int prev_thirst <- thirsty;


    reflex reached_info_center when:
        infoCenter != nil
        and onTheWayToShop = false
        and targetShop = nil
        and (location distance_to infoCenter.location) < 1.0 {

        //write "Reached info center; waiting for a shop to be assigned";

        // Check if guest was attacked and needs to report
        if (beingAttacked and attackerRef != nil) {
            ask infoCenter {
                do reportBadGuest(myself.attackerRef);
            }
            beingAttacked <- false;
            attackerRef <- nil;
        }
        // Check needs
        bool needFood <- (hunger >= hungerThreshold);
        bool needWater <- (thirsty >= thirstThreshold);
        
        // If no needs, exit early
        if (!needFood and !needWater) {
            return;
        }
        
        // Determine which need to address
        string primaryNeed;
        
        if (hunger = thirsty) {
            // If equal, choose randomly
            primaryNeed <- one_of(["food", "water"]);
        } else if (hunger > thirsty) {
            primaryNeed <- "food";
        } else {
            primaryNeed <- "water";
        }
        
        targetShop <- infoCenter.getShopFor(need: primaryNeed);
        
        if (targetShop = nil) {
            //write "No target shop found for " + primaryNeed;
            return; 
        }
               
        onTheWayToShop <- true;
        currentAction <- "-> " + primaryNeed + " shop";
        //write "The Information Center has assigned " + targetShop;
        //write "Going to " + targetShop + " to get " + primaryNeed + " - hunger: " + hunger + ", thirst: " + thirsty;
	}

	// Reflex to continuously move to the shop
	reflex moving_to_shop when: onTheWayToShop = true and targetShop != nil {
	    do goto target: targetShop.location speed: movingSpeed;
	    distanceTravelled <- distanceTravelled + movingSpeed;
	}
	
	
	action satisfy_needs {
		string shopType <- targetShop.getShopType("");
		if (shopType = "food") {
            hunger <- 0;
            //write "Ate food! Hunger reset.";
        } else if (shopType = "water") {
            thirsty <- 0;
            //write "Drank water! Thirst reset.";
        }
	}
	
	action check_for_more_needs {
		bool stillNeedFood <- (hunger >= hungerThreshold);
        bool stillNeedWater <- (thirsty >= thirstThreshold);
        
        if (stillNeedFood or stillNeedWater) {
            // They still need something, go back to info center
            //write "Still need something! Going back to info center.";
            targetShop <- nil;
            onTheWayToShop <- false;
            currentAction <- "";
            // The manage_needs reflex will send them back to info center
        } else {
            // All needs satisfied
            //write "All needs satisfied!";
            onTheWayToShop <- false;
            targetShop <- nil;
            currentAction <- "";
        }
	}

    
    reflex reached_shop when: targetShop != nil and (location distance_to targetShop.location) < 1.0 {      
        
        // Satisfy the need for this shop type
        do satisfy_needs;        
        
        // Check if they still have another need
        do check_for_more_needs;
    }
}

species SmartGuest parent: Guest{
	list <Shop> visitedPlaces;
	
	reflex manage_needs{        
        if ((hunger >= hungerThreshold or thirsty >= thirstThreshold) and onTheWayToShop = false and targetShop = nil) {
            // No visited places go to info center
            if (length(visitedPlaces)) <= 0 {
            	currentAction <- "-> Info Center";
            	do go_infocenter;
            	return;
            }
            
            bool visitNewPlace <- rnd(0, 1);  
            if (!visitNewPlace) {
            	currentAction <- "-> Info Center";
            	do go_infocenter;
            	return;
            }
            
            list shuffledPlaces <- shuffle(visitedPlaces);
            loop i from: 0 to: length(shuffledPlaces) - 1{  
            	Shop candidateShop <- shuffledPlaces[i];          	
            	if (hunger >= hungerThreshold) {   
            		if (candidateShop.trait = "food") {
            			targetShop <- candidateShop;
            			onTheWayToShop <- true;
            			currentAction <- "-> Known " + candidateShop.trait + " shop"; 
            			return;         		 
            		}        		
            		 
            	}
            	
            	if (thirsty >= thirstThreshold) {   
            		if (candidateShop.trait = "water") {
            			targetShop <- candidateShop;
            			onTheWayToShop <- true;
            			currentAction <- "-> Known " + candidateShop.trait + " shop"; 
            			return;         		 
            		}        		
            		 
            	}            	
            	
            }  
            
        } else if (hunger < hungerThreshold and thirsty < thirstThreshold) {
        	currentAction <- "";
        }
    }
    
    reflex reached_info_center when:
        infoCenter != nil
        and onTheWayToShop = false
        and targetShop = nil
        and (location distance_to infoCenter.location) < 1.0 {

        write "Smart Guest reached info center; waiting for a shop to be assigned";

        // Check if guest was attacked and needs to report
        if (beingAttacked and attackerRef != nil) {
            ask infoCenter {
                do reportBadGuest(myself.attackerRef);
            }
            beingAttacked <- false;
            attackerRef <- nil;
        }

        bool needFood <- (hunger >= hungerThreshold);
        bool needWater <- (thirsty >= thirstThreshold);
        
        // If no needs, exit early
        if (!needFood and !needWater) {
            return;
        }
        
        // Determine which need to address
        string primaryNeed;
        
        if (hunger = thirsty) {
            // If equal, choose randomly
            primaryNeed <- one_of(["food", "water"]);
        } else if (hunger > thirsty) {
            primaryNeed <- "food";
        } else {
            primaryNeed <- "water";
        }
        
        // Pass memory to info center to get a shop not in memory
        targetShop <- infoCenter.getShopForSmart(need: primaryNeed, memory: visitedPlaces);
        
        if (targetShop = nil) {
            //write "No target shop found for " + primaryNeed;
            return; 
        }
               
        onTheWayToShop <- true;
        currentAction <- "-> " + primaryNeed + " shop";
        //write "The Information Center has assigned " + targetShop + " (considering memory)";
        //write "Going to " + targetShop + " to get " + primaryNeed + " - hunger: " + hunger + ", thirst: " + thirsty;
	}
    
    reflex reached_shop when: targetShop != nil and (location distance_to targetShop.location) < 1.0 {
    	
    	if (length(visitedPlaces) <= 0) {
    		add targetShop to: visitedPlaces;
    	}    
    	
    	bool found <- false;
    	loop i from: 0 to: length(visitedPlaces) - 1{
    		if (targetShop.location = visitedPlaces[i].location)
    		{
    			found <- true;
    		}
    	}  
    	
    	
    	if (!found)
    	{
    		add targetShop to: visitedPlaces;
    	}
    	
        
        // Satisfy the need for this shop type
        do satisfy_needs;        
        
        // Check if they still have another need
        do check_for_more_needs;
        
        
    }
    
    aspect base {
        rgb peopleColor <- #black;
        draw circle(1) at: location color: #yellow;
        draw "Smart guest" at: location color: #black;
        
        // Display current action above the guest
        if (currentAction != "") {
            draw currentAction at: location + {0, 2} color: #orange font: font("Arial", 10, #bold);
        }
        
        // Display status below the guest name
        string status <- "";
        rgb statusColor <- #black;
        bool isHungry <- hunger >= hungerThreshold;
        bool isThirsty <- thirsty >= thirstThreshold;
        
        if (isHungry and isThirsty) {
            status <- "hungry & thirsty";
            statusColor <- #purple; 
        } else if (isHungry) {
            status <- "hungry";
            statusColor <- #red;
        } else if (isThirsty) {
            status <- "thirsty";
            statusColor <- #blue;
        }
        
        if (status != "") {
            draw status at: location + {0, -2} color: statusColor font: font("Arial", 10, #bold);
        }
        
        // Display distance travelled
        // draw "dist: " + with_precision(distanceTravelled, 1) at: location + {0, -4} color: #darkgreen font: font("Arial", 9, #plain);
        if (show_distance) {
            draw "dist: " + with_precision(distanceTravelled, 1) at: location + {0, -4} color: #darkgreen font: font("Arial", 9, #plain);
        }
        
        // Display memory size
        // draw "mem: " + length(visitedPlaces) at: location + {0, -5.5} color: #purple font: font("Arial", 9, #plain);
        if (show_memory) {
            draw "mem: " + length(visitedPlaces) at: location + {0, -5.5} color: #purple font: font("Arial", 9, #plain);
        }
        
        // Display favourites (interest items)
        if (display_favourites and length(interest_items) > 0) {
            string favourites_text <- "likes: " + string(interest_items);
            float y_offset <- show_memory ? -7.5 : -6.0;
            draw favourites_text at: location + {0, y_offset} color: #blue font: font("Arial", 9, #plain);
        }
    }
	
}

species BadApple skills:[moving] parent: Guest {
    list<Guest> guestsToAnnoy;
    list<SmartGuest> smartToAnnoy;

    // Tuning knobs
    float sight_radius   <- 100.0;  // how far it can see targets
    float chase_speed    <- 0.8;   // movement speed when chasing
    float attack_range   <- 1.0;   // how close to "bump"

    Guest targetGuest <- nil;
    SmartGuest smartTarget <- nil;

    aspect base {
        draw circle(1) at: location color: #red;
        draw "bad apple" at: location color: #red;
    }

    reflex cause_trouble {

        // Probability of 2/6 to attack a smart guest, otherwise the normal ones
        int pickWhichType <- rnd(0,5);
        if (pickWhichType < 2)
        {
            // shuffle candidates and pick one randomly
            list<SmartGuest> candidates <- smartToAnnoy where (self distance_to each < sight_radius);
            if (length(candidates) > 0) {
                list<SmartGuest> shuffledCandidates <- shuffle(candidates);
                smartTarget <- nil;
                loop i from: 0 to: length(shuffledCandidates) - 1 {
                    int pick <- rnd(0, 1);
                    if (pick = 1) {
                        smartTarget <- shuffledCandidates[i];
                        break;
                    }
                }
            } else {
                smartTarget <- nil;
            }
        } else
        {
            // shuffle candidates and pick one randomly
            list<Guest> candidates <- guestsToAnnoy where (self distance_to each < sight_radius);
            if (length(candidates) > 0) {
                list<Guest> shuffledCandidates <- shuffle(candidates);
                targetGuest <- nil;
                loop i from: 0 to: length(shuffledCandidates) - 1 {
                    int pick <- rnd(0, 1);
                    if (pick = 1) {
                        targetGuest <- shuffledCandidates[i];
                        break;
                    }
                }

        }
        }

        // chase if we have a target of type normal guest
        if (targetGuest != nil) {
            do goto target: targetGuest speed: chase_speed;

            // if close enough, "attack"
            if (self distance_to targetGuest < attack_range) {
            	BadApple attacker <- self;
            	//write "Attacking a normal guest";
                ask targetGuest {
                	int   hunger_bump    <- 50;    // how much hunger to add
    				int   thirst_bump    <- 30;    // how much thirst to add
    				float shove_amplitude <- 2.0;  // how much the victim stumbles
    				
                    // make life harder
                    hunger  <- min(100, hunger  + hunger_bump);
                    thirsty <- min(100, thirsty + thirst_bump);

                    // cancel their current trip so they re-plan
                    onTheWayToShop <- false;
                    targetShop <- nil;

                    // make them stumble
                    do wander amplitude: shove_amplitude;
                    
                    // Set attacked flag and go to info center
                    beingAttacked <- true;
                    attackerRef <- attacker;
                    do go_infocenter;
                }
                
            }
        }

        if (smartTarget != nil) {
            do goto target: smartTarget speed: chase_speed;

            // if close enough, "attack"
            if (self distance_to smartTarget < attack_range) {
            	BadApple attacker <- self;
                //write "Attacking a smart guest";
                ask smartTarget {
                	int   hunger_bump    <- 50;    // how much hunger to add
    				int   thirst_bump    <- 30;    // how much thirst to add
    				float shove_amplitude <- 2.0;  // how much the victim stumbles
    				
                    // make life harder
                    hunger  <- min(100, hunger  + hunger_bump);
                    thirsty <- min(100, thirsty + thirst_bump);

                    // cancel their current trip so they re-plan
                    onTheWayToShop <- false;
                    targetShop <- nil;

                    // make them stumble
                    do wander amplitude: shove_amplitude;
                    
                    // Set attacked flag and go to info center
                    beingAttacked <- true;
                    attackerRef <- attacker;
                    do go_infocenter;
                }
                
            }
        }
                
        }
        



    
}

species SecurityGuard skills:[moving]{
    point location <- point(25,25);
    list<Guest> badActors <- nil;
    Guest latestBadActor <- nil;


    aspect base{
        draw circle(1) at: location color: #blue;
        draw "guard" at: location color: #black;
    }
    
    action orderToEliminate(Guest badGuest) {
    	//write("Order to eliminate guest: " + badGuest + " received");
    	add badGuest to: badActors;
    	Guest closestBadActor <- badActors closest_to self;
    	//write("Executing kill order for: " + badGuest);
    	latestBadActor <- closestBadActor;
    	do goto target: closestBadActor.location speed: 1.2;
    }
    
    reflex killNearbyBadActors when: latestBadActor != nil and (location distance_to latestBadActor.location) < 1.0  {
    	ask latestBadActor {
            write "A BadApple has been caught!";
            do die;
        }
        latestBadActor <- nil;
    }
}


experiment MyExperiment type:gui{
    output
    {
        display myDisplay
        {
            species InformationCenter aspect: base;
            species SecurityGuard aspect: base;
            species Guest aspect: base;
            species Shop aspect: base;
            species SmartGuest aspect: base;
            species BadApple aspect: base;
            species Auctioneer aspect: base;
        }

    }

}


