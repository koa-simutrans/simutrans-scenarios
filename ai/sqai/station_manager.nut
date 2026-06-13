class freight_station_t
{
	factory  = null // factory_x
	road_depot  = null // tile_x
	road_unload = null // tile_x
	ship_depot  = null // tile_x
	rail_depot  = null // tile_x
	rail_unload = null // tile_x

	constructor(f)
	{
		factory = f
	}

	function _save()
	{
		return ::saveinstance("freight_station_t", this)
	}
}



class freight_station_manager_t extends node_t
{
	freight_station_list = null

	constructor()
	{
		base.constructor("freight_station_manager_t")
		freight_station_list = {}
		::station_manager = this
	}

	/// Generate unique key from link data
	static function key(factory)
	{
		return (factory.get_name() + coord_to_string(factory)).toalnum()
	}

	/**
	 * Access freight_station_t data, create node if not existent.
	 */
	function access_freight_station(factory)
	{
		local k = key(factory)
		local res
		try {
			res = freight_station_list[k]
		}
		catch(ev) {
			local fs = freight_station_t(factory)
			freight_station_list[k] <- fs
			res = fs
		}
		return res
	}
}

class station_manager_t extends node_t
{
	// 駅舎の向き(バージョンごとに変わる)
	SO_NORTH = 4
	SO_EAST = 3
	SO_SOUTH = 2
	SO_WEST = 1

	constructor() 
	{
		base.constructor("station_manager_t")
	}

	/***************************************
	 * 低規格の線路アドオン選択
	 * 引数：
	 * 戻り値：線路アドオン(way_desc_x)
	 ***************************************/
	function select_low_cost_rail()
	{
		local way_desc_list = way_desc_x.get_available_ways(wt_rail, st_flat)
		way_desc_list = filter(way_desc_list, @(a) a.get_topspeed() >= 30)
		way_desc_list = sort(way_desc_list, @(a,b) a.get_cost() <=> b.get_cost())
		return way_desc_list.len() == 0 ? null : way_desc_list[0]
	}

	/***************************************
	 * 旅客用ホームアドオン選択
	 * 引数：プレイヤー属性(player_x)、地上のみ(true)地下のみ(false)(boolean)
	 * 戻り値：ホームアドオン(building_desc_x)
	 ***************************************/
	function select_form(pl, only_ground)
	{
		local form_desc_list = building_desc_x.get_available_stations(building_desc_x.station, wt_rail, good_desc_x.passenger)
		if(only_ground)
		{
			form_desc_list = filter(form_desc_list, @(a) a.can_be_built_aboveground())
		}else{
			form_desc_list = filter(form_desc_list, @(a) a.can_be_built_underground())
		}
		if(form_desc_list.len() == 0){ return null }
		if(form_desc_list.len() == 1){ return form_desc_list[0] }
		// 建設費の降順でソート
		form_desc_list = sort(form_desc_list, @(a,b) b.get_cost() <=> a.get_cost())
		// 月粗利益取得
		local profit = pl.get_profit()
		// 収入に応じてホームのグレードが上がる
		for(local ii=1; ii<form_desc_list.len(); ii++)
		{
			if( profit[0] >= 100000 / (form_desc_list.len() - 1) * (form_desc_list.len() - ii))
			{
				return form_desc_list[ii-1]
			}
		}
		return form_desc_list.top()
	}

	/***************************************
	 * 隣接タイルが自社駅か調査
	 * 引数：プレイヤー属性(player_x)、タイル(tile_x)
	 * 戻り値：自社駅かどうか(boolean)
	 ***************************************/
	 function is_station_neighbor(pl, tile)
	 {
	 	// 隣接タイル取得
	 	local neighbor_tile_list = finder.base_to_tile_list(tile, 3, 3, 0)
	 	neighbor_tile_list = filter(neighbor_tile_list, @(a) !(compare_coord(a, tile)))
	 	// 駅があるか調査
	 	neighbor_tile_list = filter(neighbor_tile_list, @(a) a.get_halt() != null)
	 	neighbor_tile_list = filter(neighbor_tile_list, @(a) a.get_halt().get_owner() == pl.nr)
	 	if(neighbor_tile_list.len() != 0){ return true }
	 	return false
	 }

	/***************************************
	 * 旅客用ホーム新規建設
	 * 引数：プレイヤー属性(player_x)、建設座標リスト(tile_xのリスト)、地上のみ(true)地下のみ(false)(boolean)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	 function build_form(pl, tile_list, only_ground)
	 {
	 	// 既に駅が建っている場合、処理終了
	 	tile_list = filter(tile_list, @(a) a.has_way(wt_rail))
	 	if(tile_list.len() == 0){ return "no rail" }
	 	local temp_list = filter(tile_list, @(a) a.find_object(mo_building) != null)
	 	if(temp_list.len() != 0)
	 	{
		 	temp_list = filter(temp_list, @(a) a.find_object(mo_building) != null)
		 	temp_list = filter(temp_list, @(a) a.find_object(mo_building).get_desc().get_type() != building_desc_x.station)
		 	if(tile_list.len() == 0){ return "already build other station" }
	 	}
	 	// ホーム選択
	 	local form_desc = select_form(pl, only_ground)
	 	// 隣接タイルに既存駅がある場合、隣接しているタイルから建設
	 	while(tile_list.len() != 0)
	 	{
	 		local neighbor_halt_tile = filter(tile_list, @(a) is_station_neighbor(pl, a))
	 		if(neighbor_halt_tile.len() == 0)
	 		{
	 			local err = command_x.build_station(pl, tile_list.top(), form_desc)
	 			if(err != null){ return err }
	 			tile_list.pop()
	 		}else{
	 			// TODO : 対向線路のform_descを選択するようにしたい
	 			
	 			local err = command_x.build_station(pl, neighbor_halt_tile.top(), form_desc)
	 			if(err != null){ return err }
	 			tile_list = filter(tile_list, @(a) !(compare_coord(a, neighbor_halt_tile.top())))
	 		}
	 	}
	 	return null
	 }

	/***************************************
	 * 駅舎アドオン選択
	 * 引数：プレイヤー属性(player_x)
	 * 戻り値：駅舎アドオン(building_desc_x)
	 ***************************************/
	function select_station_office(pl)
	{
		local form_desc_list = building_desc_x.get_available_stations(building_desc_x.station_extension, wt_all, good_desc_x.passenger)
		if(form_desc_list.len() == 0){ return null }
		if(form_desc_list.len() == 1){ return form_desc_list[0] }
		form_desc_list = filter(form_desc_list, @(a) a.enables_pax())
		// 建設費の降順でソート
		form_desc_list = sort(form_desc_list, @(a,b) b.get_cost() <=> a.get_cost())
		// 月粗利益取得
		local profit = pl.get_profit()
		// 収入に応じて駅舎のグレードが上がる
		for(local ii=1; ii<form_desc_list.len(); ii++)
		{
			if( profit[0] >= 100000 / (form_desc_list.len() - 1) * ii)
			{
				return form_desc_list[ii-1]
			}
		}
		form_desc_list = filter(form_desc_list, @(a) a.get_cost() == form_desc_list.top().get_cost())
		// 同スコアのアドオンがあれば、活動月に応じてアドオンを変える
		local idx = get_idx_by_month(form_desc_list.len())
		return form_desc_list[idx]
	}

	/***************************************
	 * 駅舎設置
	 * 引数：プレイヤー属性(player_x)、ホームのタイル(tile_x)、駅舎アドオン(building_desc_x)
	 * 戻り値：エラーメッセージ
	 * 備考：引数は駅の中心タイルが望ましい
	 * 駅舎アドオンがnullの場合、select_station_office関数で自動選択する
	 ***************************************/
	function build_station_office(pl, tile, station_office_desc)
	{
		// 線路の向き取得
		if(!(tile.has_way(wt_rail))){ return }
		local d = tile.get_way_dirs(wt_rail)
		// 駅舎選択
		if(station_office_desc == null){ station_office_desc = select_station_office(pl) }
		local size = station_office_desc.get_size(0)

		local station_office_dir = dir.none
		local station_office_tile = null
		// 駅周辺座標取得
		local halt = tile.get_halt()
		local around_tile_list = finder.bldg_neighbor_tile_list(halt.get_tile_list())
		// ホームから2マス離れた座標取得
		local around_second_tile_list = finder.bldg_neighbor_tile_list(around_tile_list)
		// ホームから2マス離れた座標に既存バス停がある場合、ホームとバス停双方に隣接する座標に駅舎を建設
		local already_busstop_tile_list = filter(around_second_tile_list, @(a) a.has_way(wt_road) && a.get_halt() != null && is_member(a.get_halt().get_owner().nr, [1, pl.nr]))
		local merge_busstop_tile = []
		if(already_busstop_tile_list.len() != 0)
		{
			local around_busstop_tile_list = finder.bldg_neighbor_tile_list(already_busstop_tile_list)
			local candidate_station_office_tile_list = finder.check_covered_area(around_tile_list, around_busstop_tile_list)
			if(candidate_station_office_tile_list.len() != 0)
			{
				station_office_tile = candidate_station_office_tile_list[0]
				local temp_size = size
				local temp_dir = dir.west
				if(d == dir.north || d == dir.south || d == dir.northsouth)
				{
					temp_size = coord(size.y, size.x)
					temp_dir = dir.north
				}
				local temp_list = search_station_office_tile(candidate_station_office_tile_list, temp_size, temp_dir)
				if(temp_list.len() != 0)
				{
					//駅舎候補タイルのうち、ホームに最も近いタイルを選択
					temp_list = sort(temp_list, @(a,b) abs(a.x-tile.x)+abs(a.y-tile.y) <=> abs(b.x-tile.x)+abs(b.y-tile.y))
					station_office_tile = temp_list[0]
					if(d == dir.north || d == dir.south || d == dir.northsouth)
					{
						if(tile.x < station_office_tile.x)
						{
							station_office_dir = SO_WEST
						}else{
							station_office_dir = SO_EAST
						}
					}
					if(d == dir.west || d == dir.east || d == dir.eastwest)
					{
						if(tile.y < station_office_tile.y)
						{
							station_office_dir = SO_NORTH
						}else{
							station_office_dir = SO_SOUTH
						}
					}
				}
				merge_busstop_tile = finder.bldg_neighbor_tile_list([station_office_tile])
				merge_busstop_tile = filter(merge_busstop_tile, @(a) a.has_way(wt_road) && a.get_halt() != null && is_member(a.get_halt().get_owner().nr, [1, pl.nr]))
			}
		}

		if(station_office_tile == null)
		{
			// 駅から見た近くの町の方向と線路の向きから駅舎を配置する向き設定
			local city = finder.find_nearest_city(tile)
			if(d == dir.north || d == dir.south || d == dir.northsouth)
			{
				if(tile.x - city.get_pos().x >= 0)
				{
					station_office_dir = SO_EAST
					// 駅に隣接し、ホームと隣り合うタイルが最も多いエリアを検索
					around_tile_list = filter(around_tile_list, @(a) a.x < tile.x)
					local base_tile_list = map(around_tile_list, @(a) finder.coord2D_to_tile(finder.move_coord(a, dir.west, size.y-1)))
					base_tile_list = filter(base_tile_list, @(a) a != null)
					local hit_tile_list = search_station_office_tile(base_tile_list, coord(size.y, size.x), dir.north)
					if(hit_tile_list.len() != 0)
					{
						//駅舎候補タイルのうち、ホームに最も近いタイルを選択
						hit_tile_list = sort(hit_tile_list, @(a,b) abs(a.x-tile.x)+abs(a.y-tile.y) <=> abs(b.x-tile.x)+abs(b.y-tile.y))
						station_office_tile = hit_tile_list[0]
					}else{
						// 従来の処理(駅が大きいとうまく処理できない)
						station_office_tile = finder.coord2D_to_tile(finder.move_coord(tile, dir.north))
						if(station_office_tile == null)
						{
							station_office_dir = SO_WEST
							station_office_tile = finder.coord2D_to_tile(finder.move_coord(tile, dir.south))
						}
					}
				}else{
					station_office_dir = SO_WEST
					// 駅に隣接し、ホームと隣り合うタイルが最も多いエリアを検索
					around_tile_list = filter(around_tile_list, @(a) a.x > tile.x)
					local hit_tile_list = search_station_office_tile(around_tile_list, coord(size.y, size.x), dir.north)
					if(hit_tile_list.len() != 0)
					{
						//駅舎候補タイルのうち、ホームに最も近いタイルを選択
						hit_tile_list = sort(hit_tile_list, @(a,b) abs(a.x-tile.x)+abs(a.y-tile.y) <=> abs(b.x-tile.x)+abs(b.y-tile.y))
						station_office_tile = hit_tile_list[0]
					}else{
						// 従来の処理(駅が大きいとうまく処理できない)
						station_office_tile = finder.coord2D_to_tile(finder.move_coord(tile, dir.south))
						if(station_office_tile == null)
						{
							station_office_dir = SO_EAST
							finder.coord2D_to_tile(finder.move_coord(tile, dir.north))
						}
					}
				}
			}
			if(d == dir.west || d == dir.east || d == dir.eastwest)
			{
				if(tile.y - city.get_pos().y >= 0)
				{
					station_office_dir = SO_SOUTH
					// 駅に隣接し、ホームと隣り合うタイルが最も多いエリアを検索
					around_tile_list = filter(around_tile_list, @(a) a.y < tile.y)
					local base_tile_list = map(around_tile_list, @(a) finder.coord2D_to_tile(finder.move_coord(a, dir.north, size.x-1)))
					base_tile_list = filter(base_tile_list, @(a) a != null)
					local hit_tile_list = search_station_office_tile(base_tile_list, size, dir.west)
					if(hit_tile_list.len() != 0)
					{
						//駅舎候補タイルのうち、ホームに最も近いタイルを選択
						hit_tile_list = sort(hit_tile_list, @(a,b) abs(a.x-tile.x)+abs(a.y-tile.y) <=> abs(b.x-tile.x)+abs(b.y-tile.y))
						station_office_tile = hit_tile_list[0]
					}else{
						// 従来の処理(駅が大きいとうまく処理できない)
						station_office_tile = finder.coord2D_to_tile(finder.move_coord(tile, dir.west))
						if(station_office_tile == null)
						{
							station_office_dir = SO_NORTH
							finder.coord2D_to_tile(finder.move_coord(tile, dir.east))
						}
					}
				}else{
					station_office_dir = SO_NORTH
					// 駅に隣接しホームと、隣り合うタイルが最も多いエリアを検索
					around_tile_list = filter(around_tile_list, @(a) a.y > tile.y)
					local hit_tile_list = search_station_office_tile(around_tile_list, size, dir.west)
					if(hit_tile_list.len() != 0)
					{
						//駅舎候補タイルのうち、ホームに最も近いタイルを選択
						hit_tile_list = sort(hit_tile_list, @(a,b) abs(a.x-tile.x)+abs(a.y-tile.y) <=> abs(b.x-tile.x)+abs(b.y-tile.y))
						station_office_tile = hit_tile_list[0]
					}else{
						// 従来の処理(駅が大きいとうまく処理できない)
						station_office_tile = finder.coord2D_to_tile(finder.move_coord(tile, dir.east))
						if(station_office_tile == null)
						{
							station_office_dir = SO_SOUTH
							finder.coord2D_to_tile(finder.move_coord(tile, dir.west))
						}
					}
				}
			}
		}
		if(station_office_dir == dir.none){ return }
		// 建設予定地内の市内建築は撤去
		local station_office_area = []
		if(is_member(station_office_dir, [SO_WEST, SO_EAST]))
		{
			station_office_area = finder.base_to_tile_list(station_office_tile, size.x, size.y, 1)
		}else{
			station_office_area = finder.base_to_tile_list(station_office_tile, size.y, size.x, 1)
		}
		local bulldoze_area = filter(station_office_area, @(a) a.find_object(mo_building))
		map(bulldoze_area, @(a) a.remove_object(pl, mo_building))
		
		// 駅舎建設
		local err = command_x.build_station(pl, station_office_tile, station_office_desc, station_office_dir)
		if(err != null){ 
gui.add_message_at(pl,"build_station_office:["+coord_to_string(station_office_tile)+"],"+station_office_desc.get_name()+",dir:"+station_office_dir,station_office_tile)
return err }
		// 駅舎の向きに合わせてホームの向き変更
		if(station_office_dir == SO_WEST || station_office_dir == SO_NORTH)
		{
			// TODO : ホームが複数タイルに存在する時
			local tool = command_x(tool_rotate_building)
			tool.work(pl, tile)
		}
		if(merge_busstop_tile.len() != 0)
		{
			local cmd = command_x(tool_merge_stop)
			foreach(merge_busstop in _step_generator(merge_busstop_tile))
			{
				cmd.work(pl, station_office_tile, merge_busstop, "")
			}
		}
	}

