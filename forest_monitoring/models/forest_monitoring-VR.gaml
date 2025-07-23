model NewModel_model_VR

import "New Model.gaml"

global {
	int n_year <- 5;
	init{
//		create wait_area{
////			point at_location <- {-10,75,0};
//			point at_location <- {10,10,0};
//			location <- at_location;
//		}
		
//		create unity_player{
//			name <- "Player_106";
//			location <- {-10,75,0};
//		}
	}
	
	reflex send_readID when:cycle=(init_cycle+1){
		list<map<string,string>> send_tree_update <- [];
		ask p1tree{
			add map<string, string>(["PlayerID"::map_player_id[1], "Name"::self.name, "State"::""]) to:send_tree_update;
		}
		ask p2tree{
			add map<string, string>(["PlayerID"::map_player_id[2], "Name"::self.name, "State"::""]) to:send_tree_update;
		}
		ask p3tree{
			add map<string, string>(["PlayerID"::map_player_id[3], "Name"::self.name, "State"::""]) to:send_tree_update;
		}
		ask p4tree{
			add map<string, string>(["PlayerID"::map_player_id[4], "Name"::self.name, "State"::""]) to:send_tree_update;
		}
		ask p5tree{
			add map<string, string>(["PlayerID"::map_player_id[5], "Name"::self.name, "State"::""]) to:send_tree_update;
		}
		ask p6tree{
			add map<string, string>(["PlayerID"::map_player_id[6], "Name"::self.name, "State"::""]) to:send_tree_update;
		}
		write send_tree_update;
		write "End First Start";
		
		if not empty(unity_player){
			ask unity_linker {
				do send_message players: unity_player as list mes: ["Head"::"ReadID", "Body"::"", "Content"::send_tree_update];
			}
			write "Send ReadID";
		}
	}
	
	action resume_game {
		write "send Start";
		if not empty(unity_player){
			ask unity_linker {
				do send_message players: unity_player as list mes: ["Head"::"Start", "Body"::"", "Content"::""];
			}
		}
	}
	
	action pause_game {
		write "send Stop";
		if not empty(unity_player){
			ask unity_linker {
				do send_message players: unity_player as list mes: ["Head"::"Stop", "Body"::"", "Content"::""];
			}
		}
	}
	
	reflex end_game when:(cycle >= (n_year*365)){
		do pause;
	}
	
	reflex prepare_step when:(cycle=1) and (first_start=true){
		first_start <- false;
		do pause_game;
		do pause;
	}
	
	reflex do_create_tree_and_move_player when:(first_start=false) and (first_create_tree=true) and (cycle>=init_cycle){
//		write "do create tree";
		first_create_tree <- false;
		
		ask unity_player{
			write "move player " + self.name;
			location <- playerable_area[map_player_id_reverse[self.name]-1].location + {0, 0, 3};
			ask unity_linker {
				new_player_position[myself.name] <- [myself.location.x *precision,myself.location.y *precision,myself.location.z *precision];
				move_player_event <- true;
			}
		}	
	}
//	and (cycle mod 10=0)
	reflex update_height_and_state when:(cycle >= init_cycle)  {
		list<map<string,string>> send_tree_update <- [];
		
		ask p1tree{
			if (it_can_growth = "1"){
				current_cycle <- current_cycle + 1;
//				write "update tree " + self.tree_type + " " + init_height  + " " + float(list_of_height[self.tree_type-1]) + " " + float(list_of_growth_rate[self.tree_type-1]);
				height <- logist_growth(init_height, float(list_of_height[self.tree_type-1]), float(list_of_growth_rate[self.tree_type-1]));
	
				if (height >= (list_of_max_height_in_n_years[self.tree_type-1]*0.5)) and 
					(height < (list_of_max_height_in_n_years[self.tree_type-1]*0.8)) and 
					(it_state = 1){
					it_state <- 2;
					write "Tree: " + self.name + " State -> 2 (it_type=" + self.tree_type +")";
					add map<string, string>(["PlayerID"::map_player_id[1], "Name"::self.name, "State"::it_state]) to:send_tree_update;
				}
				else if (height >= (list_of_max_height_in_n_years[self.tree_type-1]*0.8)) and 
						(height <= (list_of_max_height_in_n_years[self.tree_type-1])) and 
						(it_state = 2){
					it_state <- 3;
					write "Tree: " + self.name + " State -> 3 (it_type=" + self.tree_type +")";
					add map<string, string>(["PlayerID"::map_player_id[1], "Name"::self.name, "State"::it_state]) to:send_tree_update;
				}
			}
			else if (it_can_growth = "-1"){
				write "Tree" + self.name + "Stop Growth";
			}
			else if (it_can_growth = "0"){
				write "Tree" + self.name + "Die";
			}
		}
		
		if (not empty(unity_player)) and (not empty(send_tree_update)){
			write send_tree_update;
			write length(send_tree_update);
			ask unity_linker {
				do send_message players: unity_player as list mes: ["Head"::"Update", "Body"::"GROW", "Content"::send_tree_update];
				write "send Update";
			}
		}

		send_tree_update <- [];
	}
	
	reflex update_grass when:(cycle >= init_cycle) and (cycle mod 10 = 0){
		list<map<string,string>> send_tree_update_grass <- [];
		int target_zone <- rnd(1,4);
//		write "target_zone " + target_zone;
		ask p1tree{
			if flip(0.05){
				add map<string, string>(["PlayerID"::map_player_id[1], "Name"::self.name, "State"::99]) to:send_tree_update_grass;
			}
		}
		ask unity_linker {
			do send_message players: unity_player as list mes: ["Head"::"Update", "Body"::"GRASS", "Content"::send_tree_update_grass];
				write "send Grass";
		}
	}
	
	reflex update_wildfire when:(cycle >= init_cycle) and (cycle mod 10 = 0){
		point at_location <- any_location_in(usable_area_for_wildfire[0]-1);
		loop j from:0 to:1{
			loop i from:0 to:2{
				create wildfire{
					point final_location <- {at_location.x + (83.33*i), at_location.y + (75*j), at_location.z};
					location <- final_location;
				}
			}	
		}
	}
	
	reflex update_alien when:(cycle >= init_cycle) and (cycle mod 10 = 0){
		point at_location <- any_location_in(playerable_area[0]-1);
		loop j from:0 to:1{
			loop i from:0 to:2{
				create alien{
					point final_location <- {at_location.x + (83.33*i), at_location.y + (75*j), at_location.z};
					location <- final_location;
				}
			}	
		}
	}
	
	reflex update_n_remain_tree when:(cycle >= init_cycle){
//		loop i from:0 to:2{
//			write "loop update_n_remain_tree here!";
//			write n_remain_tree[i];
//		}
	}
	
	reflex delete_tree{

	}
}

