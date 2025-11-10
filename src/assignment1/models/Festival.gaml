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
            create InformationCenter number: numCenter;
            
            create Shop number: numShop;

            create Guest number: numGuests;
        }
}


species InformationCenter{

	point location <- infoCenterLocalization;
	
    aspect base{
        draw square(10) color: #black;
    }

}

species Shop{
	// nil is a sort of constant in GAML for empty string
    string trait <- nil;

    aspect base{
        if (trait = "water")
        {
            draw triangle(5) color: #blue;

        }
        else //When trait is food
        {
            draw triangle(5) color: #brown;
        }
    }
}

species Guest skills:[moving]{

    int hunger <- 0;
    int thirsty <- 0;

    aspect base{
        
        rgb peopleColor <- #green;

    }

}

experiment MyExperiment type:gui{
    output
    {
        display myDisplay
        {
            species InformationCenter aspect:base;
        }

    }

}