	/***************************************
	 * 駅前バス停設置
	 * 引数：プレイヤー属性(player_x)、駅(halt_x)
	 ***************************************/
	function build_station_bus_stop(pl, halt)
	{
		if(finder.check_sta_freight_property(halt, wt_road, 2).len() != 0){ return }
		// 駅舎検出(多くとも1軒しかないものとする)
		local sta_tile_list = halt.get_tile_list()
		local sta_office_tile_list = filter(sta_tile_list, @(a) !(a.has_ways()))
		sta_office_tile_list = filter(sta_office_tile_list, @(a) a.find_object(mo_building).get_desc().enables_pax())
		local bus_stop_tile = null
		if(sta_office_tile_list.len() != 0)
		{
			// 駅舎の隣接タイル取得
			local neighbor_tile_list = finder.bldg_neighbor_tile_list(sta_office_tile_list)
			// 駅舎の隣接タイルに既にバス停がある場合、駅を統合
			local already_busstop_tile_list = filter(neighbor_tile_list, @(a) a.has_way(wt_road) && a.get_halt() != null)
			if(already_busstop_tile_list.len() != 0)
			{
				local cmd = command_x(tool_merge_stop)
				foreach(already_busstop_tile in _step_generator(already_busstop_tile_list))
				{
					cmd.work(pl, sta_office_tile_list[0], already_busstop_tile, "")
				}
				return
			}
			// 線路のタイル取得
			local rail_tile_list = filter(neighbor_tile_list, @(a) a.has_way(wt_rail) && a.get_halt() != null)
			// 線路の方角取得
			local d_list = map(rail_tile_list, @(a) coord(a.x-sta_office_tile_list[0].x, a.y-sta_office_tile_list[0].y).to_dir())
			// バス停設置の方角取得
			d_list = map(d_list, @(a) dir.backward(a))
			// 駅舎の正面が配列最初に来るようにソート
			d_list = sort(d_list, @(a,b) a <=> b)
			// バス停設置タイルの選定
			local bus_stop_tile_list = []
			foreach(sta_office_tile in _step_generator(sta_office_tile_list))
			{
				local temp_list = map(d_list, @(a) finder.coord2D_to_tile(coord(sta_office_tile.x, sta_office_tile.y) + dir.to_coord(a)))
				foreach(temp in temp_list)
				{
					if(!(is_member(temp, bus_stop_tile_list))){ bus_stop_tile_list.append(temp) }
				}
			}
			bus_stop_tile_list = filter(bus_stop_tile_list, @(a) a.get_slope() == 0)
			if(bus_stop_tile_list.len() != 0)
			{
				foreach(tile in _step_generator(bus_stop_tile_list))
				{
					if(tile.is_empty())
					{
						// 頭上に他社の高架線がある場合は候補から除外
						for(local ii = 1; ii < 3; ii++)
						{
							local tile_z_plus = tile_x(tile.x, tile.y, tile.z + ii)
							local temp_way = tile_z_plus.get_way(wt_all)
							if(temp_way != null)
							{
								if(temp_way.get_owner().nr != pl.nr){ continue }
							}
						}
						bus_stop_tile = tile
						break
					}
					if(tile.has_way(wt_road))
					{
						if(!(dir.is_straight(tile.get_way_dirs(wt_road)))){ continue }
						local road = tile.get_way(wt_road)
						if(!(is_member(road.get_owner().nr, [pl.nr, city_player_nr, 1]))){ continue }
						bus_stop_tile = tile
						break
					}
				}
			}
		}
		if(bus_stop_tile == null)
		{
			// 駅の隣接タイル取得
			local neighbor_tile_list = finder.bldg_neighbor_tile_list(sta_tile_list)
			neighbor_tile_list = filter(neighbor_tile_list, @(a) a.get_slope() == 0)
			if(neighbor_tile_list.len() != 0)
			{
				// 町に近い順にソート
				local city = finder.find_nearest_city(neighbor_tile_list[0])
				neighbor_tile_list = sort(neighbor_tile_list, @(a,b) abs(a.x-city.get_pos().x)+abs(a.y-city.get_pos().y) <=> abs(b.x-city.get_pos().x)+abs(b.y-city.get_pos().y))
				foreach(tile in _step_generator(neighbor_tile_list))
				{
					if(tile.is_empty())
					{
						// 頭上に他社の高架線がある場合は候補から除外
						for(local ii = 1; ii < 3; ii++)
						{
							local tile_z_plus = tile_x(tile.x, tile.y, tile.z + ii)
							local temp_way = tile_z_plus.get_way(wt_all)
							if(temp_way != null)
							{
								if(temp_way.get_owner().nr != pl.nr){ continue }
							}
						}
						bus_stop_tile = tile
						break
					}
					if(tile.has_way(wt_road))
					{
						if(!(dir.is_straight(tile.get_way_dirs(wt_road)))){ continue }
						local road = tile.get_way(wt_road)
						if(!(is_member(road.get_owner().nr, [pl.nr, city_player_nr, 1]))){ continue }
						bus_stop_tile = tile
						break
					}
				}
			}
		}
		// 対象タイルに道がなければ、道建設
		local road_info = road_manager_t()
		if(!(bus_stop_tile.has_way(wt_road)))
		{
			// 近くの道路を検索
			local nearest_road = []
			local counter = 6
			while(nearest_road.len() == 0)
			{
				nearest_road = finder.find_target_places(bus_stop_tile, 1, 1, counter-5, counter, @(a) a.has_way(wt_road) && a.get_halt() == null)
				if(nearest_road == null){ return }
				counter = counter + 5
			}
			// 近い順にソート
			nearest_road = sort(nearest_road, @(a,b) abs(a.x-bus_stop_tile.x)+abs(a.y-bus_stop_tile.y) <=> abs(b.x-bus_stop_tile.x)+abs(b.y-bus_stop_tile.y))
			// 建設
			local as = astar_builder()
			as.builder = way_planner_x(pl)
			local way = road_info.select_road(our_player, null)
			if(way == null)
			{
				gui.add_message_at(pl, "No road addon.", world.get_time())
				return
			}
			as.way = way
			as.builder.set_build_types(way)
			as.bridger = pontifex(pl, way)
			if (as.bridger.bridge == null) {
				as.bridger = null
			}
			local rtn = as.search_route([bus_stop_tile], [nearest_road[0]])
			if("err" in rtn)
			{
				gui.add_message_at(pl, "Failed to build road from "+ coord_to_string(bus_stop_tile) +" to "+coord_to_string(nearest_road[0])+".", bus_stop_tile)
				return
			}
		}
		// バス停建設
		local err = road_info.build_bus_stop(pl, bus_stop_tile)
		if(err)
		{
			gui.add_message_at(pl, "failed build busstop at "+ coord_to_string(bus_stop_tile), bus_stop_tile)
		}
	}

