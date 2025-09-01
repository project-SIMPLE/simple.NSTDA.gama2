model forestmonitoringonemap_model_VR

import "forest_monitoring_one_map.gaml"

global{
	int adjust_z <- 0;
	list all_for_send <- [];
	init{
		create unity_player{
			name <- "Player_104";
			location <- {width/2, height/2, adjust_z};
		}
		create unity_player{
			name <- "Player_102";
			location <- {width/2, height/2, adjust_z};
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
						new_player_position[myself.name] <- [myself.location.x *precision,myself.location.y *precision,myself.location.z *precision];
						move_player_event <- true;
					}
				}
				do send_readID;
				sum_score_list <- list_with(6,0);
			}
			else{
				add ["Head"::"TutorialStart", 
					"Body"::"", 
					"Trees"::"",
					"Threats"::""] to:all_for_send;
				write "send TutorialStart at cycle = " + cycle;
				
				ask unity_player{
					location <- {tutorial_location.x, tutorial_location.y, adjust_z};
					ask unity_linker {
						new_player_position[myself.name] <- [myself.location.x *precision,myself.location.y *precision,myself.location.z *precision];
						move_player_event <- true;
					}
				}
				if skip_tutorial{
					do pause;
					can_start <- true;
					tutorial_finish <- true;
				}
			}
		}
		else{
			do prepare_step;
			ready_team_list <- [];
			before_Q_team_list <- [];
			after_Q_team_list <- [];
			
			add ["Head"::"ReadyCheck", 
			"Body"::"", 
			"Trees"::"",
			"Threats"::""] to:all_for_send;
			write "send ReadyCheck at cycle = " + cycle;
//			do pause;
//			can_start <- true;
			ask old_tree {do die;}
			ask tree {do die;}
		}
	}
	
	action pause_game {
		if tutorial_finish{
			add ["Head"::"StopGame", 
				"Body"::"", 
				"Trees"::"",
				"Threats"::""] to:all_for_send;
			write "send StopGame at cycle = " + cycle;
		}
		tutorial_finish <- false;
		game_start <- false;
		all_player_ready <- false;
//		ready_team_list <- [];
	}
		
	action update_n_remain_tree {
		write "n_remain_tree " + n_remain_tree;
		
		loop p over:connect_team_list{
			loop i from:0 to:2{
				list<tree> for_count_tree_state <- tree where ((each.it_state = i+1) 
															and (each.player = p) 
															and (each.it_can_growth != "0"));
				n_remain_tree[p-1][i] <- length(for_count_tree_state);
				write "Player" + p + " length state" + (i+1) + " " + n_remain_tree[p-1][i];
			}
		}

		loop i over:connect_team_list{
			sum_score_list[i-1] <- 	1*n_remain_tree[i-1][0] + 
									1.25*n_remain_tree[i-1][1] + 
									1.5*n_remain_tree[i-1][2] -
									0.5*(100 - sum(n_remain_tree[i-1]));
		}
		
		write "sum_score_list " + sum_score_list;
	}
	
	action prepare_step {		
		ask unity_player{
			if not (map_player_idint[self.name] in connect_team_list){
				add map_player_idint[self.name] to:connect_team_list;
			}
		}
		write "connect_team_list " + connect_team_list;
//		n_teams <- length(connect_team_list);
	}
	
	reflex end_game when:(time_now >= time_to_play*n_teams){
		do pause_game;
		
		time_now <- (time_to_play*n_teams);
		can_start <- false;
		tutorial_finish <- true;
		game_start <- false;
		end_game <- true;
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
//		write send_tree_update_readID;
		
		add ["Head"::"ReadID", 
				"Body"::"", 
				"Trees"::send_tree_update_readID,
				"Threats"::""] to:all_for_send;
				
		write "Send ReadID at cycle = " + cycle;
		
		ask tree where not(each.player in connect_team_list){
			do die;
		}
		ask old_tree where not(each.player in connect_team_list){
			do die;
		}	
		
//		ask unity_player{
//			write "move player " + self.name;
//			location <- main_location + {0, 0, 3};
//			ask unity_linker {
//				new_player_position[myself.name] <- [myself.location.x *precision,myself.location.y *precision,myself.location.z *precision];
//				move_player_event <- true;
//			}
//		}	
	}
	
	reflex update_height_and_threats when:(tutorial_finish = true) and (game_start = true){
		list<map<string,string>> send_tree_update_grass <- [];
		list<map<string,string>> send_tree_update_threats <- [];
		list<map<string,string>> send_tree_update_grow <- [];
		list<map<string,string>> send_tree_update_environment <- [];
		list<map<string,string>> send_tree_update_rain <- [];
		
		// Fire
		loop i from:0 to:(length(fire_Stime)-1){
			if (time_now >= fire_Stime[i]) and (time_now < fire_Etime[i]) and (time_now mod 15 = 0){
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
				}
			}
		}
		
		// Alien
		loop i from:0 to:(length(alien_Stime)-1){
			if (time_now >= alien_Stime[i]) and (time_now < alien_Etime[i]) and (time_now mod 15 = 0){
				list<int> it_zone;
				point at_location;
				if alien_type[i] = "A1"{
					it_zone <- sample(zone_list,1,false);
					loop j over:it_zone{
						list<tree> for_rnd_tree <- tree where ((each.player = connect_team_list[0]) 
															and (each.zone = j)
															and (each.it_can_growth != "0"));
						ask sample(for_rnd_tree,1,false){
							at_location <- {self.location.x + rnd(-tree_distance/2, tree_distance/2), 
											self.location.y + rnd(-tree_distance/2, tree_distance/2), 
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
							at_location <- {self.location.x + rnd(-tree_distance/2, tree_distance/2), 
											self.location.y + rnd(-tree_distance/2, tree_distance/2), 
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
							}
						}
					}
				}
				write "send_tree_update_threats " + send_tree_update_threats;
				write "it_zone " + it_zone + " at time " + time_now +"s" + " type " + alien_type[i];
			}
		}
			
		// Weeds
			loop i from:0 to:(length(grass_Stime)-1){
				if (time_now >= grass_Stime[i]) and (time_now < grass_Etime[i]) and (time_now mod 15 = 0){
					list<int> it_zone;
					if grass_type[i] = "G1"{
						it_zone <- sample(zone_list,1,false);
						loop j over:it_zone{
							loop p over:connect_team_list{
								list<tree> for_rnd_tree <- tree where ((each.player = p) 
																	and (each.zone = j)
																	and (each.it_can_growth = "1"));
								ask sample(for_rnd_tree,2,false){
									add map<string, string>(["PlayerID"::map_player_intid[self.player], 
															"Name"::self.name, 
															"State"::99]) to:send_tree_update_grass;
									it_can_growth <- "-1";
									
									list<tree> temp_list_tree <- tree at_distance (tree_distance)#m 
																		where (each.it_can_growth = "1");
									write "See hereeeeeeee G1 Player" + p + " " 
										+ self.name + " " + temp_list_tree;
									ask temp_list_tree where (each.player = p){
										add map<string, string>(["PlayerID"::map_player_intid[self.player], 
																"Name"::self.name, 
																"State"::99]) to:send_tree_update_grass;
										it_can_growth <- "-1";
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
																	and (each.it_can_growth = "1"));
								ask sample(for_rnd_tree,4,false){
									add map<string, string>(["PlayerID"::map_player_intid[self.player], 
															"Name"::self.name, 
															"State"::99]) to:send_tree_update_grass;
									it_can_growth <- "-1";
									
									list<tree> temp_list_tree <- tree at_distance (tree_distance)#m 
																		where (each.it_can_growth = "1");
									write "See hereeeeeeee G2 Player" + p + " " 
										+ self.name + " " + temp_list_tree;
									ask temp_list_tree where (each.player = p){
										add map<string, string>(["PlayerID"::map_player_intid[self.player], 
																"Name"::self.name, 
																"State"::99]) to:send_tree_update_grass;
										it_can_growth <- "-1";
									}
								}
							}
						}
					}
					write "send_tree_update_grass " + send_tree_update_grass;
					write "it_zone " + it_zone + " at time " + time_now +"s" + " type " + grass_type[i];
				}
			}
			
		// Growth
		ask tree where (each.it_can_growth = "1"){
			current_time <- current_time + 1;
			height <- logist_growth(init_height, float(list_of_height[self.tree_type-1]), float(list_of_growth_rate[self.tree_type-1]), 1);
			int h_max <- list_of_max_height_in_n_years[self.tree_type - 1];
			
			if (height >= (h_max*0.5)) and (height < (h_max*0.8)) and (it_state = 1){
				it_state <- 2;
				write "Tree: " + self.name + " State -> 2 (it_type=" + self.tree_type +")";
				add map<string, string>(["PlayerID"::map_player_intid[self.player], "Name"::self.name, "State"::it_state]) to:send_tree_update_grow;
			}
			else if (height >= (h_max*0.8)) and (height <= (h_max)) and (it_state = 2){
				it_state <- 3;
				write "Tree: " + self.name + " State -> 3 (it_type=" + self.tree_type +")";
				add map<string, string>(["PlayerID"::map_player_intid[self.player], "Name"::self.name, "State"::it_state]) to:send_tree_update_grow;
			}
		}
		
		do update_n_remain_tree;
		
		// Background
		loop p over:connect_team_list{
			loop j from:0 to:4{
				if (sum_score_list[p-1] >= list_of_bg_score[j]) and 
					(sum_score_list[p-1] < list_of_bg_score[j+1]) and
					(j != list_of_player_bg[p-1]){
					add map<string, string>(["PlayerID"::map_player_intid[p], 
											"Name"::string(j+1), 
											"State"::""]) to:send_tree_update_environment;
					list_of_player_bg[p-1] <- j;
					write "Player " + map_player_intid[p] + " send " + string("Environment"+(j+1)) ;
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
			}
			else if (time_now = raining_Etime[i]){
				add ["Head"::"Rain", 
					"Body"::"Stop", 
					"Trees"::"", 
					"Threats"::""] to:all_for_send;	
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
	}
	
	reflex send_message_to_unity{
		write "all_for_send " + all_for_send;
		if not empty(all_for_send){
			ask unity_linker {
				do send_message players: unity_player as list mes: ["ListOfMessage"::all_for_send];
			}
			all_for_send <- [];
		}
	}
}

species unity_linker parent: abstract_unity_linker {
	string player_species <- string(unity_player);
	int max_num_players  <- 6;
	int min_num_players  <- 6;
	unity_property up_oldtree_1;
	unity_property up_oldtree_2;
	unity_property up_oldtree_3;
	unity_property up_seeding1;
	unity_property up_seeding2;
	unity_property up_seeding3;
	unity_property up_alien;
	unity_property up_fire;
	unity_property up_road;
	
	list<point> init_locations <- define_init_locations();

	list<point> define_init_locations {
		return [main_location + {0, 0, adjust_z},
			main_location + {0, 0, adjust_z},
			main_location + {0, 0, adjust_z},
			main_location + {0, 0, adjust_z},
			main_location + {0, 0, adjust_z},
			main_location + {0, 0, adjust_z}
		];
	}
	
	action ChangeTreeState(string tree_Name, string status){
		list<string> split_tree_ID ;
		list<string> playerID ;
		write "ChangeTreeState: " + tree_Name + " it_can_growth " + status;
		ask tree where ((each.name = tree_Name)){
			if it_can_growth in ["-1", "1"]{
				it_can_growth <- status;
				write "(ReceiveMessage) Tree: " + self.name + " it_can_growth " + status;
			}
		}	
	}
	
	action PlayerID_Ready(string player_ID, string Ready){
		write "PlayerID_Ready " + player_ID + " " + Ready;
		if not (map_player_idint[player_ID] in ready_team_list){
			add map_player_idint[player_ID] to:ready_team_list;
		}
		
		if (ready_team_list sort_by (each)) = (connect_team_list sort_by (each)){
			write "All player ready " + (ready_team_list sort_by (each)) + " = " +
					(connect_team_list sort_by (each));
			all_player_ready <- true;
//			ask world{
//				do pause;
//				can_start <- true;
//			}
		}
	}
	
	action QuestionnaireData(string PlayerID, string Header, string Message){
		write "QuestionnaireData " + Header + " " + PlayerID + " " + Message;
		list<string> answer_list <- Message split_with '';
		if Header = "Before"{
			write "" + Header + " " + answer_list;
			
			if not (map_player_idint[PlayerID] in before_Q_team_list){
				add map_player_idint[PlayerID] to:before_Q_team_list;	
			}
			
			if (before_Q_team_list sort_by (each)) = (connect_team_list sort_by (each)){
				write "All player before Q " + (before_Q_team_list sort_by (each)) + " = " +
					(connect_team_list sort_by (each));
				all_player_before_Q <- true;
				ask world{
					do pause;
					can_start <- true;
//					tutorial_finish <- true;
				}
			}
		}
		else if Header = "After"{
			write "" + Header + " " + answer_list;
			
			if not (map_player_idint[PlayerID] in after_Q_team_list){
				add map_player_idint[PlayerID] to:after_Q_team_list;	
			}
			
			if (after_Q_team_list sort_by (each)) = (connect_team_list sort_by (each)){
				write "All player after Q " + (after_Q_team_list sort_by (each)) + " = " +
					(connect_team_list sort_by (each));
				all_player_after_Q <- true;
				ask world{
					do pause;
					can_start <- true;
				}
			}
		}
	}


	init {
		do define_properties;
		player_unity_properties <- [nil,nil,nil,nil,nil,nil];
		
//		do add_background_geometries(playerable_area,up_road);
//		do add_background_geometries(tree_area,up_road);
//		do add_background_geometries(map_area,up_road);
//		do add_background_geometries(tutorial_area,up_road);

	}
	action define_properties {
		unity_aspect seeding1_aspect <- prefab_aspect("temp/Prefab/VU2/Gmelina/SeedingGmelina",1.0,0.0,1.0,0.0,precision);
		up_seeding1 <- geometry_properties("seeding1","",seeding1_aspect,#no_interaction,true);
		unity_properties << up_seeding1;
		
		unity_aspect seeding2_aspect <- prefab_aspect("temp/Prefab/VU2/Magnolia/SeedingMagnolia",1.0,0.0,1.0,0.0,precision);
		up_seeding2 <- geometry_properties("seeding2","",seeding2_aspect,#no_interaction,true);
		unity_properties << up_seeding2;
		
		unity_aspect seeding3_aspect <- prefab_aspect("temp/Prefab/VU2/Phoebe/SeedingPhoebe",1.0,0.0,1.0,0.0,precision);
		up_seeding3 <- geometry_properties("seeding3","",seeding3_aspect,#no_interaction,true);
		unity_properties << up_seeding3;
		
		unity_aspect old_tree1_aspect <- prefab_aspect("temp/Prefab/Tree/12.Gmelina/Gmelina_Tree_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_1 <- geometry_properties("old_tree1","",old_tree1_aspect,#no_interaction,true);
		unity_properties << up_oldtree_1;
		
		unity_aspect old_tree2_aspect <- prefab_aspect("temp/Prefab/Tree/4.Magnolia/MagnoliaTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_2 <- geometry_properties("old_tree2","",old_tree2_aspect,#no_interaction,true);
		unity_properties << up_oldtree_2;
		
		unity_aspect old_tree3_aspect <- prefab_aspect("temp/Prefab/Tree/5.Phoebe/PhoebeTree_TallNoFruit",1.0,0.0,1.0,0.0,precision);
		up_oldtree_3 <- geometry_properties("old_tree3","",old_tree3_aspect,#no_interaction,true);
		unity_properties << up_oldtree_3;
		
//		unity_aspect seeding1_aspect <- prefab_aspect("temp/Prefab/VU2/Gmelina/SeedingGmelina",1.0,0.0,1.0,0.0,precision);
//		up_seeding1 <- geometry_properties("seeding1","",seeding1_aspect,new_geometry_interaction(true, false,false,[]),true);
//		unity_properties << up_seeding1;
//		
//		unity_aspect seeding2_aspect <- prefab_aspect("temp/Prefab/VU2/Magnolia/SeedingMagnolia",1.0,0.0,1.0,0.0,precision);
//		up_seeding2 <- geometry_properties("seeding2","",seeding2_aspect,new_geometry_interaction(true, false,false,[]),true);
//		unity_properties << up_seeding2;
//		
//		unity_aspect seeding3_aspect <- prefab_aspect("temp/Prefab/VU2/Phoebe/SeedingPhoebe",1.0,0.0,1.0,0.0,precision);
//		up_seeding3 <- geometry_properties("seeding3","",seeding3_aspect,new_geometry_interaction(true, false,false,[]),true);
//		unity_properties << up_seeding3;
//		
//		unity_aspect old_tree1_aspect <- prefab_aspect("temp/Prefab/Tree/12.Gmelina/Gmelina_Tree_NoFruit",1.0,0.0,1.0,0.0,precision);
//		up_oldtree_1 <- geometry_properties("old_tree1","",old_tree1_aspect,new_geometry_interaction(true, false,false,[]),true);
//		unity_properties << up_oldtree_1;
//		
//		unity_aspect old_tree2_aspect <- prefab_aspect("temp/Prefab/Tree/4.Magnolia/MagnoliaTree_Tall_NoFruit",1.0,0.0,1.0,0.0,precision);
//		up_oldtree_2 <- geometry_properties("old_tree2","",old_tree2_aspect,new_geometry_interaction(true, false,false,[]),true);
//		unity_properties << up_oldtree_2;
//		
//		unity_aspect old_tree3_aspect <- prefab_aspect("temp/Prefab/Tree/5.Phoebe/PhoebeTree_TallNoFruit",1.0,0.0,1.0,0.0,precision);
//		up_oldtree_3 <- geometry_properties("old_tree3","",old_tree3_aspect,new_geometry_interaction(true, false,false,[]),true);
//		unity_properties << up_oldtree_3;
		
		unity_aspect road_aspect <- geometry_aspect(0.1, #black, precision);
		up_road<- geometry_properties("road", "", road_aspect, #collider, false);
		unity_properties << up_road;


	}
	reflex send_geometries {
		list<tree> tree_type1 <- tree where (each.tree_type = 1);
		list<tree> tree_type2 <- tree where (each.tree_type = 2);
		list<tree> tree_type3 <- tree where (each.tree_type = 3);
		do add_geometries_to_send(tree_type1,up_seeding1);
		do add_geometries_to_send(tree_type2,up_seeding2);
		do add_geometries_to_send(tree_type3,up_seeding3);
		
		list<old_tree> old_tree_type1 <- old_tree where (each.tree_type = 1);
		list<old_tree> old_tree_type2 <- old_tree where (each.tree_type = 2);
		list<old_tree> old_tree_type3 <- old_tree where (each.tree_type = 3);
		do add_geometries_to_send(old_tree_type1,up_oldtree_1);
		do add_geometries_to_send(old_tree_type2,up_oldtree_2);
		do add_geometries_to_send(old_tree_type3,up_oldtree_3);
	}
}

species unity_player parent: abstract_unity_player{
	float player_size <- 1.0;
	rgb color <- #red;
	float cone_distance <- 5.0 * player_size;
	float cone_amplitude <- 90.0;
	float player_rotation <- 90.0;
	bool to_display <- true;
	float z_offset <- 2.0;
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
	float minimum_cycle_duration <- 1.0;
	string unity_linker_species <- string(unity_linker);
	list<string> displays_to_hide <- ["Main"];
	float t_ref;

	action create_player(string id) {
		ask unity_linker {
			do create_player(id);
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
					 }
					 t_ref <- t;
				 }
			 }
		 }
	}
}
