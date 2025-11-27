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

     init {
        create InformationCenter number: numCenter returns: center; 
        create Stage number: numStages returns: stages;
        create Guest number: numGuests returns: guests;            

        allStages <- stages;

        ask center {
            allGuests <- guests;
            allStages <- stages;
        }

        ask guests {
            infoCenter <- center[0];
            set stages <- allStages;
            allGuests <- guests;         // NEW: every guest knows all other guests
        }
    }

}

species InformationCenter skills:[fipa] {

    point location <- infoCenterLocalization;

    // ---- leader data ----
    list<Guest> allGuests <- [];
    list<Stage> allStages <- [];
    map<Guest, Stage> currentAssignment <- nil;
    map<Stage, int> currentCrowd <- nil;

    float currentGlobalUtility <- 0.0;
    float bestGlobalUtility <- -1.0;
    int noImprovementSteps <- 0;
    int maxNoImprovementSteps <- 25; // after 10 steps with no improvement -> stop
    bool allInitialChoicesReceived <- false;
    bool globalOptimumReached <- false;
    
    float initialGlobalUtility <- 0.0;
    bool initialGlobalUtilityRecorded <- false;

    aspect base{
        draw square(5) color: #pink;
        draw "info center" at: location color: #black;
        // current global utility
        draw ("Global U: " + currentGlobalUtility) at: location + {0, -5} color: #blue;
        // initial global utility (only once recorded)
        if (initialGlobalUtilityRecorded) {
            draw ("Initial U: " + initialGlobalUtility) at: location + {0, -10} color: #red;
        }
    }

    // guests send: ["choice", selectedStage] once
	reflex receive_initial_choices when: !empty(informs) and !globalOptimumReached and !allInitialChoicesReceived {
	    loop msg over: informs {
	        list contents_list <- list(msg.contents);
	        if (contents_list[0] = "choice") {
	            Stage chosen <- contents_list[1] as Stage;
	            Guest g <- msg.sender as Guest;
	            currentAssignment[g] <- chosen;
	            write "Leader: received initial choice from " + g + " -> " + chosen;
	        }
	    }
	
	    if (length(currentAssignment) = length(allGuests) and !allInitialChoicesReceived) {
	        allInitialChoicesReceived <- true;
	        write "Leader: All initial choices received.";
	        do recompute_crowds_and_global_utility;
	    }
	}

    action recompute_crowds_and_global_utility {

        // reset crowd counts
        currentCrowd <- nil;
        loop st over: allStages {
            currentCrowd[st] <- 0;
        }

        // count how many guests per stage
	    loop g over: allGuests {
	        Stage st <- currentAssignment[g];
	        if (st != nil) {
	            currentCrowd[st] <- currentCrowd[st] + 1;
	        }
	    }
	
	    loop st over: allStages {
	        st.currentCrowd <- currentCrowd[st];
	    }
	
	    int totalGuests <- length(allGuests);
	    float newGlobalUtility <- 0.0;

        // compute global utility
        loop g over: allGuests {
            Stage st <- currentAssignment[g];
            if (st != nil and g.utilities != nil and g.utilities contains_key(st)) {
                int baseU <- g.utilities[st];

                int crowdOnStage <- currentCrowd[st];

                float crowdRatio <- 0.0;
                if (totalGuests > 0) {
                    crowdRatio <- (crowdOnStage as float) / (totalGuests as float);
                }

                float preferredRatio <- (g.crowdMassPreference as float) / 100.0;

                // crowdU ∈ [0,1], maximum when crowdRatio == preferredRatio
                float diff <- crowdRatio - preferredRatio;
                if (diff < 0.0) {
                    diff <- -diff;
                }

                float crowdU <- 1.0 - diff;
                if (crowdU < 0.0) {
                    crowdU <- 0.0;
                }

                // weight crowd vs base: 70% base, 30% crowd
                float effective <- (0.7 * (baseU as float)) + (0.3 * crowdU * 1000000.0);

                newGlobalUtility <- newGlobalUtility + effective;
            }
        }

        currentGlobalUtility <- newGlobalUtility;
        
        if (allInitialChoicesReceived and !initialGlobalUtilityRecorded) {
            initialGlobalUtilityRecorded <- true;
            initialGlobalUtility <- currentGlobalUtility;
        }

        write "===== GLOBAL UTILITY =====";
        write "Global utility: " + currentGlobalUtility;
        loop st over: allStages {
            write "Stage " + st + " has " + currentCrowd[st] + " guest(s).";
        }
        write "==========================";

        if (currentGlobalUtility > bestGlobalUtility) {
            bestGlobalUtility <- currentGlobalUtility;
            noImprovementSteps <- 0;
        } else {
            noImprovementSteps <- noImprovementSteps + 1;
        }

        if (noImprovementSteps >= maxNoImprovementSteps and !globalOptimumReached) {
		    globalOptimumReached <- true;
		    write "***** MAX GLOBAL UTILITY APPROXIMATELY REACHED *****";
		    write "Best global utility: " + bestGlobalUtility;
		    loop g over: allGuests {
		        do start_conversation
		            to: [g]
		            protocol: 'fipa-contract-net'
		            performative: 'inform'
		            contents: ["optimization_finished"];
		    }
		}
    }
	
	
    // using true change in GLOBAL utility (not only individual gain)
    reflex propose_switches when: (cycle mod 30) = 0 and allInitialChoicesReceived and !globalOptimumReached {

        int totalGuests <- length(allGuests);
        if (totalGuests = 0) {
            globalOptimumReached <- true;
        } else {

            Guest bestGuest <- nil;
            Stage bestNewStage <- nil;
            float bestDeltaGlobal <- 0.0;

            // Try each guest as a candidate for switching
            loop g over: allGuests {

                Stage currentSt <- currentAssignment[g];

                // need a current assignment and a utilities map for this guest
                if (currentSt != nil and g.utilities != nil and g.utilities contains_key(currentSt) and !g.optimizationFinished) {

                    // ----- current effective utility of g on its current stage -----
                    int baseCurrentG <- g.utilities[currentSt];
                    int crowdCurrentA <- currentCrowd[currentSt];

                    float crowdRatioCurrentA <- 0.0;
                    if (totalGuests > 0) {
                        crowdRatioCurrentA <- (crowdCurrentA as float) / (totalGuests as float);
                    }

                    float preferredRatioG <- (g.crowdMassPreference as float) / 100.0;
                    float diffCurrentA <- crowdRatioCurrentA - preferredRatioG;
                    if (diffCurrentA < 0.0) {
                        diffCurrentA <- -diffCurrentA;
                    }
                    float crowdUG_A <- 1.0 - diffCurrentA;
                    if (crowdUG_A < 0.0) {
                        crowdUG_A <- 0.0;
                    }

                    float effG_A <- (0.7 * (baseCurrentG as float)) + (0.3 * crowdUG_A * 1000000.0);

                    // ----- try moving g to each other stage B -----
                    loop B over: allStages {

                        if (B != currentSt and g.utilities contains_key(B)) {

                            // old crowds on A (currentSt) and B
                            int crowdOldA <- currentCrowd[currentSt];
                            int crowdOldB <- currentCrowd[B];

                            // simulate new crowds if g moves: A loses one, B gains one
                            int crowdNewA <- crowdOldA - 1;
                            int crowdNewB <- crowdOldB + 1;

                            // ---------- delta utility for g itself ----------
                            int baseG_B <- g.utilities[B];

                            float crowdRatioNewB_forG <- 0.0;
                            if (totalGuests > 0) {
                                crowdRatioNewB_forG <- (crowdNewB as float) / (totalGuests as float);
                            }

                            float diffNewB_forG <- crowdRatioNewB_forG - preferredRatioG;
                            if (diffNewB_forG < 0.0) {
                                diffNewB_forG <- -diffNewB_forG;
                            }
                            float crowdUG_B <- 1.0 - diffNewB_forG;
                            if (crowdUG_B < 0.0) {
                                crowdUG_B <- 0.0;
                            }

                            float effG_B <- (0.7 * (baseG_B as float)) + (0.3 * crowdUG_B * 1000000.0);

                            float deltaGlobal <- effG_B - effG_A;

                            // ---------- delta utility for other guests on A or B ----------
                            loop h over: allGuests {

                                if (h != g and h.utilities != nil) {

                                    Stage st_h <- currentAssignment[h];

                                    // Guests on A (g leaves, crowd A decreases by 1)
                                    if (st_h = currentSt and h.utilities contains_key(currentSt)) {

                                        int base_h_A <- h.utilities[currentSt];
                                        float prefRatio_h <- (h.crowdMassPreference as float) / 100.0;

                                        // old eff on A with old crowd
                                        float crowdRatioOldA <- 0.0;
                                        if (totalGuests > 0) {
                                            crowdRatioOldA <- (crowdOldA as float) / (totalGuests as float);
                                        }
                                        float diffOldA <- crowdRatioOldA - prefRatio_h;
                                        if (diffOldA < 0.0) {
                                            diffOldA <- -diffOldA;
                                        }
                                        float crowdUOldA <- 1.0 - diffOldA;
                                        if (crowdUOldA < 0.0) {
                                            crowdUOldA <- 0.0;
                                        }
                                        float effOld_h <- (0.7 * (base_h_A as float)) + (0.3 * crowdUOldA * 1000000.0);

                                        // new eff on A with new crowd
                                        float crowdRatioNewA <- 0.0;
                                        if (totalGuests > 0) {
                                            crowdRatioNewA <- (crowdNewA as float) / (totalGuests as float);
                                        }
                                        float diffNewA <- crowdRatioNewA - prefRatio_h;
                                        if (diffNewA < 0.0) {
                                            diffNewA <- -diffNewA;
                                        }
                                        float crowdUNewA <- 1.0 - diffNewA;
                                        if (crowdUNewA < 0.0) {
                                            crowdUNewA <- 0.0;
                                        }
                                        float effNew_h <- (0.7 * (base_h_A as float)) + (0.3 * crowdUNewA * 1000000.0);

                                        deltaGlobal <- deltaGlobal + (effNew_h - effOld_h);
                                    }

                                    // Guests on B (g joins, crowd B increases by 1)
                                    else if (st_h = B and h.utilities contains_key(B)) {

                                        int base_h_B <- h.utilities[B];
                                        float prefRatio_h2 <- (h.crowdMassPreference as float) / 100.0;

                                        // old eff on B with old crowd
                                        float crowdRatioOldB <- 0.0;
                                        if (totalGuests > 0) {
                                            crowdRatioOldB <- (crowdOldB as float) / (totalGuests as float);
                                        }
                                        float diffOldB <- crowdRatioOldB - prefRatio_h2;
                                        if (diffOldB < 0.0) {
                                            diffOldB <- -diffOldB;
                                        }
                                        float crowdUOldB <- 1.0 - diffOldB;
                                        if (crowdUOldB < 0.0) {
                                            crowdUOldB <- 0.0;
                                        }
                                        float effOld_h2 <- (0.7 * (base_h_B as float)) + (0.3 * crowdUOldB * 1000000.0);

                                        // new eff on B with new crowd
                                        float crowdRatioNewB_forH <- 0.0;
                                        if (totalGuests > 0) {
                                            crowdRatioNewB_forH <- (crowdNewB as float) / (totalGuests as float);
                                        }
                                        float diffNewB_forH <- crowdRatioNewB_forH - prefRatio_h2;
                                        if (diffNewB_forH < 0.0) {
                                            diffNewB_forH <- -diffNewB_forH;
                                        }
                                        float crowdUNewB <- 1.0 - diffNewB_forH;
                                        if (crowdUNewB < 0.0) {
                                            crowdUNewB <- 0.0;
                                        }
                                        float effNew_h2 <- (0.7 * (base_h_B as float)) + (0.3 * crowdUNewB * 1000000.0);

                                        deltaGlobal <- deltaGlobal + (effNew_h2 - effOld_h2);
                                    }
                                }
                            }

                            // keep the move that gives the best positive gain in GLOBAL utility
                            if (deltaGlobal > bestDeltaGlobal) {
                                bestDeltaGlobal <- deltaGlobal;
                                bestGuest <- g;
                                bestNewStage <- B;
                            }
                        }
                    }
                }
            }

            // After checking all candidates, propose the single best switch (if any)
            if (bestGuest != nil and bestNewStage != nil and bestDeltaGlobal > 0.0) {
                write "Leader: proposing switch (GLOBAL) " + bestGuest + " from "
                    + currentAssignment[bestGuest] + " to " + bestNewStage
                    + " (ΔGlobal=" + bestDeltaGlobal + ")";

                do start_conversation
                    to: [bestGuest]
                    protocol: 'fipa-contract-net'
                    performative: 'inform'
                    contents: ["switch_to", bestNewStage];
            } else {
                // no move increases global utility: count one "no improvement" step
                noImprovementSteps <- noImprovementSteps + 1;
                if (noImprovementSteps >= maxNoImprovementSteps and !globalOptimumReached) {
                    globalOptimumReached <- true;
                    write "***** MAX GLOBAL UTILITY APPROXIMATELY REACHED (no improving moves) *****";
                    write "Best global utility: " + bestGlobalUtility;
                    loop g over: allGuests {
                        do start_conversation
                            to: [g]
                            protocol: 'fipa-contract-net'
                            performative: 'inform'
                            contents: ["optimization_finished"];
                    }
                }
            }
        }
    }
    
    reflex receive_choice_updates when: (cycle mod 15) = 0 and !empty(informs) and allInitialChoicesReceived and !globalOptimumReached {
	    loop msg over: informs {
	        list contents_list <- list(msg.contents);
	        if (contents_list[0] = "choice_update") {
	            Stage newSt <- contents_list[1] as Stage;
	            Guest g <- msg.sender as Guest;
	            currentAssignment[g] <- newSt;
	            write "Leader: updated choice for " + g + " -> " + newSt;
	        }
	    }
	
	    if (!globalOptimumReached) {
	        do recompute_crowds_and_global_utility;
	    }
	}

}


