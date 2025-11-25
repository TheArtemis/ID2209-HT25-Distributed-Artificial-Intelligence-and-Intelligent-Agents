/**
* Name: FestivalStages2
* Based on the internal empty template. 
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags: 
*/


model FestivalStages2


global {

    int numCenter <- 1;
    int numStages <- 3;
    int numGuests <- 10;    
    
    float movingSpeed <- 0.75;
        
    point infoCenterLocalization <- point(50,50);
    
    list<Stage> allStages;

    // Initialize the agents
        init {
            create InformationCenter number: numCenter returns: center; 
            create Stage number: numStages returns: stages;
            create Guest number: numGuests returns: guests;            
            allStages <- stages;
            ask guests {
            	infoCenter <- center[0];
                set stages <- allStages;
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

species Stage skills: [fipa] {

    // 0 is 0, 100 is 1.0
    int lightShow <- rnd(0, 100);
    int speaker <- rnd(0, 100);
    int musicStyle <- rnd(0, 100);

    int startFestivalTime <- rnd(0, 1000);
    int duration <- rnd(10000, 100000);


    int endFestivalTime <- startFestivalTime + duration;


    reflex receiveCFP when: !empty(cfps) {
        loop cfpMsg over: cfps {
            list contents_list <- list(cfpMsg.contents);
            
            if (contents_list[0] = "stats") {
                write 'Receiving stats message from ' + cfpMsg.sender;
                write 'Sending stats message to ' + cfpMsg.sender;
                write 'Stats message: lightShow: ' + lightShow + ' speaker: ' + speaker + ' musicStyle: ' + musicStyle;
                
                do propose message: cfpMsg contents: [lightShow, speaker, musicStyle];
            }
        }
    }    


    aspect base{
        draw circle(5) color: #purple;
        draw "stage" at: location color: #black;
    }    
}



species Guest skills:[moving, fipa]{
	
	list<Stage> stages;
	map<Stage, int> utilities <- nil;
    bool hasRequestedUtilities <- false;
    bool hasReceivedUtilities <- false;
    bool hasComputedUtilities <- false;
    bool hasSelectedStage <- false;
    Stage selectedStage <- nil;
    point targetLocation <- nil;
    bool isDancing <- false;
    float danceAngle <- 0.0;
    float danceRadius <- rnd(3.0, 6.0);
    point wanderTarget <- nil;
    int wanderTimer <- 0;


    int lightShowPreference <- rnd(0, 100);
    int speakerPreference <- rnd(0, 100);
    int musicStylePreference <- rnd(0, 100);

    reflex test when: true {
        //write 'Stages: ' + stages;
    }


    InformationCenter infoCenter <- nil;

    reflex request_utilities when: hasRequestedUtilities = false {
        write 'Requesting utilities from stages';
        do start_conversation to: list(Stage) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["stats"];
        hasRequestedUtilities <- true;
    }    
    
    reflex receiveProposals when: hasReceivedUtilities = false and hasRequestedUtilities = true and !empty(proposes){
        loop proposeMsg over: proposes {
            list<int> contents_list <- list<int>(list(proposeMsg.contents));
            do compute_utilities(contents_list, proposeMsg.sender);
        }
        hasReceivedUtilities <- true;
        do select_stage;
    }

    action compute_utilities(list<int> stats, Stage sender) {
        int lightShow <- stats[0];
        int speaker <- stats[1];
        int musicStyle <- stats[2];

        int utility <- lightShowPreference * lightShow + speakerPreference * speaker + musicStylePreference * musicStyle;
        utilities[sender] <- utility;
        write name + ': Utility for stage ' + sender + ' is ' + utility;
        hasComputedUtilities <- true;
    }

    action select_stage {
        int maxUtility <- 0;
        Stage bestStage <- nil;
        loop stage over: stages {
            if (utilities != nil and utilities contains_key(stage)) {
                int stageUtility <- utilities[stage];
                if (stageUtility > maxUtility) {
                    maxUtility <- stageUtility;
                    bestStage <- stage;
                }
            }
        }
        
        selectedStage <- bestStage;
        write name + ': Selected stage ' + selectedStage + ' with utility ' + maxUtility;
        hasSelectedStage <- true;
    }
    
    reflex go_to_stage when: hasSelectedStage = true and selectedStage != nil and time > selectedStage.startFestivalTime and time < selectedStage.endFestivalTime and !isDancing {
        if (targetLocation = nil) {
            float angleDeg <- rnd(0, 360);
            float angleRad <- angleDeg * #pi / 180.0;
            float distance <- rnd(6, 12);
            targetLocation <- selectedStage.location + {distance * cos(angleRad), distance * sin(angleRad)};
            wanderTarget <- nil;
        }
        do goto target: targetLocation speed: movingSpeed;
    }
    
    reflex reached_stage_area when: hasSelectedStage = true and selectedStage != nil and targetLocation != nil and (location distance_to targetLocation) < 2.0 and !isDancing {
        isDancing <- true;
        write name + ': Reached stage area and started dancing!';
    }
    
    reflex dance when: isDancing and selectedStage != nil and time > selectedStage.startFestivalTime and time < selectedStage.endFestivalTime {
        float randomAngle <- rnd(0, 360) * #pi / 180.0;
        float randomDistance <- rnd(0.5, danceRadius);
        float randomX <- rnd(-2.0, 2.0);
        float randomY <- rnd(-2.0, 2.0);
        
        point danceLocation <- targetLocation + {randomDistance * cos(randomAngle) + randomX, randomDistance * sin(randomAngle) + randomY};
        location <- danceLocation;
    }
    
    reflex stop_dancing when: isDancing and (selectedStage = nil or time < selectedStage.startFestivalTime or time > selectedStage.endFestivalTime) {
        isDancing <- false;
        targetLocation <- nil;
        danceAngle <- 0.0;
        danceRadius <- rnd(3.0, 6.0);
    }
    
    reflex wander when: !isDancing and (selectedStage = nil or time < selectedStage.startFestivalTime or time > selectedStage.endFestivalTime or (targetLocation != nil and (location distance_to targetLocation) < 2.0)) {
        wanderTimer <- wanderTimer + 1;
        if (wanderTarget = nil or (location distance_to wanderTarget) < 2.0 or wanderTimer > 20) {
            wanderTarget <- {rnd(0, 100), rnd(0, 100)};
            wanderTimer <- 0;
        }
        do goto target: wanderTarget speed: movingSpeed * 0.5;
    }

    aspect base{
        rgb peopleColor <- #green;
        if (isDancing) {
            draw circle(2) at: location color: #yellow;
            draw "DANCING!" at: location color: #red;
        } else {
            draw circle(1) at: location color: #pink;
            draw "Guest" at: location color: #black;
        }
    }
    

    action go_infocenter {
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
            species Stage aspect: base;
            species Guest aspect: base;
        } 	
    }
}



