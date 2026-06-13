/**
 * Classes for road info
 */

class road_manager_t extends manager_t
{
	constructor() 
	{
		base.constructor("road_manager_t")
	}

	/***************************************
	 * 道路アドオン選択
	 * 引数：プレイヤー属性(player_x)、置き換え対象道路アドオン(way_desc_x)
	 * 戻り値：道路アドオン(way_desc_x)
	 ***************************************/
	function select_road(pl, old_way_desc)
	{
		local way_desc_list = way_desc_x.get_available_ways(wt_road, st_flat)
		if(way_desc_list.len() == 0){ return }
		if(way_desc_list.len() == 1){ return way_desc_list[0] }
		
		local current_speed = 30
		if(old_way_desc != null){ current_speed = old_way_desc.get_topspeed() + 1 }
		// 30km/h未満の道路は除外
		way_desc_list = filter(way_desc_list, @(a) a.get_topspeed() >= current_speed)
		// 建設費の降順でソート
		way_desc_list = sort(way_desc_list, @(a,b) b.get_cost() <=> a.get_cost())
		// 月粗利益取得
		local profit = pl.get_profit()
		// 収入に応じて道路のグレードが上がる
		for(local ii=1; ii<way_desc_list.len(); ii++)
		{
			if( profit[0] >= 100000 / (way_desc_list.len() - 1) * (way_desc_list.len() - ii))
			{
				return way_desc_list[ii-1]
			}
		}
		return way_desc_list.len() != 0 ? way_desc_list.top() : null
	}