species Stage skills: [fipa] {

    int lightShow <- rnd(0, 100);
    int speaker <- rnd(0, 100);
    int musicStyle <- rnd(0, 100);

    int startFestivalTime <- rnd(0, 1000);
    int duration <- rnd(1000000, 10000000);

    int endFestivalTime <- startFestivalTime + duration;

    int currentCrowd <- 0;

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
        draw ("crowd: " + currentCrowd) at: location + {0, -4} color: #blue;
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

    list<Guest> allGuests;

    int crowdMassPreference <- rnd(0, 100);
    bool prefersLargeCrowd <- crowdMassPreference > 50;
    bool hasInformedLeader <- false;
    bool optimizationFinished <- false;

    map<Stage, int> localCrowdEstimate <- nil;
    bool hasSharedChoiceWithGuests <- false;
    bool hasRefinedInitialChoice <- false;

    int lightShowPreference <- rnd(0, 100);
    int speakerPreference <- rnd(0, 100);
    int musicStylePreference <- rnd(0, 100);
    
    Stage initialStage <- nil;
    int initialUtility <- 0;
    bool initialChoiceRecorded <- false;

    InformationCenter infoCenter <- nil;

    // 1) ask stages for their stats
    reflex request_utilities when: hasRequestedUtilities = false {
        write 'Requesting utilities from stages';
        do start_conversation to: list(Stage) protocol: 'fipa-contract-net' performative: 'cfp' contents: ["stats"];
        hasRequestedUtilities <- true;
    }    
    
    // 2) receive proposals from stages and compute base utilities
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

        int baseUtility <- lightShowPreference * lightShow
                         + speakerPreference    * speaker
                         + musicStylePreference * musicStyle;

        utilities[sender] <- baseUtility;
        write name + ': Base utility for stage ' + sender + ' is ' + baseUtility;
        hasComputedUtilities <- true;
    }

    // 3) initial local choice, including a first crowd-mass term (rough, before messages)
    action select_stage {
        int maxEffectiveU <- -1;
        Stage bestStage <- nil;

        int nbStages <- length(stages);
        float assumedRatio <- (nbStages > 0) ? (1.0 / (nbStages as float)) : 0.0;
        float preferredRatio <- (crowdMassPreference as float) / 100.0;

        float diffAssumed <- assumedRatio - preferredRatio;
        if (diffAssumed < 0.0) { diffAssumed <- -diffAssumed; }
        float crowdU_assumed <- 1.0 - diffAssumed;
        if (crowdU_assumed < 0.0) { crowdU_assumed <- 0.0; }

        loop stage over: stages {
            if (utilities != nil and utilities contains_key(stage)) {
                int baseU <- utilities[stage];

                // combine baseU with this guest's crowd preference (assumed)
                float eff <- (0.7 * (baseU as float)) + (0.3 * crowdU_assumed * 1000000.0);
                int effInt <- eff as int;

                if (effInt > maxEffectiveU) {
                    maxEffectiveU <- effInt;
                    bestStage <- stage;
                }
            }
        }
        
        selectedStage <- bestStage;
        write name + ': Initial selected stage ' + selectedStage + ' with effective utility ' + maxEffectiveU;
        hasSelectedStage <- true;
        
        // record initial choice & utility only once (based on this first effective choice)
        if (!initialChoiceRecorded) {
            initialChoiceRecorded <- true;
            initialStage <- bestStage;
            initialUtility <- maxEffectiveU;
        }
    }

    // 4) go to currently selected stage
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
    
    // 5) inform leader of choice
    reflex inform_leader_choice when: hasSelectedStage and !hasInformedLeader {
	    if (selectedStage != nil and infoCenter != nil) {
	        write name + ': Informing leader about initial choice ' + selectedStage;
	        do start_conversation
			    to: [infoCenter]
			    protocol: 'fipa-contract-net'
			    performative: 'inform'
			    contents: ["choice", selectedStage];
	        hasInformedLeader <- true;
	    }
	}

    // 6) inform all other guests of our choice 
    reflex inform_guests_choice when: hasSelectedStage and !hasSharedChoiceWithGuests {
        if (selectedStage != nil and !empty(allGuests)) {
            write name + ': Broadcasting choice ' + selectedStage + ' to other guests';
            do start_conversation
                to: allGuests
                protocol: 'fipa-contract-net'
                performative: 'inform'
                contents: ["guest_choice", selectedStage];
            
            // initialize our local estimate with at least ourselves
            if (localCrowdEstimate = nil) {
                // GAMA will create the map when assigning the first key
            }
            localCrowdEstimate[selectedStage] <- (localCrowdEstimate[selectedStage] + 1);
            hasSharedChoiceWithGuests <- true;
        }
    }
    
    // 7) refine initial choice based on REAL crowd mass from guest messages
    reflex refine_initial_choice_with_crowd when: hasSharedChoiceWithGuests and !hasRefinedInitialChoice and cycle > 15 {
        // Build default 0 counts if never set
        loop st over: stages {
            if (localCrowdEstimate = nil or !(localCrowdEstimate contains_key(st))) {
                localCrowdEstimate[st] <- 0;
            }
        }

        // ensure our own presence is counted at least once
        if (selectedStage != nil) {
            localCrowdEstimate[selectedStage] <- localCrowdEstimate[selectedStage] + 1;
        }

        int totalGuestsLocal <- length(allGuests);
        if (totalGuestsLocal <= 0) {
            hasRefinedInitialChoice <- true; // nothing to refine
        } else {

            float preferredRatio <- (crowdMassPreference as float) / 100.0;

            float bestEff <- -1.0;
            Stage bestStage <- selectedStage;

            loop st over: stages {
                if (utilities != nil and utilities contains_key(st)) {
                    int baseU <- utilities[st];
                    int crowdCount <- localCrowdEstimate[st];

                    float crowdRatio <- (crowdCount as float) / (totalGuestsLocal as float);
                    float diff <- crowdRatio - preferredRatio;
                    if (diff < 0.0) { diff <- -diff; }

                    float crowdU <- 1.0 - diff;
                    if (crowdU < 0.0) { crowdU <- 0.0; }

                    float eff <- (0.7 * (baseU as float)) + (0.3 * crowdU * 1000000.0);

                    if (eff > bestEff) {
                        bestEff <- eff;
                        bestStage <- st;
                    }
                }
            }

            if (bestStage != selectedStage and bestStage != nil) {
                write name + ': Refined choice with crowd info: switching from ' + selectedStage + ' to ' + bestStage;
                // reset movement so we re-target
                isDancing <- false;
                targetLocation <- nil;
                wanderTarget <- nil;
                wanderTimer <- 0;
                selectedStage <- bestStage;

                // inform leader of the updated initial choice
                if (infoCenter != nil) {
                    do start_conversation
                        to: [infoCenter]
                        protocol: 'fipa-contract-net'
                        performative: 'inform'
                        contents: ["choice_update", selectedStage];
                }
            } else {
                write name + ': Refined choice: staying at stage ' + selectedStage;
            }

            hasRefinedInitialChoice <- true;
        }
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
    
    reflex wander when: !isDancing and selectedStage = nil {
        wanderTimer <- wanderTimer + 1;
        if (wanderTarget = nil or (location distance_to wanderTarget) < 2.0 or wanderTimer > 20) {
            wanderTarget <- {rnd(0, 100), rnd(0, 100)};
            wanderTimer <- 0;
        }
        do goto target: wanderTarget speed: movingSpeed * 0.5;
    }

    // 8) handle ALL incoming inform messages (from leader AND from other guests)
    reflex handle_informs when: !empty(informs) {
        loop msg over: informs {
            list contents_list <- list(msg.contents);
            string tag <- contents_list[0] as string;

            // Ignore our own broadcasts to avoid double counting
            if (msg.sender = self) {
                continue;
            }

            // Leader says: we reached max global utility
            if (tag = "optimization_finished") {
                optimizationFinished <- true;
                write name + ": Optimization finished, enjoying the show!";
            }

            // Leader suggests a switch to a different stage (global optimization)
            else if (tag = "switch_to" and !optimizationFinished) {
                Stage proposedStage <- contents_list[1] as Stage;

                write name + ": Leader suggests switching to " + proposedStage + ". ACCEPT.";

                // stop current dancing / movement so we can re-target
                isDancing <- false;
                targetLocation <- nil;
                wanderTarget <- nil;
                wanderTimer <- 0;

                // switch to the new stage
                selectedStage <- proposedStage;

                // Inform leader of new choice so it can update assignments
                if (infoCenter != nil) {
                    do start_conversation
                        to: [infoCenter]
                        protocol: 'fipa-contract-net'
                        performative: 'inform'
                        contents: ["choice_update", selectedStage];
                }
            }

            else if (tag = "guest_choice") {
                Stage st <- contents_list[1] as Stage;
                if (localCrowdEstimate = nil) {
                    // ... ignore
                }
                localCrowdEstimate[st] <- localCrowdEstimate[st] + 1;
            }
        }
    }

    aspect base {
	
	    rgb prefColor <- prefersLargeCrowd ? #green : #blue;
	
	    if (isDancing) {
	        draw circle(2) at: location color: prefColor;
	        draw "DANCING!" at: location color: #red;
	    } else {
	        draw circle(1.3) at: location color: prefColor;
	        draw "Guest" at: location + {0, -1.5} color: #black;
	    }
	
	    // icon/text showing crowd mass preference
	    string prefText <- prefersLargeCrowd ?
	        "Crowd pref: LARGE (" + crowdMassPreference + ")" :
	        "Crowd pref: SMALL (" + crowdMassPreference + ")";
	
	    draw prefText at: location + {0, 2.5} color: #gray;
	
	    // optional emojis
	    string emoji <- prefersLargeCrowd ? "👥" : "🧍";
	    draw emoji at: location + {0, 4} color: #darkgray;
	
	
	    // ===== EXISTING VISUALS =====
	    if (selectedStage != nil) {
	        draw ("Cur stage: " + selectedStage) at: location + {0, -3.5} color: #black;
	    }
	
	    if (initialChoiceRecorded) {
	        draw ("Init stage: " + initialStage) at: location + {0, 6} color: #gray;
	        draw ("Init U: " + initialUtility) at: location + {0, 8} color: #blue;
	    }
	}


    action go_infocenter {
        do goto target: infoCenter.location speed: movingSpeed;
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



