/**
* Name: OptimizeSpeciesonemap
* Based on the internal empty template. 
* Author: Tassathorn Poonsin
* Tags: 
*/


model OptimizeSpeciesonemap

global{
//	image_file fire_image_file <- image_file("../images/fire.png");
//	image_file alien_image_file <- image_file("../images/alien.png");
	image_file fire_image_file <- gif_file("../images/fire1.gif");
	image_file alien_image_file <- gif_file("../images/alien1.gif");
	image_file rain_image_file <- image_file("../images/rain.png");
	image_file blank_image_file <- image_file("../images/blank.png");
	
	int time_now;
	int time_interval;
	int n_years <- 2;
	int time_to_play <- 240;
	int announce_time <- time_to_play - 60;
	float day_per_time <- (n_years*365)/time_to_play;
	
	float init_height <- 50.0;
//								Quercus, Debregeasia, Gmelina
	list<int> list_of_height <- [1000, 500, 2500]; 
	list<int> list_of_max_height_in_n_years <- [130, 181, 120]; 
	list<float> list_of_growth_rate <- [0.523, 0.8155, 0.4537];
	
	init{
		write "time_to_play " + time_to_play;
		write "day_per_second " + day_per_time;
	}
}

species icon_everything{
	int init_time ;
	string type <- "blank";
	image_file status_icon;
	
	reflex count_down when: (time_now - init_time = 15){
		do die;
	}
	
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
		
//		draw status_icon size:{1.25,1.25};
		draw status_icon size:{10.0,10.0};
	}
}

species old_tree{
	int player <- 1;
	int tree_type <- 0;
	rgb color <- #yellow;
	
	aspect default{
		draw shape color:color;
	}
}

species front_tree{
	float tree_ratio ;
	rgb color <- rgb(151, 255, 110);
	
	reflex change_color{
		if tree_ratio = 0.0{
			color <- rgb(151, 255, 110);
		}
		else if tree_ratio = 1.0{
			color <- #black;
		}
		else {
			color <- #gray;
		}
	}
	
	aspect default{
		draw shape color:color;
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
	int number <- 1;
	string name_for_front_tree ;
	
	float logist_growth (float init_input, float max_height, float growth_rate, int multiple){
		float height_logist <- (init_input * max_height) / (init_input + (max_height - init_height) * 
							exp (-((growth_rate * multiple) * ((current_time * n_years / (time_to_play)) - 0)))) ;
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
	rgb border_color <- #black;

	aspect default{
		draw shape color:color border:border_color ;
	}
}

species tree_area{
	geometry shape <- rectangle(35#m, 35#m);
	rgb color <- #white;
	rgb border_color <- #black;
	
	aspect default{
		draw shape color:color border:border_color ;
	}
}

species map_area{
	geometry shape <- rectangle(50#m, 50#m); //(82#m, 74#m);
	rgb color <- #white;
	rgb border_color <- #black;
	
	aspect default{
		draw shape color:color border:border_color ;
	}
}

species tutorial_area{
	rgb color <- #white;
	rgb border_color <- #black;

	aspect default{
		draw shape color:color border:border_color ;
	}
}