	/***************************************
	 * バス停建設
	 * 引数：プレイヤー属性(player_x)、建設座標(tile_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function build_bus_stop(pl, pos)
	{
		// 既にバス停が建っている場合、処理終了
		local halt = pos.get_halt()
		if(halt != null)
		{
			if(halt.get_owner().nr == pl.nr || halt.get_owner().nr == 1)
			{
				return
			}else{
				return "already build other company"
			}
		}
		local station_list = building_desc_x.get_available_stations(building_desc_x.station, wt_road, good_desc_x.passenger)
		// 建設費の安い順にソート
		station_list = sort(station_list, @(a,b) a.get_cost() <=> b.get_cost())
		local err = command_x.build_station(pl, pos, station_list[0])
		return err
	}

	/***************************************
	 * バス停のグレードアップ
	 * 引数：プレイヤー属性(player_x)、バス停(halt_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function update_bus_stop(pl, stop)
	{
		local rtn = null

		local target_tile = finder.check_sta_freight_property(stop, wt_road, 2)
		if(target_tile.len() == 0)
		{
			return "no bus stop"
		}
		target_tile = sort(target_tile, @(a,b) a.find_object(mo_building).get_desc().get_capacity() <=> b.find_object(mo_building).get_desc().get_capacity())
		local capacity = target_tile[0].find_object(mo_building).get_desc().get_capacity()
		
		local station_list = building_desc_x.get_available_stations(building_desc_x.station, wt_road, good_desc_x.passenger)
		station_list = filter(station_list, @(a) a.get_capacity() > capacity)
		station_list = filter(station_list, @(a) a.get_cost() < pl.get_current_net_wealth())
		if(station_list.len() > 0)
		{
			// 建設費の安い順にソート
			station_list = sort(station_list, @(a,b) a.get_cost() <=> b.get_cost())
			// バス停のタイルを取得
			local pos_list = finder.check_sta_freight_property(stop, wt_road, 2)
			foreach(pos in pos_list)
			{
				rtn = command_x.build_station(pl, pos, station_list[0])
			}
		}
		return rtn
	}

	/***************************************
	 * バス路線建設(道路から)
	 * 引数：プレイヤー属性(player_x)、ルート情報(町Idxのarray)
	 * 戻り値：ルート情報(町Idxのarray)
	 ***************************************/
	function build_bus_root(pl, root_info)
	{
		local city_info = persistent.city.get_city_info()
		local bus_stop = []
		foreach(ii in root_info)
		{
			local city = filter(city_list_x(), @(a) compare_coord(a.get_pos(), city_info[ii].townhall))
			// ルート上の各都市内の公共駅取得
			local public_sta_list = []
			local temp = finder.reseach_station_nearest_city(city[0], pl, true)
			if(temp == null)
			{
				public_sta_list = finder.reseach_sta_in_city(city[0], 1)
			}else{
				public_sta_list.append(temp)
			}
			// 公共駅を定員の多い順にソート
			public_sta_list = sort(public_sta_list, @(a,b) b.get_capacity(good_desc_x.passenger) <=> a.get_capacity(good_desc_x.passenger))
			//市域がほぼ重複しているとき、都市内の公共駅が同一駅を指すことがある->当該駅を通過バス停の候補から外す
			if(bus_stop.len() != 0 && public_sta_list.len() != 0)
			{
				local previous_halt = bus_stop.top().get_halt()
				if(previous_halt != null && finder.is_same_halt(previous_halt, public_sta_list[0]))
				{
					public_sta_list.remove(0)
				}
			}
			// 公共駅のバス停の座標取得
			local public_bus_stop = []
			if(public_sta_list.len() != 0)
			{
				public_bus_stop = finder.check_sta_freight_property(public_sta_list[0], wt_road, 2)
			}

			// バス停設置位置選定
			if(public_bus_stop.len() == 0)
			{
				// 既存バスターミナルの座標取得(役場移転に対応)
				local pos = finder.get_bus_terminal(city[0], pl)
				if(pos == null)
				{
					// 役場に最近接の直線道路の座標取得
					pos = finder.get_road_near_townhall(city_info[ii].townhall, pl)
				}
				if(pos != null)
				{
					bus_stop.append(finder.coord2D_to_tile(pos))
				}
			}else{
				// 公共バス停を役場に近い順にソート
				public_bus_stop = sort(public_bus_stop, @(a,b) abs(a.x - city_info[ii].townhall.x) + abs(a.y - city_info[ii].townhall.y) <=> abs(b.x - city_info[ii].townhall.x) + abs(b.y - city_info[ii].townhall.y))
				local num = calc_idx(pl.nr, public_bus_stop.len())
				bus_stop.append(finder.coord2D_to_tile(public_bus_stop[num]))
			}
		}
if(debug_mode){
for(local ii = 0; ii < bus_stop.len(); ii++){
gui.add_message_at(our_player, ii+". "+coord_to_string(bus_stop[ii]), bus_stop[ii])
}
}		
		// 道路接続チェック & 建設
		local as = astar_builder()
		as.builder = way_planner_x(pl)
		// 道路アドオンを選択
		local way = select_road(pl, null)
		if(way == null){ return }
		as.way = way
		as.builder.set_build_types(way)
		as.bridger = pontifex(pl, way)
		if (as.bridger.bridge == null) {
			as.bridger = null
		}
		for(local ii = 0; ii < bus_stop.len() - 1; ii++)
		{
			local rtn = as.search_route([bus_stop[ii]], [bus_stop[ii + 1]])
			if("err" in rtn)
			{
				bus_stop.resize(ii + 1)
				root_info.resize(ii + 1)
				break
			}
		}
		
		// 新規ルートが既存ルートと重複してないかチェック
		if(is_member_in_doublearray(root_info, persistent.used_root)){ return }
		// ルートを設定できないなら終了
		if(bus_stop.len() < 2){ return }
		
		// バス停建設
		local del_root = []
		for(local ii = 0; ii < bus_stop.len(); ii++)
		{
			local err = build_bus_stop(pl, bus_stop[ii])
			if(err)
			{
				// 建設リトライ
				local pos = finder.get_road_near_townhall(city_info[root_info[ii]].townhall, pl)
				if(pos != null)
				{
					bus_stop[ii] = finder.coord2D_to_tile(pos)
					err = build_bus_stop(pl, bus_stop[ii])
				}
				if(err)
				{
					gui.add_message_at(pl, "failed build busstop at "+ coord_to_string(bus_stop[ii]), bus_stop[ii])
					del_root.append(ii)
				}
			}
		}
		// バス停を建設できなかった町をルート情報から消す
		for(local ii = 0; ii < del_root.len(); ii++)
		{
			bus_stop.remove(del_root[ii])
			root_info.remove(del_root[ii])
			for(local jj = ii; jj < del_root.len(); jj++)
			{
				del_root[jj]--
			}
		}
		if(is_member_in_doublearray(root_info, persistent.used_root)){ return }
		if(bus_stop.len() < 2){ return }

		// 車庫探索・建設
		local depot_pos = 0
		if(bus_stop.len() != 0)
		{
			local idx = 0
			do
			{
				depot_pos = search_bus_depot(bus_stop[idx], pl)
				idx++
			}while(depot_pos == null && idx < bus_stop.len())
			local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
			// バス購入
			local vehicle = vehicle_constructor_t()
			local convoy = vehicle.buy_convoy(depot, pl, wt_road, null)
			if(convoy != null)
			{
				// スケジュール設定
				local schedule = vehicle.set_line(bus_stop, null, pl)
				convoy.set_line(pl, schedule)
				// 運行開始
				depot.start_convoy(pl, convoy)
				return root_info
			}
		}
	}