species unity_linker parent: abstract_unity_linker {
	string player_species <- string(unity_player);
//	int max_num_players  <- 6;
//	int min_num_players  <- 6;
	unity_property up_tree_1;
	unity_property up_tree_2;
	unity_property up_tree_3;
	unity_property up_tree_Dead;
	unity_property up_default;
	unity_property up_alien;
	unity_property up_fire;
	unity_property up_road;
	
	action ChangeTreeState(string tree_Name, string status){
		if tree_Name = "SeedingWithGrass"{
			list<string> split_tree_ID ;
			list<string> playerID ;
			write "ChangeTreeState: " + tree_Name + " it_can_growth " + status;
			split_tree_ID <- tree_Name split_with ('tree', true);
			playerID <- split_tree_ID[0] split_with ('p', true);
			write split_tree_ID;
			write playerID;
			write "------------";
			write split_tree_ID[1];
			write playerID[1];
			write p1tree[int(split_tree_ID[1])].name;
	
			switch playerID[1] {
				match "1" {
					ask p1tree[int(split_tree_ID[1])]{
						it_can_growth <- status;
						write "Tree: " + self.name + " it_can_growth " + it_state;
					}
				}
				match "2" {
					ask p2tree[int(split_tree_ID[1])]{
						it_can_growth <- status;
						write "Tree: " + self.name + " it_can_growth " + it_state;
					}
				}
				match "3" {
					ask p3tree[int(split_tree_ID[1])]{
						it_can_growth <- status;
						write "Tree: " + self.name + " it_can_growth " + it_state;
					}
				}
				match "4" {
					ask p4tree[int(split_tree_ID[1])]{
						it_can_growth <- status;
						write "Tree: " + self.name + " it_can_growth " + it_state;
					}
				}
				match "5" {
					ask p5tree[int(split_tree_ID[1])]{
						it_can_growth <- status;
						write "Tree: " + self.name + " it_can_growth " + it_state;
					}
				}
				match "6" {
					ask p6tree[int(split_tree_ID[1])]{
						it_can_growth <- status;
						write "Tree: " + self.name + " it_can_growth " + it_state;
					}
				}
			}
		}
		
	}
	
	list<point> init_locations <- define_init_locations();

//	list<point> define_init_locations {
//		return [{50.0,50.0,0.0},{50.0,50.0,0.0},{50.0,50.0,0.0},{50.0,50.0,0.0},{50.0,50.0,0.0},{50.0,50.0,0.0}];
//	}
	list<point> define_init_locations {
		list<point> init_pos;
		loop times: 6 {
//			init_pos << {-10, 75, 0} + {0, 0, 3};
			init_pos << {0, 0, 0};
			//write "init_pos " + init_pos;
		}
		return init_pos;
	}


	init {
		do define_properties;
		player_unity_properties <- [nil,nil,nil,nil,nil,nil];
		
		do add_background_geometries(p1tree,up_default);
		do add_background_geometries(p2tree,up_default);
		do add_background_geometries(p3tree,up_default);
		do add_background_geometries(p4tree,up_default);
		do add_background_geometries(p5tree,up_default);
		do add_background_geometries(p6tree,up_default);
//		do add_background_geometries(zone_area,up_road);
//		do add_background_geometries(playerable_area,up_road);
//		do add_background_geometries(wait_area,up_road);
	}
	
	action define_properties {
//		unity_aspect tree1_aspect <- prefab_aspect("temp/Prefab/VU2/Seeding_1",1.0,0.0,1.0,0.0,precision);
//		up_tree_1 <- geometry_properties("tree_state1","",tree1_aspect,new_geometry_interaction(true, false,false,[]),false);
//		unity_properties << up_tree_1;
//		
//		unity_aspect tree2_aspect <- prefab_aspect("temp/Prefab/VU2/Seeding_2",1.0,0.0,1.0,0.0,precision);
//		up_tree_2 <- geometry_properties("tree_state2","",tree2_aspect,new_geometry_interaction(true, false,false,[]),false);
//		unity_properties << up_tree_2;
//		
//		unity_aspect tree3_aspect <- prefab_aspect("temp/Prefab/VU2/Seeding_3",1.0,0.0,1.0,0.0,precision);
//		up_tree_3 <- geometry_properties("tree_state3","",tree3_aspect,new_geometry_interaction(true, false,false,[]),false);
//		unity_properties << up_tree_3;
//		
//		unity_aspect treeDead_aspect <- prefab_aspect("temp/Prefab/VU2/Seeding_Dead",1.0,0.0,1.0,0.0,precision);
//		up_tree_Dead <- geometry_properties("tree_stateDead","",treeDead_aspect,new_geometry_interaction(true, false,false,[]),false);
//		unity_properties << up_tree_Dead;
		
		unity_aspect alien_aspect <- prefab_aspect("temp/Prefab/VU2/AlienWeed_F",1.0,0.0,1.0,0.0,precision);
		up_alien <- geometry_properties("alien","",alien_aspect,new_geometry_interaction(true, false,false,[]),false);
		unity_properties << up_alien;
		
		unity_aspect fire_aspect <- prefab_aspect("temp/Prefab/VU2/ForestFire",1.0,0.0,1.0,0.0,precision);
		up_fire <- geometry_properties("fire","",fire_aspect,new_geometry_interaction(true, false,false,[]),false);
		unity_properties << up_fire;

		unity_aspect default_aspect <- prefab_aspect("temp/Prefab/VU2/SeedingWithGrass",1.0,0.0,1.0,0.0,precision);
		up_default <- geometry_properties("default","",default_aspect,new_geometry_interaction(true, false,false,[]),false);
		unity_properties << up_default;
		
		unity_aspect road_aspect <- geometry_aspect(0.1, #black, precision);
		up_road<- geometry_properties("road", "", road_aspect, #collider, false);
		unity_properties << up_road;

	}
	reflex send_geometries {
		if not empty(wildfire){
			list<wildfire> list_wildfire_to_send <- wildfire where (each.it_sent = false);
			write "list_wildfire_to_send " + list_wildfire_to_send;
			do add_geometries_to_send(list_wildfire_to_send, up_fire);
			ask list_wildfire_to_send{
				it_sent <- true;
			}
		}
		
		if not empty(alien){
			list<alien> list_alien_to_send <- alien where (each.it_sent = false);
			write "list_alien_to_send " + list_alien_to_send;
			do add_geometries_to_send(list_alien_to_send, up_alien);
			ask list_alien_to_send{
				it_sent <- true;
			}
		}
		
		
//		list<tree> t1_state1 <- p1tree where ((each.it_state = 1));
//		list<tree> t1_state2 <- p1tree where ((each.it_state = 2));
//		list<tree> t1_state3 <- p1tree where ((each.it_state = 3));
//		list<tree> t1_stateDead <- p1tree where ((each.it_state = 0));
////		write "State1:" + t1_state1;
////		write "State2:" + t1_state2;
////		write "State3:" + t1_state3;
////		write "State0:" + t1_stateDead;
//		if not empty(t1_state1){
//			do add_geometries_to_send(t1_state1,up_tree_1);
////			write "Send t1_state1";
//		}
//		if not empty(t1_state2){
//			do add_geometries_to_send(t1_state2,up_tree_2);
////			write "Send t1_state2";
//		}
//		if not empty(t1_state3){
//			do add_geometries_to_send(t1_state3,up_tree_3);
////			write "Send t1_state3";
//		}
//		if not empty(t1_stateDead){
//			do add_geometries_to_send(t1_stateDead,up_tree_Dead);
////			write "Send t1_stateDead";
//		}
//		
//		
//		list<tree> t2_state1 <- p2tree where ((each.it_state = 1));
//		list<tree> t2_state2 <- p2tree where ((each.it_state = 2));
//		list<tree> t2_state3 <- p2tree where ((each.it_state = 3));
//		list<tree> t2_stateDead <- p2tree where ((each.it_state = 0));
//		do add_geometries_to_send(t2_state1,up_tree_1);
//		do add_geometries_to_send(t2_state2,up_tree_2);
//		do add_geometries_to_send(t2_state3,up_tree_3);
//		do add_geometries_to_send(t2_stateDead,up_tree_Dead);
//		
//		list<tree> t3_state1 <- p3tree where ((each.it_state = 1));
//		list<tree> t3_state2 <- p3tree where ((each.it_state = 2));
//		list<tree> t3_state3 <- p3tree where ((each.it_state = 3));
//		list<tree> t3_stateDead <- p3tree where ((each.it_state = 0));
//		do add_geometries_to_send(t3_state1,up_tree_1);
//		do add_geometries_to_send(t3_state2,up_tree_2);
//		do add_geometries_to_send(t3_state3,up_tree_3);
//		do add_geometries_to_send(t3_stateDead,up_tree_Dead);
//		
//		list<tree> t4_state1 <- p4tree where ((each.it_state = 1));
//		list<tree> t4_state2 <- p4tree where ((each.it_state = 2));
//		list<tree> t4_state3 <- p4tree where ((each.it_state = 3));
//		list<tree> t4_stateDead <- p4tree where ((each.it_state = 0));
//		do add_geometries_to_send(t4_state1,up_tree_1);
//		do add_geometries_to_send(t4_state2,up_tree_2);
//		do add_geometries_to_send(t4_state3,up_tree_3);
//		do add_geometries_to_send(t4_stateDead,up_tree_Dead);
//		
//		list<tree> t5_state1 <- p5tree where ((each.it_state = 1));
//		list<tree> t5_state2 <- p5tree where ((each.it_state = 2));
//		list<tree> t5_state3 <- p5tree where ((each.it_state = 3));
//		list<tree> t5_stateDead <- p5tree where ((each.it_state = 0));
//		do add_geometries_to_send(t5_state1,up_tree_1);
//		do add_geometries_to_send(t5_state2,up_tree_2);
//		do add_geometries_to_send(t5_state3,up_tree_3);
//		do add_geometries_to_send(t5_stateDead,up_tree_Dead);
//		
//		list<tree> t6_state1 <- p6tree where ((each.it_state = 1));
//		list<tree> t6_state2 <- p6tree where ((each.it_state = 2));
//		list<tree> t6_state3 <- p6tree where ((each.it_state = 3));
//		list<tree> t6_stateDead <- p6tree where ((each.it_state = 0));
//		do add_geometries_to_send(t6_state1,up_tree_1);
//		do add_geometries_to_send(t6_state2,up_tree_2);
//		do add_geometries_to_send(t6_state3,up_tree_3);
//		do add_geometries_to_send(t6_stateDead,up_tree_Dead);
		
	}
}

species unity_player parent: abstract_unity_player{
	float player_size <- 1.0;
	rgb color <- #red;
	float cone_distance <- 10.0 * player_size;
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


