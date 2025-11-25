/**
* Name: FestivalStages
* Based on the internal empty template. 
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags: 
*/


model FestivalStages


global {

    int numCenter <- 1;
    int numGuests <- 10;    
    
    float movingSpeed <- 0.75;
        
    point infoCenterLocalization <- point(50,50);    
    

    // Initialize the agents
        init {
            create InformationCenter number: numCenter returns: center;
            
            
            
            

            create Guest number: numGuests returns: guests;

            
            
            
            
            ask guests {
            	infoCenter <- center[0];
        	}
        	
        }
}

species InformationCenter{

	point location <- infoCenterLocalization;


    aspect base{
        draw square(5) color: #pink;
        draw "info center" at: location color: #black;
        
        
    }
}



species Guest skills:[moving, fipa]{


    InformationCenter infoCenter <- nil;
    
    // Receive CFP messages from auctioneer - participate when in wander state or at an auctioneer
    reflex receiveCFP when: !empty(cfps) {
        loop cfpMsg over: cfps {
            list contents_list <- list(cfpMsg.contents);
            
            // Todo: implment
        }
    }    

    aspect base{
        rgb peopleColor <- #green;
        draw circle(1) at: location color: #pink;
        draw "Guest" at: location color: #black;
       
    }
    

    action go_infocenter {
        //note: now it always goes to the info center
        do goto target: infoCenter.location speed: movingSpeed;
    }   

    reflex reached_info_center when: infoCenter != nil and (location distance_to infoCenter.location) < 1.0 {
        // todo: implement
	}   

}

experiment MyExperiment type: gui {
    
    output {
        
        display myDisplay {
            species InformationCenter aspect: base;
            species Guest aspect: base;
        } 	
    }
}



