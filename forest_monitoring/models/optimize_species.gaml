/**
* Name: optimizespecies
* Based on the internal empty template. 
* Author: lilti
* Tags: 
*/


model optimizespecies

global{
	image_file fire_image_file <- image_file("../images/fire.png");
	image_file alien_image_file <- image_file("../images/alien.png");
	image_file rain_image_file <- image_file("../images/rain.png");
	image_file blank_image_file <- image_file("../images/blank.png");
	
//	float time_per_cycle <- 1.0;
	int n_years <- 2;
	int time_to_play <- 300;
	
	int init_cycle <- 2;
	
//	float used_cycle <- time_to_play / time_per_cycle;
//	float day_per_time <- (n_years*365)/used_cycle;

	float day_per_time <- (n_years*365)/time_to_play;
	
	
	float init_height <- 50.0;
//								Quercus, Debregeasia, Gmelina
	list<int> list_of_height <- [1000, 500, 2500]; 
	list<int> list_of_max_height_in_n_years <- [130, 181, 120]; 
	list<float> list_of_growth_rate <- [0.523, 0.8155, 0.4537];
	
	init{
//		write "used_cycle " + used_cycle; 
		write "time_to_play " + time_to_play;
		write "day_per_second " + day_per_time;
	}
}
	
species icon_everything{
	string type <- "blank";
	image_file status_icon;
	
	aspect default {
		switch type{
			match "blank"{
				status_icon <- blank_image_file;
			}
			match "fire"{
				status_icon <- fire_image_file;
			}
			match "alien"{
				status_icon <- alien_image_file;
			}
			match "rain"{
				status_icon <- rain_image_file;
			}
		}
		
		draw status_icon size:{1.25,1.25};
	}
}

species tree{
	int player <- 1;
	int tree_type <- 0;
	int it_state <- 1;
	float height <- 50.0;
	string it_can_growth <- "1" ;
	rgb color <- rgb(43, 150, 0);
	int current_time <- 0;
	int zone <- 1;
	
	float logist_growth (float init_input, float max_height, float growth_rate, int multiple){
		float height_logist <- (init_input * max_height) / (init_input + (max_height - init_height) * 
							exp (-((growth_rate * multiple) * ((current_time * n_years / time_to_play) - 0)))) ;
							
//		float height_logist <- (init_input * max_height) / (init_input + (max_height - init_height) * 
//							exp (-((growth_rate * multiple) * (current_time  - 0)))) ;
		return height_logist;
	}
	
	reflex change_color{
		if it_can_growth = "0"{
			color <- #black;
		}
		else if it_can_growth = "-1"{
			color <- #purple;
		}
		else if it_can_growth = "1"{
			if it_state = 1{
				color <- rgb(151, 255, 110);
			}
			else if it_state = 2{
				color <- rgb(50, 176, 0);
			}
			else if it_state = 3{
				color <- rgb(32, 112, 0);
			}
		}
	}

//	reflex change_color{
//		if zone = 1{
//			color <- #black;
//		}
//		else if zone = 2{
//			color <- #red;
//		}
//		else if zone = 3{
//			color <- #blue;
//		}
//		else if zone = 4{
//			color <- #green;
//		}
//	}
	
	aspect default{
		draw shape color:color;
	}
}

species playerable_area{
	geometry shape <- rectangle(40#m, 40#m);
	rgb color <- #white;

	aspect default{
		draw shape color:color border:#black ;
	}
}

species tree_area{
	geometry shape <- rectangle(35#m, 35#m);
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