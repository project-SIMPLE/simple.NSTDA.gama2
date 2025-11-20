/**
* Name: OptimizeSpeciesonemap
* Based on the internal empty template. 
* Author: Tassathorn Poonsin
* Tags: 
*/


model OptimizeSpeciesonemap

global{
	image_file fire_image_file <- gif_file("../images/simple_fire.PNG");
	image_file alien_image_file <- gif_file("../images/simple_alien.PNG");
	image_file rain_image_file <- image_file("../images/rain.png");
	image_file blank_image_file <- image_file("../images/blank.png");
	image_file reset_image <- image_file("../images/reset.png");
	
	int time_now;
	int n_years <- 2;
	int time_to_play <- 240;
	int announce_time <- time_to_play - 60;
	
	float init_height <- 50.0;
	
	list tree_name <- ['Qu','Sa','Ma','Pho','De','Di','Os','Phy','Ca','Gm'];
	list<int> list_of_height <- [1000,3500,2500,1500,500,1500,800,2000,2500,2500]; 
	list<int> list_of_max_height_in_n_years <- [130, 234, 211, 118, 181, 157, 133, 180, 183, 120]; 
	list<float> list_of_growth_rate <- [0.523,0.798,0.7543,0.4552,0.8155,0.6093,0.55,0.6761,0.6761,0.4537];	
		
	init{
		write "time_to_play " + time_to_play;
	}
}

species reset {
	image_file img <- reset_image;
	aspect default {
		draw img size:{10,6};
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
		
		draw status_icon size:{10.0,10.0};
	}
}

species old_tree{
	int tree_type <- 0;
	rgb color <- #yellow;
	
	aspect default{
		draw shape color:color;
	}
}

species tree{
	int tree_type <- 0;
	rgb color <- rgb(43, 150, 0);
	int zone <- 1;
	
	list<float> height <- list_with(6, 50.0);
	list<string> it_can_growth <- list_with(6, "1") ;
	list<int> it_state <- list_with(6, 1);
	list<int> current_time <- list_with(6, 0);
	float tree_ratio <- 0.0;
	
	float logist_growth (float init_input, float max_height, float growth_rate, int p){
		growth_rate <- growth_rate + rnd (-0.1, 0.1) * growth_rate;
		
		float height_logist <- (init_input * max_height) / (init_input + (max_height - init_height) * 
							exp (-((growth_rate) * ((current_time[p-1] * n_years / (time_to_play)) - 0)))) ;
		return height_logist;
	}
	
	reflex update_tree_ratio{
		int dead_stack_tree <- it_can_growth count (each = "0");
		tree_ratio <- dead_stack_tree/length(it_can_growth);
	}
	
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


