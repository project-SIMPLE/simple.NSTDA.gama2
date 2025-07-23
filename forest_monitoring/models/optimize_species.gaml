/**
* Name: optimizespecies
* Based on the internal empty template. 
* Author: lilti
* Tags: 
*/


model optimizespecies

global{
	float time_per_cycle <- 1.0;
	int n_years <- 2;
	int time_to_play <- 300;
	
	int init_cycle <- 3;
	
	float used_cycle <- time_to_play / time_per_cycle;
	float day_per_cycle <- (n_years*365)/used_cycle;
	
	
	float init_height <- 50.0;
//								Quercus, Debregeasia, Gmelina
	list<int> list_of_height <- [1000, 500, 2500]; 
	list<int> list_of_max_height_in_n_years <- [130, 181, 120]; 
	list<float> list_of_growth_rate <- [0.523, 0.8155, 0.4537];
	
	init{
		write "used_cycle " + used_cycle; 
		write "day_per_second " + day_per_cycle;
	}
}	

species tree{
	int tree_type <- 0;
	int it_state <- 1;
	float height <- 50.0;
	string it_can_growth <- "1" ;
	rgb color <- rgb(43, 150, 0);
	int current_cycle <- 0;
	
	float logist_growth (float init_input, float max_height, float growth_rate){
//		growth_rate <- growth_rate + rnd (-0.1, 0.1) * growth_rate;
//		float height_logist <- (init_input * max_height) / (init_input + (max_height - init_height) * 
//							exp (-(( growth_rate ) * ((current_cycle)/(365/day_per_cycle) - init_cycle)))) ;
		
		float height_logist <- (init_input * max_height) / (init_input + (max_height - init_height) * 
							exp (-(( growth_rate ) * ((current_cycle * n_years / used_cycle) - 0)))) ;
		return height_logist;
	}
	
	reflex change_color{
		if it_can_growth = "0"{
			color <- #black;
		}
		if it_can_growth = "-1"{
			color <- #purple;
		}
		else if it_state = 1{
			color <- rgb(43, 150, 0);
		}
		else if it_state = 2{
			color <- #blue;
		}
		else if it_state = 3{
			color <- #red;
		}
	}
	
	aspect default{
		draw shape color:color;
	}
}

species p1tree parent:tree {
	
}

species p2tree parent:tree {
	
}

species p3tree parent:tree {
	
}

species p4tree parent:tree {
	
}

species p5tree parent:tree {
	
}

species p6tree parent:tree {
	
}

species wildfire{
	bool it_sent <- false;
	geometry shape <- circle(1#m);
	rgb color <- #red;
	
	aspect default{
		draw shape color:color ;
	}
}

species alien{
	bool it_sent <- false;
	geometry shape <- triangle(2#m);
	rgb color <- #blue;
	
	aspect default{
		draw shape color:color ;
	}
}

species playerable_area{
	geometry shape <- rectangle(50#m, 50#m);
	rgb color <- #white;
	
	aspect default{
		draw shape color:color border:#black ;
	}
}

species tree_area{
	geometry shape <- rectangle(45#m, 45#m);
	rgb color <- #white;
	
	aspect default{
		draw shape color:color border:#black ;
	}
}

species zone_area{
	geometry shape <- rectangle(82#m, 74#m);
	rgb color <- #white;
	
	aspect default{
		draw shape color:color border:#black ;
	}
}

species wait_area{
	geometry shape <- rectangle(10#m, 10#m);
	rgb color <- #yellow;
	
	aspect default{
		draw shape color:color border:#black ;
	}
}