	/***************************************
	 * タイルに引数の向きと直交以外の道路があるかチェック
	 * 引数：座標(tile_x)、向き(dir)
	 * 戻り値：true:直交以外の道路がある false:直交道路があるor道路なし
	 * 備考：道路標識は考慮しない
	 ***************************************/
	 function check_not_cross_road(tile, d)
	 {
	 	local rtn = false
	 	if(tile.has_way(wt_road))
	 	{
	 		local target_dir = tile.get_way_dirs(wt_road)
	 		if(2 * d != target_dir && d != 2 * target_dir)
	 		{
	 			rtn = true
	 		}
	 	}
	 	return rtn
	 }

	/***************************************
	 * 道路付け替え処理
	 * 引数：撤去する道路の座標リスト(tile_xのリスト)、道路ずらす方向(dir)、プレイヤー会社(player_x)
	 * 戻り値：撤去失敗したタイルリスト(tile_xのリスト)
	 ***************************************/
	function move_road(tile_list, d, pl)
	{
		local rtn = []
		local tile_list = filter(tile_list, @(a) a.has_way(wt_road))
		if(tile_list.len() == 0){ return rtn }
		// 道路アドオンを選択
		local way = select_road(pl, null)
		if(way == null){ return rtn }
		foreach(tile in tile_list)
		{
			local road_dir = tile.get_way_dirs(wt_road)
			local road_dir_list = finder.divide_dir(road_dir)
			road_dir_list = filter(road_dir_list, @(a) a != d)
			// 付け替え後のタイル取得
			local new_tile = tile.get_neighbour(wt_road, d)
			if(new_tile != null && finder.can_remove_all_objects(tile, pl))
			{
				// 空き地にする
				local obj_list = tile.get_objects()
				foreach(obj in _step_generator(obj_list))
				{
					if(obj.get_type() == mo_tree){ break }
					target_tile.remove_object(pl, obj.get_type())
				}
				foreach(road_d in road_dir_list)
				{
					command_x.build_road(pl, new_tile, new_tile.get_neighbour(wt_road, road_d), way, true, true)
				}
			}else{
				rtn.append(tile)
				continue
			}
			// バス停がある場合
			if(tile.get_halt() != null)
			{
				build_bus_stop(pl, new_tile)
				// 駅が公共駅の場合
				if(tile.get_halt().get_owner().nr == 1)
				{
					local sta_name = tile.get_halt().get_name()
					local cmd = command_x(tool_make_stop_public)
					cmd.work(pl, new_tile)
					tile.get_halt().set_name(sta_name)
				}
				// バスのスケジュール変更
				local cmd = command_x(tool_stop_mover)
				cmd.work(pl, tile, new_tile, "")
			}
		}
		return rtn
	}

	/***************************************
	 * 道路高速化
	 * 引数：対象バス路線(line_x)
	 * 戻り値：
	 ***************************************/
	function update_road(line)
	{
		local schedule_entries = line.get_schedule().entries
		local sche_len = schedule_entries.len()
		// 路線の末端側から自社所有のタイルを通過する区間取得
		local pl = line.get_owner()
		local ii = sche_len / 2
		local pl_tile_list = []
		local asf = astar_route_finder(wt_road)
		while(ii > 0 && pl_tile_list.len() == 0)
		{
			local res = asf.search_route([schedule_entries[ii]], [schedule_entries[ii - 1]])
			if ("err" in res)
			{
				gui.add_message_at(pl,"err:"+res.err+",["+coord_to_string(schedule_entries[ii])+"] -> ["+coord_to_string(schedule_entries[ii - 1])+"]",world.get_time())
				return
			}
			// 自社所有のタイル取得
			pl_tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
			pl_tile_list = filter(pl_tile_list, @(a) a.get_way(wt_road) != null)
			pl_tile_list = filter(pl_tile_list, @(a) a.get_way(wt_road).get_owner().nr == pl.nr)
			ii--
		}
		if(pl_tile_list.len() == 0){ return }
		// 最低規格の道路アドオン取得
		local obj_list =map(pl_tile_list, @(a) a.find_object(mo_way))
		local used_way_speed_list = unique(map(obj_list, @(a) a.get_desc().get_topspeed()))
		used_way_speed_list = sort(used_way_speed_list, @(a,b) a <=> b)

		local way_desc_list = way_desc_x.get_available_ways(wt_road, st_flat)
		way_desc_list = filter(way_desc_list, @(a) a.get_topspeed() == used_way_speed_list[0])
		// アップデート後の道路アドオン取得
		local way = select_road(pl, way_desc_list[0])
		if(way == null){ return }

		// 道路引き直し
		for(local ii = 0; ii < sche_len / 2; ii++)
		{
			local res = asf.search_route([schedule_entries[ii]], [schedule_entries[ii + 1]])
			if ("err" in res)
			{
				gui.add_message_at(pl,"err:"+res.err+",["+coord_to_string(schedule_entries[ii])+"] -> ["+coord_to_string(schedule_entries[ii + 1])+"]",world.get_time())
				break
			}
			// 事業実施判断
			local cost = way.get_cost()
			local mainte = way.get_maintenance()
			if(!(judge_investment(cost * res.routes.len(), (mainte - way_desc_list[0].get_maintenance()) * res.routes.len()))){ return }

			local tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
			// 立体交差している箇所を除外
			tile_list = filter(tile_list, @(a) a.get_way(wt_road) != null)
			for(local jj = 0; jj < tile_list.len() - 1; jj++)
			{
				// 市道はスキップ
				if(tile_list[jj].get_way(wt_road).get_owner().nr == city_player_nr){ continue }
				if(tile_list[jj + 1].get_way(wt_road).get_owner().nr == city_player_nr){ continue }
				command_x.build_way(pl, tile_list[jj], tile_list[jj + 1], way, false )
			}
		}
	}