	/***************************************
	 * 駅の新規建設
	 * 引数：プレイヤー属性(player_x)、駅建設の線路の座標リスト(tile_xのリスト)、地上のみ(true)地下のみ(false)(boolean)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function build_new_station(pl, rail_tile_list, only_ground)
	{
		// ホーム建設
		local err = build_form(pl, rail_tile_list, only_ground)
		if(err != null){ return err }
		// 駅舎建設
		local central_tile = finder.get_center(rail_tile_list)
		err = build_station_office(pl, finder.coord2D_to_tile(central_tile), null)
		if(err != null){ gui.add_message_at(pl, "failed build station office: "+err, central_tile) }
		// 駅前バス停建設
		local halt = rail_tile_list[0].get_halt()
		build_station_bus_stop(pl, halt)
	}

	/***************************************
	 * 駅のグレードアップ
	 * 引数：プレイヤー属性(player_x)、駅(halt_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function update_station(pl, halt)
	{
		local rtn = null
		local station_list = building_desc_x.get_available_stations(building_desc_x.station, wt_rail, good_desc_x.passenger)
		local form_tile_list = finder.check_sta_freight_property(halt, wt_rail, 2)
		// プラットホームの中で最も定員が少ないホームを使っているタイルを取得
		local tbl_form_desc_info_list = []
		foreach(tile in _step_generator(form_tile_list))
		{
			local sta_desc = tile.find_object(mo_building).get_desc()
			local tbl_temp =
			{
				tile = tile
				sta_desc = sta_desc
			}
			tbl_form_desc_info_list.append(tbl_temp)
		}
		// 最も定員が少ないホームをアップデート
		tbl_form_desc_info_list = sort(tbl_form_desc_info_list, @(a,b) a.sta_desc.get_capacity() <=> b.sta_desc.get_capacity())
		station_list = filter(station_list, @(a) a.get_capacity() > tbl_form_desc_info_list[0].sta_desc.get_capacity())
		station_list = filter(station_list, @(a) a.get_cost() < pl.get_current_net_wealth())
		if(tbl_form_desc_info_list[0].sta_desc.can_be_built_underground())
		{
			station_list = filter(station_list, @(a) a.can_be_built_underground())
		}else{
			station_list = filter(station_list, @(a) a.can_be_built_aboveground())
		}
		if(station_list.len() > 0)
		{
			// 建設費の安い順にソート
			station_list = sort(station_list, @(a,b) a.get_cost() <=> b.get_cost())
			// pak64のバグ対策(r10811で対応予定)
			station_list = filter(station_list, @(a) a.get_name() != "GCG1TrainStop" && a.get_name()!= "GCG2TrainStop")
			// 同スコアのアドオンがあれば、活動月に応じてアドオンを変える
			station_list = filter(station_list, @(a) a.get_cost() == station_list[0].get_cost())
			local idx = get_idx_by_month(station_list.len())
			rtn = command_x.build_station(pl, tbl_form_desc_info_list[0].tile, station_list[idx])
			return rtn
		}
		// プラットホームがアップデート出来ないなら駅舎をアップデート
		local sta_office_tile_list = filter(halt.get_tile_list(), @(a) !(a.has_ways()))
		if(sta_office_tile_list.len() == 0){ return }
		local tbl_sta_office_desc_info_list = []
		foreach(tile in _step_generator(sta_office_tile_list))
		{
			local sta_desc = tile.find_object(mo_building).get_desc()
			if(is_member(true, map(tbl_sta_office_desc_info_list, @(a) sta_desc.is_equal(a.sta_desc)))){ continue }
			local tbl_temp =
			{
				tile = tile
				sta_desc = sta_desc
			}
			tbl_sta_office_desc_info_list.append(tbl_temp)
		}
		// 最も定員が少ない駅舎をアップデート
		tbl_sta_office_desc_info_list = sort(tbl_sta_office_desc_info_list, @(a,b) a.sta_desc.get_capacity() <=> b.sta_desc.get_capacity())
		local sta_office_list = building_desc_x.get_available_stations(building_desc_x.station_extension, wt_rail, good_desc_x.passenger)
		sta_office_list = filter(sta_office_list, @(a) a.get_capacity() > tbl_sta_office_desc_info_list[0].sta_desc.get_capacity())
		sta_office_list = filter(sta_office_list, @(a) a.get_cost() < pl.get_current_net_wealth())
		if(sta_office_list.len() > 0)
		{
			// 建設費の安い順にソート
			sta_office_list = sort(sta_office_list, @(a,b) a.get_cost() <=> b.get_cost())
			// 同スコアのアドオンがあれば、活動月に応じてアドオンを変える
			local idx = get_idx_by_month(sta_office_list.len())
			// 新駅舎のタイルサイズが既存駅舎と異なる場合、建設用地を探索
			local next_office_tile_list = [tbl_sta_office_desc_info_list[0].tile]
			local current_office_size = tbl_sta_office_desc_info_list[0].sta_desc.get_size(0)
			local next_office_size = sta_office_list[idx].get_size(0)
			if(current_office_size.x < next_office_size.x || current_office_size.y < next_office_size.y)
			{
				local current_office_tile_list = tbl_sta_office_desc_info_list[0].tile.find_object(mo_building).get_tile_list()
				local crrt_office_tile_list_x = map(current_office_tile_list, @(a) a.x)
				crrt_office_tile_list_x = sort(crrt_office_tile_list_x, @(a,b) a <=> b)
				local x = crrt_office_tile_list_x.top() - crrt_office_tile_list_x[0] + 1
				local new_x = next_office_size.x
				local new_y = next_office_size.y
				local dd = dir.west
				local dy = abs(next_office_size.y - current_office_size.y)
				if(current_office_size.x != x)
				{
					// 既存駅舎はrotation=1or3の向きで建設されている
					new_x = next_office_size.y
					new_y = next_office_size.x
					dd = dir.north
					dy = abs(next_office_size.x - current_office_size.x)
				}
				// 新駅舎設置タイル探索(市内建築を撤去する場合、旅客レベルが最も低いタイルを選択する)
				local c_target = finder.move_coord(tbl_sta_office_desc_info_list[0].tile, dd)
				local target = finder.coord2D_to_tile(c_target)
				if(target.has_way(wt_rail))
				{
					c_target = tbl_sta_office_desc_info_list[0].tile
				}else{
					c_target = finder.move_coord(tbl_sta_office_desc_info_list[0].tile, dd, dy)
				}
				local candidate_target = search_station_office_tile([c_target], coord(new_x, new_y), dd)
				if(candidate_target.len() == 0){ return "missing updating station." }
				local candidate_target_area = finder.base_to_tile_list(candidate_target, new_x, new_y, 1)
				candidate_target_area = filter(candidate_target_area, @(a) !(is_member(a, next_office_tile_list)))
				next_office_tile_list = combine(next_office_tile_list, candidate_target_area)
			}

			// 既存駅舎と新駅舎用地の建物を撤去
			local cmd = command_x(tool_remover)
			foreach(next_office_tile in next_office_tile_list){ cmd.work(pl, next_office_tile) }
			
			rtn = build_station_office(pl, finder.coord2D_to_tile(finder.get_center(form_tile_list)), sta_office_list[idx])
		}
		return rtn
	}

	/***************************************
	 * 駅舎建設地の探索
	 * 候補地のリスト(1x1のリスト)から既存建物の撤去を少なくする場所(建設する駅舎のサイズのタイルリスト)を探索する
	 * 引数：候補地(tile_xのリスト)、駅舎のサイズ(Coord)、探索方向(dir)
	 * 戻り値：最適なタイルのリスト(tile_xのリスト)
	 * 備考：探索方向はwestかnorthのみ
	 *       候補地は駅舎建設予定地の左上のタイルを設定する
	 ***************************************/
	function search_station_office_tile(candidate_tile_list, size, d)
	{
		local tbl_list = []
		local max_cnt = size.x
		if(d == dir.north){ max_cnt = size.y }
		local already_checked_tile_list = []
		foreach(tile in candidate_tile_list)
		{
			// 候補地を内包する駅舎のサイズのタイルリストを探索
			for(local ii = 0; ii < max_cnt; ii++)
			{
				local c_target = finder.move_coord(tile, d, ii)
				if(c_target == null || is_member(c_target, already_checked_tile_list)){ continue }
				already_checked_tile_list.append(c_target)
				local target_area = finder.base_to_tile_list(c_target, size.x, size.y, 1)
				local bad_tile_area = filter(target_area, @(a) a.has_ways() || !(a.is_ground()) || a.is_water())
				if(bad_tile_area.len() != 0){ continue }
				local tbl_bldg_area_info = finder.get_area_bldg_info(target_area)
				local tbl_candidate_info =
				{
					candidate_tile = c_target
					bldg_counter = tbl_bldg_area_info.bldg_counter
					level = tbl_bldg_area_info.total_bldg_level
				}
				tbl_list.append(tbl_candidate_info)
			}
		}
		if(tbl_list.len() == 0){ return tbl_list }
		tbl_list = sort(tbl_list, @(a,b) a.bldg_counter <=> b.bldg_counter)
		tbl_list = filter(tbl_list, @(a) a.bldg_counter == tbl_list[0].bldg_counter)
		tbl_list = sort(tbl_list, @(a,b) a.level <=> b.level)
		tbl_list = filter(tbl_list, @(a) a.level == tbl_list[0].level)
		return map(tbl_list, @(a) finder.coord2D_to_tile(a.candidate_tile))
	}

	/***************************************
	 * 自社のターミナル駅取得
	 * 引数：プレイヤー属性(player_x)
	 * 戻り値：駅(halt_x)
	 ***************************************/
	function get_own_terminal_station(pl)
	{
		local city_info = persistent.city.get_city_info()
		local c_townhall = city_info[persistent.base_city].townhall
		local b_city = city_x(c_townhall.x, c_townhall.y)
		local terminal_halt = finder.reseach_station_nearest_city(b_city, pl, true)
		// 大都市が拠点の場合、隣接都市がターミナルの最近接になることがある
		// ->駅名でチェック
		if(terminal_halt == null)
		{
			local candidate_list = filter(halt_list_x(), @(a) a.get_name().find(b_city.get_name()) != null)
			candidate_list = filter(candidate_list @(a) a.get_owner().nr == 1)
			candidate_list = sort(candidate_list, @(a,b) b.get_capacity(good_desc_x.passenger) <=> a.get_capacity(good_desc_x.passenger))
			if(candidate_list.len() != 0){ terminal_halt = candidate_list[0] }
		}

		if(terminal_halt == null || finder.check_sta_freight_property(terminal_halt, wt_rail, 2).len() == 0){ return null }
		return terminal_halt
	}

