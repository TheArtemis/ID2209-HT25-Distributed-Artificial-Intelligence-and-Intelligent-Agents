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
    
    int hungerThreshold <- 800;
    int thirstThreshold <- 800;
    
    
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
            create SecurityGuard number: 1 returns: guards;

            // Asking to the information center
            ask center {
                set shops <- stores;
                set guard <- guards[0];
            }

            ask [guests[0], guests[4], guests[7]]{
                set hasMemory <- true;
            }
            
            ask stores {
    			location <- rnd(point(100, 100));
			}
            
            ask guests {
            	infoCenter <- center[0];
        	}
        }
}


species InformationCenter{

	point location <- infoCenterLocalization;
	list<Shop> shops;

    //Added one guard per security shop
    SecurityGuard guard;

    aspect base{
        draw square(5) color: #black;
        draw "info center" at: location color: #black;
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

    InformationCenter infoCenter <- nil;

    Shop targetShop;

    Shop memory <- nil;

    bool hasMemory <- false;

    aspect base{
        
        rgb peopleColor <- #green;
        draw circle(3) at: location color: #pink;
        draw "guest" at: location color: #black;
    }
    
    reflex manage_needs {
        hunger <- min(maxHunger, hunger + rnd(0, 1));
        thirsty <- min(maxThirst, thirsty + rnd(0, 1));

        // Go to info center when EITHER need reaches 80
        if ((hunger >= hungerThreshold or thirsty >= thirstThreshold) and onTheWayToShop = false and targetShop = nil) {
            do goto target: infoCenter.location speed: 0.3;
        }
    }
    
    // Wander around when not hungry or thirsty
    reflex wander when: hunger < hungerThreshold and thirsty < thirstThreshold and onTheWayToShop = false and targetShop = nil {
        do wander speed: 0.8;
    }

    /*
     * Reflex when guest reaches the information center
     */
    reflex reached_info_center when:
        infoCenter != nil
        and onTheWayToShop = false
        and targetShop = nil
        and (location distance_to infoCenter.location) < 1.0 {

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
        write "Going to " + targetShop + " to get " + primaryNeed + " - hunger: " + hunger + ", thirst: " + thirsty;
	}

	// Reflex to continuously move to the shop
	reflex moving_to_shop when: onTheWayToShop = true and targetShop != nil {
	    do goto target: targetShop.location speed: 0.9;
	}

    
    reflex reached_shop when: targetShop != nil and (location distance_to targetShop.location) < 1.0 {
        string shopType <- targetShop.getShopType("");
        
        // Satisfy the need for this shop type
        if (shopType = "food") {
            hunger <- 0;
            write "Ate food! Hunger reset.";
        } else if (shopType = "water") {
            thirsty <- 0;
            write "Drank water! Thirst reset.";
        }
        
        // Check if they still have another need
        bool stillNeedFood <- (hunger >= hungerThreshold);
        bool stillNeedWater <- (thirsty >= thirstThreshold);
        
        if (stillNeedFood or stillNeedWater) {
            // They still need something, go back to info center
            write "Still need something! Going back to info center.";
            targetShop <- nil;
            onTheWayToShop <- false;
            // The manage_needs reflex will send them back to info center
        } else {
            // All needs satisfied
            write "All needs satisfied!";
            onTheWayToShop <- false;
            targetShop <- nil;
        }
    }
}

species SecurityGuard skills:[moving]{
    point location <- point(25,25);


    aspect base{
        draw circle(1) at: location color: #blue;
        draw "guard" at: location color: #black;
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
        }

    }

}