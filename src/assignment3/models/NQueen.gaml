/**
* Name: queen
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags: 
*/


model NQueen


global {
    int neighbors <- 8;
    // This value is to be defined and corrected later
    int queens <- 19;
    
    init{
        create Queen number: queens;
        // Set up circular predecessor/successor chain after all queens are created
        loop i from: 0 to: length(Queen) - 1 {
            Queen current <- Queen[i];
            // Predecessor: previous queen, or last queen if current is first (circular)
            if i > 0 {
                current.predecessor <- Queen[i - 1];
            } else {
                current.predecessor <- Queen[length(Queen) - 1]; // Queen0's predecessor is last queen
            }
            // Successor: next queen, or first queen if current is last (circular)
            if i < length(Queen) - 1 {
                current.successor <- Queen[i + 1];
            } else {
                current.successor <- Queen[0]; // Last queen's successor is Queen0
            }
        }
        write "Circular chain established: " + length(Queen) + " queens linked.";
    }
    
    list<chessBoardCell> allCells;
    list<Queen> allQueens;
    bool isCalculating <- false;
}


species Queen skills:[fipa]{

    chessBoardCell myCell <- one_of (chessBoardCell);
    list<list<int>> occupancyGrid;
    bool awaitingResponse <- false;
    string messageContext <- "";
    chessBoardCell requestedTargetCell <- nil;
    
    // Each queen knows only its predecessor and successor
    Queen predecessor <- nil;
    Queen successor <- nil;
    
    rgb myColor <- #black;

    init {
        //Assign a free cell
        loop cell over: myCell.neighbours{
            if cell.queen = nil{
                myCell <- cell;
                break;
            }
        }
        location <- myCell.location;
        myCell.queen <- self;
        add self to: allQueens;
        do refreshOccupancyGrid;
    }


    action refreshOccupancyGrid{
        self.occupancyGrid <- [];
        loop m from:0 to:queens-1{
            list<int> mList;
            loop n from:0 to: queens-1{
                add 0 to: mList;    
            }
            add mList to: occupancyGrid;
        }
    }

    action calculateOccupancyGrid{
        do refreshOccupancyGrid;
        //identify occupied cells
        loop cell over:allCells{
            if cell.queen != nil and cell.queen != self{
                self.occupancyGrid[cell.grid_x][cell.grid_y] <- 1000;
            }
        }
        //evaluate free AllCells
        loop cell over:allCells{
            int m <- cell.grid_x;
            int n <- cell.grid_y;
             if self.occupancyGrid[int(m)][int(n)] = 1000{
                loop i from: 1 to:queens{
                    //Up
                    int mi <- int(m) + i;
                    if mi < queens{
                        self.occupancyGrid[mi][n] <- self.occupancyGrid[mi][n] + 1;
                    }
                    //Down
                    int n_mi <- int(m) - i;
                    if n_mi > -1{
                        self.occupancyGrid[n_mi][n] <- self.occupancyGrid[n_mi][n] + 1;
                    }
                    // Right
                    int ni <- int(n) + i;
                    if ni < queens{
                        self.occupancyGrid[m][ni] <- self.occupancyGrid[m][ni] + 1;
                    }
                    //Left
                    int n_ni <- int(n) - i;
                    if n_ni > -1{
                        self.occupancyGrid[m][n_ni] <- self.occupancyGrid[m][n_ni] + 1;
                    }
                    //top right diagonal
                    if mi < queens and ni < queens{
                        self.occupancyGrid[mi][ni] <- self.occupancyGrid[mi][ni] + 1;
                    }
                    //bottom right diagonal
                    if n_mi > -1 and ni < queens{
                        self.occupancyGrid[n_mi][ni] <- self.occupancyGrid[n_mi][ni] + 1;
                    }
                    //top left diagonal
                    if mi < queens and n_ni > -1{
                        self.occupancyGrid[mi][n_ni] <- self.occupancyGrid[mi][n_ni] + 1;
                    }
                    //bottom left diagonal
                    if n_mi > -1 and n_ni > -1{
                        self.occupancyGrid[n_mi][n_ni] <- self.occupancyGrid[n_mi][n_ni] + 1;
                    }
                }
             }
        }
    }


    list<point> availableallCells(int val) {
        list<point> Checks;
        loop cell over: allCells{
            int m <- cell.grid_x;
            int n <- cell.grid_y;
            if self.occupancyGrid[int(m)][int(n)] = val and !(m = myCell.grid_x and n = myCell.grid_y){
            	add {int(m),int(n)} to: Checks;
            }
        }
        return Checks;
    }

    Queen findQueenInSightbyLocation(int x){
    	list<Queen> queensInSight;
    	
    	loop cell over: allCells{
            int m <- cell.grid_x;
            int n <- cell.grid_y;
            
            if self.occupancyGrid[m][n] > 999{
            	if m = self.myCell.grid_x {
            		add cell.queen to: queensInSight;
            	}
            	else if n = self.myCell.grid_y {
            		add cell.queen to: queensInSight;
            	}
            	else{
            		int diff_x <- abs(m - self.myCell.grid_x);
            		int diff_y <- abs(n - self.myCell.grid_y);
            		if diff_x = diff_y{
            			add cell.queen to: queensInSight;
            		}
            	}
            }
        }
    	
    	if length(queensInSight) > 0{
    		Queen sight <- queensInSight[rnd(0, length(queensInSight)-1)];
    		return sight;	
    	} else{
    		return nil;
    	}
    }



    action needToMove{
    	do calculateOccupancyGrid();
	    if self.occupancyGrid[myCell.grid_x][myCell.grid_y] != 0{
            myColor <- #red;
	    	list<point> possibleChecks <- availableallCells(0);
	    	if length(possibleChecks) > 0 {
	    		point possiblePoint <- possibleChecks[rnd(0,length(possibleChecks)-1)];
	    		loop c over: allCells {
	    			if c.grid_x = possiblePoint.x and c.grid_y = possiblePoint.y and c.queen = nil{
	    				myCell.queen <- nil;
	    				myCell <- c;
	    				location <- c.location;
	    				myCell.queen <- self;
	    				
	    				write name;
	    				write "Options: " + possibleChecks;
	    				write "Moved to: " + c.grid_x + ", " + c.grid_y;
	    				write "Grid: " + self.occupancyGrid;
	    				
	    				break;
	    			}
	    		}
	    	}
	    	else{
	    		write "I cannot move from: " + self.myCell.grid_x + ", " + self.myCell.grid_y;
	    		// Communicate via chain: ONLY ask predecessor (circular chain)
	    		if predecessor != nil and !awaitingResponse{
	    			write name + " at (" + self.myCell.grid_x + ", " + self.myCell.grid_y + ") asking predecessor " + predecessor.name + " for help";
	    			
	    			// Send Call For Proposal (CFP) to predecessor
	    			do start_conversation to: [predecessor] protocol: 'fipa-contract-net' performative: 'cfp' 
	    				contents: ['request_move', string(self.myCell.grid_x), string(self.myCell.grid_y), name];
	    			
	    			awaitingResponse <- true;
	    			messageContext <- "chain_request";
	    		}
	    	}
	    } else {
            myColor <- #green;
        }
	}
    
    reflex amIsafe when: !isCalculating and !awaitingResponse{
    	isCalculating <- true;
    	do needToMove;
    	isCalculating <- false;
    }

    reflex handleCFP when: !empty(cfps){
    	message requestMessage <- cfps[0];
    	list reqContents <- requestMessage.contents;
    	write name + " received CFP from " + requestMessage.sender + " with contents: " + reqContents;
    	if reqContents[0] = 'request_move' {
    		do calculateOccupancyGrid();
    		list<point> myOptions <- availableallCells(0);
    		string originalRequester <- string(reqContents[3]);
    		if length(myOptions) > 0 {
    			point newPos <- myOptions[rnd(0, length(myOptions) - 1)];
    			loop c over: allCells {
    				if c.grid_x = newPos.x and c.grid_y = newPos.y and c.queen = nil {
    					write name + " moving to (" + c.grid_x + ", " + c.grid_y + ") to help " + originalRequester;
    					chessBoardCell oldCell <- myCell;
    					myCell.queen <- nil;
    					myCell <- c;
    					location <- c.location;
    					myCell.queen <- self;
    					Queen originalQueen <- nil;
    					loop q over: allQueens {
    						if q.name = originalRequester {
    							originalQueen <- q;
    							break;
    						}
    					}
    					if originalQueen != nil {
    						write name + " sending position to original requester " + originalRequester;
    						do start_conversation to: [originalQueen] protocol: 'fipa-contract-net' performative: 'propose'
    							contents: ['position_available', string(oldCell.grid_x), string(oldCell.grid_y)];
    					}
    					do propose message: requestMessage contents: ['chain_resolved', string(oldCell.grid_x), string(oldCell.grid_y)];
    					break;
    				}
    			}
    		} else {
    			if predecessor != nil and predecessor.name != originalRequester {
    				write name + " cannot move, forwarding request to predecessor " + predecessor.name;
    				do start_conversation to: [predecessor] protocol: 'fipa-contract-net' performative: 'cfp'
    					contents: ['request_move', reqContents[1], reqContents[2], originalRequester];
    				do refuse message: requestMessage contents: ['forwarding_to_predecessor'];
    			} else {
    				write name + ": chain exhausted (full circle or no predecessor available)";
    				Queen originalQueen <- nil;
					loop q over: allQueens {
						if q.name = originalRequester {
							originalQueen <- q;
							break;
						}
					}
					if originalQueen != nil {
						do start_conversation to: [originalQueen] protocol: 'fipa-contract-net' performative: 'refuse'
							contents: ['chain_exhausted'];
					}
    				do refuse message: requestMessage contents: ['chain_exhausted'];
    			}
    		}
    	} else {
    		do propose message: requestMessage contents: ['position_info', string(myCell.grid_x), string(myCell.grid_y)];
    	}
    }
    
    reflex handlePropose when: !empty(proposes) and awaitingResponse{
    	message proposalMessage <- proposes[0];
    	write name + " received PROPOSE from " + proposalMessage.sender;
    	list contents <- proposalMessage.contents;
    	if length(contents) >= 1 and contents[0] = 'chain_resolved'{
    		awaitingResponse <- false;
    		messageContext <- "";
    		return;
    	}
    	if length(contents) >= 3 and contents[0] = 'position_available'{
    		int availCell_x <- int(contents[1]);
    		int availCell_y <- int(contents[2]);
    		chessBoardCell freedCell <- nil;
    		loop c over: allCells{
    			if c.grid_x = availCell_x and c.grid_y = availCell_y{
    				freedCell <- c;
    				break;
    			}
    		}
    		if freedCell != nil and freedCell.queen = nil{
    			myCell.queen <- nil;
    			myCell <- freedCell;
    			location <- freedCell.location;
    			myCell.queen <- self;
    			do accept_proposal message: proposalMessage contents: ['move_completed'];
    		} else {
    			if freedCell != nil {
    				loop s over: freedCell.neighbours{
    					if s.queen = nil{
    						myCell.queen <- nil;
    						myCell <- s;
    						location <- s.location;
    						myCell.queen <- self;
    						do accept_proposal message: proposalMessage contents: ['move_completed'];
    						break;
    					}
    				}
    			} else {
    				do reject_proposal message: proposalMessage contents: ['cell_not_found'];
    			}
    		}
    	}
    	awaitingResponse <- false;
    	messageContext <- "";
    }
    
    reflex handleRefuse when: !empty(refuses){
    	message refuseMessage <- refuses[0];
    	list contents <- refuseMessage.contents;
    	write name + " received REFUSE from " + refuseMessage.sender + ": " + contents;
    	if awaitingResponse {
    		if messageContext = "forwarded_request" {
    			awaitingResponse <- false;
    			messageContext <- "";
    		} else if messageContext = "chain_request" {
    			if length(contents) > 0 and contents[0] = 'chain_exhausted' {
    				awaitingResponse <- false;
    				messageContext <- "";
    			}
    		}
    	}
    }

    reflex handleReject when: !empty(reject_proposals) and awaitingResponse{
    	message rejectMessage <- reject_proposals[0];
    	list contents <- rejectMessage.contents;
    	write name + " received REJECT from " + rejectMessage.sender + ": " + contents;
    	awaitingResponse <- false;
    	messageContext <- "";
    }
    

    aspect base {
        draw square(2.0) color: myColor;
    }
}



grid chessBoardCell width: queens height: queens neighbors: neighbors{

    list<chessBoardCell> neighbours <- (self neighbors_at 2);
    Queen queen <- nil;

    init{
        add self to: allCells;
    }

}


experiment ChessBoard type: gui {
    output {
        display main_display{
            grid chessBoardCell border: #black;
            species Queen aspect: base;
        }
    }
}

