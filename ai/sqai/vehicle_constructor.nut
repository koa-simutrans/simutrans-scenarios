class vehicle_constructor_t extends node_t
{
	// input data
	p_depot  = null // depot_x
	p_line   = null // line_x
	p_convoy = null // prototyper_t
	p_count  = 0
	p_withdraw = false

	// generated data
	c_cnv = null
	c_wt  = 0
	// step-by-step construct convoys
	phase = 0

	constructor()
	{
		base.constructor("vehicle_constructor_t")
	}

	/***************************************
	 * 車両アドオン選択
	 * 引数：プレイヤー属性(player_x)、線タイプ(enum)、電化しているか(boolean)
	 * 戻り値：乗り物アドオン(vehicle_desc_x)
	 ***************************************/
	function select_convoy(pl, way_type, is_electrified)
	{
		// 乗り物一覧取得
		local convoy_list = []
		if(is_electrified)
		{
			local car_list = filter(vehicle_desc_x.get_available_vehicles(way_type), @(a) a.get_power() == 0 && a.get_successors().len() == 0)
			convoy_list = combine(select_needs_electrification(way_type, pl, true), car_list)
		}else{
			convoy_list = select_needs_electrification(way_type, pl, false)
		}
		// 旅客車でフィルター
		convoy_list = filter(convoy_list, @(a) a.get_freight().is_equal(good_desc_x.passenger))
		// pak128.japanで用いられる連結器を除外
		convoy_list = filter(convoy_list, @(a) !(a.get_cost == 0 && a.get_maintenance == 0))
		// 資産でフィルター
		convoy_list = filter(convoy_list, @(a) a.get_cost() <= pl.get_current_net_wealth())
		// 先頭にこれる乗り物でフィルター
		convoy_list = filter(convoy_list, @(a) a.can_be_first())
		if(convoy_list.len() == 0){ return }
		if(way_type == wt_rail)
		{
			// 月粗利益から購入可能な車の基準値取得(維持費が高くない乗り物でフィルター)
			local profit_ratio = pl.get_profit()[0] / 3000
			if(profit_ratio <= 0){ profit_ratio = 200 }
			convoy_list = filter(convoy_list, @(a) profit_ratio >= a.get_running_cost())
			if(convoy_list.len() == 0){ return }
		}
		// 各乗り物を評価
		local assessment_list = []
		foreach(convoy in convoy_list)
		{
			local capacity = convoy.get_capacity()
			local tbl_assessment = {}
			if(convoy.get_running_cost() == 0)
			{
				tbl_assessment = 
				{
					convoy = convoy
					assessment = capacity * capacity * convoy.get_topspeed()
				}
			}else{
				local assessment_tmp = capacity * capacity * convoy.get_topspeed() / convoy.get_running_cost()
				if(way_type == wt_rail)
				{
					assessment_tmp = assessment_tmp / (math.get_digit(convoy.get_cost()) + 2)
					// 客車に対しては動力車を連結する必要があるため評価を下げる
					if(convoy.get_power() == 0){ assessment_tmp /= 20 }
					if(assessment_tmp == 0){ assessment_tmp = 1 }
				}
				tbl_assessment = 
				{
					convoy = convoy
					assessment = assessment_tmp
				}
			}
			assessment_list.append(tbl_assessment)
		}
		// 評価が0(要は定員0)の乗り物は除外
		assessment_list = filter(assessment_list, @(a) a.assessment > 0)
		// 評価結果を降順ソート
		assessment_list = sort(assessment_list, @(a,b) b.assessment <=> a.assessment)
		// プレイヤーIdxで乗り物を選択
		local idx = calc_idx(pl.nr, assessment_list.len())
		return assessment_list[idx].convoy
	}

	/***************************************
	 * 車両の購入
	 * 引数：車庫情報(depot_x)、プレイヤー属性(player_x)、線タイプ(enum)、購入する乗り物アドオン(vehicle_desc_x)、電化しているか(boolean)
	 * 戻り値：乗り物(convey_x)
	 * 備考：購入する乗り物アドオンがnullの時はselect_convoy関数で自動選択
	 ***************************************/
	function buy_convoy(depot, pl, way_type, vehicle_desc, is_electrified = false)
	{
		// 乗り物選択
		if(vehicle_desc == null)
		{
			vehicle_desc = select_convoy(pl, way_type, is_electrified)
		}
		if(vehicle_desc == null){ return }
		// 選択した乗り物がトレーラー、客車の場合、動力車をセット
		local power = vehicle_desc.get_power()
		local successor_list = vehicle_desc.get_successors()
		local predecessor_list = vehicle_desc.get_predecessors()
		local convoy = null
		if(power == 0 && successor_list.len() == 0 && predecessor_list.len() == 0)
		{
			// 月粗利益から購入可能な機関車の基準値取得
			local profit_ratio = pl.get_profit()[0] / 3000
			// 動力車の維持費がnクレジット/tile*100=profit_ratio
			if(profit_ratio <= 0){ profit_ratio = 300 }
			
			// 機関車を選定
			predecessor_list = vehicle_desc_x.get_available_vehicles(way_type)
			predecessor_list = filter(predecessor_list, @(a) a.get_power() > 0 && a.can_be_first())
			predecessor_list = filter(predecessor_list, @(a) a.get_successors().len() == 0)
			if(!(is_electrified))
			{
				predecessor_list = filter(predecessor_list, @(a) !(a.needs_electrification()))
			}
			// 収入に応じて選択肢を変える
			predecessor_list = filter(predecessor_list @(a) profit_ratio >= a.get_running_cost())
			// 機関車が高価な場合、一番維持費が安いものを選択
			if(predecessor_list.len() == 0)
			{
				predecessor_list = vehicle_desc_x.get_available_vehicles(way_type)
				predecessor_list = filter(predecessor_list, @(a) a.get_power() > 0 && a.can_be_first())
				if(!(is_electrified))
				{
					predecessor_list = filter(predecessor_list, @(a) !(a.needs_electrification()))
				}
				predecessor_list = sort(predecessor_list, @(a,b) a.get_running_cost() <=> b.get_running_cost())
				predecessor_list.resize(2)
			}
			local idx = calc_idx(pl.nr, predecessor_list.len())
			depot.append_vehicle(pl, convoy_x(0), predecessor_list[idx])
			power += predecessor_list[idx].get_power()
			// 連結
			convoy = depot.get_convoy_list().top()
			depot.append_vehicle(pl, convoy, vehicle_desc)
		}else{
			depot.append_vehicle(pl, convoy_x(0), vehicle_desc)
			convoy = depot.get_convoy_list().top()
			local convoy_info_list = convoy.get_vehicles()
			// 後ろに何か連結しないといけない時
			while(!(convoy_info_list.top().can_be_last()))
			{
				vehicle_desc = convoy_info_list.top()
				successor_list = vehicle_desc.get_successors()
				if(successor_list.len() == 0)
				{
					successor_list = vehicle_desc_x.get_available_vehicles(way_type)
				}
				local temp_successor_list = []
				if(power == 0)
				{
					temp_successor_list = filter(successor_list, @(a) a.get_power() > 0)
					if(temp_successor_list.len() == 0){ temp_successor_list = successor_list }
				}else{
					temp_successor_list = filter(successor_list, @(a) a.can_be_last())
				}
				if(temp_successor_list.len() != 0)
				{
					local idx = calc_idx(pl.nr, temp_successor_list.len())
					vehicle_desc = temp_successor_list[idx]
				}else{
					local idx = calc_idx(pl.nr, successor_list.len())
					vehicle_desc = successor_list[idx]
				}
				convoy = depot.get_convoy_list().top()
				depot.append_vehicle(pl, convoy, vehicle_desc)
				convoy_info_list = convoy.get_vehicles()
				power += vehicle_desc.get_power()
			}
		}
		local cnv_list = depot.get_convoy_list()
		return cnv_list[0]
	}

	/***************************************
	 * 車両の更新
	 * 引数：路線情報(line_x)、車庫情報(depot_x)、プレイヤー属性(player_x)、線タイプ(enum)、電車かどうか(boolean)
	 * 戻り値：乗り物(convey_x)
	 ***************************************/
	function update_convoy(line, depot, pl, way_type, is_electrified = false)
	{
		local current_convoy_list = line.get_convoy_list()
		current_convoy_list = sort(current_convoy_list, @(a,b) a.get_speed() <=> b.get_speed())
		local vehicle_desc_list = current_convoy_list[0].get_vehicles()
		local vehicle_desc = vehicle_desc_list[0]

		// 乗り物一覧取得
		local convoy_list = []
		if(is_electrified)
		{
			local car_list = filter(vehicle_desc_x.get_available_vehicles(way_type), @(a) a.get_power() == 0 && a.get_successors().len() == 0)
			convoy_list = combine(select_needs_electrification(way_type, pl, true), car_list)
		}else{
			convoy_list = select_needs_electrification(way_type, pl, false)
		}
		// 旅客車でフィルター
		convoy_list = filter(convoy_list, @(a) a.get_freight().is_equal(good_desc_x.passenger))
		// 資産でフィルター
		convoy_list = filter(convoy_list, @(a) a.get_cost() <= pl.get_current_net_wealth())
		// 先頭にこれる乗り物でフィルター
		convoy_list = filter(convoy_list, @(a) a.can_be_first())
		// 今の乗り物より定員数が多いものでフィルター
		local current_capacity = 0
		if(way_type == wt_road)
		{
			foreach(vehicle in vehicle_desc_list)
			{
				current_capacity += vehicle.get_capacity()
			}
		}
		if(way_type == wt_rail){ current_capacity = vehicle_desc_list.top().get_capacity() }
		convoy_list = filter(convoy_list, @(a) a.get_capacity() > current_capacity)
		if(convoy_list.len() == 0){ return null }
		// 定員で昇順ソート
		convoy_list = sort(convoy_list, @(a,b) a.get_capacity() <=> b.get_capacity())
		// 同じ定員の車だけにする
		convoy_list = filter(convoy_list @(a) a.get_capacity() == convoy_list[0].get_capacity())

		// プレイヤーIdxで乗り物を選択
		local idx = calc_idx(pl.nr, convoy_list.len())
		vehicle_desc = convoy_list[idx]

		// 新車購入
		return buy_convoy(depot, pl, way_type, vehicle_desc, is_electrified)
	}

	/***************************************
	 * 車両選択時、電車を選ぶ
	 * 引数：線タイプ(enum)、プレイヤー属性(player_x)、電車タブかそれ以外の車両を選ぶか(boolean)
	 * 戻り値：乗り物アドオンのリスト(vehicle_desc_xのリスト)
	 ***************************************/
	function select_needs_electrification(way_type, pl, is_electric)
	{
		// 乗り物一覧取得
		local vehicle_desc_list = vehicle_desc_x.get_available_vehicles(way_type)
		// モーターを持つ車両取得
		local electric_vehicle_list = filter(vehicle_desc_list, @(a) a.needs_electrification())
		local exhibit_list = electric_vehicle_list
		// 電車の付随車や制御車も追加
		local temp = []
		foreach(electric_vehicle in electric_vehicle_list)
		{
			temp = combine(temp, electric_vehicle.get_predecessors())
			temp = combine(temp, electric_vehicle.get_successors())
		}

		exhibit_list = combine(exhibit_list, temp)
		exhibit_list = unique(exhibit_list)

		if(is_electric)
		{
			return exhibit_list
		}else{
			return filter(vehicle_desc_list, @(a) !(is_member(a, exhibit_list)))
		}
	}

	/***************************************
	 * 路線作成・白紙改正
	 * 引数：片道のバス停の座標リスト(tile_x)、改正前の路線(line_x)、プレイヤー属性(player_x)
	 * 戻り値：路線(line_x)
	 * 備考：改正前の路線がnull時、新規作成
	 ***************************************/
	function set_line(array_bus_stop, old_line, pl)
	{
		local schedule = schedule_x(wt_road, [])
		// 往路のスケジュール追加
		for(local ii = 0; ii < array_bus_stop.len(); ii++)
		{
			// 始発バス停に待機時間設定
			if(ii == 0)
			{
				local load = 30
				local wait = 704
				if ( array_bus_stop.len() < 5 )
				{
					load = 40
					wait = 968
				}
				schedule.entries.append( schedule_entry_x(array_bus_stop[ii], load, wait) )
				continue
			}
			schedule.entries.append( schedule_entry_x(array_bus_stop[ii], 0, 0) )
		}
		// 復路のスケジュール追加
		for(local ii = array_bus_stop.len() - 2; ii > 0; ii--)
		{
			schedule.entries.append( schedule_entry_x(array_bus_stop[ii], 0, 0) )
		}
		// 路線改正
		if(old_line != null)
		{
			old_line.change_schedule(pl, schedule)
			return old_line
		}
		// 路線作成
		pl.create_line(wt_road)
		local list = pl.get_line_list()
		foreach(line in list)
		{
			local schedule_entries = line.get_schedule().entries
			if (line.get_waytype() == wt_road  &&  schedule_entries.len()==0)
			{
				line.change_schedule(pl, schedule)
				return line
			}
		}
		return
	}

	/***************************************
	 * 路線更新
	 * 引数：路線(line_x)、停止位置の座標(tile_x)、路線挿入位置(int)、プレイヤー属性(player_x)
	 * 戻り値：路線(line_x)
	 ***************************************/
	function update_line(line, stop, idx, pl)
	{
		local schedule_entry = line.get_schedule().entries
		local sche_len = schedule_entry.len()
		if(sche_len < idx){ return line }
		if(idx == 0)
		{
			schedule_entry.append(schedule_entry[0])
			schedule_entry.insert(idx, schedule_entry_x(stop, 0, 0) )
		}else{
			if(sche_len / 2 + 1 == idx)
			{
				schedule_entry.insert(idx, schedule_entry[idx-1] )
				schedule_entry.insert(idx, schedule_entry_x(stop, 0, 0) )
			}else{
				if(idx > sche_len / 2 + 1){ idx =  2 * (idx - (sche_len / 2 + 1))}
				schedule_entry.insert(sche_len - idx + 1, schedule_entry_x(stop, 0, 0) )
				schedule_entry.insert(idx, schedule_entry_x(stop, 0, 0) )
			}
		}
		local schedule = schedule_x(line.get_waytype(), schedule_entry)
		line.change_schedule(pl, schedule)
		return line
	}

	/***************************************
	 * 路線から登録している駅リスト取得
	 * 引数：路線(line_x)、プレイヤー属性(player_x)
	 * 戻り値：駅リスト(halt_x)
	 ***************************************/
	function get_halt_list_from_line(line, pl)
	{
		local rtn = []
		local schedule_entry = line.get_schedule().entries
		foreach(schedule in _step_generator(schedule_entry))
		{
			rtn.append(schedule.get_halt(pl))
		}
		return rtn
	}

	/***************************************
	 * 市内交通向け路線作成・改正
	 * 引数：町情報(city_x)、始発バス停の座標リスト(tile_x)、ターミナルのバス停(tile_x)、市内全バス停の座標リスト(tile_x)、改正前の市内バス路線リスト(line_x)、プレイヤー属性(player_x)
	 * 戻り値：路線リスト(line_x)
	 * 備考：改正前の市内バス路線リストが空白時は路線を新規作成
	 ***************************************/
	function set_line_for_citybus(city, array_initial, terminal, array_bus_stop, old_line_list, pl)
	{
		local rtn = []
		local cityname = city.get_name()

		// 路線の重複を防ぐため、既存バス路線リスト作成
		local line_list = filter(pl.get_line_list(), @(a) a.get_waytype() == wt_road)
		local halt_name_list_in_line = []
		foreach(line in line_list)
		{
			halt_name_list_in_line.append(map(get_halt_list_from_line(line, pl), @(a) a.get_name()))
		}
		
		// ターミナルに最も近いバス停取得
		// ターミナル(鉄道駅)は町外れに置く事が多い為、駅近くのバス停を路線に組み込んだらそのまま終点に向かわせたい
		array_initial = filter(array_initial, @(a) !(compare_coord(a, terminal)))
		local nearest_stop = filter(array_bus_stop, @(a) !(compare_coord(a, terminal)))
		nearest_stop = get_nearest(nearest_stop, world.get_size().x + world.get_size().y, @(a) get_trace_tile(a, terminal, wt_road, true))
		
		if(!(is_member(terminal, array_bus_stop))){ array_bus_stop.append(terminal) }
		local idx = 0
		local station = station_manager_t()
		while(array_initial.len() != 0 && idx < set_max_city_bus_line)
		{
			// ターミナルから遠い順に並べる
			local farthest_stop = get_nearest(array_initial, 0, @(a) -1 * get_trace_tile(a, terminal, wt_road, false))
			// ターミナルから遠いバス停～ターミナルの路線を作成
			local temp_root = []
			temp_root = select_root(array_bus_stop, farthest_stop[0], terminal, nearest_stop, temp_root)

			// 2番目のバス停が路線設定済み
			local update_flg = false
			
			if(old_line_list.len() == 0)
			{
				local second_stop_line = []
				if(compare_coord(temp_root[1], terminal))
				{
					second_stop_line = pl.get_line_list()
				}else{
					// 路線作成直後なのでget_halt()がnullにならない
					second_stop_line = temp_root[1].get_halt().get_line_list()
				}
				second_stop_line = filter(second_stop_line, @(a) a.get_owner().nr == pl.nr && a.get_waytype() == wt_road)
				foreach(line in second_stop_line)
				{
					if(line.get_name().find(cityname) != null)
					{
						// 停車駅数がcity_bus_max_schedule_desc以上の路線は除外
						local schedule = line.get_schedule()
						if(schedule.entries.len() == city_bus_max_schedule_desc * 2){ continue }
						// 2番目のバス停が終点の路線を検索
						local target_idx_list = station.get_idx_in_line(line, temp_root[1])
						if(target_idx_list.len() == 1)
						{
							// 終点の路線を延伸
							if(target_idx_list[0] == 0)
							{
								// 始発バス停側を延伸
								rtn.append(update_line(line, farthest_stop[0], 0, pl))
							}else{
								// 終点バス停側を延伸
								rtn.append(update_line(line, farthest_stop[0], target_idx_list[0]+1, pl))
							}
							update_flg = true
							break
						}
					}
				}
			}

			// ルート選定されたバス停は除いていく
			array_initial = filter(array_initial, @(a) !(is_member(a, temp_root)))
			if(!(update_flg))
			{
				// 既に存在する路線のルートは除外する
				if(is_duplicate_in_doublearray(map(temp_root, @(a) a.get_halt().get_name()), halt_name_list_in_line)){ continue }
				if(idx < old_line_list.len())
				{
					rtn.append(set_line(temp_root, old_line_list[idx], pl))
				}else{
					local line = set_line(temp_root, null, pl)
					// 路線名設定
					local ii = 1
					while(is_member(cityname+" ("+ii+")", map(pl.get_line_list(), @(a) a.get_name()))){ ii++ }
					line.set_name(cityname+" ("+ii+")")
					rtn.append(line)
				}
			}
			halt_name_list_in_line.append(map(temp_root, @(a) a.get_halt().get_name()))
			idx++
		}
		return rtn
	}

	/***************************************
	 * 市内交通のルート選定
	 * 引数：バス停の座標リスト(tile_xのリスト)、基準のバス停座標(tile_x)、
	 *	終点のバス停(tile_x)、終点のバス停に最も近いバス停座標リスト(tile_xのリスト)、ルートに所属したバス停リスト(tile_x)
	 * 戻り値：ルートに所属したバス停リスト(tile_x)
	 * 備考：city.nutに類似関数があるが、あっちは純粋な距離で比較するだけである(こっちは通過するタイル上にバス停があれば、追加していく)
	 ***************************************/
	function select_root(bus_stop_list, target, terminal, nearest_terminal_st_list, t_root_list)
	{
		local asf = astar_route_finder(wt_road)
		local road_info = road_manager_t()
		// ルートに基準のバス停追加
		t_root_list.append(target)
		// 基準のバス停が駅の場合、そこを終点とする
		local halt = target.get_halt()
		if(halt != null && t_root_list.len() > 2)
		{
			local sta_tile_list = finder.check_sta_freight_property(halt, wt_rail, 2)
			if(sta_tile_list.len() > 0){ return t_root_list }
		}
		// 停車停留所数がcity_bus_max_schedule_descに到達したら
		// または停車停留所が終点のバス停に最も近いバス停座標リストに到達したら強制終了
		if(t_root_list.len() >= city_bus_max_schedule_desc || is_member(target, nearest_terminal_st_list))
		{
			local res = asf.search_route([target], [terminal])
			if ("err" in res)
			{
				// 道路建設
				local as = astar_builder()
				as.builder = way_planner_x(our_player)
				// 道路アドオンを選択
				local way = road_info.select_road(our_player, null)
				if(way == null){ return }
				as.way = way
				as.builder.set_build_types(way)
				as.bridger = pontifex(our_player, way)
				if (as.bridger.bridge == null) {
					as.bridger = null
				}
				res = as.search_route([target], [terminal])
			}
			t_root_list.append(terminal)
		}else{
			// 既にルートに登録済みのバス停を除外
			bus_stop_list = filter(bus_stop_list, @(a) !(is_member(a, t_root_list)))
			// 基準バス停からマンハッタン距離である程度近いバス停を取得
			local temp_nearest_stop = filter(bus_stop_list, @(a) abs(a.x-target.x)+abs(a.y-target.y) <= 2*(2*settings.get_station_coverage()+1))
			local map_distance = world.get_size().x + world.get_size().y
			temp_nearest_stop = get_nearest(temp_nearest_stop, map_distance, @(a) get_trace_tile(a, target, wt_road, true))
			// 最も近いバス停が複数ある場合、終点に近いバス停を選択
			if(temp_nearest_stop.len() > 1)
			{
				temp_nearest_stop = get_nearest(temp_nearest_stop, map_distance, @(a) get_trace_tile(a, terminal, wt_road, true))
			}
			local nearest_stop = temp_nearest_stop.len() == 0 ? terminal : temp_nearest_stop[0]

			// 通過する道路上にバス停があれば、ついでに追加していく
			local res = asf.search_route([target], [nearest_stop])
			if("err" in res)
			{
				// 道路建設
				local as = astar_builder()
				as.builder = way_planner_x(our_player)
				// 道路アドオンを選択
				local way = road_info.select_road(our_player, null)
				if(way == null){ return }
				as.way = way
				as.builder.set_build_types(way)
				as.bridger = pontifex(our_player, way)
				if (as.bridger.bridge == null) {
					as.bridger = null
				}
				res = as.search_route([target], [nearest_stop])
			}

			local another_bus_stop_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
			another_bus_stop_list = filter(another_bus_stop_list, @(a) a.get_halt() != null)
			another_bus_stop_list = filter(another_bus_stop_list, @(a) is_member(a.get_halt().get_owner().nr, [our_player_nr, 1]))
			another_bus_stop_list = filter(another_bus_stop_list, @(a) !(is_member(a, [target, nearest_stop])))
			// another_bus_stop_listにはターミナル側から情報が格納されている
			for(local ii = another_bus_stop_list.len()-1; ii >= 0; ii--)
			{
				t_root_list.append(another_bus_stop_list[ii])
				if(compare_coord(another_bus_stop_list[ii], terminal))
				{
					return t_root_list
				}
			}
			
			// 終点のバス停にたどり着くまで再帰処理
			if(compare_coord(nearest_stop, terminal))
			{
				t_root_list.append(nearest_stop)
			}else{
				t_root_list = select_root(bus_stop_list, nearest_stop, terminal, nearest_terminal_st_list, t_root_list)
			}
		}
		return t_root_list
	}

	/***************************************
	 * 2点間の経路探索した時に通過するタイル数を取得
	 * 引数：探索開始座標(Coord)、探索終了座標(Coord)、線タイプ(enum)、最近接調査か最遠方調査か(boolean)
	 * 戻り値：2点間の経路探索した時に通過するタイル数
	 ***************************************/
	function get_trace_tile(from, to, way_type, blnNearest)
	{
		if(from.x == to.x && from.y == to.y){ return 0 }
		local asf = astar_route_finder(way_type)
		local res = asf.search_route([from], [to])
		if ("err" in res)
		{
			if(debug_mode){ gui.add_message_at(our_player,"get_trace_tile:"+res.err+",["+coord_to_string(from)+"] -> ["+coord_to_string(to)+"]",world.get_time()) }
			if(blnNearest)
			{
				return world.get_size().x + world.get_size().y
			}else{
				return 0
			}
		}
		return res.routes.len()
	}

	/***************************************
	 * 赤棒が建った駅に増発
	 * 引数：プレイヤー属性(player_x)
	 ***************************************/
	function add_convoy(pl)
	{
		// 赤棒が建った駅を検索
		local overflow_stop = filter(halt_list_x(), @(a) (a.get_owner().nr == pl.nr || a.get_owner().nr == 1) && a.get_capacity(good_desc_x.passenger) < (a.get_waiting())[0])
		local overflow_stop_onetile = map(overflow_stop, @(a) a.get_tile_list().top())
		local road_info = road_manager_t()
		foreach(onetile in overflow_stop_onetile)
		{
			local stop = onetile.get_halt()
			// 接続している各路線別の待機人数と所属車両の定員を取得し、比較。車両不足なら増発
			local line_list = filter(stop.get_line_list(), @(a) a.get_owner().nr == pl.nr)
			foreach(line in line_list)
			{
				local wait_pas = 0
				local schedule_entries = line.get_schedule().entries
				local halt_list = map(schedule_entries, @(a) a.get_halt(pl))

				halt_list = filter(halt_list, @(a) a != null)
				foreach(schedule in schedule_entries)
				{
					local from_halt = schedule.get_halt(pl)
					if(from_halt == null){ continue }
					foreach(to_halt in _step_generator(halt_list))
					{
						if(from_halt != null && from_halt.get_name() != to_halt.get_name())
						{
							wait_pas += from_halt.get_freight_to_halt(good_desc_x.passenger, to_halt)
						}
					}
				}
				local convoy_cap = 0
				local convoy_list = line.get_convoy_list()
				foreach(convoy in convoy_list)
				{
					local vehicle_info = convoy.get_vehicles()
					foreach(vehicle in vehicle_info)
					{
						convoy_cap += vehicle.get_capacity()
					}
				}
try{
if(debug_mode){gui.add_message_at(pl, line.get_name()+". "+convoy_cap+", "+wait_pas+", "+line.get_waytype(), (stop.get_tile_list())[0])}
}catch(e){gui.add_message_at(pl, line.get_name()+". "+convoy_cap+", "+wait_pas+", "+line.get_waytype(), world.get_time())}
				if(convoy_cap < wait_pas)
				{
					if(line.get_waytype() == wt_road)
					{
						local check_add_convoy = true

						// check transported good
						local transported_goods = line.get_transported_goods()
						// line not transported good = not add convoy
						if ( ( transported_goods[0] + transported_goods[1] ) == 0 )
						{
							check_add_convoy = false
						}

						// check convoy count
						local line_convoy_count = line.get_convoy_count()
						// last two month change convoy count = not add convoy
						// convoy count 0 = new line
						if ( line_convoy_count[2] == 0 || line_convoy_count[1] == 0 )
						{
							// new line not add cnv
							check_add_convoy = false
						} else if ( line_convoy_count[1] > line_convoy_count[2] || line_convoy_count[0] > line_convoy_count[1] ) {
							// not add cnv, last month add cnv
							check_add_convoy = false
						}

						// not add cnv first 1/3 from month
						local time_check = world.get_time().next_month_ticks - ( world.get_time().ticks_per_month - (abs(world.get_time().ticks_per_month / 3) * 2) )
						if ( world.get_time().ticks < time_check )
						{
							check_add_convoy = false
						}

						if(check_add_convoy)
						{
							if ( schedule_entries[0].wait > 88 )
							{
								// change waiting time and load
								schedule_entries[0].wait = schedule_entries[0].wait - 88
								local schedule = schedule_x(line.get_waytype(), schedule_entries)
								line.change_schedule(pl, schedule)
								gui.add_message_at(pl, " reduce waiting time schedule line " + line.get_name(), world.get_time())
							} else if ( schedule_entries[0].wait == 88 ){
								// remove waiting time and load
								schedule_entries[0].wait = 0
								schedule_entries[0].load = 0
								local schedule = schedule_x(line.get_waytype(), schedule_entries)
								line.change_schedule(pl, schedule)
								gui.add_message_at(pl, " remove load/wait schedule line " + line.get_name() world.get_time())
							} else {
								add_road_convoy(line, pl)
							}
						}
						// 道路高速化
						road_info.update_road(line)
					} else if ( line.get_waytype() == wt_rail ) {
						local stop_pos = (stop.get_tile_list())[0]
						solute_overflow_station(line, pl)
						// 公共駅の場合、ホーム延伸とかすると駅情報が更新される
						stop = stop_pos.get_halt()
						// 鉄道高速化
						local rail_info = rail_manager_t()
						rail_info.update_rail(line)
					}
				}
			}

			// バス停をアップデート
			local bus_stop_tile = finder.check_sta_freight_property(stop, wt_road, 2)
			if(bus_stop_tile.len() != 0)
			{
				local err = road_info.update_bus_stop(pl, stop)
				if(err)
				{
					local stop_pos = (stop.get_tile_list())[0]
					gui.add_message_at(pl, "Failed update bus stop at "+coord_to_string(stop_pos), stop_pos)
				}
			}
			// 鉄道線に原因があるなら駅をアップデート
			if(stop.get_capacity(good_desc_x.passenger) < (stop.get_waiting())[0] && (filter(line_list, @(a) a.get_waytype() == wt_rail)).len() != 0)
			{
				local station = station_manager_t()
				local err = station.update_station(pl, stop)
				if(err)
				{
					local stop_pos = (stop.get_tile_list())[0]
					gui.add_message_at(pl, "Failed update station at "+stop.get_name()+":"+err, stop_pos)
				}
			}
		}
		sleep()
	}

	/***************************************
	 * 赤棒が建ったバス停に増発
	 * 引数：路線(line_x)、プレイヤー会社(player_x)
	 ***************************************/
	function add_road_convoy(line, pl)
	{
		local road_info = road_manager_t()
		local schedule_entries = line.get_schedule().entries
		local depot_pos = road_info.search_bus_depot(schedule_entries[0], pl)
		local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
		if(line.get_convoy_list().get_count() >= schedule_entries.len())
		{
			update_convoy_in_line(line, depot, wt_road, pl, false)
		}else{
			// 増発
			local convoy_list = line.get_convoy_list()
			local vehicle_info = convoy_list[0].get_vehicles()
			local convoy = null
			// 年代設定有効で当該車両が製造中止になってる場合
			if(world.use_timeline() && !(vehicle_info[0].is_available(world.get_time())))
			{
				convoy = update_convoy(line, depot, pl, wt_road)
			}else{
				convoy = buy_convoy(depot, pl, wt_road, vehicle_info[0])
			}
			if(convoy != null)
			{
				convoy.set_line(pl, line)
				depot.start_convoy(pl, convoy)
			}
		}
	}

	/***************************************
	 * 路線の車両をアップデート
	 * 引数：路線(line_x)、車庫(depot_x)、線タイプ(enum)、プレイヤー会社(player_x)、旧車はそのまま削除(true)回送してから削除(false)
	 ***************************************/
	function update_convoy_in_line(line, depot, way_type, pl, bln_del_withdraw)
	{
		local electric_convoy = filter(line.get_convoy_list(), @(a) a.needs_electrification())
		local is_electrified = false
		if(electric_convoy.len() != 0){ is_electrified = true }
		// 車両アップデート
		local convoy = update_convoy(line, depot, pl, way_type, is_electrified)
		// 旧車は全てリタイア
		if(convoy != null)
		{
			convoy.set_line(pl, line)
			depot.start_convoy(pl, convoy)
			local new_convoy_cap = 0
			local new_vehicle_info = convoy.get_vehicles()
			foreach(new_vehicle in new_vehicle_info)
			{
				new_convoy_cap += new_vehicle.get_capacity()
			}
			local convoy_info_list = []
			foreach(current_convoy in line.get_convoy_list())
			{
				local vehicle_info = current_convoy.get_vehicles()
				local current_convoy_cap = 0
				foreach(vehicle in _step_generator(vehicle_info))
				{
					current_convoy_cap += vehicle.get_capacity()
				}
				local convoy_info =
				{
					convoy_capacity = current_convoy_cap
					convoy = current_convoy
				}
				convoy_info_list.append(convoy_info)
			}
			local old_convoy = filter(convoy_info_list, @(a) a.convoy_capacity < new_convoy_cap)
			foreach(convoy_retired in old_convoy)
			{
				if(bln_del_withdraw)
				{
					convoy_retired.convoy.destroy(pl)
					sleep()
				}else{
					convoy_retired.convoy.toggle_withdraw(pl)
				}
			}
		}else{
			// convoyがnullの時、都市間連絡バス路線なら鉄道に変更
			if(way_type != wt_road || line.get_name().slice(0, 1) != "("){ return }
			local schedule_entries = line.get_schedule().entries
			// 町情報取得
			local townhall_list = map(persistent.city.get_city_info(), @(a) a.townhall)
			local city_idx_list =[persistent.base_city]
			for(local ii = 1; ii < schedule_entries.len() / 2; ii++)
			{
				local city = finder.find_nearest_city(schedule_entries[ii])
				city_idx_list = combine(city_idx_list, get_idx_in_member(city.get_pos(), townhall_list))
			}
			if(city_idx_list.len() < 2){ return }
			local rail_info = rail_manager_t()
			rail_info.build_rail_root(pl, city_idx_list)
		}
	}

	/***************************************
	 * 赤棒が建った駅に増発or増結
	 * 引数：路線(line_x)、プレイヤー会社(player_x)
	 ***************************************/
	function solute_overflow_station(line, pl)
	{
		local blnSelectFlg = false
		local convoy_list = line.get_convoy_list()
		convoy_list = filter(convoy_list, @(a) !(a.is_withdrawn()))
		local first_car_list = map(convoy_list, @(a) a.get_vehicles()[0])
		first_car_list = filter(first_car_list, @(a) a.get_capacity() == 0)
		if(first_car_list.len() == 0)
		{
			// 路線内の赤棒が建っている駅数が半数以上なら増発、そうでないなら増結
			local overflow_counter = 0
			local schedule_entries = line.get_schedule().entries
			for(local ii = 0; ii < schedule_entries.len() / 2; ii++)
			{
				local halt = finder.coord2D_to_tile(schedule_entries[ii]).get_halt()
				if(halt.get_capacity(good_desc_x.passenger) < (halt.get_waiting())[0]){ overflow_counter++ }
			}
			if(overflow_counter >= schedule_entries.len() / 4 && schedule_entries.len() > 3){ blnSelectFlg = true }
			
			if(!(blnSelectFlg))
			{
				// 全編成が6両になったら増発
				convoy_list = filter(convoy_list, @(a) a.get_vehicles().len() < 6)
				if(convoy_list.len() == 0)
				{
					blnSelectFlg = true
				}
			}
		}else{
			// 機関車編成の場合、増結優先(全編成が8両になったら増発)
			convoy_list = filter(convoy_list, @(a) a.get_vehicles().len() < 8)
			if(convoy_list.len() == 0)
			{
				blnSelectFlg = true
			}else{
				// 往復駅数/最小編成の車両数が2を下回ったら増発(列車本数を確保するため)
				local schedule_entry_list = line.get_schedule().entries
				convoy_list = sort(convoy_list, @(a,b) a.get_vehicles().len() <=> b.get_vehicles().len())
				if(schedule_entry_list.len() / convoy_list[0].get_vehicles().len() < 2){ blnSelectFlg = true }
			}
		}
		
		if(blnSelectFlg)
		{
			local err = add_rail_convoy(line, pl)
			if(err == null){ return }
		}
		add_vehicle(line, pl)
	}

	/***************************************
	 * 鉄道増発
	 * 引数：路線(line_x)、プレイヤー会社(player_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function add_rail_convoy(line, pl)
	{
		// 路線が通過する駅の行き違い設備の数をカウント
		local peo_sta = get_pass_each_other(line, pl)
		// 復路分は削除
		peo_sta.resize(peo_sta.len() / 2)

		local err = null
		local convoy_list = line.get_convoy_list()
		local station = station_manager_t()
		local schedule_entries = line.get_schedule().entries
		// 途中駅全てに行き違い設備設置を試みる
		for(local ii = 1; ii < schedule_entries.len() / 2; ii++)
		{
			if(is_member(ii, peo_sta)){ continue }
			err = station.set_passing_each_other(pl, finder.coord2D_to_tile(schedule_entries[ii]).get_halt())
			// TODO : err時は前後の駅の信号をLongBlockに変更したい
			if(err == null)
			{
				peo_sta.append(ii)
			}else{
				gui.add_message_at(pl,"failed update station at "+finder.coord2D_to_tile(schedule_entries[ii]).get_halt().get_name()+":"+err,world.get_time())
			}
		}
		// 行き違い設備設置をリトライ
		if(convoy_list.get_count() > peo_sta.len())
		{
			local t_list = []
			for(local ii = 1; ii < schedule_entries.len() / 2; ii++)
			{
				if(!(is_member(ii, peo_sta)))
				{
					err = station.set_passing_each_other(pl, finder.coord2D_to_tile(schedule_entries[ii]).get_halt())
					if(err == null)
					{
						peo_sta.append(ii)
					}else{
						gui.add_message_at(pl,"failed update station at "+finder.coord2D_to_tile(schedule_entries[ii]).get_halt().get_name()+":"+err,world.get_time())
					}
				}
			}
		}

		// リトライ失敗
		if(convoy_list.get_count() > peo_sta.len())
		{
			// 電車編成がないなら、電車化する
			local rail_info = rail_manager_t()
			local depot_pos = rail_info.search_depot(finder.coord2D_to_tile(schedule_entries[0]), pl)
			local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
			local temp_list = filter(convoy_list, @(a) a.needs_electrification())
			if(temp_list.len() == 0)
			{
				// 電化
				local blnElectric = rail_info.electrify_line(line)
				
				if(blnElectric)
				{
					// 気動車編成を置換
					convoy_list = filter(convoy_list, @(a) !(a.is_withdrawn()))
					map(convoy_list, @(a) a.toggle_withdraw(pl))
					local convoy = buy_convoy(depot, pl, wt_rail, null, true)
					if(convoy != null)
					{
						convoy.set_line(pl, line)
						start_convoy(convoy, depot, pl)
						return
					}
				}
			}
			update_convoy_in_line(line, depot, wt_rail, pl, false)
			return
		}

		// 増発
		local base_idx = schedule_entries.len() / 2
		local rail_info = rail_manager_t()
		local depot_pos = rail_info.search_depot(tile_x(schedule_entries[base_idx].x,schedule_entries[base_idx].y,schedule_entries[base_idx].z), pl)
		local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
		local vehicle_info = convoy_list[0].get_vehicles()
		convoy_list = filter(convoy_list, @(a) a.needs_electrification())
		local is_electrified = convoy_list.len() != 0 ? true : false
		// 先頭車が機関車の場合、客車の情報を取得
		local ii = 0
		while(vehicle_info[ii].get_capacity() == 0){ ii++ }
		// 年代設定有効で当該車両が製造中止になってる場合
		local convoy = null
		if(world.use_timeline() && !(vehicle_info[ii].is_available(world.get_time())))
		{
			convoy = update_convoy(line, depot, pl, wt_rail, is_electrified)
			if(convoy == null){ convoy = buy_convoy(depot, pl, wt_rail, null, is_electrified) }
		}else{
			convoy = buy_convoy(depot, pl, wt_rail, vehicle_info[ii], is_electrified)
		}
		if(convoy != null)
		{
			convoy.set_line(pl, line)
			start_convoy(convoy, depot, pl)
		}
		return null
	}

	/***************************************
	 * 鉄道路線で通過する行き違い設備のある駅一覧取得
	 * 引数：路線(line_x)、プレイヤー会社(player_x)
	 * 戻り値：行き違い設備のある駅indexリスト
	 * 備考：駅indexは引数の路線の停車駅の位置
	 ***************************************/
	function get_pass_each_other(line, pl)
	{
		// 所属車両は電車か
		local is_electrified = false
		local convoy_list = line.get_convoy_list()
		foreach(convoy in _step_generator(convoy_list))
		{
			if(convoy.needs_electrification())
			{
				is_electrified = true
				break
			}
		}

		local schedule_entries = line.get_schedule().entries
		local peo_sta = []            /* 行き違い設備のある駅indexリスト */
		local station = station_manager_t()
		for(local ii = 0; ii < schedule_entries.len() / 2; ii++)
		{
			local halt = finder.coord2D_to_tile(schedule_entries[ii]).get_halt()
			local tbl_sta_info_list = station.get_station_info(halt, 2, is_electrified)
			local tbl_form_info_list = tbl_sta_info_list.tbl_form_info_list
			if(tbl_form_info_list.len() < 2){ continue }
			local temp_list = filter(tbl_form_info_list, @(a) dir.is_single(a.dir))
			if(temp_list.len() == 0){ continue }
			local a_dir = temp_list[0].dir
			for(local jj = 1; jj < temp_list.len(); jj++)
			{
				if(temp_list[jj].dir == dir.backward(a_dir))
				{
					peo_sta.append(ii)
					break
				}
			}
		}
		
		for(local ii = peo_sta.len()-1; ii >= 0; ii--)
		{
			peo_sta.append(schedule_entries.len() - peo_sta[ii])
			if(peo_sta[ii] == 0){ peo_sta[peo_sta.len()-1] = peo_sta.top() - 1 }
		}
		return peo_sta
	}

	/***************************************
	 * 鉄道車両の増発時における出庫
	 * 引数：車両編成(convoy_x)、車庫(depot_x)、プレイヤー会社(player_x)
	 * 備考：車両編成は路線が設定されていること
	 ***************************************/
	function start_convoy(convoy, depot, pl)
	{
		// 路線からスケジュール取得
		local line = convoy.get_line()
		local schedule_entries = line.get_schedule().entries
		
		// 路線から行き違い設備のある駅一覧取得
		local peo_sta_idx_list = get_pass_each_other(line, pl)
		
		// 車庫～最初の行き違い設備に列車がいないことを確認
		local peo_sta_pos_list = map(peo_sta_idx_list, @(a) schedule_entries[a])
		if(peo_sta_pos_list.len() == 0)
		{
			peo_sta_pos_list = [schedule_entries[schedule_entries.len() / 2]]
		}
		
		local depot_pos = finder.coord2D_to_tile(depot.get_pos())
		local neighbor_tile = depot_pos.get_neighbour(wt_rail, depot_pos.get_way_dirs(wt_rail))
		local asf = astar_route_finder(wt_rail)
		local res_list = map(peo_sta_pos_list, @(a) asf.search_route([a], [neighbor_tile]))
		res_list = filter(res_list, @(a) ("routes" in a))
		res_list = sort(res_list, @(a,b) a.routes.len() <=> b.routes.len())
		
		local convoy_list = line.get_convoy_list()
		while(1)
		{
			local onrail_flg_list = []
			foreach(current_convoy in _step_generator(convoy_list))
			{
				onrail_flg_list.append(is_member(current_convoy.get_pos(), res_list[0].routes))
			}
			if(!(is_member(true, onrail_flg_list))){ break }
		}

		depot.start_convoy(pl, convoy)
	}

	/***************************************
	 * 車両増結
	 * 引数：路線(line_x)、プレイヤー会社(player_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function add_vehicle(line, pl)
	{
		// 所属車両は電車か
		local is_electrified = false
		local convoy_list = line.get_convoy_list()
		foreach(convoy in _step_generator(convoy_list))
		{
			if(convoy.needs_electrification())
			{
				is_electrified = true
				break
			}
		}
		// 最小編成取得
		convoy_list = sort(convoy_list, @(a,b) a.get_vehicles().len() <=> b.get_vehicles().len())
		local t_convoy = convoy_list[0]
		// 最小編成が回送なら新しい編成が出庫中なので対応しない
		if(t_convoy.is_withdrawn()){ return }
		// 最後尾車に連結可能な車をセット
		local vehicle_list = t_convoy.get_vehicles()
		local t_vehicle = vehicle_list.top()
		local add_vehicle_list = t_vehicle.get_successors()
		if(t_vehicle.get_successors().len() == 0 && t_vehicle.get_predecessors().len() != 0)
		{
			// 編成の中間車から増結
			t_vehicle = vehicle_list[vehicle_list.len()-2]
			add_vehicle_list = t_vehicle.get_successors()
		}
		// 最後尾車が何でも連結可能な場合、同じ車両をセット
		local ado_vehicle = null
		if(add_vehicle_list.len() == 0)
		{
			// 年代設定有効で当該車両が製造中止になってる場合
			if(world.use_timeline() && !(t_vehicle.is_available(world.get_time())))
			{
				ado_vehicle = select_convoy(pl, wt_rail, is_electrified)
				if(ado_vehicle == null){ return "no selectable vehicle." }
			}else{
				// TODO : 増結車用をバリエーション豊にしたい
				ado_vehicle = t_vehicle
			}
		}else{
			ado_vehicle = add_vehicle_list[get_idx_by_month(add_vehicle_list.len())]
		}
		
		local rail_info = rail_manager_t()
		local schedule_entries = line.get_schedule().entries
		local depot_pos = rail_info.search_depot(tile_x(schedule_entries[0].x,schedule_entries[0].y,schedule_entries[0].z), pl)
		local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
		
		// 増結した時、パワーが不足しないか計算
		local power_total = 0
		local weight_total = 0
		local speed = vehicle_list[0].get_topspeed()
		local length_total = 0
		foreach(vehicle in _step_generator(vehicle_list))
		{
			power_total += vehicle.get_power()
			weight_total += vehicle.get_weight()
			if(speed > vehicle.get_topspeed()){ speed = vehicle.get_topspeed() }
			length_total += vehicle.get_length()
		}
		local station = station_manager_t()
		power_total += ado_vehicle.get_power()
		weight_total += ado_vehicle.get_weight()
		if(speed - 10 > convoy_x.calc_max_speed(power_total, weight_total, speed))
		{
			// 編成の先頭は機関車か？
			if(vehicle_list[0].get_capacity() == 0)
			{
				// 既存編成廃止してよりハイスペックな編成作成
				local vehicle_desc_list = vehicle_desc_x.get_available_vehicles(wt_rail)
				vehicle_desc_list = filter(vehicle_desc_list, @(a) a.get_power() > vehicle_list[0].get_power() && a.can_be_first() && a.needs_electrification() == is_electrified)
				local new_vehicle_desc = vehicle_desc_list[get_idx_by_month(vehicle_desc_list.len())]
				
				local new_convoy = buy_convoy(depot, pl, wt_rail, new_vehicle_desc, is_electrified)
				while(!(new_convoy.get_vehicles().top().can_be_last()))
				{
					local new_vehicle_desc_list = new_convoy.get_vehicles().top().get_successors()
					depot.append_vehicle(pl, new_convoy, new_vehicle_desc_list[get_idx_by_month(new_vehicle_desc_list.len())])
				}

				local idx = 0
				while(vehicle_list[idx].get_capacity() == 0){ idx++ }
				// 増結後の客車数
				idx = vehicle_list.len() - idx + 1
				// 客車の選定
				local new_car = select_convoy(pl, wt_rail, is_electrified)
				if(new_car == null){ return "no selectable vehicle." }
				// 客車じゃない車両を選定した場合、既存車を選定
				if(new_car.get_power() != 0){ new_car = t_vehicle }
				for(local ii = 0; ii < idx; ii++)
				{
					depot.append_vehicle(pl, new_convoy, new_car)
				}
				
				// ホーム延長
				local length = new_convoy.get_tile_length()
				local err = null
				for(local ii = 0; ii < schedule_entries.len()/2 + 1; ii++)
				{
					local halt = schedule_entries[ii].get_halt(pl)
					local stop_list = [schedule_entries[ii]]
					if(ii != 0 && ii != schedule_entries.len() / 2)
					{
						stop_list.append(schedule_entries[schedule_entries.len()-ii])
					}
					err = station.extend_form(pl, halt, length, stop_list)
					if("err" in err){ break }
				}
				if("err" in err)
				{
					new_convoy.destroy(pl)
					sleep()
					// ホーム延長失敗した駅があるので、増結やめて増発する
					add_rail_convoy(line, pl)
					return
				}
				
				// 新編成スタート
				new_convoy.set_line(pl, line)
				// 旧編成リタイア
				if(!(t_convoy.is_withdrawn())){ t_convoy.toggle_withdraw(pl) }
				// 車庫～最初の行き違い設備に列車がいないことを確認し、出庫
				start_convoy(new_convoy, depot, pl)
				t_convoy = new_convoy
				return
			}else{
				// 機関車の編成でないので、とりあえず駆動装置ついた車を連結
				add_vehicle_list = filter(add_vehicle_list, @(a) a.get_power() > 0)
				ado_vehicle = add_vehicle_list[get_idx_by_month(add_vehicle_list.len())]
			}
		}
		// ホーム延長の必要判断
		length_total += ado_vehicle.get_length()
		local length = length_total / CARUNITS_PER_TILE
		if(length_total % CARUNITS_PER_TILE != 0){ length += 1 }
		
		// ホーム延長
		local err = null
		for(local ii = 0; ii < schedule_entries.len()/2 + 1; ii++)
		{
			local halt = schedule_entries[ii].get_halt(pl)
			local stop_list = [schedule_entries[ii]]
			if(ii != 0 && ii != schedule_entries.len() / 2)
			{
				stop_list.append(schedule_entries[schedule_entries.len()-ii])
			}
			err = station.extend_form(pl, halt, length, stop_list)
			if("err" in err){ break }
		}
		if("err" in err)
		{
			// ホーム延長失敗した駅があるので、増結やめて増発する
			add_rail_convoy(line, pl)
			return
		}

		// 車両追加
		depot.append_vehicle(pl, t_convoy, ado_vehicle)
	}

	/***************************************
	 * 減便
	 * 引数：路線(line_x)、プレイヤー属性(player_x)
	 ***************************************/
	function pop_convoy(line, pl)
	{
		// 待機人数取得
		local wait_pas = 0
		local schedule_entries = line.get_schedule().entries
		local halt_list = map(schedule_entries, @(a) a.get_halt(pl))
		halt_list = filter(halt_list, @(a) a != null)
		foreach(schedule in schedule_entries)
		{
			local from_halt = schedule.get_halt(pl)
			if(from_halt == null){ continue }
			foreach(to_halt in _step_generator(halt_list))
			{
				if(from_halt.get_name() != to_halt.get_name())
				{
					wait_pas += from_halt.get_freight_to_halt(good_desc_x.passenger, to_halt)
				}
			}
		}
		// 所属車両のキャパ取得
		local convoy_cap = 0
		local convoy_list = line.get_convoy_list()
		foreach(convoy in convoy_list)
		{
			local vehicle_info = convoy.get_vehicles()
			foreach(vehicle in vehicle_info)
			{
				convoy_cap += vehicle.get_capacity()
			}
		}
		if(wait_pas * 10 < convoy_cap)
		{
			local remove_cnv = true
			local line_cnv_count = line.get_convoy_count()
			if ( line_cnv_count[1] < line_cnv_count[2] || line_cnv_count[0] < line_cnv_count[1] )
			{
				remove_cnv = false
				gui.add_message_at(pl, line.get_name() + ": not remove cnv; last month remove convoy from line ", world.get_time())
			}

			// not remove cnv first 1/3 from month
			local time_check = world.get_time().next_month_ticks - ( world.get_time().ticks_per_month - (abs(world.get_time().ticks_per_month / 3) * 2) )
			if ( world.get_time().ticks < time_check )
			{
				remove_cnv = false
			}

			local convoy_list = line.get_convoy_list()
			if( remove_cnv && convoy_list.get_count() > 1)
			{
				convoy_list[0].toggle_withdraw(pl)
			} else {
				// change schedule
				// change waiting time
				local schedule_entries = line.get_schedule().entries
				if (schedule_entries[0].wait > 0 && schedule_entries[0].wait < 2000 )
				{
					schedule_entries[0].wait = schedule_entries[0].wait + 88
					local schedule = schedule_x(line.get_waytype(), schedule_entries)
					line.change_schedule(pl, schedule)
					gui.add_message_at(pl, " increase waiting time schedule line " + line.get_name(), world.get_time())
				}
			}
		}
	}

	/***************************************
	 * 鉄道路線新規作成
	 * 引数：プレイヤー属性(player_x)
	 * 戻り値：路線(line_x)
	 ***************************************/
	function set_rail_line(pl)
	{
		local station = station_manager_t()
		local base_terminal = station.get_own_terminal_station(pl)
		if(base_terminal == null){ return }
		// 路線が通ってない駅一覧
		local station_list = filter(halt_list_x(), @(a) a.get_owner().nr == pl.nr || a.get_owner().nr == 1)
		station_list = filter(station_list,@(a) finder.check_sta_freight_property(a, wt_rail, 2).len() != 0)
		station_list = filter(station_list,@(a) filter(a.get_line_list(), @(b) b.get_waytype() == wt_rail && b.get_owner().nr == pl.nr).len() == 0)

		// ベースの駅情報取得
		local tbl_no_line_sta_list = []
		local tbl_bt_sta_info = station.get_station_info(base_terminal, 2, false)
		local tbl_bt_form_info_list = tbl_bt_sta_info.tbl_form_info_list
		foreach(t_station in station_list)
		{
			// ベースの駅と接続しているかチェック
			local tbl_sta_info = station.get_station_info(t_station, 2, false)
			local tbl_form_info_list = tbl_sta_info.tbl_form_info_list
			local blnFlg = false
			foreach(tbl_bt_form_info in tbl_bt_form_info_list)
			{
				foreach(tbl_form_info in tbl_form_info_list)
				{
					local asf = astar_route_finder(wt_rail)
					local res = asf.search_route([tbl_form_info.stop], [tbl_bt_form_info.stop])
					if("routes" in res)
					{
						local tbl_no_line_sta =
						{
							halt = t_station
							length = res.routes.len()
						}
						tbl_no_line_sta_list.append(tbl_no_line_sta)
						blnFlg = true
						break
					}
				}
				if(blnFlg){ break }
			}
		}
		
		// ベースの駅と接続している駅がない場合
		if(tbl_no_line_sta_list.len() == 0)
		{
			station_list = filter(station_list, @(a) a.get_owner().nr == pl.nr)
			foreach(t_station in station_list)
			{
				// ベースの駅までのマンハッタン距離を取得
				local sta_tile = t_station.get_tile_list().top()
				local length = abs(tbl_bt_form_info_list[0].stop.x - sta_tile.x) + abs(tbl_bt_form_info_list[0].stop.y - sta_tile.y)
				local tbl_no_line_sta =
				{
					halt = t_station
					length = length
				}
				tbl_no_line_sta_list.append(tbl_no_line_sta)
			}
		}
		if(tbl_no_line_sta_list.len() == 0){ return }
		// 路線が通ってない駅でベースの駅から最遠の駅を選出
		tbl_no_line_sta_list = sort(tbl_no_line_sta_list, @(a,b) b.length <=> a.length)
		local no_line_sta = tbl_no_line_sta_list[0].halt
		// 隣の駅に鉄道路線があり、終着駅なら、それを延伸する
		local halt_info = station.get_station_info(no_line_sta, 2, false)
		// 路線が通ってない駅は大抵棒線駅なので...
		local from_tile = halt_info.tbl_form_info_list[0].stop
		local dir_list = finder.divide_dir(halt_info.tbl_form_info_list[0].dir)

		local update_flg = null
		foreach(dd in dir_list)
		{
			local tbl_target = { halt = no_line_sta, dir = dd }
			local next_sta_list = station.search_next_sta(tbl_target, from_tile, dd, false, [])
			next_sta_list = filter(next_sta_list, @(a) a.halt.get_line_list().get_count() != 0)
			if(next_sta_list.len() == 0){ continue }
			// 隣接駅のうち距離が近い駅を選定
			next_sta_list = sort(next_sta_list, @(a,b) abs(a.tile_list[0].x-from_tile.x)+abs(a.tile_list[0].y-from_tile.y) <=> abs(b.tile_list[0].x-from_tile.x)+abs(b.tile_list[0].y-from_tile.y))
			local convoy_length = 0
			local line_list = next_sta_list[0].halt.get_line_list()
			line_list = filter(line_list, @(a) a.get_waytype() == wt_rail && a.get_owner().nr == pl.nr)
			local tbl_next_sta_info = station.get_station_info(next_sta_list[0].halt, 2, false)
			local convoy_counter = 0
			foreach(line in line_list)
			{
				// 隣の駅が終着駅の路線検索
				local target_idx_list = []
				foreach(tbl_form_info in tbl_next_sta_info.tbl_form_info_list)
				{
					local temp_list = station.get_idx_in_line(line, tbl_form_info.stop)
					foreach(temp in _step_generator(temp_list))
					{
						target_idx_list.append(temp)
					}
				}

				if(target_idx_list.len() == 1)
				{
					// 終点の路線を延伸
					if(target_idx_list[0] == 0)
					{
						// 始発駅側を延伸
						update_line(line, from_tile, 0, pl)
					}else{
						// 終点駅側を延伸
						update_line(line, from_tile, target_idx_list[0]+1, pl)
					}
					// 電化
					if(line.get_convoy_list()[0].needs_electrification())
					{
						local electric_tile = filter(next_sta_list[0].tile_list, @(a) a.find_object(mo_wayobj) != null)
						local catenary = electric_tile.top().find_object(mo_wayobj).get_desc()
						for(local ii = 0; ii < electric_tile.len(); ii++)
						{
							command_x.build_wayobj(pl, from_tile, electric_tile[ii], catenary)
						}
						if(dir_list.len() == 1)
						{
							local temp_list = station.trace_way(from_tile, wt_rail, dir.backward(dd), @(a) a.has_way(wt_rail))
							command_x.build_wayobj(pl, from_tile, temp_list.top(), catenary)
						}
					}
					update_flg = line
					// 路線所属車両が複数ある、または路線が複数ある場合、隣の駅に行き違い設備を設ける
					convoy_counter = convoy_counter + line.get_convoy_list().get_count()
					if(convoy_counter > 1)
					{
						local next_sta_name = next_sta_list[0].halt.get_name()
						local err = station.set_passing_each_other(pl, next_sta_list[0].halt)
						if(err)
						{
							gui.add_message_at(pl,"failed update station at "+next_sta_name+":"+err,world.get_time())
						}
					}
					// 路線所属編成で最長を取得
					foreach(convoy in _step_generator(line.get_convoy_list()))
					{
						if(convoy_length < convoy.get_tile_length()){ convoy_length = convoy.get_tile_length() }
					}
				}
			}

			// ホーム長さ調整
			if(convoy_length > 1)
			{
				local tbl_temp = station.extend_form(pl, no_line_sta, convoy_length, [from_tile])
				// 公共駅の場合、情報更新
				if("halt" in tbl_temp){ no_line_sta = tbl_temp.halt }
			}
		}
		if(update_flg){ return update_flg }

		// 隣の駅に鉄道路線があり(もしくは無し)、終着駅でなかったので、この駅を始発として終着駅まで線路を追跡する -> 往路の路線候補作成
		local outward_root_list = []
		foreach(dd in dir_list)
		{
			// 始発駅の情報
			local tbl_stop =
			{
				stop = from_tile
				halt = no_line_sta
				dir = dd
				info = halt_info
			}
			// 往路の路線候補作成
			local temp_info = select_rail_outward_root(pl, [tbl_stop], false)
			if(temp_info.len() > 0 && temp_info[0].len() > 1)
			{
				foreach(temp in _step_generator(temp_info))
				{
					outward_root_list.append(temp)
if(debug_mode){
  gui.add_message_at(pl, "[", world.get_time())
  foreach(ttt in temp)
  {
    gui.add_message_at(pl, ""+ttt.halt.get_name(), ttt.stop)
  }
  gui.add_message_at(pl, "]", world.get_time())
}
				}
			}
		}
		
		// 往路路線を選出(ベースの駅を通っている路線を選出、ない場合は全候補をそのまま通す)
		local outward_root = []
		local no_candidate_root = []
		foreach(candidate_root in _step_generator(outward_root_list))
		{
			local halt_list = map(candidate_root, @(a) a.halt.get_name())
			if(is_member(base_terminal.get_name(), halt_list))
			{
				outward_root.append(candidate_root)
			}else{
				// ベースの駅を通っていないので候補から外れた往路路線を取得
				no_candidate_root.append(candidate_root)
			}
		}
		if(outward_root.len() == 0)
		{
			outward_root = outward_root_list
			no_candidate_root = []
		}
		// 往路路線を停車駅数で昇順ソート
		outward_root = sort(outward_root, @(a,b) a.len() <=> b.len())
		if(no_candidate_root.len() != 0)
		{
			// 往路路線の中に駅手前で180度ターンする路線は駅でスイッチバックするように駅を挿入
			foreach(temp_outward_root in outward_root)
			{
				local jj = 1
				local kk = 0
				local no_candidate_root_bk = no_candidate_root
				// 各往路路線の停車駅分ループ
				while(jj + kk < temp_outward_root.len())
				{
					no_candidate_root_bk = filter(no_candidate_root_bk, @(a) a.len() > jj)
					local no_candidate_stop_list = map(no_candidate_root_bk, @(a) a[jj].stop)
					no_candidate_stop_list = unique(no_candidate_stop_list)
					// 往路路線と候補から外れた路線でjj番目の駅が異なる
					no_candidate_stop_list = filter(no_candidate_stop_list, @(a) !(compare_coord(temp_outward_root[jj+kk].stop, a)))
					if(no_candidate_stop_list.len() == 0)
					{
						jj++
						continue
					}
					local no_candidate_root_jj = []
					foreach(no_candidate_stop in no_candidate_stop_list)
					{
						local temp = filter(map(no_candidate_root_bk, @(a) a[jj]), @(b) compare_coord(b.stop, no_candidate_stop))
						no_candidate_root_jj.append(temp[0])
					}
					// 候補から外れた路線の1番目jj-1番目の停車駅座標取得
					local previous_stop = no_candidate_root_bk[0][jj-1].stop
					// 往路路線のjj+kk番目とjj+kk-1番目の距離取得
					local dist = get_trace_tile(temp_outward_root[jj+kk-1].stop, temp_outward_root[jj+kk].stop, wt_rail, true)
					local tbl_no_candidate_info_list = []
					// 往路路線のjj+kk番目～jj+kk-1番目より候補から外れた路線の方が短い場合は、
					// jj+kk番目に候補から外れた路線の駅をjj+kk-1番目に近い順に往路路線に挿入
					foreach(ncr_jj in no_candidate_root_jj)
					{
						local temp_dist = get_trace_tile(previous_stop, ncr_jj.stop, wt_rail, true)
						local tbl_temp =
						{
							dist = temp_dist
							root = ncr_jj
						}
						if(tbl_temp.dist < dist){ tbl_no_candidate_info_list.append(tbl_temp) }
					}
					tbl_no_candidate_info_list = sort(tbl_no_candidate_info_list, @(a,b) a.dist <=> b.dist)
					foreach(tbl_no_candidate_info in tbl_no_candidate_info_list)
					{
						temp_outward_root.insert(jj+kk, tbl_no_candidate_info.root)
						kk++
					}
					// 往路路線に挿入した、候補から外れた路線を除去
					no_candidate_root_bk = filter(no_candidate_root_bk, @(a) !(is_member(a[jj].stop, no_candidate_stop_list)))
					jj++
				}
			}
		}

		// 往復路線を作成
		local tbl_root_info = []
		foreach(candidate_root in _step_generator(outward_root))
		{
			local stop_list = []
			local halt_name_list = []
			// 往路路線選出時に遠方の駅->ベースの駅で取得しているので
			// 往復路線はベースの駅->遠方の駅->ベースの駅になるように順番を入れ替える
			// 復路分
			for(local ii = candidate_root.len() - 1; ii > 0; ii--)
			{
				local info = candidate_root[ii].info.tbl_form_info_list
				// 往路と逆向きに発着できる番線を検索
				info = filter(info, @(a) is_member(a.dir, [dir.backward(candidate_root[ii].dir), dir.backward(candidate_root[ii].dir)+candidate_root[ii].dir]))
				// ホームを使用している路線数が最小のホームを選択
				local tbl_form_info = station.get_line_using_track(candidate_root[ii].halt, 2)
				if(tbl_form_info.len() > 1){ tbl_form_info = filter(tbl_form_info, @(a) a.stop != candidate_root[ii].stop) }
				tbl_form_info = filter(tbl_form_info, @(a) is_member(a.stop, map(info, @(b) b.stop)))
				tbl_form_info = sort(tbl_form_info, @(a,b) a.line_list.len() <=> b.line_list.len())
				stop_list.append(tbl_form_info[0].stop)
				halt_name_list.append(candidate_root[ii].halt.get_name())
			}
			// 往路分
			for(local ii = 0; ii < candidate_root.len() - 1; ii++)
			{
				stop_list.append(candidate_root[ii].stop)
				halt_name_list.append(candidate_root[ii].halt.get_name())
			}
			local tbl_temp =
			{
				stop = stop_list
				halt_name = halt_name_list
			}
			tbl_root_info.append(tbl_temp)
		}
		// 既存路線と重複してないかチェック
		local line_list = filter(pl.get_line_list(), @(a) a.get_waytype() == wt_rail)
		local halt_name_list_in_line = []
		foreach(line in _step_generator(line_list))
		{
			halt_name_list_in_line.append(map(get_halt_list_from_line(line, pl), @(a) a.get_name()))
		}
		
		tbl_root_info = filter(tbl_root_info, @(a) !(is_member_in_doublearray(a.halt_name, halt_name_list_in_line)))
		if(tbl_root_info.len() == 0)
		{
			return null
		}

		// 路線作成
		local schedule = schedule_x(wt_rail, [])
		for(local ii = 0; ii < tbl_root_info[0].stop.len(); ii++)
		{
			schedule.entries.append( schedule_entry_x(tbl_root_info[0].stop[ii], 0, 0) )
		}
		pl.create_line(wt_rail)
		local list = filter(pl.get_line_list(), @(a) a.get_waytype() == wt_rail)
		foreach(line in list)
		{
			local schedule_entries = line.get_schedule().entries
			if (schedule_entries.len()==0)
			{
				line.change_schedule(pl, schedule)
				return line
			}
		}
		return null
	}

	/***************************************
	 * 鉄道路線の往路ルート選定
	 * 引数：プレイヤー属性(player_x)、ルートに所属した駅情報リスト(1次元配列)、電化区間のみ情報取得するか(boolean)
	 * 戻り値：更新したルートに所属した駅情報リスト(2次元配列:以下の構造体をリストにした路線リストを更にリストにする)
	 * 備考　：以下は第二引数の構造体情報を示す。戻り値は以下を二次元配列にしたものである
	 *         stop：停止位置(tile_x)
	 *         halt：駅(halt_x)
	 *         dir ：停止位置における線路の方角(dir)
	 *         info：駅情報
	 *              tbl_form_info_list    ：プラットホームの情報リスト
	 *                                     length：ホーム長さ
	 *                                     stop  ：列車停車位置の座標(スケジュール設定時に使用)
	 *                                     dir   ：ホーム上の列車の進行方向
	 *              sta_office_tile_list  ：駅本屋のタイルリスト
	 ***************************************/
	function select_rail_outward_root(pl, tbl_stop_info_list, is_electrified)
	{
		local rtn = []
		local station = station_manager_t()
		local target =
		{
			halt = tbl_stop_info_list.top().halt
			dir = tbl_stop_info_list.top().dir
		}
		local from_tile = tbl_stop_info_list.top().stop
		local d = tbl_stop_info_list.top().dir
		// 次駅検索
		local next_sta_list = station.search_next_sta(target, from_tile, d, is_electrified, [])
		if(next_sta_list.len() == 0)
		{
			rtn.append(tbl_stop_info_list)
			return rtn
		}
		next_sta_list = filter(next_sta_list, @(a) a.halt.get_owner().nr == pl.nr || a.halt.get_owner().nr == 1)
		// 既にルートに組み込まれている駅は除外
		next_sta_list = filter(next_sta_list, @(a) !(is_member(true, map(tbl_stop_info_list, @(b) finder.is_same_halt(a.halt, b.halt)))))
		if(next_sta_list.len() == 1)
		{
			// 次駅情報取得
			local next_sta_info = station.get_station_info(next_sta_list[0].halt, 2, is_electrified)
			// 次駅停車位置取得
			local stop_candidate = map(next_sta_list[0].tile_list, @(a) station.trace_way(a, wt_rail, next_sta_list[0].dir, @(b) b.get_halt() != null).top())
			if(stop_candidate.len() > 1)
			{
				// ホームを使用している路線数が最小のホームを選択
				local tbl_form_info = station.get_line_using_track(next_sta_list[0].halt, 2)
				local no_line_stop_list = filter(stop_candidate, @(a) !(is_member(a, map(tbl_form_info, @(b) b.stop))))
				if(no_line_stop_list.len() == 0)
				{
					tbl_form_info = filter(tbl_form_info, @(a) is_member(a.stop, stop_candidate))
					tbl_form_info = sort(tbl_form_info, @(a,b) a.line_list.len() <=> b.line_list.len())
					stop_candidate[0] = tbl_form_info[0].stop
				}else{
					stop_candidate = no_line_stop_list
				}
			}
			local tbl_temp =
			{
				stop = stop_candidate[0]
				halt = next_sta_list[0].halt
				dir = next_sta_list[0].dir
				info = next_sta_info
			}
			tbl_stop_info_list.append(tbl_temp)

			// 再帰処理
			rtn = select_rail_outward_root(pl, tbl_stop_info_list, is_electrified)
		}else{
			foreach(next_sta in _step_generator(next_sta_list))
			{
				// 分岐駅までの路線情報を保持
				local tbl_import_list = clone(tbl_stop_info_list)
				// 次駅情報取得
				local next_sta_info = station.get_station_info(next_sta.halt, 2, is_electrified)
				// 次駅停車位置取得
				local stop_candidate = map(next_sta.tile_list, @(a) station.trace_way(a, wt_rail, next_sta.dir, @(b) b.get_halt() != null).top())
				if(stop_candidate.len() > 1)
				{
					// ホームを使用している路線数が最小のホームを選択
					local tbl_form_info = station.get_line_using_track(next_sta.halt, 2)
					local no_line_stop_list = filter(stop_candidate, @(a) !(is_member(a, map(tbl_form_info, @(b) b.stop))))
					if(no_line_stop_list.len() == 0)
					{
						tbl_form_info = filter(tbl_form_info, @(a) is_member(a.stop, stop_candidate))
						tbl_form_info = sort(tbl_form_info, @(a,b) a.line_list.len() <=> b.line_list.len())
						stop_candidate[0] = tbl_form_info[0].stop
					}else{
						stop_candidate = no_line_stop_list
					}
				}
				local tbl_temp =
				{
					stop = stop_candidate[0]
					halt = next_sta.halt
					dir = next_sta.dir
					info = next_sta_info
				}
				tbl_stop_info_list.append(tbl_temp)

				// 再帰処理
				local tbl_temp_stop_info_list = select_rail_outward_root(pl, tbl_stop_info_list, is_electrified)
				foreach(tbl_temp_stop_info in tbl_temp_stop_info_list)
				{
					rtn.append(tbl_temp_stop_info)
				}
				// 保持した路線情報に戻す
				tbl_stop_info_list = tbl_import_list
			}
		}
		
		return rtn
	}

	/***************************************
	 * 電化必要な鉄道路線か
	 * 引数：路線(line_x)
	 * 戻り値：電化必要(true)(boolean)
	 ***************************************/
	function need_electrified_line(line)
	{
		local rtn = false
		foreach(convoy in _step_generator(line.get_convoy_list()))
		{
			if(convoy.needs_electrification())
			{
				rtn = true
				break
			}
		}
		return rtn
	}

	/***************************************
	 * 鉄道路線と並行しているバス路線を縮小
	 * 引数：プレイヤー会社(player_x)
	 ***************************************/
	function merge_to_rail(pl)
	{
		// 都市間連絡バス路線取得
		local bus_line_list = filter(pl.get_line_list(), @(a) a.get_waytype() == wt_road)
		bus_line_list = filter(bus_line_list, @(a) a.get_name().slice(0, 1) == "(")
		foreach(bus_line in bus_line_list)
		{
			local schedule_entries = bus_line.get_schedule().entries
			local idx = 0
			// どこまで鉄道と並行しているか取得
			local station_bus_stop_list = []
			local initial_sta_rail_line_list = []
			while(idx <= schedule_entries.len() / 2)
			{
				local city = finder.find_nearest_city(finder.coord2D_to_tile(schedule_entries[idx]))
				// バスターミナルは必ずある。最悪都市間連絡バス停がそれになる
				local station_bus_stop =finder.get_bus_terminal(city, pl)
				local temp_list = filter(station_bus_stop.get_halt().get_line_list(), @(a) a.get_waytype() == wt_rail)
				if(temp_list.len() == 0)
				{
					idx--
					break
				}
				if(idx == 0){ initial_sta_rail_line_list = temp_list }
				local increment_flg = false
				foreach(temp in _step_generator(temp_list))
				{
					if(is_member(temp.get_name(), map(initial_sta_rail_line_list, @(a) a.get_name())))
					{
						station_bus_stop_list.append(station_bus_stop)
						increment_flg = true
						break
					}
				}
				if(increment_flg)
				{
					if(idx == schedule_entries.len() / 2)
					{
						break
					}else{
						idx++
						continue
					}
				}
				idx--
				break
			}

			if(idx > 0)
			{
				for(local ii = 0; ii <= idx; ii++)
				{
					// 市内交通の路線は鉄道駅始発に変更
					local city = finder.find_nearest_city(finder.coord2D_to_tile(schedule_entries[ii]))
					local halt_in_city_list = finder.check_busstop_in_city(city, pl, 0)
					// 既に変更済みの町は除外
					local sta = station_bus_stop_list[ii].get_halt()
					local no_change_halt_list = filter(halt_in_city_list, @(a) !(is_connected(a, sta, good_desc_x.passenger)))
					if(no_change_halt_list.len() == 0){ continue }
					
					local busstop_in_city_list = []
					// バス停の座標取得
					foreach(halt_in_city in _step_generator(halt_in_city_list))
					{
						local temp = finder.check_sta_freight_property(halt_in_city, wt_road, 2)
						if(temp.len() != 0){ busstop_in_city_list.append(temp[calc_idx(pl.nr, temp.len())]) }
					}

					local changed_line_num = 0
					// 始発バス停候補
					local init_busstop_list = busstop_in_city_list
					do
					{
						local city_bus_line_list = filter(pl.get_line_list(), @(a) a.get_waytype() == wt_road && a.get_name().find(city.get_name()) != null)
						city_bus_line_list = filter(city_bus_line_list, @(a) a.get_name().slice(city.get_name().len()+2, a.get_name().len()-1).tointeger() > changed_line_num)
						local new_line_list = set_line_for_citybus(city, init_busstop_list, station_bus_stop_list[ii], busstop_in_city_list, city_bus_line_list, pl)
						if(new_line_list.len() == set_max_city_bus_line && city_bus_line_list.len() > set_max_city_bus_line)
						{
							changed_line_num += set_max_city_bus_line
						}else{
							break
						}
						init_busstop_list = filter(init_busstop_list, @(a) !(is_connected(a.get_halt(), sta, good_desc_x.passenger)))
					}while(init_busstop_list.len() > 0)
					// 路線の改正したら従来のバスターミナルを通る路線が消失した場合、
					// 従来のバスターミナルと鉄道駅を結ぶ路線作成
					/*if(schedule_entries[ii].get_halt(pl).get_line_list().get_count() == 0)
					{
						local array_bus_stop = [station_bus_stop_list[ii], schedule_entries[ii]]
						local line = set_line(array_bus_stop, null, pl)
						// 路線名設定
						local kk = 1
						local cityname = city.get_name()
						while(is_member(cityname+" ("+kk+")", map(pl.get_line_list(), @(a) a.get_name()))){ kk++ }
						line.set_name(cityname+" ("+kk+")")
					}*/
				}

				if(idx == schedule_entries.len() / 2)
				{
					// 都市間連絡バス路線に鉄道が完全並行してるので、バス廃止
					local convoy_list = bus_line.get_convoy_list()
					foreach(convoy in _step_generator(convoy_list))
					{
						convoy.toggle_withdraw(pl)
					}
					while(1)
					{
						if(bus_line.get_convoy_list().get_count() == 0){ break }
					}
					bus_line.destroy(pl)
					continue
				}else{
					// 都市間連絡バス路線の鉄道並行区間を縮小
					schedule_entries = schedule_entries.slice(idx, schedule_entries.len() - idx)
					
					// 都市間連絡バス路線の始発バス停を鉄道駅に移設
					if(!(compare_coord(station_bus_stop_list.top(), schedule_entries[0])))
					{
						schedule_entries.remove(0)
						schedule_entries.insert(0, schedule_entry_x(station_bus_stop_list.top(), 0, 0))
					}
				}
				local schedule = schedule_x(bus_line.get_waytype(), schedule_entries)
				bus_line.change_schedule(pl, schedule)
				if(idx == schedule_entries.len() / 2)
				{
					// 都市間連絡系統じゃなくなったので路線名変更
					local city = finder.find_nearest_city(finder.coord2D_to_tile(schedule_entries[idx]))
					local cityname = city.get_name()
					local ii = 1
					while(is_member(cityname+" ("+ii+")", map(pl.get_line_list(), @(a) a.get_name()))){ ii++ }
					bus_line.set_name(cityname+" ("+ii+")")
				}
			}
		}
	}

	/***************************************
	 * 2つの駅を結ぶ乗り物があるかチェック
	 * 引数：駅1(halt_x)、駅2(halt_x)、貨物詳細情報(good_desc_x)
	 * 戻り値：結んでる(true)(boolean)
	 * 備考：halt_x.is_connected()が正しく動作しないので自作
	 ***************************************/
	function is_connected(haltA, haltB, good_desc)
	{
		if(finder.is_same_halt(haltA, haltB)){ return true }
		local connected_list = haltA.get_connections(good_desc)
		return is_member(true, map(connected_list, @(a) finder.is_same_halt(haltB, a)))
	}

	/***************************************
	 * デッドロック対応
	 * 引数：プレイヤー会社(player_x)
	 * 備考：
	 ***************************************/
	function solute_dead_lock(pl)
	{
		// デッドロックしている車両探索
		local dl_convoy_list = filter(world.get_convoy_list(), @(a) a.get_owner().nr == pl.nr)
		dl_convoy_list = filter(dl_convoy_list, @(a) a.get_distance_traveled_total() > 1 && a.get_traveled_distance().len() > 1 && a.get_traveled_distance()[0] == 0 && a.get_traveled_distance()[1] == 0)
		// dl_convoy_list = filter(dl_convoy_list, @(a) !(a.is_loading) && !(a.is_waiting)) // デッドロックしてる車両は常にis_loading=is_waiting=trueなので意味なし
		local line_list = []
		foreach(convoy in dl_convoy_list)
		{
			local temp_line = convoy.get_line()
			if(!(is_member(temp_line.get_name(), map(line_list, @(a) a.get_name())))){ line_list.append(temp_line) }
		}

		local road_info = road_manager_t()
		local rail_info = rail_manager_t()
		foreach(line in line_list)
		{
			switch(line.get_waytype())
			{
				case wt_road:
				local schedule_entries = line.get_schedule().entries
				local depot_pos = road_info.search_bus_depot(schedule_entries[0], pl)
				local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
				update_convoy_in_line(line, depot, wt_road, pl, true)
				break
				
				case wt_rail:
				local schedule_entries = line.get_schedule().entries
				local station = station_manager_t()
				foreach(schedule in schedule_entries)
				{
					local tile_list = station.get_track_list(schedule)
					local tool = command_x(tool_clear_reservation)
					foreach(tile in tile_list)
					{
						tool.work(pl, tile)
					}
				}
				break
			}
		}
	}


	function step()
	{
		local pl = player_x(our_player)

		c_wt = p_convoy.veh[0].get_waytype()

		switch(phase) {
			case 0: // create the convoy (and the first vehicles)
				{
					p_depot.append_vehicle(pl, convoy_x(0), p_convoy.veh[0])

					// find the newly created convoy
					// it should be the last in the list
					local cnv_list = p_depot.get_convoy_list()

					local trythis = cnv_list[cnv_list.len()-1]
					if (check_convoy(trythis)) {
						c_cnv = trythis
					}

					if (c_cnv == null) {
						foreach(cnv in cnv_list) {
							if (check_convoy(cnv)) {
								c_cnv = cnv
								break
							}
						}
					}
					phase ++
				}
			case 1: // complete the convoy
				{
					local vlist = c_cnv.get_vehicles()
					while (vlist.len() < p_convoy.veh.len())
					{
						p_depot.append_vehicle(pl, c_cnv, p_convoy.veh[ vlist.len() ])
						vlist = c_cnv.get_vehicles()
					}

					phase ++
				}
			case 2: // set line
				{
					c_cnv.set_line(pl, p_line)
					phase ++
				}
			case 3: // withdraw old vehicles
				{
					if (p_withdraw) {
						local cnv_list = p_line.get_convoy_list()
						foreach(o_cnv in cnv_list) {
							if (o_cnv.id != c_cnv.id  &&  !o_cnv.is_withdrawn()) {
								o_cnv.toggle_withdraw(pl)
							}
						}
						p_withdraw = false
					}
					phase ++
				}
			case 4: // start
				{
					p_depot.start_convoy(pl, c_cnv)

					p_count --
					if (p_count > 0) {
						phase = 0
						return r_t(RT_PARTIAL_SUCCESS)
					}
					else {
						phase ++
					}
				}
		}
		return r_t(RT_TOTAL_SUCCESS)
	}

	function check_convoy(cnv)
	{
		// check whether this convoy is for our purpose
		if (cnv.get_line() == null  &&  cnv.get_waytype() == c_wt) {
			// now test for equal vehicles
			local vlist = cnv.get_vehicles()
			local len = vlist.len()
			if (len <= p_convoy.veh.len()) {
				local equal = true;

				for (local i=0; equal  &&  i<len; i++) {
					equal = vlist[i].is_equal(p_convoy.veh[i])
				}
				if (equal) {
					return true
				}
			}
		}
		return false
	}
}
