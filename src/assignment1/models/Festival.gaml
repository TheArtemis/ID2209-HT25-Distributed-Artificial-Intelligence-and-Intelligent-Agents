/**
* Name: NewModel
* Based on the internal empty template. 
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags: 
*/


model Festival

/* Insert your model definition here */

global {
    int numCenter <- 1;
    int numShop <- 4;
    int numGuests <- 10;
    
    int maxHunger <- 1000;
    int maxThirst <- 1000;
    
    int hungerThreshold <- 300;
    int thirstThreshold <- 300;
    
    float movingSpeed <- 0.75;
    float movingSpeedUnderAttack <- 1.50;
    
    
    point infoCenterLocalization <- point(50,50);

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
        	
        }
}


species InformationCenter{

	point location <- infoCenterLocalization;
	list<Shop> shops;
	bool notifiedAboutAttack <- false;

    //Added one guard per security shop
    SecurityGuard guard;

    aspect base{
        draw square(5) color: #black;
        draw "info center" at: location color: #black;
        
        if (notifiedAboutAttack) {
        	draw "BAD GUEST REPORTED" at: location + {0, -5} color: #red font: font("Arial", 10, #bold);
        }
    }
    
    Shop getShopFor(string need) {
        // find all shops matching the requested need (trait)
        list<Shop> matching <- shops where (each.trait = need);
        if (length(matching) > 0) {
            return one_of(matching);
        } else {
            return nil;
        }
    }
    
    Shop getShopForSmart(string need, list<Shop> memory) {
        // find all shops matching the requested need (trait)
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
	// nil is a sort of constant in GAML for empty string
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

species Guest skills:[moving]{

    int hunger <- 0;
    int thirsty <- 0;
    bool onTheWayToShop <- false;
    float distanceTravelled <- 0.0;
    bool beingAttacked <- false;
    BadApple attackerRef <- nil;
    string currentAction <- "";

    InformationCenter infoCenter <- nil;

    Shop targetShop;
	
	
	// refactored
    Shop memory <- nil;
    
   
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
            statusColor <- #purple;  // Purple for both needs
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
        draw "dist: " + with_precision(distanceTravelled, 1) at: location + {0, -4} color: #darkgreen font: font("Arial", 9, #plain);
    }
    
    reflex update_needs {
    	hunger <- min(maxHunger, hunger + rnd(0, 1));
        thirsty <- min(maxThirst, thirsty + rnd(0, 1));
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
        // Go to info center when EITHER need reaches 80
        if ((hunger >= hungerThreshold or thirsty >= thirstThreshold or beingAttacked = true) and onTheWayToShop = false and targetShop = nil) {
            currentAction <- "-> Info Center";
            do go_infocenter;
        } else if (hunger < hungerThreshold and thirsty < thirstThreshold) {
        	currentAction <- "";
        }
    }
    
    // Wander around when not hungry or thirsty
    reflex wander when: hunger < hungerThreshold and thirsty < thirstThreshold and onTheWayToShop = false and targetShop = nil and beingAttacked = false {
        do wander speed: movingSpeed;
        distanceTravelled <- distanceTravelled + movingSpeed;
    }
    
    int prev_hunger <- hunger;
	int prev_thirst <- thirsty;

    /*
     * Reflex when guest reaches the information center
     */
    reflex reached_info_center when:
        infoCenter != nil
        and onTheWayToShop = false
        and targetShop = nil
        and (location distance_to infoCenter.location) < 1.0 {

        write "Reached info center; waiting for a shop to be assigned";

        // Check if guest was attacked and needs to report
        if (beingAttacked and attackerRef != nil) {
            ask infoCenter {
                do reportBadGuest(myself.attackerRef);
            }
            beingAttacked <- false;
            attackerRef <- nil;
        }

        // Check BOTH needs
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
            write "No target shop found for " + primaryNeed;
            return; 
        }
               
        onTheWayToShop <- true;
        currentAction <- "-> " + primaryNeed + " shop";
        write "The Information Center has assigned " + targetShop;
        write "Going to " + targetShop + " to get " + primaryNeed + " - hunger: " + hunger + ", thirst: " + thirsty;
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
            write "Ate food! Hunger reset.";
        } else if (shopType = "water") {
            thirsty <- 0;
            write "Drank water! Thirst reset.";
        }
	}
	
	action check_for_more_needs {
		bool stillNeedFood <- (hunger >= hungerThreshold);
        bool stillNeedWater <- (thirsty >= thirstThreshold);
        
        if (stillNeedFood or stillNeedWater) {
            // They still need something, go back to info center
            write "Still need something! Going back to info center.";
            targetShop <- nil;
            onTheWayToShop <- false;
            currentAction <- "";
            // The manage_needs reflex will send them back to info center
        } else {
            // All needs satisfied
            write "All needs satisfied!";
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

        // Check BOTH needs
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
            write "No target shop found for " + primaryNeed;
            return; 
        }
               
        onTheWayToShop <- true;
        currentAction <- "-> " + primaryNeed + " shop";
        write "The Information Center has assigned " + targetShop + " (considering memory)";
        write "Going to " + targetShop + " to get " + primaryNeed + " - hunger: " + hunger + ", thirst: " + thirsty;
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
            statusColor <- #purple;  // Purple for both needs
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
        draw "dist: " + with_precision(distanceTravelled, 1) at: location + {0, -4} color: #darkgreen font: font("Arial", 9, #plain);
        
        // Display memory size
        draw "mem: " + length(visitedPlaces) at: location + {0, -5.5} color: #purple font: font("Arial", 9, #plain);
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
            	write "Attacking a normal guest";
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
                write "Attacking a smart guest";
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
    	write("Order to eliminate guest: " + badGuest + " received");
    	add badGuest to: badActors;
    	Guest closestBadActor <- badActors closest_to self;
    	write("Executing kill order for: " + badGuest);
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
        }

    }

}