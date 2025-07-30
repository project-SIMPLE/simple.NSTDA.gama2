model NewModel_model_VR

import "forest_monitoring.gaml"

global {
	int init_time <- 0;
	int time_now <- 0;
	int test_send <- 1;
	
	init{
//		create unity_player{
//			name <- "Player_106";
//		}
	}
	
	reflex update_time_and_bound when: (cycle >= init_cycle){
		if (gama.machine_time div 1000) - init_time >= 1{
			init_time <- gama.machine_time div 1000;
			time_now <- time_now + 1;
			write "time_now " + time_now + "s";
		}
	}
	
	reflex send_readID when:cycle=(init_cycle){
		list<map<string,string>> send_tree_update_readID <- [];
		ask tree{
			add map<string, string>(["PlayerID"::map_player_id[self.player], 
									"Name"::self.name, 
									"State"::""]) to:send_tree_update_readID;
		}
		
		write send_tree_update_readID;
		write "End First Start";
		
		ask unity_linker {
			do send_message players: unity_player as list mes: ["ListOfMessage"::[["Head"::"ReadID", 
																					"Body"::"", 
																					"Trees"::send_tree_update_readID,
																					"Threats"::""]]];
		}
		write "Send ReadID";
		
		ask tree where not(each.player in connect_team_list){
			do die;
		}
		
		ask unity_player{
			write "move player " + self.name;
			location <- playerable_area[map_player_id_reverse[self.name]-1].location + {0, 0, 3};
			ask unity_linker {
				new_player_position[myself.name] <- [myself.location.x *precision,myself.location.y *precision,myself.location.z *precision];
				move_player_event <- true;
			}
		}	
	}
	
	action resume_game {
		write "send Start";
		ask unity_linker {
			do send_message players: unity_player as list mes: ["ListOfMessage"::[["Head"::"Start", 
																					"Body"::"", 
																					"Trees"::"",
																					"Threats"::""]]];
		}
	}
	
	action pause_game {
		write "send Stop";
		ask unity_linker {
			do send_message players: unity_player as list mes: ["ListOfMessage"::[["Head"::"Stop", 
																					"Body"::"", 
																					"Trees"::"",
																					"Threats"::""]]];
		}
	}
	
	reflex end_game when:(time_now >= time_to_play){
		do pause_game;
		if time_now >= (time_to_play+1){
			do pause;
		}
	}
	
	reflex prepare_step when:(cycle=1) and (first_start=true){
		first_start <- false;
		
		ask unity_player{
			add map_player_id_reverse[self.name] to:connect_team_list;
		}
		write "connect_team_list " + connect_team_list;
		can_start <- true;
		do pause_game;
		do pause;
	}
	
//	reflex do_move_player when:(first_start=false) and (first_move_player=true) and (cycle>=init_cycle){
//		first_move_player <- false;
//		
//		ask unity_player{
//			write "move player " + self.name;
//			location <- playerable_area[map_player_id_reverse[self.name]-1].location + {0, 0, 3};
//			ask unity_linker {
//				new_player_position[myself.name] <- [myself.location.x *precision,myself.location.y *precision,myself.location.z *precision];
//				move_player_event <- true;
//			}
//		}	
//	}

	reflex update_n_remain_tree when:(cycle >= init_cycle){
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
			sum_score_list[i-1] <- n_remain_tree[i-1][0] + 2*n_remain_tree[i-1][1] + 3*n_remain_tree[i-1][2] ;
		}
		
		write "sum_score_list " + sum_score_list;
	}

