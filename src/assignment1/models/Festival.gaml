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
            
            create Shop number: numShop returns: shops;

            ask [shops[0], shops[2]]{
                set trait <- "food";
            }

            ask [shops[1], shops[3]]{
                set trait <- "water";
            }

            create Guest number: numGuests returns: guests;
            create SecurityGuard number: 1 returns: guard;
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

}

species Shop{
	// nil is a sort of constant in GAML for empty string
    string trait <- nil;

    aspect base{
        if (trait = "water")
        {
            draw triangle(5) color: #grey;
            draw "water shop" color: #black;

        }
        else //When trait is food
        {
            draw triangle(5) color: #brown;
            draw "food shop" color: #black;
        }
    }
}

species Guest skills:[moving]{

    int hunger <- 0;
    int thirsty <- 0;

    aspect base{
        
        rgb peopleColor <- #green;
        draw circle(3) at: location color: #pink;
        draw "guest" at: location color: #black;
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






