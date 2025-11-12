model forestmonitoringonemap_model_VR

import "forest_monitoring_one_map.gaml"

global{
	float adjust_z <- 0.0;
	float adjust_y <- 4.5;
	list all_for_send <- [];
	init{
		create Server {
			do connect protocol: "websocket_server" port: 3001 with_name: name raw: true;
		}
	}
	
	action resend_command_to_unity (string player_name_ID){
		int player_ID <- -1;
		loop i from:0 to:length(unity_player) - 1{
			ask unity_player[i] {
				if self.name = player_name_ID{
					player_ID <- i;
				}
			}
		}
			
		if all_player_ready{
			if tutorial_finish{
				ask unity_linker {
					do send_message players: unity_player[player_ID] as list 
						mes: ["ListOfMessage"::["Head"::"StartGame", 
												"Body"::"", 
												"Trees"::"",
												"Threats"::""]];
				}
				write "Resend StartGame at cycle = " + cycle + " for player " + player_name_ID;
				
				ask unity_player[player_ID]{
					location <- {main_location.x, main_location.y, adjust_z};
					ask unity_linker {
						new_player_position[myself.name] <- [myself.location.x *precision,
															myself.location.y *precision,
															myself.location.z *precision];
						move_player_event <- true;
					}
				}
//-----------------------------------------------------------------------------------------*********
				do create_tree;

				loop i from:0 to:(length(total_score_list)-1){
					total_score_list[i] <- total_score_list[i] + sum_score_list[i];
				}
				sum_score_list <- list_with(6,0);
//-----------------------------------------------------------------------------------------*********
			}
			else{
				ask unity_linker {
					do send_message players: unity_player[player_ID] as list 
						mes: ["ListOfMessage"::["Head"::"TutorialStart", 
												"Body"::"", 
												"Trees"::"",
												"Threats"::""]];
				}
				write "Resend TutorialStart at cycle = " + cycle + " for player " + player_name_ID;
			}
		}
		else{
			ask unity_linker {
				do send_message players: unity_player[player_ID] as list 
					mes: ["ListOfMessage"::["Head"::"ReadyCheck", 
											"Body"::"", 
											"Trees"::"",
											"Threats"::""]];
			}
			write "Resend ReadyCheck at cycle = " + cycle + " for player " + player_name_ID;
			
			ask unity_player[player_ID]{
				self.correct_location <- false;
				location <- {result_location.x, result_location.y, result_location.z + adjust_z};
				ask unity_linker {
					new_player_position[myself.name] <- [myself.location.x *precision,
														myself.location.y *precision,
														myself.location.z *precision];
					move_player_event <- true;
				}
			}			
		}
	}
	
	reflex check_location when: (tutorial_finish = true) and (game_start = false){
		ask unity_player where not(each.shape overlaps (tutorial_area[2].shape + 1)){
				self.correct_location <- false;
		}
		ask unity_player where (each.correct_location = false){
			if self.shape overlaps (tutorial_area[2].shape + 1){
				write self.name + " correct location in tutorial_area[2]";
				self.correct_location <- true;
			}
			else{
				write self.name + " not in tutorial_area[2]";

				location <- {result_location.x, result_location.y, result_location.z + adjust_z};
				ask unity_linker {
					new_player_position[myself.name] <- [myself.location.x *precision,
														myself.location.y *precision,
														myself.location.z *precision];
					move_player_event <- true;
				}
			}
		}
	}

	action resume_game {
		if all_player_ready{
			if tutorial_finish{
				add ["Head"::"StartGame", 
				"Body"::"", 
				"Trees"::"",
				"Threats"::""] to:all_for_send;
				write "send StartGame at cycle = " + cycle;
				
				ask unity_player{
					location <- {main_location.x, main_location.y, adjust_z};
					ask unity_linker {
						new_player_position[myself.name] <- [myself.location.x *precision,
															myself.location.y *precision,
															myself.location.z *precision];
						move_player_event <- true;
					}
				}
//-----------------------------------------------------------------------------------------*********
				do create_tree;

				loop i from:0 to:(length(total_score_list)-1){
					total_score_list[i] <- total_score_list[i] + sum_score_list[i];
				}
				sum_score_list <- list_with(6,0);
//-----------------------------------------------------------------------------------------*********
			}
			else{
				add ["Head"::"TutorialStart", 
					"Body"::"", 
					"Trees"::"",
					"Threats"::""] to:all_for_send;
				write "send TutorialStart at cycle = " + cycle;
				
				if skip_tutorial{
					do pause;
					can_start <- true;
					tutorial_finish <- true;
				}
			}
		}
		else{
			if empty(unity_player){
				write "No any player connected...";
				do pause;
				can_start <- true;
			}
			else{
				do prepare_step;
				ready_team_list <- [];
				before_Q_team_list <- [];
				after_Q_team_list <- [];
				tutorial_finish <- false;
				for_save_answer <- list_with(6, list_with(2, []));
				
				add ["Head"::"ReadyCheck", 
					"Body"::"", 
					"Trees"::"",
					"Threats"::""] to:all_for_send;
				write "send ReadyCheck at cycle = " + cycle;
				
				ask unity_player{
					self.correct_location <- false;
//					location <- {tutorial_location.x, tutorial_location.y + adjust_y, adjust_z};
					location <- {result_location.x, result_location.y, result_location.z + adjust_z};
					ask unity_linker {
						new_player_position[myself.name] <- [myself.location.x *precision,
															myself.location.y *precision,
															myself.location.z *precision];
						move_player_event <- true;
					}
				}

				ask old_tree {do die;}
				ask tree {do die;}
				ask front_tree {do die;}
			}
		}
	}
	
	action pause_game {		
		list<map<string,string>> send_final_score <- [];
		list<map<string,string>> send_tree_update_environment <- [];
		
		do update_n_remain_tree;
		
		// score
		loop p over:connect_team_list{
			add map<string, string>(["PlayerID"::map_player_intid[p], 
										"Name"::sum_score_list[p-1], 
										"State"::""]) to:send_final_score;
		}
		
		// Background
		loop p over:connect_team_list{
			loop j from:0 to:(length(list_of_bg_score)-2){
				if (sum_score_list[p-1] >= list_of_bg_score[j]) and 
					(sum_score_list[p-1] < list_of_bg_score[j+1]){
					add map<string, string>(["PlayerID"::map_player_intid[p], 
											"Name"::string(j+1), 
											"State"::""]) to:send_tree_update_environment;
					write "Player " + map_player_intid[p] + " change environment to " + string("Environment"+(j+1)) ;
				}
			}
		}
		
		add ["Head"::"Background", 
			"Body"::"", 
			"Trees"::send_tree_update_environment, 
			"Threats"::""] to:all_for_send;
	
		add ["Head"::"StopGame", 
			"Body"::"", 
			"Trees"::send_final_score,
			"Threats"::""] to:all_for_send;
		write "send StopGame at cycle = " + cycle;
			
		all_player_ready <- false;
		game_start <- false;
		time_now <- 0;
	}
	
	action prepare_step {		
		ask unity_player{
			if not (map_player_idint[self.name] in connect_team_list){
				add map_player_idint[self.name] to:connect_team_list;
			}
		}
		write "connect_team_list " + connect_team_list;
	}
		
	action update_n_remain_tree {		
		loop p over:connect_team_list{
			loop i from:0 to:2{
				list<tree> for_count_tree_state <- tree where ((each.it_state = i+1) 
															and (each.player = p) 
															and (each.it_can_growth != "0"));
				n_remain_tree[p-1][i] <- length(for_count_tree_state);
			}
		}

		loop p over:connect_team_list{
			sum_score_list[p-1] <- 	((-2*alpha)	*(100 - sum(n_remain_tree[p-1]))) +
									(0			*n_remain_tree[p-1][0]) + 
									(alpha		*n_remain_tree[p-1][1]) + 
									((2*alpha)	*n_remain_tree[p-1][2]);
			
			loop j from:0 to:(length(tree_name)-1){
				n_remain_tree_all[p-1][j] <- length(tree where ((each.tree_type = j+1) 
															and (each.player = p) 
															and (each.it_can_growth != "0")));
			}
			ask Server{
				do send to: "All" contents:["team"::color_list[p-1], "score"::n_remain_tree_all[p-1]] ;
				write "Send score for team= " + color_list[p-1] + " score= " + n_remain_tree_all[p-1];
			}
		}
		
		ask front_tree{
			list<tree> stack_tree <- tree where (each.name_for_front_tree = self.name);
			list<tree> dead_stack_tree <- tree where (each.name_for_front_tree = self.name 
													and	each.it_can_growth = "0");
			tree_ratio <- length(dead_stack_tree)/length(stack_tree);		
		}
	}
	
	action send_readID{		
		list<map<string,string>> send_tree_update_readID <- [];
		ask tree{
			add map<string, string>(["PlayerID"::map_player_intid[self.player], 
									"Name"::self.name, 
									"State"::""]) to:send_tree_update_readID;
		}
		
		ask old_tree{
			add map<string, string>(["PlayerID"::map_player_intid[self.player], 
									"Name"::self.name, 
									"State"::""]) to:send_tree_update_readID;
		}
		
		add ["Head"::"ReadID", 
				"Body"::"", 
				"Trees"::send_tree_update_readID,
				"Threats"::""] to:all_for_send;
				
		write "Send ReadID at cycle = " + cycle;
	}
	
	reflex for_send_readID when: cycle = (create_tree_cycle+1){
		do send_readID;
	}
	
	reflex update_height_and_threats when: tutorial_finish and 
										game_start and 
										next_time and 
										(time_now <= time_to_play){
		list<map<string,string>> send_tree_update_grass <- [];
		list<map<string,string>> send_tree_update_threats <- [];
		list<map<string,string>> send_tree_update_grow <- [];
		list<map<string,string>> send_tree_update_environment <- [];
		list<map<string,string>> send_tree_update_rain <- [];
		
		// Fire
		loop i from:0 to:(length(fire_Stime)-1){
			if (time_now >= fire_Stime[i]) and (time_now < fire_Etime[i]) and (time_now mod time_interval = 1){
				point at_location;
				if fire_type[i] = "F1"{
					at_location <- any_location_in(usable_area_for_wildfire);
					loop p over:connect_team_list{
						add map<string, string>(["Name"::"Flame1", 
								"x"::at_location.x, 
								"y"::at_location.z, 
								"z"::-at_location.y,
								"PlayerID"::map_player_intid[p]]) to:send_tree_update_threats;			
					}
				}

				else if fire_type[i] = "F2"{
					at_location <- any_location_in(tree_area[0]);
					loop p over:connect_team_list{
						add map<string, string>(["Name"::"Flame2",
								"x"::at_location.x, 
								"y"::at_location.z, 
								"z"::-at_location.y,
								"PlayerID"::map_player_intid[p]]) to:send_tree_update_threats;			
					}
				}
				create icon_everything{
					location <- at_location;
					type <- "fire";
					init_time <- time_now;
				}
				write "Create Fireee!"  + " at time " + time_now +"s" + " type " + fire_type[i];
			}
		}
		
		// Alien
		loop i from:0 to:(length(alien_Stime)-1){
			if (time_now >= alien_Stime[i]) and (time_now < alien_Etime[i]) and (time_now mod time_interval = 1){
				list<int> it_zone;
				point at_location;
				if alien_type[i] = "A1"{
					it_zone <- sample(zone_list,1,false);
					loop j over:it_zone{
						list<tree> for_rnd_tree <- tree where ((each.player = connect_team_list[0]) 
															and (each.zone = j)
															and (each.it_can_growth != "0"));
						ask sample(for_rnd_tree,1,false){
							at_location <- {self.location.x + rnd_choice([(-1)::0.5,(1)::0.5]) + rnd(0.5, tree_distance/1.5), 
											self.location.y + rnd_choice([(-1)::0.5,(1)::0.5]) + rnd(0.5, tree_distance/1.5), 
											self.location.z};
							loop p over:connect_team_list{
								add map<string, string>(["Name"::"Alien2", 
									"x"::at_location.x, 
									"y"::at_location.z, 
									"z"::-at_location.y,
									"PlayerID"::map_player_intid[p]]) to:send_tree_update_threats;	
							}
							create icon_everything{
								location <- at_location;
								type <- "alien";
								init_time <- time_now;
							}
						}
					}
				}
				else if alien_type[i] = "A2"{
					it_zone <- sample(zone_list,2,false);
					loop j over:it_zone{
						list<tree> for_rnd_tree <- tree where ((each.player = connect_team_list[0]) 
															and (each.zone = j)
															and (each.it_can_growth != "0"));
						ask sample(for_rnd_tree,2,false){
							at_location <- {self.location.x + rnd_choice([(-1)::0.5,(1)::0.5]) + rnd(0.5, tree_distance/1.5), 
											self.location.y + rnd_choice([(-1)::0.5,(1)::0.5]) + rnd(0.5, tree_distance/1.5), 
											self.location.z};
							loop p over:connect_team_list{
								add map<string, string>(["Name"::"Alien", 
									"x"::at_location.x, 
									"y"::at_location.z, 
									"z"::-at_location.y,
									"PlayerID"::map_player_intid[p]]) to:send_tree_update_threats;
							}
							create icon_everything{
								location <- at_location;
								type <- "alien";
								init_time <- time_now;
							}
						}
					}
				}
				write "Create Aliennn! at zone " + it_zone + " at time " + time_now +"s" + " type " + alien_type[i];
			}
		}
			
		// Weeds
			loop i from:0 to:(length(grass_Stime)-1){
				if (time_now >= grass_Stime[i]) and (time_now < grass_Etime[i]) and (time_now mod time_interval = 1){
					list<int> it_zone;
					if grass_type[i] = "G1"{
						it_zone <- sample(zone_list,1,false);
						loop j over:it_zone{
							loop p over:connect_team_list{
								list<tree> for_rnd_tree <- tree where ((each.player = p) 
																	and (each.zone = j)
																	and (each.it_can_growth = "1")
																	and (each.it_state != 3));
								ask sample(for_rnd_tree,2,false){
									add map<string, string>(["PlayerID"::map_player_intid[self.player], 
															"Name"::self.name, 
															"State"::99]) to:send_tree_update_grass;
//									it_can_growth <- "-1";
									
									list<tree> temp_list_tree <- tree at_distance (tree_distance)#m 
																		where ((each.it_can_growth = "1")
																			and (each.it_state != 3));
									ask temp_list_tree where (each.player = p){
										add map<string, string>(["PlayerID"::map_player_intid[self.player], 
																"Name"::self.name, 
																"State"::99]) to:send_tree_update_grass;
//										it_can_growth <- "-1";
									}
								}
							}
						}
					}
					else if grass_type[i] = "G2"{
						it_zone <- sample(zone_list,2,false);
						loop j over:it_zone{
							loop p over:connect_team_list{
								list<tree> for_rnd_tree <- tree where ((each.player = p) 
																	and (each.zone = j)
																	and (each.it_can_growth = "1")
																	and (each.it_state != 3));
								ask sample(for_rnd_tree,4,false){
									add map<string, string>(["PlayerID"::map_player_intid[self.player], 
															"Name"::self.name, 
															"State"::99]) to:send_tree_update_grass;
//									it_can_growth <- "-1";
									
									list<tree> temp_list_tree <- tree at_distance (tree_distance)#m 
																		where ((each.it_can_growth = "1")
																			and (each.it_state != 3));
									ask temp_list_tree where (each.player = p){
										add map<string, string>(["PlayerID"::map_player_intid[self.player], 
																"Name"::self.name, 
																"State"::99]) to:send_tree_update_grass;
//										it_can_growth <- "-1";
									}
								}
							}
						}
					}
					write "Create Grass! at zone " + it_zone + " at time " + time_now +"s" + " type " + grass_type[i];
				}
			}
			
		// Growth
		ask tree where (each.it_can_growth = "1"){
			current_time <- current_time + 1;
			height <- logist_growth(init_height, float(list_of_height[self.tree_type-1]), float(list_of_growth_rate[self.tree_type-1]));
			int h_max <- list_of_max_height_in_n_years[self.tree_type - 1];
			
			if (height >= (h_max*0.5)) and (height < (h_max*0.8)) and (it_state = 1){
				it_state <- 2;
				add map<string, string>(["PlayerID"::map_player_intid[self.player], "Name"::self.name, "State"::it_state]) to:send_tree_update_grow;
			}
			else if (height >= (h_max*0.8)) and (height <= (h_max)) and (it_state = 2){
				it_state <- 3;
				add map<string, string>(["PlayerID"::map_player_intid[self.player], "Name"::self.name, "State"::it_state]) to:send_tree_update_grow;
			}
		}
		
		do update_n_remain_tree;
		
		// Background
		loop p over:connect_team_list{
			loop j from:0 to:(length(list_of_bg_score)-2){
				if (sum_score_list[p-1] >= list_of_bg_score[j]) and 
					(sum_score_list[p-1] < list_of_bg_score[j+1]) and
					(j != list_of_player_bg[p-1]){
					add map<string, string>(["PlayerID"::map_player_intid[p], 
											"Name"::string(j+1), 
											"State"::""]) to:send_tree_update_environment;
					list_of_player_bg[p-1] <- j;
					write "Player " + map_player_intid[p] + " change environment to " + string("Environment"+(j+1)) ;
				}
			}
		}
		
		// Send update
		if not empty(send_tree_update_grass){
			add ["Head"::"Update", 
				"Body"::"GRASS", 
				"Trees"::send_tree_update_grass, 
				"Threats"::""] to:all_for_send;
		}

		if not empty(send_tree_update_grow){
			add ["Head"::"Update", 
				"Body"::"GROW", 
				"Trees"::send_tree_update_grow, 
				"Threats"::""] to:all_for_send;
		}			
		
		if not empty(send_tree_update_threats){
			add ["Head"::"Update", 
				"Body"::"", 
				"Trees"::"",
				"Threats"::send_tree_update_threats] to:all_for_send;
		}
		
		if not empty(send_tree_update_environment){
			add ["Head"::"Background", 
				"Body"::"", 
				"Trees"::send_tree_update_environment, 
				"Threats"::""] to:all_for_send;
		}
		
		// Rain
		loop i from:0 to:(length(raining_Stime)-1){
			if (time_now = raining_Stime[i]){
				add ["Head"::"Rain", 
					"Body"::"Start", 
					"Trees"::"", 
					"Threats"::""] to:all_for_send;	
				write "Start rainnnn" + " at time " + time_now +"s" ;
			}
			else if (time_now = raining_Etime[i]){
				add ["Head"::"Rain", 
					"Body"::"Stop", 
					"Trees"::"", 
					"Threats"::""] to:all_for_send;	
				write "Stop rainnnn" + " at time " + time_now +"s";
			}
		}
		
		// Announce
		if time_now = announce_time{
			write "send Announce!!!!!! hereeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee";
			add ["Head"::"Announce", 
			"Body"::"", 
			"Trees"::"", 
			"Threats"::""] to:all_for_send;
		}
		
		next_time <- false;
	}
	
	action remove_threat(int p, string threat){
		list<map<string,string>> send_remove_threats <- [];
		if (threat = "Fire"){
			add map<string, string>(["Name"::"Fire", 
								"x"::"",
								"y"::"", 
								"z"::"",
								"PlayerID"::map_player_intid[p]]) to:send_remove_threats;
		}
		else if (threat = "Aliens"){
			add map<string, string>(["Name"::"Aliens", 
								"x"::"",
								"y"::"", 
								"z"::"",
								"PlayerID"::map_player_intid[p]]) to:send_remove_threats;
		}
		else if (threat = "Grasses"){
			add map<string, string>(["Name"::"Grasses", 
								"x"::"",
								"y"::"", 
								"z"::"",
								"PlayerID"::map_player_intid[p]]) to:send_remove_threats;
		}
		
		write "send_remove_threats: " + send_remove_threats;
		add ["Head"::"RemoveThreat", 
			"Body"::"", 
			"Trees"::"", 
			"Threats"::send_remove_threats] to:all_for_send;
	}
	
			
	reflex send_message_to_unity{
//		write "all_for_send " + all_for_send;
		if not empty(all_for_send){
			ask unity_linker {
				do send_message players: unity_player as list mes: ["ListOfMessage"::all_for_send];
			}
			all_for_send <- [];
		}
	}
	
	action save_Questionnaire_answer_to_csv{
		if count_start = 1{
			list header <- ["round", "team", "no.", "before/after", "answer"];
			write header;
			save header to: "../results/Questionnaire_answers.csv" header:false format:"csv" rewrite:true;
		}	
		
		loop p over:connect_team_list{
			if not empty(for_save_answer[map_player_idint[map_player_intid[p]]-1][0]){
				loop i from:0 to: length(for_save_answer[map_player_idint[map_player_intid[p]]-1][0])-1{
					list temp <- [];
					add count_start to:temp;
					add ("team"+p) to:temp;
					add (i+1) to:temp;
					add "before" to:temp;
					add for_save_answer[map_player_idint[map_player_intid[p]]-1][0][i] to:temp;
					
					write temp;
					save temp to: "../results/Questionnaire_answers.csv" header:false format:"csv" rewrite:false;
				}
			}
			else{
				write "The questionnaire (before) is empty.";
			}
			
			if not empty(for_save_answer[map_player_idint[map_player_intid[p]]-1][1]){
				loop i from:0 to: length(for_save_answer[map_player_idint[map_player_intid[p]]-1][1])-1{
					list temp <- [];
					add count_start to:temp;
					add ("team"+p) to:temp;
					add (i+1) to:temp;
					add "after" to:temp;
					add for_save_answer[map_player_idint[map_player_intid[p]]-1][1][i] to:temp;
					
					write temp;
					save temp to: "../results/Questionnaire_answers.csv" header:false format:"csv" rewrite:false;
				}	
			}
			else{
				write "The questionnaire (after) is empty.";
			}
		}
	}
}

