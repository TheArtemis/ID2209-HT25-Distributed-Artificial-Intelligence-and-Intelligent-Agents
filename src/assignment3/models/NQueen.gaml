/**
* Name: queen
* Author: Lorenzo Deflorian, Riccardo Fragale, Juozas Skarbalius
* Tags: 
*/


model NQueen


global {
    int neighbors <- 8;
    int queens <- 12;
    
    init{
        create Queen number: queens;
    }
    
    list<chessBoardCell> allCells;
    list<Queen> allQueens;
    
    bool isCalculating <- false;
    
}


species Queen{

    chessBoardCell myCell <- one_of (chessBoardCell);
    
    aspect base {
        draw square(1.0) color: #black;
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

