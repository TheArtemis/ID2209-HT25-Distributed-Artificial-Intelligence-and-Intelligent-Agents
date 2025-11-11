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
        // increase at different rates
        hunger <- min(100, hunger + 2);
        thirsty <- min(100, thirsty + 1);

        if ((hunger = 100 or thirsty = 100) and onTheWayToShop = false) {
            do goto target: infoCenter.location speed: 0.3;
        }
    }

    /*
     * 
     * 
     */
    reflex reached_info_center when:
	    infoCenter != nil
	    and onTheWayToShop = false
	    and targetShop = nil
	    and (location distance_to infoCenter.location) < 1.0 {
	
	    string need <- (hunger = 100) ? "food" :
	                   ((thirsty = 100) ? "water" : nil);
	
	    if (need != nil) {
	        targetShop <- infoCenter.getShopFor(need: need);
	        if (targetShop != nil) {
	            onTheWayToShop <- true;
	            do goto target: targetShop.location speed: 0.5;
	        }
	    }
	}

    
    reflex reached_shop when: targetShop != nil and (location distance_to targetShop.location) < 1.0 {
        string need <- targetShop.getShopType("");
        
        if (need = "food") {
        	hunger <- 0;
        } else {
        	thirsty <- 0;
        }
        
        onTheWayToShop <- false;
        targetShop <- nil;
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