species Server skills: [network] parallel: false {	
	map string_to_map (string txt) {
//		write "txt= " + txt;
		map m <- map([]);
		list<string> parts <- txt split_with ";";
//		write "parts= " + parts;
		loop p over: parts {
			list<string> kv <- p split_with "=";
//			write "kv= " + kv;
		    if (length(kv) >= 2) {
		      add kv[0]::kv[1] to:m;    
	      }
	  	}
	  	return m;
	}

	reflex receive when: has_more_message() {
		loop while: has_more_message() {
			message mm <- fetch_message();
			string txt <- mm.contents;
			map msg <- string_to_map(txt);
//			write "msg=" + msg;
			string type <- msg["type"];
			string team <- msg["team"];
			string threat <- msg["threat"];
		    write "" + msg["type"] + " || " + msg["team"] + " || " + msg["threat"];
		    
		    ask world{
		    	do remove_threat(map_player_colorint[team], threat);
		    }
		    
			do send to: mm.sender contents: ("Team " + team + " has completed removing " + threat + "!");
		}
	}
}

species unity_linker parent: abstract_unity_linker {
	string player_species <- string(unity_player);
	int max_num_players  <- -1;
	int min_num_players  <- 7;
	unity_property up_oldtree_1;
	unity_property up_oldtree_2;
	unity_property up_oldtree_3;
	unity_property up_oldtree_4;
	unity_property up_oldtree_5;
	unity_property up_oldtree_6;
	unity_property up_oldtree_7;
	unity_property up_oldtree_8;
	unity_property up_oldtree_9;
	unity_property up_oldtree_10;
	unity_property up_seeding1;
	unity_property up_seeding2;
	unity_property up_seeding3;
	unity_property up_seeding4;
	unity_property up_seeding5;
	unity_property up_seeding6;
	unity_property up_seeding7;
	unity_property up_seeding8;
	unity_property up_seeding9;
	unity_property up_seeding10;
	unity_property up_alien;
	unity_property up_fire;
	unity_property up_road;

	list<point> init_locations <- define_init_locations();

	list<point> define_init_locations {
		return [result_location + {0,adjust_y, adjust_z},
			result_location + {0, adjust_y, adjust_z},
			result_location + {0, adjust_y, adjust_z},
			result_location + {0, adjust_y, adjust_z},
			result_location + {0, adjust_y, adjust_z},
			result_location + {0, adjust_y, adjust_z}
		];
	}
	
	action ChangeTreeState(string tree_Name, string status){
		ask tree where ((each.name = tree_Name)){
			if it_can_growth in ["-1", "1"]{
				it_can_growth <- status;
			}
		}	
	}
	
	action PlayerID_Ready(string player_ID, string Ready){					
		if Ready = "Ready1"{
			write "PlayerID_Ready " + player_ID + " " + Ready + "Readyyyyyyyyy";
			
			if not (map_player_idint[player_ID] in ready_team_list){
				add map_player_idint[player_ID] to:ready_team_list;
			}
			
			if (ready_team_list sort_by (each)) = (connect_team_list sort_by (each)){
				write "All player ready " + (ready_team_list sort_by (each)) + " = " +
						(connect_team_list sort_by (each));
				all_player_ready <- true;
				ask world{
					do pause;
					can_start <- true;
				}
			}
		}
		else if Ready = "Ready2"{
			ask unity_player where (each.name = player_ID){
				location <- {tutorial_location.x, tutorial_location.y + adjust_y, adjust_z};
				ask unity_linker {
					new_player_position[myself.name] <- [myself.location.x *precision,
														myself.location.y *precision,
														myself.location.z *precision];
					move_player_event <- true;
				}
			}
			write "PlayerID_Ready " + player_ID + " " + Ready + " move to tutorial zone";
		}
		
	}
	
	action QuestionnaireData(string PlayerID, string Header, string Message){
		write "QuestionnaireData " + Header + " " + PlayerID + " " + Message;

		list<string> answer_list ;
		loop i over: container(Message){
			add i to: answer_list;
		}
		
		if Header = "Before"{
			write "" + Header + " " + answer_list;
			
			if not (map_player_idint[PlayerID] in before_Q_team_list){
				add map_player_idint[PlayerID] to:before_Q_team_list;	
				loop i over: answer_list{
					add i to: for_save_answer[map_player_idint[PlayerID]-1][0];
				}
			}
			write for_save_answer;
			
			if (before_Q_team_list sort_by (each)) = (connect_team_list sort_by (each)){
				write "All player before Q " + (before_Q_team_list sort_by (each)) + " = " +
					(connect_team_list sort_by (each));
				all_player_before_Q <- true;
				ask world{
					do pause;
					can_start <- true;
					tutorial_finish <- true;
				}
			}
		}
		else if Header = "After"{
			list<map<string,string>> send_tree_update_environment <- [];
			write "" + Header + " " + answer_list;
			
			if not (map_player_idint[PlayerID] in after_Q_team_list){
				add map_player_idint[PlayerID] to:after_Q_team_list;	
				loop i over: answer_list{
					add i to: for_save_answer[map_player_idint[PlayerID]-1][1];
				}
			}
			write for_save_answer;
			
			// Background
			add map<string, string>(["PlayerID"::PlayerID, 
									"Name"::string(2), 
									"State"::""]) to:send_tree_update_environment;
			write "Player " + PlayerID + " send " + string("Environment"+(2)) ;
			
			add ["Head"::"Background", 
				"Body"::"", 
				"Trees"::send_tree_update_environment, 
				"Threats"::""] to:all_for_send;
						
			if (after_Q_team_list sort_by (each)) = (connect_team_list sort_by (each)){
				write "All player after Q " + (after_Q_team_list sort_by (each)) + " = " +
					(connect_team_list sort_by (each));
				all_player_after_Q <- true;
				ask world{
					do save_Questionnaire_answer_to_csv;
					write "save_Questionnaire_answer_to_csvvvvvvvvvvvvvvvvvvvvvvvvvvvv";
					do pause;
					can_start <- true;
				}
			}
		}
	}
	
	init {
		do define_properties;
//		player_unity_properties <- [nil,nil,nil,nil,nil,nil];
		
//		do add_background_geometries(playerable_area,up_road);
//		do add_background_geometries(tree_area,up_road);
//		do add_background_geometries(map_area,up_road);
//		do add_background_geometries(tutorial_area,up_road);

	}
	
	action define_properties {
		unity_aspect seeding3_aspect <- prefab_aspect("temp/Prefab/VU2/Magnolia/SeedingMagnolia",1.0,0.0,1.0,0.0,precision);
		up_seeding3 <- geometry_properties("seeding3","",seeding3_aspect,#no_interaction,true);
		unity_properties << up_seeding3;
		
		unity_aspect seeding4_aspect <- prefab_aspect("temp/Prefab/VU2/Phoebe/SeedingPhoebe",1.0,0.0,1.0,0.0,precision);
		up_seeding4 <- geometry_properties("seeding4","",seeding4_aspect,#no_interaction,true);
		unity_properties << up_seeding4;
		
		unity_aspect seeding10_aspect <- prefab_aspect("temp/Prefab/VU2/Gmelina/SeedingGmelina",1.0,0.0,1.0,0.0,precision);
		up_seeding10 <- geometry_properties("seeding10","",seeding10_aspect,#no_interaction,true);
		unity_properties << up_seeding10;
		
		
		unity_aspect old_tree1_aspect <- prefab_aspect("temp/Prefab/Tree/2.Quercus/QuercusTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_1 <- geometry_properties("old_tree1","",old_tree1_aspect,#no_interaction,true);
		unity_properties << up_oldtree_1;
		
		unity_aspect old_tree2_aspect <- prefab_aspect("temp/Prefab/Tree/3.Sapindus/SapindusTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_2 <- geometry_properties("old_tree2","",old_tree2_aspect,#no_interaction,true);
		unity_properties << up_oldtree_2;
		
		unity_aspect old_tree3_aspect <- prefab_aspect("temp/Prefab/Tree/4.Magnolia/MagnoliaTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_3 <- geometry_properties("old_tree3","",old_tree3_aspect,#no_interaction,true);
		unity_properties << up_oldtree_3;
		
		unity_aspect old_tree4_aspect <- prefab_aspect("temp/Prefab/Tree/5.Phoebe/PhoebeTree_TallNoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_4 <- geometry_properties("old_tree4","",old_tree4_aspect,#no_interaction,true);
		unity_properties << up_oldtree_4;
		
		unity_aspect old_tree5_aspect <- prefab_aspect("temp/Prefab/Tree/6.Debregeasia/DebregeasiaTree_Short_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_5 <- geometry_properties("old_tree5","",old_tree5_aspect,#no_interaction,true);
		unity_properties << up_oldtree_5;

		unity_aspect old_tree6_aspect <- prefab_aspect("temp/Prefab/Tree/7.Diospyros/DiospyrosTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_6 <- geometry_properties("old_tree6","",old_tree6_aspect,#no_interaction,true);
		unity_properties << up_oldtree_6;

		unity_aspect old_tree7_aspect <- prefab_aspect("temp/Prefab/Tree/8.Ostodes/OstodesTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_7 <- geometry_properties("old_tree7","",old_tree7_aspect,#no_interaction,true);
		unity_properties << up_oldtree_7;

		unity_aspect old_tree8_aspect <- prefab_aspect("temp/Prefab/Tree/9.Phyllan/PhyllanTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_8 <- geometry_properties("old_tree8","",old_tree8_aspect,#no_interaction,true);
		unity_properties << up_oldtree_8;
		
		unity_aspect old_tree9_aspect <- prefab_aspect("temp/Prefab/Tree/11.Castano/CastanoTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_9 <- geometry_properties("old_tree9","",old_tree9_aspect,#no_interaction,true);
		unity_properties << up_oldtree_9;
		
		unity_aspect old_tree10_aspect <- prefab_aspect("temp/Prefab/Tree/12.Gmelina/Gmelina_Tree_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_10 <- geometry_properties("old_tree10","",old_tree10_aspect,#no_interaction,true);
		unity_properties << up_oldtree_10;
		
		unity_aspect road_aspect <- geometry_aspect(0.1, #black, precision);
		up_road<- geometry_properties("road", "", road_aspect, #collider, false);
		unity_properties << up_road;
	}
	reflex send_geometries {
		list<tree> tree_type1 <- tree where (each.tree_type = 1);
		list<tree> tree_type2 <- tree where (each.tree_type = 2);
		list<tree> tree_type3 <- tree where (each.tree_type = 3);
		list<tree> tree_type4 <- tree where (each.tree_type = 4);
		list<tree> tree_type5 <- tree where (each.tree_type = 5);
		list<tree> tree_type6 <- tree where (each.tree_type = 6);
		list<tree> tree_type7 <- tree where (each.tree_type = 7);
		list<tree> tree_type8 <- tree where (each.tree_type = 8);
		list<tree> tree_type9 <- tree where (each.tree_type = 9);
		list<tree> tree_type10 <- tree where (each.tree_type = 10);
		if not empty(tree_type1){
			do add_geometries_to_send(tree_type1,up_seeding3);
		}
		if not empty(tree_type2){
			do add_geometries_to_send(tree_type2,up_seeding3);
		}
		if not empty(tree_type3){
			do add_geometries_to_send(tree_type3,up_seeding3);
		}
		if not empty(tree_type4){
			do add_geometries_to_send(tree_type4,up_seeding4);
		}
		if not empty(tree_type5){
			do add_geometries_to_send(tree_type5,up_seeding3);
		}
		if not empty(tree_type6){
			do add_geometries_to_send(tree_type6,up_seeding3);
		}
		if not empty(tree_type7){
			do add_geometries_to_send(tree_type7,up_seeding3);
		}
		if not empty(tree_type8){
			do add_geometries_to_send(tree_type8,up_seeding3);
		}
		if not empty(tree_type9){
			do add_geometries_to_send(tree_type9,up_seeding3);
		}
		if not empty(tree_type10){
			do add_geometries_to_send(tree_type10,up_seeding10);
		}
		
		list<old_tree> old_tree_type1 <- old_tree where (each.tree_type = 1);
		list<old_tree> old_tree_type2 <- old_tree where (each.tree_type = 2);
		list<old_tree> old_tree_type3 <- old_tree where (each.tree_type = 3);
		list<old_tree> old_tree_type4 <- old_tree where (each.tree_type = 4);
		list<old_tree> old_tree_type5 <- old_tree where (each.tree_type = 5);
		list<old_tree> old_tree_type6 <- old_tree where (each.tree_type = 6);
		list<old_tree> old_tree_type7 <- old_tree where (each.tree_type = 7);
		list<old_tree> old_tree_type8 <- old_tree where (each.tree_type = 8);
		list<old_tree> old_tree_type9 <- old_tree where (each.tree_type = 9);
		list<old_tree> old_tree_type10 <- old_tree where (each.tree_type = 10);
		if not empty(old_tree_type1){
			do add_geometries_to_send(old_tree_type1,up_oldtree_1);
		}
		if not empty(old_tree_type2){
			do add_geometries_to_send(old_tree_type2,up_oldtree_2);
		}
		if not empty(old_tree_type3){
			do add_geometries_to_send(old_tree_type3,up_oldtree_3);
		}
		if not empty(old_tree_type4){
			do add_geometries_to_send(old_tree_type4,up_oldtree_4);
		}	
		if not empty(old_tree_type5){
			do add_geometries_to_send(old_tree_type5,up_oldtree_5);
		}	
		if not empty(old_tree_type6){
			do add_geometries_to_send(old_tree_type6,up_oldtree_6);
		}	
		if not empty(old_tree_type7){
			do add_geometries_to_send(old_tree_type7,up_oldtree_7);
		}	
		if not empty(old_tree_type8){
			do add_geometries_to_send(old_tree_type8,up_oldtree_8);
		}	
		if not empty(old_tree_type9){
			do add_geometries_to_send(old_tree_type9,up_oldtree_9);
		}	
		if not empty(old_tree_type10){
			do add_geometries_to_send(old_tree_type10,up_oldtree_10);
		}		
	}
}


species unity_player parent: abstract_unity_player{
	float player_size <- 1.0;
	rgb color ; // <- #red;
	float cone_distance <- 5.0 * player_size;
	float cone_amplitude <- 90.0;
	float player_rotation <- 90.0;
	bool to_display <- true;
	float z_offset <- 2.0;
	
	int team_id ;
	bool correct_location <- false;
	
	init{
		team_id <- map_player_idint[name];
		write name + " " + team_id;
		color <- rgb(player_colors[team_id-1]);		
	}
	
	aspect default {
		if to_display {
			if selected {
				 draw circle(player_size) at: location + {0, 0, z_offset} color: rgb(#blue, 0.5);
			}
			draw circle(player_size/2.0) at: location + {0, 0, z_offset} color: color ;
			draw player_perception_cone() color: rgb(color, 0.5);
		}
	}
}

experiment vr_xp parent:init_exp autorun: false type: unity {
//	float minimum_cycle_duration <- 1.0;
	float minimum_cycle_duration <- 0.5;
	string unity_linker_species <- string(unity_linker);
	list<string> displays_to_hide <- ["Main"];
	float t_ref;
	
	action create_player(string id) {
		ask unity_linker {
			write 'create player' + id;
			do create_player(id);
			write 'create player completed!';
		}
	}

	action remove_player(string id_input) {
		if (not empty(unity_player)) {
			ask first(unity_player where (each.name = id_input)) {
				do die;
			}
		}
	}

	output {
		 display Main_VR parent:Main{
			 species unity_player;
			 event #mouse_down{
				 float t <- gama.machine_time;
				 if (t - t_ref) > 500 {
					 ask unity_linker {
						 move_player_event <- true;
//						 write "move player from user";
					 }
					 t_ref <- t;
				 }
			 }
		 }
	}
}


