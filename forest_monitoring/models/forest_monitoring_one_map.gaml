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
	list<int> n_tree <- list_with(10, 10);
	list<int> n_old_tree <- list_with(10, 1);
	float size_of_tree <- 50.0;
	float size_of_old_tree <- 100.0;
	float tree_distance <- 2.0;
	 
	list<string> color_list <- ["Blue", "Red", 'Green', "Yellow", "Black", "White"];
	list<rgb> player_colors <- [rgb(66, 72, 255), #red, #green, rgb(255, 196, 0), #black, rgb(156, 152, 142)];
	list<rgb> state_colors <- [rgb(151, 255, 110), rgb(50, 176, 0), rgb(32, 112, 0)];
	list<string> player_name <- ["Player_101", "Player_102", "Player_103", "Player_104", "Player_105", "Player_106"];
	map<int, string> map_player_intid <- [1::player_name[0], 2::player_name[1], 3::player_name[2], 4::player_name[3], 5::player_name[4], 6::player_name[5]];
	map<string, int> map_player_idint <- [player_name[0]::1, player_name[1]::2, player_name[2]::3, player_name[3]::4, player_name[4]::5, player_name[5]::6];
	map<string, int> map_player_colorint <- [color_list[0]::1, color_list[1]::2, color_list[2]::3, color_list[3]::4, color_list[4]::5, color_list[5]::6];
	list<int> connect_team_list <- [];
	list<int> ready_team_list <- [];
	list<int> before_Q_team_list <- [];
	list<int> after_Q_team_list <- [];
	list<list<list<string>>> for_save_answer <- list_with(6, list_with(2, []));
	bool all_player_ready <- false;
	bool all_player_before_Q <- false;
	bool all_player_after_Q <- false;
	bool send_ready <- true;
	int create_tree_cycle <- int(#infinity);
	
	bool skip_tutorial <- false;
	bool can_start <- true;
	bool tutorial_finish <- false;
	int time_now <- 0;
	int init_time <- 0;
	int count_start <- 0 ;
	bool game_start <- false;
	bool next_time <- false;
	
	point result_location;
	point tutorial_location;
	point main_location;
	
	action resume_game;
	action pause_game;
	action remove_threat(int p, string threat);
	action resend_command_to_unity (string player_name_ID);
	
	geometry usable_area_for_wildfire ;
	geometry usable_area_for_tree;
	
	list<list<int>> n_remain_tree <- list_with(6, list_with(3, 0));
	list<list<int>> n_remain_tree_all <- list_with(6, list_with(10, 0));
	list<list<list<int>>> remaining_tree_per_plot <- list_with(6,list_with(6, list_with(3, 0)));
	list<int> sum_score_list <- list_with(6,0);
	list<int> total_score_list <- list_with(6,0);
	int max_score <- 0;
	int upper_bound <- 150;
	
	int time_interval <- 15;
	
	list<int> raining_Stime <- [15, 90,225];
	list<int> raining_Etime <- [45,135,240];
	
	list<int> alien_Stime <- 	[   0,  15,  30,  90, 105, 120, 165, 180, 195];
	list<int> alien_Etime <- 	[  15,  30,  45, 105, 120, 135, 180, 195, 210];
	list<string> alien_type <-	["A2","A1","A2","A2","A1","A2","A1","A2","A1"];
	
	list<int> grass_Stime <- 	[  15,  30, 105, 180];
	list<int> grass_Etime <- 	[  30,  45, 135, 210];
	list<string> grass_type <- 	["G1","G2","G2","G1"];
	
	list<int> fire_Stime <- 	[  45,  60,  75, 150, 165, 210];
	list<int> fire_Etime <- 	[  60,  75,  90, 165, 210, 225];
	list<string> fire_type <- 	["F1","F2","F1","F1","F2","F1"];
	
	list<int> list_of_bg_score <- [0,150,240,300+1];
	list<int> list_of_player_bg <- [1,1,1,1,1,1];
	
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
		create tutorial_area{
			location <- {width/2,-(width/2)+15,-200};
			shape <- rectangle(10#m, 10#m);
		}
		
		main_location <- playerable_area[0].location;
		tutorial_location <- tutorial_area[0].location;
		result_location <- tutorial_area[2].location;
		
		loop i from:0 to:5{
			create reset{
				location <- {width + 6, 4 + (8*i)}; 
			}
		}
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
		int count_label_tree <- 0;
		
		loop i from:0 to:(length(n_old_tree)-1){
			loop cnt from:1 to:n_old_tree[i]{
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
					
					create old_tree{
						location <- {at_location.x,
									at_location.y,
									at_location.z
									};
						shape <- circle(size_of_old_tree#cm);
						tree_type <- i+1;
						name <- "oldtree" + count_label_tree;
						count_create_tree <- count_create_tree + 1;
					}
					
				}
				count_label_tree <- count_label_tree + 1;
			}
		}

		usable_area_for_tree <- usable_area_for_tree - (old_tree[count_create_tree-1].shape + tree_distance);
		save usable_area_for_tree to:"../includes/export/usable_area_for_tree_with_oldtree.shp" format:"shp";
		
		count_create_tree <- 0;
		count_label_tree <- 0;
		loop i from:0 to:(length(n_tree)-1){
			loop cnt from:1 to:n_tree[i]{
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
					
					create tree{
						location <- {at_location.x,
									at_location.y,
									at_location.z
									};
						shape <- circle(size_of_tree#cm);
						tree_type <- i+1;
						name <- "tree" + count_label_tree;
						zone <- temp_zone;
						count_create_tree <- count_create_tree + 1;
					}
				}
				count_label_tree <- count_label_tree + 1;
			}
		}
		usable_area_for_tree <- usable_area_for_tree - (tree[count_create_tree-1].shape + tree_distance);
		save usable_area_for_tree to:"../includes/export/usable_area_for_tree_with_alltree.shp" format:"shp";
		create_tree_cycle <- cycle;
		write "Create tree at cycle = " + create_tree_cycle + " = " + cycle;
	}
	
	reflex update_time_and_bound when: not paused and tutorial_finish and game_start{
		if (gama.machine_time div 1000) - init_time >= 1{
			init_time <- gama.machine_time div 1000;
			time_now <- time_now + 1;
			next_time <- true;
			write "time_now " + time_now + "s  at cycle = " + cycle;
		}
	}
	
	reflex do_resume when: not paused and can_start{
		if all_player_ready and tutorial_finish {
			count_start <- count_start + 1 ;
			init_time <- gama.machine_time div 1000;
			game_start <- true;
		}
		
		can_start <- false;
		do resume_game;
	}
	

	reflex do_pause when: (time_now >= time_to_play+2) 
		and (cycle != 0) and not can_start and tutorial_finish{
		do pause_game;
	}
}

experiment init_exp type: gui {
	output{ 
		layout vertical([horizontal([0::1, 1::1])::1, horizontal([2::1, 3::1, 4::1, 5::1, 6::1, 7::1])::1]) 
		toolbars: false tabs: false parameters: false consoles: false navigator: false controls: true tray: false ;
		display "Main" type: 3d background: rgb(50,50,50) locked:true antialias:true {
			camera 'default' location: {25.14,12.2616,92.8721} target: {25.14,12.26,0.0};
			species map_area;
			species playerable_area;
			species tree_area;
			species tutorial_area;
			species old_tree;
			species tree;
			species icon_everything;
			species reset;
			
			event #mouse_down {
				int temp_team1 <- 1;
				int temp_team2 <- 2;
				if (#user_location distance_to reset[0] < 3) and not paused{
					ask world{
						//write "Reset Player_101" ;
						do resend_command_to_unity(player_name[0]);
					}
				}
				else if (#user_location distance_to reset[1] < 3) and not paused{
					ask world{
						//write "Reset Player_102" ;
						do resend_command_to_unity(player_name[1]);
					}
				}
				else if (#user_location distance_to reset[2] < 3) and not paused{
					ask world{
						//write "Reset Player_103" ;
						do resend_command_to_unity(player_name[2]);
					}
				}
				else if (#user_location distance_to reset[3] < 3) and not paused{
					ask world{
						//write "Reset Player_104" ;
						do resend_command_to_unity(player_name[3]);
					}
				}
				else if (#user_location distance_to reset[4] < 3) and not paused{
					ask world{
						//write "Reset Player_105" ;
						do resend_command_to_unity(player_name[4]);
					}
				}
				else if (#user_location distance_to reset[5] < 3) and not paused{
					ask world{
						//write "Reset Player_106" ;
						do resend_command_to_unity(player_name[5]);
					}
				}
			}
			
			graphics Strings {
				if (tutorial_finish and game_start){
					if (time_now <= time_to_play){
						draw "Remaining time: "+ ((time_to_play - time_now) div 60) + " minutes " + 
						((time_to_play - time_now) mod 60) + " seconds"
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
					draw "Remaining time: - (Tutorial " + (count_start+1) + ")..." 
					at:{width/4.5, -21} 
					font:font("Times", 20, #bold+#italic) ;
				}
				loop i from:0 to:5{
					draw "Team" + (i+1) + " " + color_list[i] +  ": " 
						at:{width+1, 2 + (8*i)} 
						font:font("Times", 12, #bold+#italic) 
						color:player_colors[i];		
				}
			}
		}
		display "Total Scores" type: 2d locked:true{
			chart "Total Scores" type:histogram reverse_axes:true
			y_range:[0, 20 + max_score]
			x_serie_labels: [""]
			style:"3d"
			series_label_position: xaxis
			{
				loop i from:0 to:(length(sum_score_list)-1){
					data "Team" + (i+1) value:int(total_score_list[i]+sum_score_list[i])
					color:player_colors[i];

				}
			}
			graphics Strings {
				loop i from:0 to:(length(sum_score_list)-1){
					draw "" + int(total_score_list[i]+sum_score_list[i]) + 
						"(" + 
						int(sum_score_list[i]) + 
						")"
						at:{width/1.5, 8 + 6.3*i} 
						font:font("Times", 14, #bold+#italic) 
						border:#black color:player_colors[i];
				}
			}
		}
		
		display "His_Team1" type: 2d locked:true{ 		
			chart "Team1" type:histogram 
			x_serie_labels: ["State"] 				
			y_range:[0, sum(n_tree)] 		
			style:"3d" 			  
			series_label_position: xaxis {
				data "D" value: sum(n_tree)-sum(n_remain_tree[0])
				color:#black ;
					
				loop j from:0 to:2{
					data "S" + j value: n_remain_tree[0][j]
					color:state_colors[j] ;
				}
			}
		}	
		
		display "His_Team2" type: 2d locked:true{ 		
			chart "Team2" type:histogram 
			x_serie_labels: ["State"] 				
			y_range:[0, sum(n_tree)] 		
			style:"3d" 			  
			series_label_position: xaxis {
				data "D" value: sum(n_tree)-sum(n_remain_tree[1])
				color:#black ;
					
				loop j from:0 to:2{
					data "S" + j value: n_remain_tree[1][j]
					color:state_colors[j] ;
				}	
			}
		}
		
		display "His_Team3" type: 2d locked:true{ 		
			chart "Team3" type:histogram 
			x_serie_labels: ["State"] 				
			y_range:[0, sum(n_tree)] 		
			style:"3d" 			  
			series_label_position: xaxis {
				data "D" value: sum(n_tree)-sum(n_remain_tree[2])
				color:#black ;
					
				loop j from:0 to:2{
					data "S" + j value: n_remain_tree[2][j]
					color:state_colors[j] ;
				}
			}
		}
		
		display "His_Team4" type: 2d locked:true{ 		
			chart "Team4" type:histogram 
			x_serie_labels: ["State"] 				
			y_range:[0, sum(n_tree)] 		
			style:"3d" 			  
			series_label_position: xaxis {
				data "D" value: sum(n_tree)-sum(n_remain_tree[3])
				color:#black ;
					
				loop j from:0 to:2{
					data "S" + j value: n_remain_tree[3][j]
					color:state_colors[j] ;
				}
			}
		}
		
		display "His_Team5" type: 2d locked:true{ 		
			chart "Team5" type:histogram 
			x_serie_labels: ["State"] 				
			y_range:[0, sum(n_tree)] 		
			style:"3d" 			  
			series_label_position: xaxis {
				data "D" value: sum(n_tree)-sum(n_remain_tree[4])
				color:#black ;
					
				loop j from:0 to:2{
					data "S" + j value: n_remain_tree[4][j]
					color:state_colors[j] ;
				}
			}
		}
		
		display "His_Team6" type: 2d locked:true{ 		
			chart "Team6" type:histogram 
			x_serie_labels: ["State"] 				
			y_range:[0, sum(n_tree)] 		
			style:"3d" 			  
			series_label_position: xaxis {
				data "D" value: sum(n_tree)-sum(n_remain_tree[5])
				color:#black ;
					
				loop j from:0 to:2{
					data "S" + j value: n_remain_tree[5][j]
					color:state_colors[j] ;
				}
			}
		}
	}
}