	/***************************************
	 * バス車庫探索
	 * 引数：バス停座標(tile_x)、会社属性(player_x)
	 * 戻り値：バス車庫座標(tile_x)
	 ***************************************/
	function search_bus_depot(bus_stop, pl)
	{
		// 車庫探索
		local depot_list = depot_x.get_depot_list(pl, wt_road)
		if(depot_list.len() == 0)
		{
			// 車庫建設
			local c_depot = build_bus_depot(bus_stop, pl)
			return c_depot
		}else{
			// バス停と車庫との接続チェック
			local asf = astar_route_finder(wt_road)
			local ii = 0
			foreach(depot in depot_list)
			{
				local res = asf.search_route([bus_stop], [depot.get_pos()])
				if ("routes" in res)
				{
					break
				}
				ii++
			}
			if(ii >= depot_list.len())
			{
				// 既存の車庫では出庫できないので、車庫建設
				local c_depot = build_bus_depot(bus_stop, pl)
				return c_depot
			}
			return tile_x(depot_list[ii].get_pos().x, depot_list[ii].get_pos().y, depot_list[ii].get_pos().z)
		}
	}

	/***************************************
	 * バス車庫建設
	 * 引数：建設基準座標(この座標付近の空き地に建設)(tile_x)、会社属性(player_x)
	 * 戻り値：バス車庫座標(tile_x)
	 ***************************************/
	function build_bus_depot(pos, pl)
	{
		//車庫建設場所の準備
		local as = depot_pathfinder()
		as.builder = way_planner_x(pl)
		// 道路アドオンを選択
		local way = select_road(pl, null)
		if(way == null){ return }
		as.builder.set_build_types(way)
		local res = as.search_route(pos, way)

		if ("err" in res) {
			gui.add_message_at(pl, " "+res.err, world.get_time())
			return
		}
		local d = res.end
		local c_depot = tile_x(d.x, d.y, d.z)

		// バス車庫建設
		local depot_list = building_desc_x.get_building_list(building_desc_x.depot)
		// バス車庫を抽出
		depot_list= filter(depot_list, @(a) a.get_waytype() == wt_road && a.get_type() == building_desc_x.depot)
		local err = command_x.build_depot(pl, c_depot, depot_list[0])
		if(err)
		{
			gui.add_message_at(pl, "Failed construct bus depot with "+err, c_depot)
			return
		}
		return c_depot
	}
}

/***************************************
 * バス車庫建設場所検索クラス
 * ：
 ***************************************/
class depot_pathfinder extends astar_builder
{
	function estimate_distance(c)
	{
		local t = tile_x(c.x, c.y, c.z)
		if (t.is_empty()  &&  t.get_slope()==0) {
			return 0
		}
		local depot = t.find_object(mo_depot_road)
		if (depot  &&  depot.get_owner().nr == our_player_nr) {
			return 0
		}
		return 10
	}

	function add_to_open(c, weight)
	{
		if (c.dist == 0) {
			// test for depot
			local t = tile_x(c.x, c.y, c.z)
			if (t.is_empty()) {
				// depot not existing, we must build, increase weight
				weight += 25 * cost_straight
				if (t.get_slope() != 0) { weight += 25 * cost_straight }
			}
		}
		base.add_to_open(c, weight)
	}

	function search_route(start, way)
	{
		prepare_search()

		local dist = estimate_distance(start)
		add_to_open(ab_node(start, null, 1, dist+1, dist, 0), dist+1)

		search()

		if (route.len() > 1) {

			for (local i = 1; i<route.len(); i++) {
				local err = command_x.build_way(our_player, route[i-1], route[i], way, false )
				if (err) {
					gui.add_message_at(our_player, "Failed to build road from  " + coord_to_string(route[i-1]) + " to " + coord_to_string(route[i]) +"\n" + err, route[i])
					return { err =  err }
				}
			}
			return { start = route[ route.len()-1], end = route[0] }
		}
		print("No route found")
		return { err =  "No route" }
	}
}