//	and (time_now mod 5 = 0)(cycle >= init_cycle+1)
	reflex update_height_and_threats when:(time_now > 0)  {
		list all_for_send <- [];
		list<map<string,string>> send_tree_update_grass <- [];
		list<map<string,string>> send_tree_update_threats <- [];
		list<map<string,string>> send_tree_update_grow <- [];
		list<map<string,string>> send_tree_update_environment <- [];
		list<map<string,string>> send_tree_update_rain <- [];
		
		loop p over:connect_team_list{
			// Fire
			loop i from:0 to:(length(fire_Stime)-1){
				// and (time_now mod 15 = 0) (time_now = int((fire_Stime[i]+fire_Etime[i])/2))
				if (time_now >= fire_Stime[i]) and (time_now < fire_Etime[i]) and (time_now mod 15 = 0){
					point at_location;
					if fire_type[i] = "F1"{
						at_location <- any_location_in(usable_area_for_wildfire[p-1]-1);
						add map<string, string>(["Name"::"Flame1", 
									"x"::at_location.x, 
									"y"::at_location.z, 
									"z"::-at_location.y,
									"PlayerID"::map_player_id[p]]) to:send_tree_update_threats;
					}
					else if fire_type[i] = "F2"{
						at_location <- any_location_in(usable_area_for_wildfire[p-1]-1);
						add map<string, string>(["Name"::"Flame1",  //Flame2
									"x"::at_location.x, 
									"y"::at_location.z, 
									"z"::-at_location.y,
									"PlayerID"::map_player_id[p]]) to:send_tree_update_threats;
					}
					else if fire_type[i] = "F2C"{
						at_location <- any_location_in(tree_area[p-1]-5);
						add map<string, string>(["Name"::"Flame1",  //Flame2
									"x"::at_location.x, 
									"y"::at_location.z, 
									"z"::-at_location.y,
									"PlayerID"::map_player_id[p]]) to:send_tree_update_threats;
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
							list<tree> for_rnd_tree <- tree where ((each.player = p) 
																and (each.zone = j)
																and (each.it_can_growth != "0"));
							ask sample(for_rnd_tree,1,false){
								at_location <- {self.location.x + rnd(-tree_distance/2, tree_distance/2), 
												self.location.y + rnd(-tree_distance/2, tree_distance/2), 
												self.location.z};
								add map<string, string>(["Name"::"Alien", 
									"x"::at_location.x, 
									"y"::at_location.z, 
									"z"::-at_location.y,
									"PlayerID"::map_player_id[p]]) to:send_tree_update_threats;
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
							list<tree> for_rnd_tree <- tree where ((each.player = p) 
																and (each.zone = j)
																and (each.it_can_growth != "0"));
							ask sample(for_rnd_tree,2,false){
								at_location <- {self.location.x + rnd(-tree_distance/2, tree_distance/2), 
												self.location.y + rnd(-tree_distance/2, tree_distance/2), 
												self.location.z};
								add map<string, string>(["Name"::"Alien", 
									"x"::at_location.x, 
									"y"::at_location.z, 
									"z"::-at_location.y,
									"PlayerID"::map_player_id[p]]) to:send_tree_update_threats;
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
		}
		
		// Weeds
		loop p over:connect_team_list{
			loop i from:0 to:(length(grass_Stime)-1){
				if (time_now >= grass_Stime[i]) and (time_now < grass_Etime[i]) and (time_now mod 15 = 0){
					list<int> it_zone;
					if grass_type[i] = "G1"{
						it_zone <- sample(zone_list,1,false);
						loop j over:it_zone{
							list<tree> for_rnd_tree <- tree where ((each.player = p) 
																and (each.zone = j)
																and (each.it_can_growth = "1"));
							ask sample(for_rnd_tree,2,false){
								add map<string, string>(["PlayerID"::map_player_id[self.player], 
														"Name"::self.name, 
														"State"::99]) to:send_tree_update_grass;
								it_can_growth <- "-1";
							}
						}
					}
					else if grass_type[i] = "G2"{
						it_zone <- sample(zone_list,2,false);
						loop j over:it_zone{
							list<tree> for_rnd_tree <- tree where ((each.player = p) 
																and (each.zone = j)
																and (each.it_can_growth = "1"));
							ask sample(for_rnd_tree,4,false){
								add map<string, string>(["PlayerID"::map_player_id[self.player], 
														"Name"::self.name, 
														"State"::99]) to:send_tree_update_grass;
								it_can_growth <- "-1";
							}
						}
					}
					write "send_tree_update_grass " + send_tree_update_grass;
					write "it_zone " + it_zone + " at time " + time_now +"s" + " type " + grass_type[i];
				}
			}
		}
		
		// Growth
		ask tree where (each.it_can_growth = "1"){
			current_time <- time_now;
			height <- logist_growth(init_height, float(list_of_height[self.tree_type-1]), float(list_of_growth_rate[self.tree_type-1]), 1);
			int h_max <- list_of_max_height_in_n_years[self.tree_type - 1];
			
			if (height >= (h_max*0.5)) and (height < (h_max*0.8)) and (it_state = 1){
				it_state <- 2;
				write "Tree: " + self.name + " State -> 2 (it_type=" + self.tree_type +")";
				add map<string, string>(["PlayerID"::map_player_id[self.player], "Name"::self.name, "State"::it_state]) to:send_tree_update_grow;
			}
			else if (height >= (h_max*0.8)) and (height <= (h_max)) and (it_state = 2){
				it_state <- 3;
				write "Tree: " + self.name + " State -> 3 (it_type=" + self.tree_type +")";
				add map<string, string>(["PlayerID"::map_player_id[self.player], "Name"::self.name, "State"::it_state]) to:send_tree_update_grow;
			}
		}
		
		// Background
		loop p over:connect_team_list{
			loop j from:0 to:4{
				if (sum_score_list[p-1] >= list_of_bg_score[j]) and 
					(sum_score_list[p-1] < list_of_bg_score[j+1]) and
					(j != list_of_player_bg[p-1]){
					add map<string, string>(["PlayerID"::map_player_id[p], 
											"Name"::string(j+1), 
											"State"::""]) to:send_tree_update_environment;
					list_of_player_bg[p-1] <- j;
					write "Player " + map_player_id[p] + " send " + string("Environment"+(j+1)) ;
				}
			}
		}

//		if time_now mod 10 = 0{
//			loop p over:connect_team_list{
//				add map<string, string>(["PlayerID"::map_player_id[p], 
//									"Name"::string(test_send), 
//									"State"::""]) to:send_tree_update_environment;
//			list_of_player_bg[p-1] <- test_send;
//			write "Player " + map_player_id[p] + " send " + string("Environment"+string(test_send));
//			}
//			test_send <- test_send + 1 ;	
//		}
		
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
			
		write "all_for_send " + all_for_send;
		
		// Send it!
		if not empty(all_for_send){
			ask unity_linker {
				do send_message players: unity_player as list mes: ["ListOfMessage"::all_for_send];
			}
		}
	}
}

species unity_linker parent: abstract_unity_linker {
	string player_species <- string(unity_player);
	int max_num_players  <- 6;
	int min_num_players  <- 6;
	unity_property up_tree_1;
	unity_property up_tree_2;
	unity_property up_tree_3;
	unity_property up_tree_Dead;
	unity_property up_default;
	unity_property up_alien;
	unity_property up_fire;
	unity_property up_road;
	
	action ChangeTreeState(string tree_Name, string status){
		list<string> split_tree_ID ;
		list<string> playerID ;
		write "ChangeTreeState: " + tree_Name + " it_can_growth " + status;
		ask tree where ((each.name = tree_Name)){
			if it_can_growth in ["-1", "1"]{
				it_can_growth <- status;
				write "Tree: " + self.name + " it_can_growth " + status;
			}
		}
//		split_tree_ID <- tree_Name split_with ('tree', true);
//		playerID <- split_tree_ID[0] split_with ('p', true);
//		write "split_tree_ID " + split_tree_ID;
//		write " playerID " + playerID;
//		write "------------";
//		write "split_tree_ID[1] " + split_tree_ID[1];
//		write "playerID[1] " + playerID[1];
//		write "------------";
		
//		switch playerID[1] {
//			match "1" {
//				ask p1tree[int(split_tree_ID[1])]{
//					it_can_growth <- status;
//					write "Tree: " + self.name + " it_can_growth " + it_state;
//				}
//			}
//			match "2" {
//				ask p2tree[int(split_tree_ID[1])]{
//					it_can_growth <- status;
//					write "Tree: " + self.name + " it_can_growth " + it_state;
//				}
//			}
//			match "3" {
//				ask p3tree[int(split_tree_ID[1])]{
//					it_can_growth <- status;
//					write "Tree: " + self.name + " it_can_growth " + it_state;
//				}
//			}
//			match "4" {
//				ask p4tree[int(split_tree_ID[1])]{
//					it_can_growth <- status;
//					write "Tree: " + self.name + " it_can_growth " + it_state;
//				}
//			}
//			match "5" {
//				ask p5tree[int(split_tree_ID[1])]{
//					it_can_growth <- status;
//					write "Tree: " + self.name + " it_can_growth " + it_state;
//				}
//			}
//			match "6" {
//				ask p6tree[int(split_tree_ID[1])]{
//					it_can_growth <- status;
//					write "Tree: " + self.name + " it_can_growth " + it_state;
//				}
//			}
//		}		
	}
	
	list<point> init_locations <- define_init_locations();


	list<point> define_init_locations {
		list<point> init_pos;
		loop times: 6 {
			init_pos << {10, 10, 0};
			
		}
		write "init_pos " + init_pos;
		return init_pos;
	}


	init {
		do define_properties;
		player_unity_properties <- [nil,nil,nil,nil,nil,nil];
		
		do add_background_geometries(tree,up_default);
//		do add_background_geometries(p1tree,up_default);
//		do add_background_geometries(p2tree,up_default);
//		do add_background_geometries(p3tree,up_default);
//		do add_background_geometries(p4tree,up_default);
//		do add_background_geometries(p5tree,up_default);
//		do add_background_geometries(p6tree,up_default);
//		do add_background_geometries(zone_area,up_road);
//		do add_background_geometries(playerable_area,up_road);
//		do add_background_geometries(wait_area,up_road);
	}
	
	action define_properties {		
		unity_aspect alien_aspect <- prefab_aspect("temp/Prefab/VU2/AlienWeed_F",1.0,0.0,1.0,0.0,precision);
		up_alien <- geometry_properties("alien","",alien_aspect,new_geometry_interaction(true, false,false,[]),true);
		unity_properties << up_alien;
		
		unity_aspect fire_aspect <- prefab_aspect("temp/Prefab/VU2/ForestFire",1.0,0.0,1.0,0.0,precision);
		up_fire <- geometry_properties("fire","",fire_aspect,new_geometry_interaction(true, false,false,[]),true);
		unity_properties << up_fire;

		unity_aspect default_aspect <- prefab_aspect("temp/Prefab/VU2/SeedingWithGrass",1.0,0.0,1.0,0.0,precision);
		up_default <- geometry_properties("default","",default_aspect,new_geometry_interaction(true, false,false,[]),false);
		unity_properties << up_default;
		
		unity_aspect road_aspect <- geometry_aspect(0.1, #black, precision);
		up_road<- geometry_properties("road", "", road_aspect, #collider, false);
		unity_properties << up_road;

	}
	reflex send_geometries {
//		do add_geometries_to_send(wildfire, up_fire);
//		do add_geometries_to_send(alien, up_alien);	
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
//	float minimum_cycle_duration <- 0.1;
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