	/***************************************
	 * 駅情報取得
	 * 引数：駅(halt_x)、対象貨物属性(0:荷物、1:郵便、2:旅客)、電化区間のみ情報取得するか(boolean)
	 * 戻り値：駅情報(table)
	 *         tbl_form_info_list    ：プラットホームの情報リスト
	 *                                 length：ホーム長さ
	 *                                 stop  ：列車停車位置の座標(スケジュール設定時に使用)
	 *                                 dir   ：ホーム上の列車の進行方向
	 *         sta_office_tile_list  ：駅本屋のタイルリスト
	 *         sta_premises_tile_list：駅場内入口のタイルリスト(未実装)
	 ***************************************/
	function get_station_info(halt, freight, is_electrified)
	{
		local rail_tile_list = finder.check_sta_freight_property(halt, wt_rail, freight)
		local sta_tile_list = halt.get_tile_list()
		// 駅舎のタイル取得
		local sta_office_tile_list = filter(sta_tile_list, @(a) !(a.has_ways()))
		sta_office_tile_list = filter(sta_office_tile_list, @(a) a.find_object(mo_building).get_desc().enables_pax())
		if(is_electrified)
		{
			rail_tile_list = filter(rail_tile_list, @(a) a.get_way(wt_rail).is_electrified())
		}
		// プラットホームの情報取得
		// 車止めに注意しながら同じ行方向または列方向のタイルを収集する
		local tbl_rail_info_list = get_rail_info_in_sta(rail_tile_list)
		local tbl_form_tile_list = []
		local end_rail_list = filter(tbl_rail_info_list, @(a) is_member(a.dir, [dir.north, dir.south, dir.east, dir.west]))
		foreach(rail_info in end_rail_list)
		{
			tbl_form_tile_list.append([rail_info])
		}
		foreach(rail_info in tbl_rail_info_list)
		{
			local form_idx = []
			if(end_rail_list.len() == 0)
			{
				if(rail_info.dir == dir.eastwest)
				{
					form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) rail_info.tile.y == a[0].tile.y))
				}
				if(rail_info.dir == dir.northsouth)
				{
					form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) rail_info.tile.x == a[0].tile.x))
				}
			}else{
				if(is_member(rail_info.tile, map(end_rail_list, @(a) a.tile))){ continue }
				if(rail_info.dir == dir.eastwest)
				{
					local end_list = filter(end_rail_list, @(a) rail_info.tile.y == a.tile.y)
					if(end_list.len() == 0)
					{
						form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) rail_info.tile.y == a[0].tile.y))
					}else{
						foreach(end in end_list)
						{
							if(end.dir == dir.east && end.tile.x < rail_info.tile.x)
							{
								form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) is_member(end.tile, map(a, @(b) b.tile))))
							}
							if(end.dir == dir.west && end.tile.x > rail_info.tile.x)
							{
								form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) is_member(end.tile, map(a, @(b) b.tile))))
							}
						}
					}
				}
				if(rail_info.dir == dir.northsouth)
				{
					local end_list = filter(end_rail_list, @(a) rail_info.tile.x == a.tile.x)
					if(end_list.len() == 0)
					{
						form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) rail_info.tile.x == a[0].tile.x))
					}else{
						foreach(end in end_list)
						{
							if(end.dir == dir.north && end.tile.y > rail_info.tile.y)
							{
								form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) is_member(end.tile, map(a, @(b) b.tile))))
							}
							if(end.dir == dir.south && end.tile.y < rail_info.tile.y)
							{
								form_idx = get_idx_in_member(true, map(tbl_form_tile_list, @(a) is_member(end.tile, map(a, @(b) b.tile))))
							}
						}
					}
				}
			}
			if(form_idx.len() == 0)
			{
				tbl_form_tile_list.append([rail_info])
			}else{
				tbl_form_tile_list[form_idx[0]].append(rail_info)
			}
		}
		local tbl_form_info_list = []
		// 棒線駅の場合
		if(tbl_form_tile_list.len() == 1)
		{
			local origin_dir = tbl_form_tile_list[0][0].tile.get_way_dirs_masked(wt_rail)
			local search_dir_list = finder.divide_dir(origin_dir)
			for(local ii = 0; ii < search_dir_list.len(); ii++)
			{
				local rail_list = trace_way(tbl_form_tile_list[0][0].tile, wt_rail, search_dir_list[ii], @(a) a.get_halt() != null)
				rail_list = trace_way(rail_list.top(), wt_rail, search_dir_list[ii], @(a) abs(rail_list.top().x-a.x) + abs(rail_list.top().y-a.y) < 4)
				if(dir.is_single(rail_list.top().get_way_dirs(wt_rail)))
				{
					origin_dir = dir.backward(search_dir_list[ii])
					break
				}
			}
			local tbl_temp =
			{
				length = tbl_form_tile_list[0].len()
				stop = tbl_form_tile_list[0][0].tile
				dir = origin_dir
			}
			tbl_form_info_list.append(tbl_temp)
		}else{
			// ホームが複数ある場合
			foreach(form_tile in _step_generator(tbl_form_tile_list))
			{
				// 各ホームの線路の向きを調査
				local pos = form_tile[0].tile
				local rail_dir = pos.get_way_dirs_masked(wt_rail)
				local origin_dir = rail_dir
				local search_dir_list = finder.divide_dir(rail_dir)
				if(dir.is_single(rail_dir)){ pos = pos.get_neighbour(wt_rail, rail_dir) }  //pak128jpだと車止めを停車位置にしない
				for(local ii = 0; ii < search_dir_list.len(); ii++)
				{
					pos = form_tile[0].tile
					local search_dir = search_dir_list[ii]
					while(dir.is_twoway(rail_dir))
					{
						pos = pos.get_neighbour(wt_rail, search_dir)
						// 別の駅や車庫に到達したらトレース終了
						if(pos.get_halt() != null && !(finder.is_same_halt(halt, pos.get_halt())))
						{
							rail_dir = origin_dir
							break
						}
						if(pos.find_object(mo_depot_rail) != null)
						{
							rail_dir = origin_dir
							break
						}
						rail_dir = pos.get_way_dirs_masked(wt_rail)
						if(dir.is_curve(rail_dir))
						{
							search_dir = abs(dir.backward(search_dir) - rail_dir)
						}
					}
					// 線路終端や線路の向きを指定する信号・標識、分岐に到達すると調査終了
					if(dir.is_single(rail_dir))
					{
						// 終端線路に到達したら探索向きの逆をセット
						if(pos.find_object(mo_signal) == null){ rail_dir = dir.backward(search_dir_list[ii]) }
						break
					}
					if(dir.is_threeway(rail_dir)){ rail_dir = origin_dir }
				}
				
				local tbl_temp =
				{
					length = form_tile.len()
					stop = form_tile[0].tile
					dir = rail_dir
				}
				tbl_form_info_list.append(tbl_temp)
			}
		}
		
		local rtn =
		{
			tbl_form_info_list = tbl_form_info_list
			sta_office_tile_list = sta_office_tile_list
		}
		return rtn
	}

	/***************************************
	 * 駅を構成している線路タイルの情報取得
	 * 引数：プラットホームがある線路タイルのリスト(tile_xのリスト)
	 * 戻り値：駅を構成している各タイルの駅に関する情報(table)
	 *         tile          ：タイル情報(tile_x)
	 *         dir           ：線路の方向(dir)
	 *         is_electrified：電化しているか(boolean)
	 ***************************************/
	function get_rail_info_in_sta(tile_list)
	{
		local rtn = []
		foreach(tile in _step_generator(tile_list))
		{
			local tbl_info =
			{
				tile = tile
				dir = tile.get_way_dirs(wt_rail)
				is_electrified = tile.get_way(wt_rail).is_electrified()
			}
			rtn.append(tbl_info)
		}
		return rtn
	}

	/***************************************
	 * 従来の停車位置を新しく取得した駅情報の停車位置の座標に変換
	 * 引数：従来の停車位置(Coord3D)、駅情報(table)
	 * 戻り値：従来の停車位置と同一ホームで駅情報から取得した停車位置(tile_x)
	 * 備考：駅情報はget_station_info関数で取得した、以下の情報をメンバーに持つ
	 *         tbl_form_info_list    ：プラットホームの情報リスト
	 *                                 length：ホーム長さ
	 *                                 stop  ：列車停車位置の座標(スケジュール設定時に使用)
	 *                                 dir   ：ホーム上の列車の進行方向
	 *         sta_office_tile_list  ：駅本屋のタイルリスト
	 ***************************************/
	function get_current_stop(stop, tbl_station_info)
	{
		local rtn = null
		local tbl_form_info_list = tbl_station_info.tbl_form_info_list
		foreach(tbl_form_info in tbl_form_info_list)
		{
			local d = tbl_form_info.dir
			local d_list = []
			if(dir.is_twoway(d))
			{
				if(d == dir.northsouth)
				{
					d_list = [dir.north, dir.south]
				}else{
					d_list = [dir.west, dir.east]
				}
			}else{
				d_list = [d, dir.backward(d)]
			}
			local form_tile_list = []
			local blnFlg = false
			foreach(temp_d in _step_generator(d_list))
			{
				form_tile_list = trace_way(tbl_form_info.stop, wt_rail, temp_d, @(a) a.get_halt() != null)
				if(is_member(stop, form_tile_list))
				{
					rtn = tbl_form_info.stop
					blnFlg = true
					break
				}
			}
			if(blnFlg){ break }
		}
		return rtn
	}

	/***************************************
	 * ホームの一座標から同一ホーム全体の座標リスト取得
	 * 引数：ホームの座標(tile_x)
	 * 戻り値：同一ホーム全体の座標リスト(tile_xのリスト)
	 ***************************************/
	function get_track_list(tile)
	{
		local rtn = []
		if(!(tile.has_way(wt_rail))){ return rtn }
		local d = tile.get_way_dirs(wt_rail)
		local d_list = []
		if(dir.is_twoway(d))
		{
			if(d == dir.northsouth)
			{
				d_list = [dir.north, dir.south]
			}else{
				d_list = [dir.west, dir.east]
			}
		}else{
			d_list = [d, dir.backward(d)]
		}
		foreach(temp_d in d_list)
		{
			local form_tile_list = trace_way(tile, wt_rail, temp_d, @(a) a.get_halt() != null)
			rtn = combine(rtn, form_tile_list)
		}
		// rtnの0番目は重複取得されているので削除
		rtn = rtn.slice(1)
		return rtn
	}

	/***************************************
	 * ホームの終端からn-1マス離れた線路の座標を取得
	 * 引数：プラットホームの座標(tile_x)、n(int)
	 * 戻り値：タイルリスト(tile_xのリスト)
	 * 備考：第一引数はプラットホームがある座標であること
	 * 　　　戻り値は配列長さが2
	 ***************************************/
	function get_boundary_station_pos(tile, n)
	{
		local sta_dir = tile.get_way_dirs(wt_rail)
		if(sta_dir == dir.northsouth || sta_dir == dir.none){ sta_dir = dir.north }
		if(sta_dir == dir.eastwest){ sta_dir = dir.east }
		// 建設したホームの終端からn-1マス離れた線路の座標(駅構内の境界)を取得
		local temp_list = trace_way(tile, wt_rail, sta_dir, @(a) a.get_halt() != null)
		local boundary_inside_sta = trace_way(temp_list.top(), wt_rail, sta_dir, @(a) abs(temp_list.top().x-a.x) < n && abs(temp_list.top().y-a.y) < n)
		temp_list = trace_way(tile, wt_rail, dir.backward(sta_dir), @(a) a.get_halt() != null)
		local boundary_inside_sta2= trace_way(temp_list.top(), wt_rail, dir.backward(sta_dir), @(a) abs(temp_list.top().x-a.x) < n && abs(temp_list.top().y-a.y) < n)
		return [boundary_inside_sta.top(), boundary_inside_sta2.top()]
	}

	/***************************************
	 * 路線が指定の駅を何番目に停車しているか取得
	 * 引数：路線(line_x)、ホームタイル(tile_x)
	 * 戻り値：該当するスケジュールインデックスリスト(intのリスト)
	 ***************************************/
	function get_idx_in_line(line, stop)
	{
		local rtn_list = []
		local form_list = []
		if(stop.has_way(wt_rail))
		{
			// ホーム延伸するとstopと路線に登録した座標がずれることがある
			form_list = get_track_list(stop)
		}else{
			form_list = [stop]
		}
		local schedule_entries = line.get_schedule().entries
		foreach(ii, schedule in schedule_entries)
		{
			// schedule_entry_xはcoord3dの継承なので
			if(is_member(schedule, form_list)){ rtn_list.append(ii) }
		}
		return rtn_list
	}

	/***************************************
	 * 各ホームを使用している路線一覧取得
	 * 引数：駅(halt_x)、対象貨物属性(0:荷物、1:郵便、2:旅客)
	 * 戻り値：各ホームを使用している路線情報リスト
	 *         stop        :各ホームの停車位置(Coord)  ※ホーム先端
	 *         line_list   :路線(line_xのリスト)
	 ***************************************/
	function get_line_using_track(halt, freight)
	{
		local rtn = []
		local tbl_station_info = get_station_info(halt, freight, false)
		local tbl_line_stop_list = finder.get_line_info_in_sta(halt)
		
		foreach(tbl_form_info in tbl_station_info.tbl_form_info_list)
		{
			local temp_line_list = []
			local temp_tbl_line_stop_list = filter(tbl_line_stop_list, @(a) is_member(tbl_form_info.stop, get_track_list(a.stop)))
			foreach(temp_tbl_line_stop in temp_tbl_line_stop_list)
			{
				temp_line_list.append(temp_tbl_line_stop.line)
			}
			local tbl_temp =
			{
				stop = tbl_form_info.stop
				line_list = temp_line_list
			}
			rtn.append(tbl_temp)
		}
		
		return rtn
	}

	/***************************************
	 * 次駅検索
	 * 引数：現駅情報(table)、座標(tile_x)、方向(dir)、電化区間のみ情報取得するか(boolean)、既に通過したタイルリスト(tile_listのリスト)
	 * 戻り値：次駅の情報リスト
	 *         halt     :駅情報(halt_x)
	 *         dir      :駅進入時の方角(dir)
	 *         tile_list:同一方角から駅進入する時のプラットホーム開始位置のタイルリスト
	 * 備考：座標には線路があること
	 *       第一引数の現駅情報の内訳
	 *          halt:駅情報(halt_x)
	 *          dir :検索開始の方向(dir)
	 ***************************************/
	function search_next_sta(halt_info, pos, d, is_electrified, ap_tile_list)
	{
		local rtn = []
		local tbl_next_pos_list = get_neighbor_rail(pos, d, is_electrified)
		// 終端線路に到達
		if(tbl_next_pos_list.len() == 0){ return rtn }
		// 引数の座標に到達したら探索終了
		if(is_member(tbl_next_pos_list[0].pos, ap_tile_list)){ return rtn }
		foreach(tbl_next_pos in _step_generator(tbl_next_pos_list))
		{
			ap_tile_list.append(tbl_next_pos.pos)
			local next_halt = tbl_next_pos.pos.get_halt()
			// 終端線路は検索終了
			if(dir.backward(d) == tbl_next_pos.dir)
			{
				// 駅があれば情報取得
				if(next_halt != null && !(finder.is_same_halt(next_halt, halt_info.halt)))
				{
					// 登録済みの駅の別のホームに到達
					local already_registed_list = map(rtn, @(a) finder.is_same_halt(next_halt, a.halt))
					local idx_list = get_idx_in_member(true, already_registed_list)
					local blnNew = true
					if(idx_list.len() != 0)
					{
						foreach(idx in idx_list)
						{
							if(rtn[idx].dir == d)
							{
								blnNew = false
								if(!(is_member(tbl_next_pos.pos, rtn[idx].tile_list)))
								{
									rtn[idx].tile_list.append(tbl_next_pos.pos)
								}
							}
						}
					}
					// 未登録の駅なので登録
					if(blnNew)
					{
						local tbl_next_sta_info =
						{
							halt = next_halt
							dir = d
							tile_list = [tbl_next_pos.pos]
						}
						rtn.append(tbl_next_sta_info)
					}
				}
				continue
			}

			local tbl_next_sta_info_list = []
			if(next_halt == null)
			{
				// 再帰処理
				tbl_next_sta_info_list = search_next_sta(halt_info, tbl_next_pos.pos, tbl_next_pos.dir, is_electrified, ap_tile_list)
			}else{
				// 現駅到達
				if(finder.is_same_halt(next_halt, halt_info.halt))
				{
					// 方角が検索開始時と同じなら再帰処理
					if(tbl_next_pos.dir == halt_info.dir)
					{
						tbl_next_sta_info_list = search_next_sta(halt_info, tbl_next_pos.pos, tbl_next_pos.dir, is_electrified, ap_tile_list)
					}else{
						// 方角が引数と異なるなら探索終了
						continue
					}
				}else{
					// 登録済みの駅の別のホームに到達
					local already_registed_list = map(rtn, @(a) finder.is_same_halt(next_halt, a.halt))
					local idx_list = get_idx_in_member(true, already_registed_list)
					local blnNew = true
					if(idx_list.len() != 0)
					{
						foreach(idx in idx_list)
						{
							if(rtn[idx].dir == d)
							{
								blnNew = false
								if(!(is_member(tbl_next_pos.pos, rtn[idx].tile_list)))
								{
									rtn[idx].tile_list.append(tbl_next_pos.pos)
								}
							}
						}
					}
					// 未登録の駅なので登録
					if(blnNew)
					{
						local tbl_next_sta_info =
						{
							halt = next_halt
							dir = d
							tile_list = [tbl_next_pos.pos]
						}
						rtn.append(tbl_next_sta_info)
					}
				}
			}
			foreach(tbl_next_sta_info in _step_generator(tbl_next_sta_info_list))
			{
				// 登録済みの駅の別のホームに到達
				local already_registed_list = map(rtn, @(a) finder.is_same_halt(tbl_next_sta_info.halt, a.halt))
				local idx_list = get_idx_in_member(true, already_registed_list)
				local flg = true
				if(idx_list.len() != 0)
				{
					foreach(idx in idx_list)
					{
						if(rtn[idx].dir == d)
						{
							flg = false
							foreach(tile in tbl_next_sta_info.tile_list)
							{
								if(!(is_member(tile, rtn[idx].tile_list)))
								{
									rtn[idx].tile_list.append(tile)
								}
							}
						}
					}
				}
				// 未登録の駅なので登録
				if(flg){ rtn.append(tbl_next_sta_info) }
			}
		}
		return rtn
	}

	/***************************************
	 * 線路の隣接座標取得
	 * 引数：座標(tile_x)、方向(dir)、電化区間のみ情報取得するか(boolean)
	 * 戻り値：隣接線路の情報リスト
	 *         pos          ：座標(tile_x)
	 *         dir          ：線路の方向(dir)
	 * 備考：座標には線路があること
	 ***************************************/
	function get_neighbor_rail(pos, d, is_electrified)
	{
		local rtn = []
		local target = pos.get_neighbour(wt_rail, d)
		if(target == null){ return rtn }
		local target_dir = target.get_way_dirs_masked(wt_rail)
		if(target_dir == dir.backward(d) && target.find_object(mo_signal) != null){ return rtn }
		if(is_electrified)
		{
			local way = target.get_way(wt_rail)
			if(!(way.is_electrified)){ return rtn }
		}
		local dir_list = finder.divide_dir(target_dir)
		if(dir_list.len() > 1){ dir_list = filter(dir_list, @(a) a != dir.backward(d)) }
		for(local ii = 0; ii < dir_list.len(); ii++)
		{
			local tbl_temp =
			{
				pos = target
				dir = dir_list[ii]
			}
			rtn.append(tbl_temp)
		}
		return rtn
	}

	/***************************************
	 * プラットホームの延伸
	 * 引数：プレイヤー会社(player_x)、駅(halt_x)、延伸後のホームのタイル長さ(int)、対象の停車位置リスト(tile_xのリスト)
	 * 戻り値：情報構造体
	 *         halt          ：駅情報(halt_x)(公共駅の場合、情報を更新する必要がある)
	 *         err　　　　   ：エラーメッセージ
	 ***************************************/
	function extend_form(pl, halt, length, stop_list)
	{
		local rtn = null
		// 駅情報取得
		local sta_info = get_station_info(halt, 2, false)
		// 停車位置を最新駅情報の停車位置情報に変換
		local current_stop_list = []
		foreach(stop in stop_list)
		{
			current_stop_list.append(get_current_stop(stop, sta_info))
		}
		
		local build_tile_list = []
		foreach(tbl_form_info in _step_generator(sta_info.tbl_form_info_list))
		{
			//try{
			if(tbl_form_info.length >= length){ continue }
			if(!(is_member(tbl_form_info.stop, current_stop_list))){ continue }
			local current_length = tbl_form_info.length
			// 
			local search_dir_list = []
			if(tbl_form_info.dir == dir.northsouth){ search_dir_list = [dir.north, dir.south] }
			if(tbl_form_info.dir == dir.eastwest){ search_dir_list = [dir.east, dir.west] }
			if(dir.is_single(tbl_form_info.dir)){ search_dir_list = [tbl_form_info.dir, dir.backward(tbl_form_info.dir)] }
			local cov = settings.get_station_coverage()
			while(current_length < length)
			{
				local tbl_tile_list = []
				for(local ii = 0; ii < search_dir_list.len(); ii++)
				{
					local form_tile_list = trace_way(tbl_form_info.stop, wt_rail, search_dir_list[ii], @(a) a.get_halt() !=null)
					local tbl_tile =
					{
						target = form_tile_list.top().get_neighbour(wt_rail, search_dir_list[ii])
						dir = search_dir_list[ii]
						total_bldg_level = 0
						length = form_tile_list.len()
					}
					// ホーム建設予定タイルが以下の理由で建設不可なら情報取得スキップ
					local blnSkipFlg = false
					if(tbl_tile.target == null){ continue }                     // ホーム建設予定タイル取得失敗
					if(tbl_tile.target.has_way(wt_road)){ blnSkipFlg = true }   // 踏切あり
					if(!(dir.is_straight(tbl_tile.target.get_way_dirs(wt_rail)))){ blnSkipFlg = true }   // 直線でない
					if(blnSkipFlg){ continue }
					// ホーム建設予定タイルにホーム建設した際、カバーエリアの旅客度を計算
					local target_cov_tile_list = finder.base_to_tile_list(tbl_tile.target, cov, cov, 0)
					local tbl_bldg_info = finder.get_area_bldg_info(target_cov_tile_list)
					tbl_tile.total_bldg_level = tbl_bldg_info.total_bldg_level
					tbl_tile_list.append(tbl_tile)
				}

				if(tbl_tile_list.len() == 2)
				{
					tbl_tile_list = sort(tbl_tile_list, @(a,b) b.total_bldg_level <=> a.total_bldg_level)
				}
				for(local ii = 0; ii < tbl_tile_list.len(); ii++)
				{
					local target = tbl_tile_list[ii].target
					local d = tbl_tile_list[ii].dir
					// ホーム延伸タイルに信号機があれば、移設
					if(target.find_object(mo_signal) != null)
					{
						local neighbor_target = target.get_neighbour(wt_rail, d)
						if(dir.is_threeway(neighbor_target.get_way_dirs(wt_rail)))
						{
							// 分岐線路を付け替える
							change_pos_point(pl, neighbor_target, d)
						}
						if(dir.is_curve(neighbor_target.get_way_dirs(wt_rail)))
						{
							local temp_d = neighbor_target.get_way_dirs(wt_rail) - dir.backward(d)
							local n_neighbor_t = neighbor_target.get_neighbour(wt_rail, temp_d)
							if(dir.is_threeway(n_neighbor_t.get_way_dirs(wt_rail)))
							{
								// 分岐線路を付け替える
								change_pos_point(pl, n_neighbor_t, d)
							}
						}
						// 分岐線路の付け替えに失敗した時用のif文
						if(dir.is_straight(neighbor_target.get_way_dirs(wt_rail)))
						{
							// 信号アドオン選択
							local sign_desc = sign_desc_x.get_available_signs(wt_rail)
							sign_desc = filter(sign_desc, @(a) a.is_signal())
							sign_desc = sort(sign_desc, @(a,b) a.get_cost() <=> b.get_cost())
							// 信号建設
							while(neighbor_target.get_way_dirs_masked(wt_rail) != d)
							{
								command_x.build_sign_at(pl, neighbor_target, sign_desc[0])
							}
							// 既存信号撤去
							local tool = command_x(tool_remover)
							tool.work(pl, target)
						}
					}
					// ホーム建設
					local err = build_form(pl, [target], true)
					if(err == null)
					{
						current_length++
						build_tile_list.append(target)
						break
					}
				}
				if(tbl_tile_list.len() == 0)
				{
					rtn = { err = "Can't extend form" }
					break
				}
			}
			//}catch(e){}
		}
		
		// 駅が公共なら延伸部を公共化
		if(halt.get_owner().nr == 1 && build_tile_list.len() != 0)
		{
			local sta_name = halt.get_name()
			local cmd = command_x(tool_make_stop_public)
			foreach(target in _step_generator(build_tile_list))
			{
				if(target.get_way(wt_rail).get_owner().nr == pl.nr){ cmd.work(pl, target) }
			}
			halt = build_tile_list[0].get_halt()
			halt.set_name(sta_name)
		}
		if(!("err" in rtn)){ rtn = { halt = halt }}
		return rtn
	}

	/***************************************
	 * プラットホームを増やす
	 * 引数：プレイヤー会社(player_x)、駅(halt_x)
	 * 戻り値：新設したホームの情報
	 *         halt          ：駅情報(halt_x)(公共駅の場合、情報を更新する必要がある)
	 *         expand_tile   ：新設したホームのタイル(tile_x)
	 *         expand_dir    ：既存駅から見て拡張する方向
	 *         expand_info   ：線路敷設開始位置、ホーム設置開始位置、ホーム設置終了位置、線路敷設終了位置(tile_xのリスト)
	 ***************************************/
	function expand_station(pl, halt)
	{
		// 駅情報取得
		local sta_info = get_station_info(halt, 2, false)
		local tbl_form_info_list = sta_info.tbl_form_info_list
		// 各線路の両側を調査して線路がないエリアを探索
		local construction_info = search_constract_form(pl, sta_info)
		if(construction_info == null){ return }
		// 建設(建築物撤去->整地->線路敷設->ホーム建設)
		local tl_remove = command_x(tool_remover)
		local sta_office_move_flg = false
		local tile_list = finder.get_interpolate_tile(construction_info.area_list[0], construction_info.area_list.top())
		local d = (coord(tile_list.top().x-tile_list[0].x, tile_list.top().y-tile_list[0].y)).to_dir()
		local road_info = road_manager_t()
		local road_list = []
		foreach(area_tile in _step_generator(tile_list))
		{
			if(area_tile.has_way(wt_rail))
			{
				// 車庫以外の線路なら撤去しない
				if(area_tile.find_object(mo_depot_rail) == null)
				{
					continue
				}else{
					// 車庫に車両が待機していれば、出発するまで待つ
					while(1)
					{
						if(area_tile.find_object(mo_train) == null)
						{
							break
						}
					}
					tl_remove.work(pl, area_tile)
				}
			}
			// 既存道路は付け替え
			if(area_tile.has_way(wt_road))
			{
				local d = area_tile.get_way_dirs(wt_road)
				// 直交する道路は踏切にするので何もしない
				if(road_info.check_not_cross_road(area_tile, d))
				{
					road_list.append(area_tile)
				}
			}
			// 駅舎があった場合、移転準備
			if(!(sta_office_move_flg) && area_tile.find_object(mo_building) && area_tile.get_halt() != null)
			{
				sta_office_move_flg= true
			}	
		}
		// 道路移設
		if(road_list.len() != 0)
		{
			local miss_tile_list = road_info.move_road(road_list, construction_info.dir, pl)
			if(miss_tile_list.len() != 0)
			{
				miss_tile_list = filter(miss_tile_list, @(a) a.get_halt() != null)
				// 道路移設失敗してその中にバス停タイルがある場合
				if(miss_tile_list.len() > 0)
				{
					
				}
			}
		}
		// 線路敷設
		local sta_tile_height = tbl_form_info_list[0].stop.z
		construction_info.area_list = finder.align_height(construction_info.area_list, sta_tile_height, pl, false)
		expand_straight_rail(pl, construction_info.area_list[0], construction_info.area_list.top())
		// ホーム建設
		local construct_form_tile_list = finder.get_interpolate_tile(construction_info.area_list[1], construction_info.area_list[2])
		local err = build_form(pl, construct_form_tile_list, true)
		if(err != null)
		{
			gui.add_message_at(pl, "expand_station error [" + halt.get_name() + "]:" + err, construction_info.area_list[0])
			return null
		}else{
			if(sta_office_move_flg)
			{
				local tile = finder.coord2D_to_tile(finder.get_center(construct_form_tile_list))
				build_station_office(pl, tile, null)
			}
			// 駅が公共なら延伸部を公共化
			if(halt.get_owner().nr == 1)
			{
				local sta_name = halt.get_name()
				local cmd = command_x(tool_make_stop_public)
				cmd.work(pl, construct_form_tile_list[0])
				// haltの情報更新
				halt = construct_form_tile_list[0].get_halt()
				halt.set_name(sta_name)
			}
			local tbl_temp = 
			{
				halt = halt
				expand_tile = construct_form_tile_list[0]
				expand_dir = construction_info.dir
				expand_info = construction_info.area_list
			}
			return tbl_temp
		}
	}

	/***************************************
	 * 駅に行き違い設備を設ける
	 * 引数：プレイヤー会社(player_x)、駅(halt_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function set_passing_each_other(pl, halt)
	{
		local rail_tile_list = finder.check_sta_freight_property(halt, wt_rail, 2)
		if(rail_tile_list.len() == 0){ return }
		rail_tile_list = filter(rail_tile_list, @(a) a.get_way(wt_rail).is_electrified())
		local be_electrified = false
		if(rail_tile_list.len() != 0){ be_electrified = true }

		// 駅情報取得
		local sta_info = get_station_info(halt, 2, be_electrified)
		local tbl_form_info_list = sta_info.tbl_form_info_list

		// 棒線駅に行き違い設備を設ける
		if(tbl_form_info_list.len() > 1){ return "already have passing each other." }
		local stop_tile = tbl_form_info_list[0].stop

		// 側線建設
		local tbl_expand_info = expand_station(pl, halt)
		if(tbl_expand_info == null){ return "missing setting passing each other." }
		// 駅情報更新(公共駅の対応)
		halt = tbl_expand_info.halt

		// 線路アドオンは低規格のものを選択
		local way_desc = select_low_cost_rail()
		local set_signal_flg = true
		local build_point_flg = true
		// 側線と本線を接続
		local temp_tile = finder.coord2D_to_tile(finder.move_coord(tbl_expand_info.expand_info[0], dir.backward(tbl_expand_info.expand_info[0].get_way_dirs(wt_rail))))
		if(temp_tile != null && temp_tile.has_way(wt_rail))
		{
			local rail_owner = temp_tile.get_way(wt_rail).get_owner()
			if(is_member(rail_owner.nr, [1, pl.nr]) && temp_tile.get_way_dirs_masked(wt_rail) == dir.backward(tbl_expand_info.expand_dir) + dir.backward(tbl_expand_info.expand_info[0].get_way_dirs(wt_rail)))
			{
				command_x.build_way(pl, tbl_expand_info.expand_info[0], temp_tile, way_desc, true)
				build_point_flg = false
			}
		}
		if(build_point_flg)
		{
			temp_tile = finder.coord2D_to_tile(finder.move_coord(tbl_expand_info.expand_info[0], dir.backward(tbl_expand_info.expand_dir)))
			if(tbl_form_info_list[0].dir == coord(temp_tile.x-tbl_form_info_list[0].stop.x, temp_tile.y-tbl_form_info_list[0].stop.y).to_dir() || dir.is_twoway(tbl_form_info_list[0].dir))
			{
				expand_straight_rail(pl, tbl_expand_info.expand_info[0], temp_tile)
			}else{
				set_signal_flg = false
			}
		}else{
			build_point_flg = true
		}
		temp_tile = finder.coord2D_to_tile(finder.move_coord(tbl_expand_info.expand_info.top(), dir.backward(tbl_expand_info.expand_info.top().get_way_dirs(wt_rail))))
		if(temp_tile != null && temp_tile.has_way(wt_rail))
		{
			local rail_owner = temp_tile.get_way(wt_rail).get_owner()
			if(is_member(rail_owner.nr, [1, pl.nr]) && temp_tile.get_way_dirs_masked(wt_rail) == dir.backward(tbl_expand_info.expand_dir) + dir.backward(tbl_expand_info.expand_info.top().get_way_dirs(wt_rail)))
			{
				command_x.build_way(pl, tbl_expand_info.expand_info.top(), temp_tile, way_desc, true)
				build_point_flg = false
			}
		}
		if(build_point_flg)
		{
			temp_tile = finder.coord2D_to_tile(finder.move_coord(tbl_expand_info.expand_info.top(), dir.backward(tbl_expand_info.expand_dir)))
			if(tbl_form_info_list[0].dir == coord(temp_tile.x-tbl_form_info_list[0].stop.x, temp_tile.y-tbl_form_info_list[0].stop.y).to_dir() || dir.is_twoway(tbl_form_info_list[0].dir))
			{
				expand_straight_rail(pl, tbl_expand_info.expand_info.top(), temp_tile)
			}else{
				set_signal_flg = false
			}
		}

		if(be_electrified)
		{
			local catenary = rail_tile_list[0].find_object(mo_wayobj).get_desc()
			command_x.build_wayobj(pl, temp_tile, tbl_expand_info.expand_tile, catenary)
			temp_tile = finder.coord2D_to_tile(finder.move_coord(tbl_expand_info.expand_info[0], dir.backward(tbl_expand_info.expand_dir)))
			command_x.build_wayobj(pl, temp_tile, tbl_expand_info.expand_tile, catenary)
		}

		if(set_signal_flg)
		{
			// 信号アドオン選択
			local sign_desc = sign_desc_x.get_available_signs(wt_rail)
			sign_desc = filter(sign_desc, @(a) a.is_signal())
			if(sign_desc.len() == 0){ return }
			sign_desc = sort(sign_desc, @(a,b) a.get_cost() <=> b.get_cost())
			// 信号設置
			if(tbl_form_info_list.len() == 1)
			{
				foreach(ii, t_tile in _step_generator([tbl_expand_info.expand_info[0], tbl_expand_info.expand_info.top()]))
				{
					local d = finder.rotate_right_angle(tbl_expand_info.expand_dir, false)
					local sig_tile = finder.coord2D_to_tile(finder.move_coord(t_tile, d))
					local dist = 1
					if(ii == 0)
					{
						dist = abs(tbl_expand_info.expand_info[0].x-tbl_expand_info.expand_info[1].x)+abs(tbl_expand_info.expand_info[0].y-tbl_expand_info.expand_info[1].y)
					}else{
						dist = abs(tbl_expand_info.expand_info[2].x-tbl_expand_info.expand_info[3].x)+abs(tbl_expand_info.expand_info[2].y-tbl_expand_info.expand_info[3].y)
					}
					dist--
					local neighbor_sig_tile = finder.coord2D_to_tile(finder.move_coord(sig_tile, d, dist))
					local neighbor_sig_tile_halt = neighbor_sig_tile.get_halt()
					if(!(sig_tile.has_way(wt_rail)) || neighbor_sig_tile_halt == null || !(finder.is_same_halt(halt, neighbor_sig_tile_halt)))
					{
						d = finder.rotate_right_angle(tbl_expand_info.expand_dir, true) + dir.backward(tbl_expand_info.expand_dir)
						sig_tile = finder.coord2D_to_tile(finder.move_coord(t_tile, d))
						d = finder.rotate_right_angle(tbl_expand_info.expand_dir, true)
					}
					while(sig_tile.get_way_dirs_masked(wt_rail) != dir.backward(d))
					{
					try{
						command_x.build_sign_at(pl, sig_tile, sign_desc[0])
					}catch(e)
					{
						gui.add_message_at(pl,"["+coord_to_string(sig_tile)+"],dir:"+dir.backward(d),sig_tile)
					}
					}
				}
			}
		}

		// 駅情報更新
		sta_info = get_station_info(halt, 2, be_electrified)
		tbl_form_info_list = sta_info.tbl_form_info_list
		// スケジュール更新
		local line_list = halt.get_line_list()
		line_list = filter(line_list, @(a) a.get_waytype() == wt_rail)
		foreach(line in line_list)
		{
			local schedule_entries = line.get_schedule().entries
			// schedule_entry_xはcoord3dの継承なので
			local target_sche_idx_list = get_idx_in_line(line, stop_tile)
			if(set_signal_flg)
			{
				foreach(tbl_form_info in tbl_form_info_list)
				{
					local halt_info = { halt = halt, dir = tbl_form_info.dir }
					local next_sta_list = search_next_sta(halt_info, tbl_form_info.stop, tbl_form_info.dir, be_electrified, [])
					
					foreach(target in target_sche_idx_list)
					{
						local t_idx = target + 1
						if(target == schedule_entries.len() - 1){ t_idx = 0 }
						local temp_list = filter(next_sta_list, @(a) finder.is_same_halt(a.halt,schedule_entries[t_idx].get_halt(pl)))
						if(temp_list.len() != 0)
						{
							schedule_entries[target] = tbl_form_info.stop
						}
					}
				}
			}else{
				// スイッチバック駅の場合
				foreach(target in target_sche_idx_list)
				{
					local t_idx = target - 1
					if(t_idx == -1){ t_idx = schedule_entries.len() - 1 }
					if(is_member(tbl_expand_info.expand_dir, [dir.north, dir.south]))
					{
						if(tbl_expand_info.expand_dir == coord(0,schedule_entries[target].y - schedule_entries[t_idx].y).to_dir())
						{
							local temp_stop = filter(tbl_form_info_list, @(a) schedule_entries[target] != a.stop)
							schedule_entries[target] = temp_stop[0].stop
						}
					}else{
						if(tbl_expand_info.expand_dir == coord(schedule_entries[target].x - schedule_entries[t_idx].x,0).to_dir())
						{
							local temp_stop = filter(tbl_form_info_list, @(a) schedule_entries[target] != a.stop)
							schedule_entries[target] = temp_stop[0].stop
						}
					}
				}
			}
			local schedule = schedule_x(wt_rail, schedule_entries)
			line.change_schedule(pl, schedule)
		}

		return null
	}

	/***************************************
	 * 駅拡張時、プラットホームを建設するエリアを決める
	 * 引数：プレイヤー会社(player_x)、駅情報構造体(table)
	 * 戻り値：プラットホームを建設するエリアの構造体
	 *          area_list：線路敷設開始位置、ホーム設置開始位置、ホーム設置終了位置、線路敷設終了位置
	 *          dir      ：既存駅から見て拡張する方向
	 * 備考：駅情報構造体はget_station_info関数の戻り値
	 *       呼び出し元で整地、建物撤去を行う
	 ***************************************/
	function search_constract_form(pl, tbl_station_info)
	{
		local construction_info = {}
		local tbl_form_info_list = tbl_station_info.tbl_form_info_list
		local tbl_bldg_info_list = []
		local road_info = road_manager_t()
		foreach(tbl_form_info in tbl_form_info_list)
		{
			// 各ホームの先端座標取得
			local stop_tile = tbl_form_info.stop
			local d = tbl_form_info.dir
			if(!(dir.is_single(d)))
			{
				if(d == dir.northsouth){ d = dir.north }
				if(d == dir.eastwest){ d = dir.west }
			}
			local temp = trace_way(stop_tile, wt_rail, d, @(a) a.get_halt() != null)
			local form_sentanA = temp.top()
			local branchA = finder.coord2D_to_tile(finder.move_coord(form_sentanA, d, 2))
			if(branchA == null){ continue }
			// ホーム直後に線路がカーブする場合は線路敷設開始位置をホーム先端直後とする
			if(!(branchA.has_way(wt_rail))){ branchA = finder.coord2D_to_tile(finder.move_coord(form_sentanA, d)) }
			temp = trace_way(stop_tile, wt_rail, dir.backward(d), @(a) a.get_halt() != null)
			local form_sentanB = temp.top()
			local branchB = finder.coord2D_to_tile(finder.move_coord(form_sentanB, dir.backward(d), 2))
			if(branchB == null){ continue }
			// ホーム直後に線路がカーブする場合は線路敷設終了位置をホーム先端直後とする
			if(!(branchB.has_way(wt_rail))){ branchB = finder.coord2D_to_tile(finder.move_coord(form_sentanB, dir.backward(d))) }
			// 各線路の両側を調査して線路がないエリアを探索
			local vertical_d_list = []
			if(d == dir.north || d == dir.south || d == dir.northsouth)
			{
				vertical_d_list = [dir.east, dir.west]
			}else{
				vertical_d_list = [dir.north, dir.south]
			}
			
			foreach(vertical_dir in _step_generator(vertical_d_list))
			{
				local neighbor_tile = finder.coord2D_to_tile(finder.move_coord(stop_tile, vertical_dir))
				if(neighbor_tile == null || neighbor_tile.has_way(wt_rail)){ continue }
				
				local initial_tile = finder.coord2D_to_tile(finder.move_coord(branchA, vertical_dir))
				local final_tile = finder.coord2D_to_tile(finder.move_coord(branchB, vertical_dir))
				if(initial_tile == null || final_tile == null){ continue }
				local temp_tile_list = finder.get_interpolate_tile(initial_tile, final_tile)
				// 線路敷設候補に他社所有地などの撤去できないものがある場合、候補から除外
				local other_com_occupy_tile = filter(temp_tile_list, @(a) !(finder.can_remove_all_objects(a, pl)))
				if(other_com_occupy_tile.len() != 0){ continue }

				// 線路敷設開始位置、線路敷設終了位置で道路が直交する場合、位置をずらす
				local temp_d = (coord(temp_tile_list[0].x - temp_tile_list[1].x, temp_tile_list[0].y - temp_tile_list[1].y)).to_dir()
				local blnFlg = false
				while(temp_tile_list[0].has_way(wt_road))
				{
					if(!(world.is_coord_valid(temp_tile_list[0])) || temp_tile_list[0] == null)
					{
					 	blnFlg = true
					 	break
					}
					if(!(road_info.check_not_cross_road(temp_tile_list[0], dir.double(temp_d))))
					{
						temp_tile_list[0] = finder.coord2D_to_tile(finder.move_coord(temp_tile_list[0], temp_d))
					}
				}

				while(temp_tile_list.top().has_way(wt_road))
				{
					if(!(world.is_coord_valid(temp_tile_list[temp_tile_list.len()-1])) || temp_tile_list[temp_tile_list.len()-1] == null)
					{
					 	blnFlg = true
					 	break
					}
					if(!(road_info.check_not_cross_road(temp_tile_list.top(), dir.double(temp_d))))
					{
						temp_tile_list[temp_tile_list.len()-1] = finder.coord2D_to_tile(finder.move_coord(temp_tile_list.top(), dir.backward(temp_d)))
					}
				}
				if(blnFlg){  continue }

				// 線路敷設開始位置、ホーム設置開始位置、ホーム設置終了位置、線路敷設終了位置の順に情報セット
				local new_formA = finder.coord2D_to_tile(finder.move_coord(form_sentanA, vertical_dir))
				local new_formB = finder.coord2D_to_tile(finder.move_coord(form_sentanB, vertical_dir))
				local target_tile_list = [temp_tile_list[0], new_formA, new_formB, temp_tile_list.top()]
				local tbl_temp_bldg_info = finder.get_area_bldg_info(temp_tile_list)
				tbl_temp_bldg_info.dir <- vertical_dir
				tbl_temp_bldg_info.target <- target_tile_list
				tbl_bldg_info_list.append(tbl_temp_bldg_info)
			}
		}
		// 建設エリアの建物の総旅客度数が低い方または建物数が少ない方を選択
		if(tbl_bldg_info_list.len() == 0){ return null }
		if(tbl_bldg_info_list.len() == 1)
		{
			construction_info.area_list <- tbl_bldg_info_list[0].target
			construction_info.dir <- tbl_bldg_info_list[0].dir
		}else{
			if(tbl_bldg_info_list[0].total_bldg_level >= tbl_bldg_info_list[1].total_bldg_level || (tbl_bldg_info_list[0].total_bldg_level == tbl_bldg_info_list[1].total_bldg_level && tbl_bldg_info_list[0].bldg_counter >= tbl_bldg_info_list[1].bldg_counter))
			{
				construction_info.area_list <- tbl_bldg_info_list[1].target
				construction_info.dir <- tbl_bldg_info_list[1].dir
			}else{
				construction_info.area_list <- tbl_bldg_info_list[0].target
				construction_info.dir <- tbl_bldg_info_list[0].dir
			}
		}
		return construction_info
	}

	/***************************************
	 * 駅を分岐駅にする
	 * 引数：プレイヤー会社(player_x)、駅(halt_x)、分岐側の基準点(tile_x)
	 * 戻り値：駅の入場、出場タイル
	 * 　　　　enter：駅に入場するタイル(tile_x)
	 * 　　　　exit：分岐駅から線路敷設する時の始点(tile_x)
	 *         halt：駅(公共駅を更新したとき用)
	 ***************************************/
	function update_junction_station(pl, halt, branch_side)
	{
		local rtn = {}
		local rail_tile_list = finder.check_sta_freight_property(halt, wt_rail, 2)
		if(rail_tile_list.len() == 0){ return }
		rail_tile_list = filter(rail_tile_list, @(a) a.get_way(wt_rail).is_electrified())
		local be_electrified = false
		if(rail_tile_list.len() != 0){ be_electrified = true }

		// 駅情報取得
		local sta_info = get_station_info(halt, 2, be_electrified)
		local tbl_form_info_list = sta_info.tbl_form_info_list

		local stop_flg = false
		// 棒線駅に行き違い設備を設ける
		if(tbl_form_info_list.len() == 1)
		{
			local err = set_passing_each_other(pl, halt)
			if(err){ stop_flg = true }
			
			// haltを更新
			halt = tbl_form_info_list[0].stop.get_halt()
		}
		// 棒線終端駅だった場合、2線で拡張をとどめる
		if(tbl_form_info_list.len() == 1 && dir.is_single(tbl_form_info_list[0].dir))
		{
			stop_flg = true
		}
		
		if(stop_flg)
		{
			// 使用数の少ないホーム取得
			local tbl_stop_info = get_line_using_track(halt, 2)
			tbl_stop_info = sort(tbl_stop_info, @(a,b) a.line_list.len() <=> b.line_list.len())
			local tbl_temp = get_sta_enter_exit(tbl_stop_info[0].stop, branch_side, pl)
			if(tbl_temp != null)
			{
				rtn.enter <- tbl_temp.enter
				rtn.exit <- tbl_temp.exit
				rtn.halt <- halt
				return rtn
			}
		}

		// 更にホーム追加
		local tbl_expand_form_info = expand_station(pl, halt)
		if(tbl_expand_form_info == null){ return }
		halt = tbl_expand_form_info.halt
		local expand_rail_dir = tbl_expand_form_info.expand_tile.get_way_dirs(wt_rail)
		local temp_dir = dir.north
		if(expand_rail_dir == dir.eastwest){ temp_dir = dir.east }
		// 拡張ホームの線路終端部取得
		local terminalA = trace_way(tbl_expand_form_info.expand_tile, wt_rail, temp_dir, @(a) 1)
		terminalA = terminalA.top()
		local terminalB = trace_way(tbl_expand_form_info.expand_tile, wt_rail, dir.backward(temp_dir), @(a) 1)
		terminalB = terminalB.top()
		local branch_rail_list = []
		if(abs(terminalA.x-branch_side.x)+abs(terminalA.y-branch_side.y) < abs(terminalB.x-branch_side.x)+abs(terminalB.y-branch_side.y))
		{
			branch_rail_list = [terminalB, terminalA]
		}else{
			branch_rail_list = [terminalA, terminalB]
		}
		// 線路アドオンは低規格のものを選択
		local way_desc = select_low_cost_rail()
		// 本線に収束する側の線路接続
		local end_tile = finder.coord2D_to_tile(finder.move_coord(branch_rail_list[0], dir.backward(tbl_expand_form_info.expand_dir)))
		local d = dir.backward(branch_rail_list[0].get_way_dirs(wt_rail))
		if(!(dir.is_single(end_tile.get_way_dirs(wt_rail))))
		{
			// 接続先に既にポイントがある場合、ポイント位置を調整
			local change_point_tile_list = []
			local pc_list = [end_tile, finder.coord2D_to_tile(finder.move_coord(end_tile, dir.backward(tbl_expand_form_info.expand_dir)))]
			for(local ii = 0; ii < pc_list.len(); ii++)
			{
				if( pc_list[ii] == null){ continue }
				local temp_tile = pc_list[ii]
				while(dir.is_threeway(temp_tile.get_way_dirs(wt_rail)))
				{
					change_point_tile_list.append(temp_tile)
					local temp_d = dir.backward(tbl_expand_form_info.expand_dir) + d
					temp_tile = finder.coord2D_to_tile(finder.move_coord(temp_tile, temp_d))
					if(temp_tile == null){ break }
				}
				for(local jj = change_point_tile_list.len() - 1; jj >= 0; jj--)
				{
					change_pos_point(pl, change_point_tile_list[jj], d)
				}
			}
			command_x.build_way(pl, branch_rail_list[0], end_tile, way_desc, true)
		}
		rtn.enter <- end_tile
		
		local in_sta_signal_pos = null
		d = dir.backward(branch_rail_list[1].get_way_dirs(wt_rail))
		local origin_d = d
		// 駅舎壊さずホーム追加した場合
		if(filter(sta_info.sta_office_tile_list, @(a) a.has_way(wt_rail)).len() == 0)
		{
			local sub_line_pos = finder.coord2D_to_tile(finder.move_coord(branch_rail_list[1], dir.backward(tbl_expand_form_info.expand_dir)))
			// 副本線から1マス外方に延長
			local extend_pos = finder.coord2D_to_tile(finder.move_coord(sub_line_pos, d))
			if(extend_pos == null){ return }
			extend_pos = expand_straight_rail(pl, sub_line_pos, extend_pos)
			if(extend_pos == null)
			{
				// 分岐駅設置に不適切なので、分岐線を廃止し処理終了
				local tool = command_x(tool_remove_way)
				tool.work(pl, branch_rail_list[0], branch_rail_list[1], "" + wt_rail)
				if(branch_rail_list[0].has_way(wt_rail) && branch_rail_list[0].get_way_dirs(wt_rail) == dir.backward(tbl_expand_form_info.expand_dir))
				{
					tool.work(pl, branch_rail_list[0], finder.coord2D_to_tile(finder.move_coord(branch_rail_list[0], dir.backward(tbl_expand_form_info.expand_dir))), "" + wt_rail)
				}
				return
			}
		}

		// 分岐線の1マス外方に線路あり&線路向きが外方+駅舎側の場合
		local extend_pos = finder.coord2D_to_tile(finder.move_coord(branch_rail_list[1], d))
		if(extend_pos == null){ return }
		local temp_tile = branch_rail_list[1]
		local connect_main_branch_flg = false     // 駅舎側延長済みフラグ
		if(extend_pos.has_way(wt_rail))
		{
			if(extend_pos.get_way_dirs(wt_rail) == d + dir.backward(tbl_expand_form_info.expand_dir))
			{
				// 分岐線から1マス外方に延長(既存線路と接続)
				extend_pos = expand_straight_rail(pl, branch_rail_list[1], extend_pos)
				// 既存線路が直線になるまで追跡
				local temp_list = trace_way(extend_pos, wt_rail, d, @(a) !(is_member(a.get_way_dirs(wt_rail), [dir.northsouth, dir.eastwest])))
				// 追跡終了地点が駅拡張側の向きを含む場合、外方の向きを駅拡張側に変更し、駅拡張側の向きを外方の向きの逆向きに変更
				if(temp_list.top().get_neighbour(wt_rail, tbl_expand_form_info.expand_dir) != null)
				{
					local temp_d = d
					d = tbl_expand_form_info.expand_dir
					tbl_expand_form_info.expand_dir = dir.backward(temp_d)
				}
				temp_tile = finder.coord2D_to_tile(finder.move_coord(temp_list.top(), d))
				// そこにポイントあるなら1マス外方に移動
				while(dir.is_threeway(temp_tile.get_way_dirs(wt_rail)))
				{
					temp_tile = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
				}
				// 駅拡張側に延長
				extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, tbl_expand_form_info.expand_dir))
				temp_tile = expand_straight_rail(pl, temp_tile, extend_pos)
				extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
				connect_main_branch_flg = true
			}else{
				// 分岐駅設置に不適切なので、分岐線を廃止し処理終了
				local tool = command_x(tool_remove_way)
				tool.work(pl, branch_rail_list[0], branch_rail_list[1], "" + wt_rail)
				if(branch_rail_list[0].has_way(wt_rail) && branch_rail_list[0].get_way_dirs(wt_rail) == dir.backward(tbl_expand_form_info.expand_dir))
				{
					tool.work(pl, branch_rail_list[0], finder.coord2D_to_tile(finder.move_coord(branch_rail_list[0], dir.backward(tbl_expand_form_info.expand_dir))), "" + wt_rail)
				}
				return
			}
		}

	try{
		while(1)
		{
			// 分岐線末端の1マス外方に線路あり
			if(extend_pos.has_way(wt_rail))
			{
				// 既存線路の向きが外方+駅舎側の場合
				if(extend_pos.get_way_dirs(wt_rail) == d + dir.backward(tbl_expand_form_info.expand_dir))
				{
					// 駅拡張側に延長
					extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, tbl_expand_form_info.expand_dir))
					temp_tile = expand_straight_rail(pl, temp_tile, extend_pos)
					// 分岐線末端から更に1マス外方に線路なし
					extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
					if(extend_pos != null && !(extend_pos.has_way(wt_rail)))
					{
						// 外方に延長
						temp_tile = expand_straight_rail(pl, temp_tile, extend_pos)
						extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
						continue
					}
				}
				// 外方の向きを駅拡張側に変更し、駅拡張側の向きを外方の向きの逆向きに変更
				local temp_d = d
				d = tbl_expand_form_info.expand_dir
				tbl_expand_form_info.expand_dir = dir.backward(temp_d)
			}
			// 分岐線末端から1マス外方に延長
			extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
			temp_tile = expand_straight_rail(pl, temp_tile, extend_pos)
			// 駅舎側延長済みフラグoffかつ駅舎側の線路が三方向でない場合
			// 分岐線と本線を接続する
			extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, dir.backward(tbl_expand_form_info.expand_dir)))
			if(!(connect_main_branch_flg) && !(dir.is_threeway(extend_pos.get_way_dirs(wt_rail))))
			{
				// 駅舎側の線路との段差をなくす
				while(temp_tile.z != extend_pos.z || temp_tile.get_slope() != slope.flat || extend_pos.get_slope() != slope.flat)
				{
					local temp = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
					if(temp_tile.z != extend_pos.z)
					{
						local diff = extend_pos.z - temp_tile.z
						local do_slope = diff > 0 ? slope.all_up_slope : slope.all_down_slope
						command_x.set_slope(pl, temp_tile, do_slope)
						temp_tile = finder.coord2D_to_tile(coord(temp_tile.x, temp_tile.y))
						// 分岐線をスロープにしたので外方に移動
						if(extend_pos.z - temp_tile.z <= 0)
						{
							while(temp.z != temp_tile.z)
							{
								command_x.set_slope(pl, temp, slope.all_up_slope)
								temp = finder.coord2D_to_tile(coord(temp.x, temp.y))
							}
							if(temp_tile.get_slope().to_dir() == coord(temp.x-temp_tile.x,temp.y-temp_tile.y).to_dir())
							{
								command_x.set_slope(pl, temp, slope.all_up_slope)
								temp = finder.coord2D_to_tile(coord(temp.x, temp.y))
							}
						}else{
							do_slope = temp.z - temp_tile.z > 1 ? slope.all_down_slope : slope.all_up_slope
							while(temp.z - temp_tile.z != 1)
							{
								command_x.set_slope(pl, temp, do_slope)
								temp = finder.coord2D_to_tile(coord(temp.x, temp.y))
							}
						}
						// 外方を平坦にする
						if(temp.get_slope() != slope.flat)
						{
							command_x.set_slope(pl, temp, slope.flat)
						}
					}
					
					// 外方に延長
					expand_straight_rail(pl, temp_tile, temp)
					temp_tile = temp
					extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
				}

				// 駅舎側の線路に信号あれば、外方に移設
				if(extend_pos.find_object(mo_signal) != null)
				{
					local sig_desc = extend_pos.find_object(mo_signal).get_desc()
					local sig_dir = extend_pos.get_way_dirs_masked(wt_rail)
					local new_sig_pos_list = trace_way(extend_pos, wt_rail, d, @(a) dir.is_threeway(a.get_way_dirs(wt_rail)))
					while(new_sig_pos_list.top().get_way_dirs_masked(wt_rail) != sig_dir)
					{
						command_x.build_sign_at(pl, new_sig_pos_list.top(), sign_desc)
					}
					extend_pos.remove_object(pl, mo_signal)
				}
				
				// 駅舎側に延長(本線と接続)
				expand_straight_rail(pl, temp_tile, extend_pos)
				connect_main_branch_flg = true
				extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
				continue
			}
			// 駅舎側延長済みフラグonかつ更に1マス外方に線路なし
			extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
			if(connect_main_branch_flg && !(extend_pos.has_way(wt_rail)))
			{
				// 当該タイルを場内信号設置タイルとする
				in_sta_signal_pos = temp_tile
				// 更に1マス外方に延長
				extend_pos = finder.coord2D_to_tile(finder.move_coord(temp_tile, d))
				expand_straight_rail(pl, temp_tile, extend_pos)
				rtn.exit <- extend_pos
				break
			}
		}
		
		// 信号アドオン選択
		local sign_desc = sign_desc_x.get_available_signs(wt_rail)
		sign_desc = filter(sign_desc, @(a) a.is_signal())
		if(sign_desc.len() == 0){ return rtn }
		sign_desc = sort(sign_desc, @(a,b) a.get_cost() <=> b.get_cost())
		// 信号設置
		command_x.build_sign_at(pl, in_sta_signal_pos, sign_desc[0])
		local pre_signal_pos = branch_rail_list[1]
		// 信号アドオン選択
		sign_desc = sign_desc_x.get_available_signs(wt_rail)
		sign_desc = filter(sign_desc, @(a) a.is_pre_signal())
		if(sign_desc.len() == 0){ return rtn }
		sign_desc = sort(sign_desc, @(a,b) a.get_cost() <=> b.get_cost())
		while(pre_signal_pos.get_way_dirs_masked(wt_rail) != origin_d)
		{
			command_x.build_sign_at(pl, pre_signal_pos, sign_desc[0])
		}
		rtn.halt <- halt
		return rtn
	}catch(e)
	{
		// 分岐駅設置に不適切なので、分岐線を廃止し処理終了
		if(temp_tile == null){ temp_tile = branch_rail_list[1] }
		local tool = command_x(tool_remove_way)
		tool.work(pl, branch_rail_list[0], branch_rail_list[1], "" + wt_rail)
		if(branch_rail_list[0].has_way(wt_rail) && branch_rail_list[0].get_way_dirs(wt_rail) == dir.backward(tbl_expand_form_info.expand_dir))
		{
			tool.work(pl, branch_rail_list[0], finder.coord2D_to_tile(finder.move_coord(branch_rail_list[0], dir.backward(tbl_expand_form_info.expand_dir))), "" + wt_rail)
		}
		if(branch_rail_list[1].has_way(wt_rail))
		{
			local list = trace_way(branch_rail_list[1], wt_rail, branch_rail_list[1].get_way_dirs(wt_rail), @(a) !(dir.is_threeway(a.get_way_dirs(wt_rail))))
			if(list.len() > 1)
			{
				tool.work(pl, list[0], list[list.len() - 1], "" + wt_rail)
			}
			rtn.exit <- list.top()
			rtn.halt <- halt
			return rtn
		}
	}
	}

	/***************************************
	 * update_junction_station関数で駅拡張失敗した時の戻り値enter,exitの情報作成
	 * 引数：探索開始地点(tile_x)、分岐側の基準点(tile_x)、プレイヤー会社(player_x)
	 * 戻り値：駅の入場、出場タイル
	 * 　　　　enter：駅に入場するタイル(tile_x)
	 * 　　　　exit：分岐駅から線路敷設する時の始点(tile_x)
	 * 備考 : 探索開始地点はホームがあること
	 ***************************************/
	 function get_sta_enter_exit(pos, branch_side, pl)
	 {
	 	// 分岐開始タイルと線路を分岐させる向き取得
	 	local sort_list = get_boundary_station_pos(pos, 4)
		sort_list = sort(sort_list @(a,b) abs(a.x-branch_side.x)+abs(a.y-branch_side.y) <=> abs(b.x-branch_side.x)+abs(b.y-branch_side.y))
		local sta_dir_list = finder.divide_dir(pos.get_way_dirs(wt_rail))
		local temp_dir_list = [coord(branch_side.x-pos.x, 0).to_dir(), coord(0, branch_side.y-pos.y).to_dir()]
		local end_dir = filter(temp_dir_list, @(a) is_member(a, sta_dir_list))
		temp_dir_list = filter(temp_dir_list, @(a) !(is_member(a, sta_dir_list)))
		local start_dir= dir.none
		if(temp_dir_list.len() == 0 || temp_dir_list[0] == dir.none)
		{
			start_dir = coord(branch_side.x-pos.x, branch_side.y-pos.y).to_dir()
		}else{
			start_dir= temp_dir_list[0]
		}
		
		local tile = sort_list[0]
		// 分岐開始タイル外方に線路がない場合、分岐向きを外方にする
		if(!(is_member(end_dir[0], finder.divide_dir(tile.get_way_dirs(wt_rail)))))
		{
			start_dir = end_dir[0]
		}
		// 分岐線設置可能エリア探索
		local tile_list = []
		while(1)
		{
			tile_list = [finder.coord2D_to_tile(finder.move_coord(tile, start_dir))]
			if(start_dir != end_dir[0])
			{
				tile_list.append(finder.coord2D_to_tile(finder.move_coord(tile_list[0], end_dir[0])))
			}
			if(!(is_member(false, filter(tile_list, @(a) a.is_empty())))){ break }
			if(is_member(null, tile_list)){ return }
			tile = finder.coord2D_to_tile(finder.move_coord(tile, end_dir[0]))
		}
		// 分岐線設置
		local rtn =
		{
			enter = sort_list[1]
			exit = expand_straight_rail(pl, tile, tile_list[0])
		}
		if(tile_list.len() == 2)
		{
			rtn.exit <- expand_straight_rail(pl, tile_list[0], tile_list[1])
		}
		return rtn
	 }

	/***************************************
	 * 駅を撤去
	 * 引数：駅(halt_x)
	 * 戻り値：成功可否
	 ***************************************/
	function remove_halt(halt)
	{
		local pl = halt.get_owner()
		if(pl.nr != our_player_nr){ return false }
		// 路線に所属しているなら撤去しない
		local line_list = halt.get_line_list()
		if(line_list.get_count() > 0){ return false }
		// バス停撤去
		local bus_stop = finder.check_sta_freight_property(halt, wt_road, 2)
		map(bus_stop, @(a) a.remove_object(pl, mo_building))
		
		local rail_stop = finder.check_sta_freight_property(halt, wt_rail, 2)
		// 駅舎撤去
		local tile_list = halt.get_tile_list()
		local sta_office_tile_list = filter(tile_list, @(a) !(is_member(a, rail_stop)))
		sta_office_tile_list = filter(sta_office_tile_list, @(a) !(is_member(a, bus_stop)))
		map(sta_office_tile_list, @(a) a.remove_object(pl, mo_building))
		// 駅撤去
		map(rail_stop, @(a) a.remove_object(pl, mo_building))
		return true
	}

	/***************************************
	 * 分岐線路を1マスずらす
	 * 引数：プレイヤー会社(player_x)、分岐線路のあるタイル(tile_x)、ずらす方向(dir)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function change_pos_point(pl, pos, d)
	{
		local target_dir = pos.get_way_dirs(wt_rail)
		if(!(dir.is_threeway(target_dir))){ return "missing change rail" }
		local t_branch_dir = target_dir - d - dir.backward(d)
		
		local branch_dir_list = []
		if(dir.is_single(t_branch_dir))
		{
			// 分岐先が車庫の場合、車庫を撤去で代用
			local branch_pos = finder.coord2D_to_tile(finder.move_coord(pos, t_branch_dir))
			local depot_rail = branch_pos.find_object(mo_depot_rail)
			if(depot_rail != null)
			{
				local err = branch_pos.remove_object(pl, mo_depot_rail)
				if(err == null)
				{
					local tool = command_x(tool_remove_way)
					err = tool.work(pl, branch_pos, pos, "" + wt_rail)
					if(err != null){ tool.work(pl, branch_pos, branch_pos, "" + wt_rail) }
					if(err == null){ return }
				}
			}
			branch_dir_list.append(t_branch_dir)
		}else{
			if(t_branch_dir == dir.northsouth){ branch_dir_list = [dir.north, dir.south] }
			if(t_branch_dir == dir.eastwest){ branch_dir_list = [dir.east, dir.west] }
		}
		// 新分岐箇所
		local new_branch_pos = finder.coord2D_to_tile(finder.move_coord(pos, d))
		if(!(world.is_coord_valid(new_branch_pos)) || new_branch_pos == null){ return "missing change rail" }
		if(!(new_branch_pos.has_way(wt_rail))){ return "new branch position has no rail" }
		if(new_branch_pos.is_bridge() || new_branch_pos.is_tunnel() || new_branch_pos.get_slope() != slope.flat){ return "new branch position has no flat" }
		// 新分岐箇所に信号がある場合、移設
		local signal = new_branch_pos.find_object(mo_signal)
		if(signal != null)
		{
			local sig_dir = new_branch_pos.get_way_dirs_masked(wt_rail)
			local new_sig_pos_list = trace_way(new_branch_pos, wt_rail, d, @(a) dir.is_threeway(a.get_way_dirs(wt_rail)))
			if(!(dir.is_single(new_sig_pos_list.top())))
			{
				local sig_desc = signal.get_desc()
				while(new_sig_pos_list.top().get_way_dirs_masked(wt_rail) != sig_dir)
				{
					command_x.build_sign_at(pl, new_sig_pos_list.top(), sign_desc)
				}
				new_branch_pos.remove_object(pl, mo_signal)
			}
		}
		
		local catenary = null
		if(pos.find_object(mo_wayobj)){ catenary = pos.find_object(mo_wayobj).get_desc() }
		foreach(branch_dir in _step_generator(branch_dir_list))
		{
			local temp = finder.coord2D_to_tile(finder.move_coord(pos, branch_dir))
			if(temp != null)
			{
				local area_list = [pos, new_branch_pos, temp, finder.coord2D_to_tile(finder.move_coord(temp, d))]
				// 線路敷設箇所を整地
				area_list = finder.flat_tiles(area_list, pl)
				if(temp.is_bridge() || temp.is_tunnel() || area_list == null || !(area_list[3].is_empty())){ continue }
				// 線路アドオンは低規格のものを選択
				local way_desc = select_low_cost_rail()
				// 新しい分岐部分の線路を敷設
				command_x.build_way(pl, area_list[1], area_list[3], way_desc, true)
				command_x.build_way(pl, area_list[3], area_list[2], way_desc, true)
				if(catenary)
				{
					command_x.build_wayobj(pl, area_list[1], area_list[3], catenary)
					command_x.build_wayobj(pl, area_list[3], area_list[2], catenary)
				}
				// 旧分岐部分の線路を撤去
				local tool = command_x(tool_remove_way)
				local err = ""
				// 車両通過中は撤去できないので撤去するまでループ
				while(err != null)
				{
					err = tool.work(pl, area_list[0], area_list[2], "" + wt_rail)
				}
			}
		}
	}

	/***************************************
	 * 駅構内の線路敷設
	 * 引数：プレイヤー会社(player_x)、敷設開始地点(tile_x)、敷設終了地点(tile_x)
	 * 戻り値：実行後の敷設終了地点(tile_x)
	 * 備考：タイルの高さは敷設開始地点を基準とする
	 * 　　　まっすぐのみ敷設可能
	 * 　　　線路延伸に利用する場合は敷設開始地点を線路があるタイルに選ぶ
	 ***************************************/
	function expand_straight_rail(pl, start, end)
	{
		// 建設タイルの高さを揃える
		local target_tile_list = finder.get_interpolate_tile(start, end)
		// 線路以外を除去する
		foreach(target_tile in target_tile_list)
		{
			if(target_tile.find_object(mo_depot_rail) != null)
			{
				// 車庫に列車がいる間、待機
				while(target_tile.find_object(mo_train) != null){ sleep() }
				target_tile.remove_object(pl, mo_depot_rail)
			}
			if(target_tile.has_way(wt_rail)){ continue }
			local obj_list = target_tile.get_objects()
			foreach(obj in _step_generator(obj_list))
			{
				if(obj.get_type() == mo_tree){ break }
				target_tile.remove_object(pl, obj.get_type())
			}
		}	
		target_tile_list = finder.align_height(target_tile_list, start.z, pl, false)
		target_tile_list = finder.flat_tiles(target_tile_list, pl)
		// 建設域の高さを変更したのでtile情報更新
		end = finder.coord2D_to_tile(end)
		// 線路アドオンは低規格のものを選択
		local way_desc = select_low_cost_rail()
		local err = command_x.build_way(pl, start, end, way_desc, true)
		if(err)
		{
			local dist = abs(end.x - start.x) + abs(end.y - start.y)
			local d = coord(end.x - start.x, end.y - start.y).to_dir()
			if(start.has_way(wt_rail))
			{
				d = start.get_way_dirs(wt_rail)
			}
			if(dir.is_single(d))
			{
				local bridge_list = bridge_desc_x.get_available_bridges(wt_rail)
				if(bridge_list.len() == 0){ return }
				local len = 1
				end = bridge_planner_x.find_end(pl, start, d, bridge_list[0], len)
				// 線路敷設時、線路より高規格な道路をオーバーパスする時や
				// 船舶が航行可能な川をheight=8でオーバーパスする時、
				// end.xが負数になるので対処
				while(end.x < 0)
				{
					len++
					if(!end || len < bridge_list[0].get_max_length()){ break }
					end = finder.coord2D_to_tile(finder.move_coord(start, d, len))
				}
				err = command_x.build_bridge(pl, start, end, bridge_list[0])
			}
			if(err){ return }
		}
		return end
	}

	/***************************************
	 * 条件を満たしている間wayをトレース
	 * 引数：トレース開始地点(tile_x)、way_type(enum)、方向(dir)、条件(func)
	 * 戻り値：開始地点から終了地点までのタイルリスト(tile_xのリスト)
	 * 備考：条件はトレース地点に関するもののみ
	 *       途中に分岐があるとそこでトレース終了
	 ***************************************/
	function trace_way(pos, way_type, d, func)
	{
		local rtn = []
		if(!(pos.has_way(way_type))){ return rtn }
		do{
			rtn.append(pos)
			local tbl_pos_list = get_neighbor_rail(pos, d, false)
			if(tbl_pos_list.len() > 1 || tbl_pos_list.len() == 0){ break }
			if(tbl_pos_list[0].dir == dir.backward(d))
			{
				// 線路の終端
				rtn.append(tbl_pos_list[0].pos)
				break
			}
			pos = tbl_pos_list[0].pos
			d = tbl_pos_list[0].dir
		}while(func(pos))
		return rtn
	}
}