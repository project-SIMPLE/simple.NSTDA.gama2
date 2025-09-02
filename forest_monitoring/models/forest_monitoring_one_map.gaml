/**
* Name: forestmonitoringonemap
* Based on the internal empty template. 
* Author: Tassathorn Poonsin
* Tags: 
*/


model forestmonitoringonemap

import "Optimize_Species_one_map.gaml"

global{
	geometry shape <- rectangle(50#m, 50#m);
	
	float width <- shape.width;
	float height <- shape.height;
	
	int n_teams <- 6;
	int n_tree <- 100;
	int n_old_tree <- 10;
	float size_of_tree <- 50.0;
	float size_of_old_tree <- 100.0;
	float tree_distance <- 2.0;
	 
	list<rgb> player_colors <- [rgb(66, 72, 255), #red, #green, rgb(255, 196, 0), #black, rgb(156, 152, 142)];
	list<string> player_name <- ["Player_101", "Player_102", "Player_103", "Player_104", "Player_59", "Player_52"];
	map<int, string> map_player_intid <- [1::player_name[0], 2::player_name[1], 3::player_name[2], 4::player_name[3], 5::player_name[4], 6::player_name[5]];
	map<string, int> map_player_idint <- [player_name[0]::1, player_name[1]::2, player_name[2]::3, player_name[3]::4, player_name[4]::5, player_name[5]::6];
	list<int> connect_team_list <- [];
	list<int> ready_team_list <- [];
	list<int> before_Q_team_list <- [];
	list<int> after_Q_team_list <- [];
	bool all_player_ready <- false;
	bool all_player_before_Q <- false;
	bool all_player_after_Q <- false;
	bool send_ready <- true;
	
	bool skip_tutorial <- false;
	bool can_start <- true;
	bool tutorial_finish <- false;
	int time_now <- 0;
	int init_time <- 0;
	int count_start <- 0 ;
	bool game_start <- false;
	bool end_game <- false;
	
	point tutorial_location;
	point main_location;
	
	action resume_game;
	action pause_game;
	
	geometry usable_area_for_wildfire ;
	geometry usable_area_for_tree;
	
	list<list<int>> n_remain_tree <- list_with(6, list_with(3, 0));
	list<int> sum_score_list <- list_with(6,0);
	
	int time_interval <- 15;
	list<int> raining_Stime <- [30,45,120,135,150,285];
	list<int> raining_Etime <- [45,60,135,150,165,300];
	
	list<int> alien_Stime <- 	[   0,  15,  30,  45, 120, 135, 150, 165, 180, 240, 255];
	list<int> alien_Etime <- 	[  15,  30,  45,  60, 135, 150, 165, 180, 195, 255, 270];
	list<string> alien_type <-	["A1","A1","A2","A2","A2","A2","A2","A1","A1","A2","A2"];
	
	list<int> grass_Stime <- 	[  30,  45,  60, 135, 150, 165, 180, 195, 240, 255];
	list<int> grass_Etime <- 	[  45,  60,  75, 150, 165, 180, 195, 210, 255, 270];
	list<string> grass_type <- 	["G2","G2","G1","G2","G2","G1","G1","G1","G2","G2"];
	
	list<int> fire_Stime <- 	[  75,  90, 105, 195, 210, 225, 240, 255, 270];
	list<int> fire_Etime <- 	[  90, 105, 120, 210, 225, 240, 255, 270, 285];
	list<string> fire_type <- 	["F1","F2","F1","F1","F2","F2","F2","F2","F1"];
	
	list<int> list_of_bg_score <- [-50,41,86,111,131,150];
	list<int> list_of_player_bg <- [2,2,2,2,2,2];
	
	list<int> zone_list <- [1,2,3,4];
	
	init{
		point at_location <- {(width/2)#m,(height/2)#m,0};
		create playerable_area{
			location <- at_location;
		}
		create tree_area{
			location <- at_location;
		}
		create map_area{
			location <- at_location;
		}
		create tutorial_area{
			location <- {width/2,-(width/2)+15,0};
			shape <- rectangle(20#m, 20#m);
		}
		create tutorial_area{
			location <- {width/2,-(width/2)+15,0};
			shape <- rectangle(10#m, 10#m);
		}
		
		main_location <- playerable_area[0].location;
		tutorial_location <- tutorial_area[0].location;
	}
	
	action create_tree{
		usable_area_for_wildfire <- playerable_area[0].shape - tree_area[0].shape ;
		usable_area_for_tree <- tree_area[0].shape;
		
		save usable_area_for_wildfire to:"../includes/export/usable_area_for_wildfire.shp" format:"shp";
		save usable_area_for_tree to:"../includes/export/usable_area_for_tree.shp" format:"shp";
		
		ask old_tree {do die;}
		ask tree {do die;}
		
		point at_location ;
		int count_create_tree <- 0;
		loop i from:0 to:(n_old_tree-1){
			if count_create_tree > 0{
				ask old_tree[count_create_tree-1]{
					usable_area_for_tree <- usable_area_for_tree - (self.shape + tree_distance);
				}
			}
			if (usable_area_for_tree = nil) {
				write 'Geometry not enough when n=' + count_create_tree;
				break;
			}
			else{
				at_location <- any_location_in(usable_area_for_tree-1);
				int temp_type <- rnd(1, 3);
				
				loop j from:1 to:n_teams{
					create old_tree{
						location <- {at_location.x,
									at_location.y,
									at_location.z
									};
						shape <- circle(size_of_old_tree#cm);
//						shape <- circle((size_of_old_tree-(10*j))#cm);
//						color <- player_colors[j-1];
						tree_type <- temp_type;
						player <- j;
						name <- "p" + j + "oldtree" + i;
						count_create_tree <- count_create_tree + 1;
					}
				}
				
			}
		}

		usable_area_for_tree <- usable_area_for_tree - (old_tree[count_create_tree-1].shape + tree_distance);
		save usable_area_for_tree to:"../includes/export/usable_area_for_tree_with_oldtree.shp" format:"shp";
		

			
		count_create_tree <- 0;
		loop i from:0 to:(n_tree-1){
			if count_create_tree > 0{
				ask tree[count_create_tree-1] {
					usable_area_for_tree <- usable_area_for_tree - (self.shape + tree_distance);
				}
			}
			if (usable_area_for_tree = nil) {
				write 'Geometry not enough when n=' + count_create_tree;
				break;
			}
			else{
				at_location <- any_location_in(usable_area_for_tree);
				int temp_type <- rnd(1, 3);
				int temp_zone;
				
				if (at_location.x <= (width/2)) and (at_location.y <= (height/2)){
					temp_zone <- 1 ;
				}
				else if (at_location.x > (width/2)) and (at_location.y <= (height/2)){
					temp_zone <- 2 ;
				}
				else if (at_location.x <= (width/2)) and (at_location.y > (height/2)){
					temp_zone <- 3 ;
				}
				else if (at_location.x > (width/2)) and (at_location.y > (height/2)){
					temp_zone <- 4 ;
				}
				
				loop j from:1 to:n_teams{
					create tree{
						location <- {at_location.x,
									at_location.y,
									at_location.z
									};
						shape <- circle(size_of_tree#cm);
						tree_type <- temp_type;
						it_state <- 1;
						player <- j;
						name <- "p" + j + "tree" + i;
						name_for_front_tree <- "tree" + i;
						number <- i;
						zone <- temp_zone;
						count_create_tree <- count_create_tree + 1;
					}
				}
				create front_tree{
					location <- {at_location.x,
								at_location.y,
								at_location.z
								};
					shape <- circle(size_of_tree#cm);
					name <- "tree" + i;
				}
			}
		}
		usable_area_for_tree <- usable_area_for_tree - (tree[count_create_tree-1].shape + tree_distance);
		save usable_area_for_tree to:"../includes/export/usable_area_for_tree_with_alltree.shp" format:"shp";
	}
	
	reflex update_time_and_bound when: not paused and tutorial_finish{
		if (gama.machine_time div 1000) - init_time >= 1{
			init_time <- gama.machine_time div 1000;
			time_now <- time_now + 1;
			write "time_now " + time_now + "s  at cycle = " + cycle;
		}
	}
	
	reflex do_resume when: not paused and can_start{
		if tutorial_finish{
			count_start <- count_start + 1 ;
			init_time <- gama.machine_time div 1000;
			do create_tree;
			game_start <- true;
		}
		
		can_start <- false;
		do resume_game;
	}
	
	reflex do_pause when: (time_now >= time_to_play*count_start) and (cycle != 0) and not can_start and tutorial_finish{
		do pause_game;
//		do pause;
//		can_start <- true;
	}
	

}

experiment init_exp type: gui {
	output{
		layout
		toolbars: true tabs: false parameters: false consoles: true navigator: false controls: true tray: false ;
		display "Main" type: 3d background: rgb(50,50,50) locked:true antialias:true {
			camera 'default' location: {25.14,12.26,70.0} target: {25.14,12.26,0.0};
			species map_area;
			species playerable_area;
			species tree_area;
			species tutorial_area;
			species icon_everything;
			species old_tree;
			species tree;
			species front_tree;
			
			graphics Strings {
				if (tutorial_finish = true){
					if not end_game{
						draw "Remaining time: "+ (((time_to_play*count_start) - time_now) div 60) + " minutes " + 
						(((time_to_play*count_start) - time_now) mod 60) + " seconds" 
						at:{width/4.5, -21} 
						font:font("Times", 20, #bold+#italic) ;
					}
					else{
						draw "Remaining time: Finished!!!" 
						at:{width/4.5, -21} 
						font:font("Times", 20, #bold+#italic) ;
					}
					
				}
				else{
					draw "Remaining time: - (Tutorial" + (count_start+1) + "...)" 
					at:{width/4.5, -21} 
					font:font("Times", 20, #bold+#italic) ;
				}
			}
		}
		display "Total" type: 2d locked:true{
			chart "Total seeds" type:histogram reverse_axes:true
			y_range:[0, (150)]
			x_serie_labels: [""]
			
			style:"3d"
			series_label_position: xaxis
			{
				loop i from:0 to:(length(sum_score_list)-1){
					data "Team" + (i+1) value:int(sum_score_list[i])
					color:player_colors[i];
//					legend: string(int(sum_total_seeds[i])) ;
				}
			}
			graphics Strings {
				loop i from:0 to:(length(sum_score_list)-1){
					draw "=> " + int(sum_score_list[i]) at:{420,65 + 36*i} font:font("Times", 16, #bold+#italic) 
					border:#black color:player_colors[i];
				}
			}
		}
	}
}

