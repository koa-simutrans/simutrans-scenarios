/**
 * Helper static functions to find places for stations, depots, etc.
 */

class finder {

	/*********************************************
	 * 2D座標から3D座標取得
	 * 引数：2D座標(Coord)
	 *********************************************/
	static function coord2D_to_3D(pos)
	{
		if(pos == null){ return }
		local ground = square_x(pos.x, pos.y)
		local tile_info = ground.get_ground_tile()
		return coord3d(tile_info.x, tile_info.y, tile_info.z)
	}

	/*********************************************
	 * 2D座標からtile_x情報取得
	 * 引数：2D座標(Coord)
	 *********************************************/
	static function coord2D_to_tile(pos)
	{
		if(pos == null){ return }
		local ground = square_x(pos.x, pos.y)
		return ground.get_ground_tile()
	}

	/*********************************************
	 * 方角から座標取得
	 * 引数：座標(Coord)、方角(dir)、n(int)
	 * 戻り値：方角にnマスずれた座標(Coord)
	 *********************************************/
	static function move_coord(pos, d, n = 1)
	{
		local rtn = null
		switch(d)
		{
			case dir.north:
			rtn = coord(pos.x, pos.y - n)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break
			case dir.east:
			rtn = coord(pos.x + n, pos.y)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break
			case dir.west:
			rtn = coord(pos.x - n, pos.y)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break
			case dir.south:
			rtn = coord(pos.x, pos.y + n)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break

			case dir.northeast:
			rtn = coord(pos.x + n, pos.y - n)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break
			case dir.southeast:
			rtn = coord(pos.x + n, pos.y + n)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break
			case dir.northwest:
			rtn = coord(pos.x - n, pos.y - n)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break
			case dir.southwest:
			rtn = coord(pos.x - n, pos.y + n)
			if(!(world.is_coord_valid(rtn))){ return null }
			return rtn
			break
		}
		return null
	}

	/*********************************************
	 * 方角を90度変える
	 * 引数：方角(dir)、右回り(true)左回り(false)(boolean)
	 * 戻り値：方角(dir)
	 *********************************************/
	static function rotate_right_angle(d, is_right_rot)
	{
		switch(d)
		{
			case dir.north:
			if(is_right_rot){ return dir.east }
			else{ return dir.west }
			break
			case dir.south:
			if(is_right_rot){ return dir.west }
			else{ return dir.east }
			break
			case dir.east:
			if(is_right_rot){ return dir.south }
			else{ return dir.north }
			break
			case dir.west:
			if(is_right_rot){ return dir.north }
			else{ return dir.south }
			break
		}
	}

	/*********************************************
	 * 二以上の方向を単一方向に分解する
	 * 引数：方角(dir)
	 * 戻り値：方角リスト(dirのリスト)
	 *********************************************/
	static function divide_dir(d)
	{
		if(dir.is_single(d)){ return [d] }
		local rtn_list = []
		if(d > dir.west)
		{
			rtn_list.append(dir.west)
			d = d - dir.west
		}
		if(d >= dir.south)
		{
			rtn_list.append(dir.south)
			d = d - dir.south
		}
		if(d >= dir.east)
		{
			rtn_list.append(dir.east)
			d = d - dir.east
		}
		if(d == dir.north)
		{
			rtn_list.append(dir.north)
		}
		return rtn_list
	}

	/*********************************************
	 * 市域内の対象の会社所有の駅検索
	 * 引数：町情報(city_x)、プレイヤーIdx(プレイヤ会社:0、公共事業:1、ライバル会社:2~)
	 * 戻り値：市域内の対象の会社所有の駅リスト(halt_xのリスト)
	 *********************************************/
	static function reseach_sta_in_city(city_info, player_nr)
	{
		local rtn = []

		// 駅一覧取得
		local sta_list = filter(halt_list_x(), (@(a) a.get_owner().nr == player_nr))

		// 駅が市域に重なっているか、チェック
		foreach(sta in sta_list)
		{
			local sta_area = sta.get_tile_list()
			sta_area = filter(sta_area, @(a) a.x >= city_info.get_pos_nw().x && a.x <= city_info.get_pos_se().x && a.y >= city_info.get_pos_nw().y && a.y <= city_info.get_pos_se().y)
			if(sta_area.len() != 0)
			{
				rtn.append(sta)
			}
		}

		return rtn
	}

	/*********************************************
	 * 町最近接の駅検索
	 * 引数：町情報(city_x)、プレイヤー会社(player_x)、公共駅を検索対象に入れるかどうか(Boolean)
	 * 戻り値：当該駅(halt_x)
	 * 備考：プレイヤー会社所属駅or公共駅を返す
	 *********************************************/
	static function reseach_station_nearest_city(city, pl, blnIncludePub)
	{
		// プレイヤー会社所属駅or公共駅一覧取得
		local halt_list = filter(halt_list_x(), @(a) check_sta_freight_property(a, wt_rail, 2).len() != 0)
		if(halt_list.len() == 0){ return }
		halt_list = filter(halt_list, @(a) a.get_owner().nr == pl.nr || a.get_owner().nr == 1)
		if(halt_list.len() == 0){ return }
		// 引数の町役場が近い駅一覧取得
		halt_list = filter(halt_list, @(a) compare_coord(find_nearest_city(a.get_tile_list().top()).get_pos(), city.get_pos()))
		if(halt_list.len() == 0){ return }
		// 公共駅があればそれ返す
		local public_sta_list = filter(halt_list, @(a) a.get_owner().nr == 1)
		if(public_sta_list.len() > 0 && blnIncludePub)
		{
			// 駅の定員で降順ソート
			if(public_sta_list.len() > 1)
			{
				public_sta_list = sort(public_sta_list, @(a,b) b.get_capacity(good_desc_x.passenger) <=> a.get_capacity(good_desc_x.passenger))
			}
			return public_sta_list[0]
		}else{
			// 町最近接の駅ならバス停あるはず
			halt_list = filter(halt_list, @(a) check_sta_freight_property(a, wt_road, 2).len() != 0 && a.get_owner().nr == pl.nr)
			if(halt_list.len() == 0){ return }
			// 駅の定員で降順ソート
			if(halt_list.len() > 1)
			{
				halt_list = sort(halt_list, @(a,b) b.get_capacity(good_desc_x.passenger) <=> a.get_capacity(good_desc_x.passenger))
			}
			return halt_list[0]
		}
	}

	/*********************************************
	 * バス以外の交通機関がある公共駅検索
	 * 引数：なし
	 * 戻り値：当該駅(halt_x)
	 *********************************************/
	static function get_complex_public_sta()
	{
		local public_sta = filter(halt_list_x(), (@(a) a.get_owner().nr == 1))
		local rtn = []
		foreach(sta in public_sta)
		{
			local convoy_list = sta.get_convoy_list()
			convoy_list = filter(convoy_list, @(a) a.get_waytype() != wt_road)
			if(convoy_list.len() != 0)
			{
				rtn.append(sta)
			}
		}
		return rtn
	}

	/*********************************************
	 * 発着する路線の停車位置取得
	 * 引数：駅(halt_x)
	 * 戻り値：各路線の停車位置情報(table)
	 *           line：路線情報(line_x)
	 *           stop：停車位置(tile_x)
	 *********************************************/
	static function get_line_info_in_sta(halt)
	{
		local rtn = []
		local line_list = halt.get_line_list()
		local owner = halt.get_owner()
		foreach(line in line_list)
		{
			if(line.get_waytype() != wt_rail){ continue }
			local schedule_entry = line.get_schedule().entries
			schedule_entry = filter(schedule_entry, @(a) a.get_halt(owner) != null)
			schedule_entry = filter(schedule_entry, @(a) is_same_halt(a.get_halt(owner), halt))
			foreach(schedule in _step_generator(schedule_entry))
			{
				local tbl =
				{
					line = line
					stop = coord2D_to_tile(schedule)
				}
				rtn.append(tbl)
			}
		}
		return rtn
	}

	/*********************************************
	 * 対象貨物属性を付与する駅施設の存在を駅のタイルごとにチェック
	 * 引数：駅情報(halt_x)、way-type、対象貨物属性(0:荷物、1:郵便、2:旅客)
	 * 戻り値：対象貨物属性が付いた建築物が作られたタイルリスト(tile_x)
	 *********************************************/
	static function check_sta_freight_property(sta, way_type, freight)
	{
		local rtn = []
		local sta_area = sta.get_tile_list()
		sta_area = filter(sta_area, (@(a) a.has_way(way_type)))
		foreach(tile in sta_area)
		{
			local obj = tile.find_object(mo_building)
			switch(freight)
			{
				case 0:
				if(obj.get_desc().enables_freight()){ rtn.append(tile) }
				break
				case 1:
				if(obj.get_desc().enables_mail()){ rtn.append(tile) }
				break
				case 2:
				if(obj.get_desc().enables_pax()){ rtn.append(tile) }
				break
			}
		}
		return rtn
	}

	/*********************************************
	 * ターゲット座標がバス停設置可能かチェック
	 * 引数：ターゲットの2D座標(Coord)、プレイヤー属性(player_x)
	 * 戻り値：true:バス停設置可能
	 *********************************************/
	static function get_put_bus_stop_tile(c_target, pl)
	{
		local tile = coord2D_to_tile(c_target)
		// 橋の端はスロープなら設置不可
		if(tile.is_bridge())
		{
			return tile.get_slope() == 0 ? false : true
		}
		// 平坦の直線道路の座標を戻り値に格納
		if(tile.get_slope() == 0 && tile.has_way(wt_road) && !(tile.has_way(wt_rail)))
		{
			if(dir.is_straight(tile.get_way_dirs(wt_road)))
			{
				// 道路が他社占有なら除外(pl.nrはplayer_all=15,市道=16)
				local road_owner = tile.get_way(wt_road).get_owner().nr
				if(road_owner != 1 && road_owner != pl.nr && road_owner < player_all){ return false }
				// 車庫が建っているなら除外
				if(tile.get_depot() != null){ return false }
				// 他社に占有済みのタイルは除外
				local halt = tile.get_halt()
				if(halt != null)
				{
					if(halt.get_owner().nr != pl.nr)
					{
						return false
					}
				}
				return true
			}
		}
		return false
	}

	/*********************************************
	 * 役場そばの道路の座標取得
	 * 引数：役場の2D座標(Coord)、建設するプレイヤー属性(player_x)
	 * 戻り値：役場最近接の直線道路の座標(Coord)
	 *********************************************/
	static function get_road_near_townhall(pos, pl)
	{
		local rtn = []
		local cov = settings.get_station_coverage()
		for(local dx = -cov; dx <= cov; dx++)
		{
			for(local dy = -cov; dy <= cov; dy++)
			{
				local c_target = coord(pos.x + dx, pos.y + dy)
				if(!(world.is_coord_valid(c_target)))
				{
					continue
				}
				if(get_put_bus_stop_tile(c_target, pl))
				{
					rtn.append(c_target)
				}
			}
		}
		if(rtn.len() == 0)
		{
			// 役場をカバーできないけどできるだけ近場の直線道路を検索
			// 最大検索回数の11はなんとなくで設定
			local temp = find_target_places(pos, 1, 1, cov + 1, 11, @(a) get_put_bus_stop_tile(a, pl))
			foreach(tmp in temp)
			{
				rtn.append(tmp)
			}
		}

		// 役場に最近接の直線道路を取得
		rtn = sort(rtn, @(a,b) abs(a.x-pos.x)+abs(a.y-pos.y) <=> abs(b.x-pos.x)+abs(b.y-pos.y))

		if(rtn.len() == 0){ return }
		return rtn[0]
	}

	/*********************************************
	 * 市内のバス停の存在チェック
	 * 引数：町情報(city_x)、プレイヤー属性(player_x)、市域外探索フラグ(boolean)
	 * 戻り値：バス停情報リスト(halt_xのリスト)
	 * 備考：市域外のバス停も検索
	 *********************************************/
	static function check_busstop_in_city(city, pl, out_area_flg)
	{
		//try
		//{
			// 市域内に自社のバス停があるかチェック
			local bus_stop = reseach_sta_in_city(city, pl.nr)
			// 市域内に公共駅のバス停があるかチェック
			if(pl.nr != 1)
			{
				local public_bus_stop = reseach_sta_in_city(city, 1)
				if(public_bus_stop.len() != 0)
				{
					// 公共駅のバス停に自社便が発着しているかチェック
					foreach(stop in public_bus_stop)
					{
						bus_stop.append(stop)
					}
				}
			}
			bus_stop = filter(bus_stop, @(a) check_sta_freight_property(a, wt_road, 2).len() != 0)

			if(out_area_flg)
			{
				// 駅一覧取得
				local halt_list = filter(halt_list_x(), @(a) check_sta_freight_property(a, wt_road, 2).len() != 0)
				local sta_list = filter(halt_list, @(a) a.get_owner().nr == pl.nr)
				if(pl.nr != 1)
				{
					local public_bus_stop = filter(halt_list, @(a) a.get_owner().nr == 1)
					// 公共駅のバス停に自社便が発着しているかチェック
					foreach(stop in public_bus_stop)
					{
						local line_list = filter(stop.get_line_list(), @(a) a.get_owner().nr == pl.nr)
						if(line_list.len() != 0)
						{
							sta_list.append(stop)
						}
					}
				}

				// 役場に近い駅探索
				foreach(sta in sta_list)
				{
					local sta_area = sta.get_tile_list()
					if(sta_area.len() == 0){ continue }
					local sta_nearest_city = find_nearest_city(sta_area[0])
					if(city.get_name() == sta_nearest_city.get_name())
					{
						if(is_member(true, map(bus_stop, @(a) is_same_halt(a, sta)))){ continue }
						bus_stop.append(sta)
						break
					}
				}
			}
			return bus_stop
		/*}catch(e)
		{
			local bus_stop = []
			return bus_stop
		}*/
	}

	/*********************************************
	 * 市内のターミナルバス停の存在チェック
	 * 引数：町情報(city_x)、プレイヤー属性(player_x)
	 * 戻り値：ターミナルバス停の座標(tile_x)
	 *********************************************/
	static function get_bus_terminal(city, pl)
	{
		/* ターミナルバス停とは
		   ①鉄道駅そばのバス停
		   ②市内交通の全系統と都市間連絡バスが
		   発着するバス停なので要は市内で最も多くのバス系統が通過する
		   バス停のことである */

		// 近くの駅検索
		local station = reseach_station_nearest_city(city, pl, true)
		if(station != null)
		{
			// 別の町の駅がヒットしないように
			// 町の名前が入っているor公共駅に絞る
			if(station.get_owner().nr == 1 || station.get_name().find(city.get_name()) != null)
			{
				// バス停あるか
				local bus_stop_list = check_sta_freight_property(station, wt_road, 2)
				if(bus_stop_list.len() > 0)
				{
					local idx = calc_idx(pl.nr, bus_stop_list.len())
					return bus_stop_list[idx]
				}
			}
		}

		// 市域内に自社が使うバス停があるかチェック
		local bus_stop = check_busstop_in_city(city, pl, 1)
		if(bus_stop.len() == 0){ return }

		// 最も多くの自社路線が発着しているバス停を検索
		local tbl_stop_list = []
		foreach(stop in bus_stop)
		{
			local line_list = stop.get_line_list()
			line_list = filter(line_list, @(a) a.get_owner().nr == pl.nr)
			local tbl_stop =
			{
				line_list = line_list
				stop = stop
			}
			tbl_stop_list.append(tbl_stop)
		}
		tbl_stop_list = sort(tbl_stop_list, @(a,b) b.line_list.len() <=> a.line_list.len())
		local tile_list = check_sta_freight_property(tbl_stop_list[0].stop, wt_road, 2)
		local idx = calc_idx(pl.nr, tile_list.len())
		return tile_list[idx]
	}

	/*********************************************
	 * 市内交通用のバス停設置候補の座標取得
	 * 引数：町情報(city_x)、建設するプレイヤー属性(player_x)
	 * 戻り値：バス停設置候補の座標リスト(tile_x)
	 *********************************************/
	static function get_road_for_city_bus(city, pl)
	{
		local rtn = []
		// 市域内に自社が使うバス停があるかチェック
		local bus_stop = check_busstop_in_city(city, pl, 1)
		if(bus_stop.len() == 0){ return rtn }
		// 公共バス停が含まれる場合、自社便が設定されているかチェック
		local temp_list = filter(bus_stop, @(a) a.get_owner().nr == 1)
		local flg_list = []
		foreach(temp in temp_list)
		{
			local convoy_owner_list = map(temp.get_line_list(), @(a) a.get_owner().nr)
			if(is_member(pl.nr, convoy_owner_list)){ flg_list.append(1) }
		}
		if(flg_list.len() == 0 && temp_list.len() == bus_stop.len()){ return rtn }

		// 直線道路・建物の座標取得
		local straight_road_list = []
		local building_area_list = []
		for(local ii = city.get_pos_nw().x; ii < city.get_pos_se().x; ii++)
		{
			for(local jj = city.get_pos_nw().y; jj < city.get_pos_se().y; jj++)
			{
				local tile = coord2D_to_tile(coord(ii, jj))
				if(tile.get_slope() == 0 && tile.has_way(wt_road) && !(tile.has_way(wt_rail)))
				{
					if(dir.is_straight(tile.get_way_dirs(wt_road)))
					{
						// 既にバス停がある道路は除外(公共駅は除く)
						if(tile.get_halt() == null || tile.get_halt().get_owner().nr == 1)
						{
							straight_road_list.append(tile)
						}
					}
				}else{
					if(!(tile.is_ground())){ continue }
					foreach(obj in tile.get_objects())
					{
						if(obj.get_type() == mo_building)
						{
							building_area_list.append(tile)
							break
						}
					}
				}
			}
		}

		// 自社駅・自社便が乗り入れる公共駅と当該駅がカバーするタイルを除外
		local cov = settings.get_station_coverage()
		local t_bus_stop = []
		foreach(stop in bus_stop)
		{
			local cover_area = stop.get_tile_list()
			local t_cover_area = clone(cover_area)
			t_bus_stop = combine(t_bus_stop, cover_area)
			foreach(area in cover_area)
			{
				for(local dx = -cov; dx <= cov; dx++)
				{
					for(local dy = -cov; dy <= cov; dy++)
					{
						local c_target = coord(area.x+dx, area.y+dy)
						if(!(world.is_coord_valid(c_target)) || is_member(c_target, t_cover_area))
						{
							continue
						}
						t_cover_area.append(coord2D_to_tile(c_target))
					}
				}
			}
			building_area_list = filter(building_area_list, @(a) !(is_member(a, t_cover_area)))
		}

		// 他社占有の道路は除外
		straight_road_list = filter(straight_road_list, @(a) get_put_bus_stop_tile(a, pl))
		// 既存バス停に近接している道路から調査
		local a_bus_stop = filter(t_bus_stop, @(a) a.has_way(wt_road))
		straight_road_list = sort(straight_road_list, @(a,b) abs(a.x-a_bus_stop.top().x)+abs(a.y-a_bus_stop.top().y) <=> abs(b.x-a_bus_stop.top().x)+abs(b.y-a_bus_stop.top().y))

		// バス停新設にふさわしいかチェック
		// TODO : 乗り入れてない公共駅は積極的に選択したい
		foreach(road in straight_road_list)
		{
			local continue_flg = false
			// 既存バス停から5距離(駅の網羅長さ)以上離れている
			foreach(stop in t_bus_stop)
			{
				local diff = abs(road.x-stop.x)+abs(road.y-stop.y)
				if(diff < 2 * cov + 1)
				{
					continue_flg = true
					break
				}
			}
			if(continue_flg){ continue }
			// 建物の数が10以上、または旅客ﾚﾍﾞﾙの合計が3以上または、建物数問わず旅客ﾚﾍﾞﾙの合計が20以上を満たす所をバス停候補にする
			local t_bldg_list = []
			for(local dx = -cov; dx <= cov; dx++)
			{
				for(local dy = -cov; dy <= cov; dy++)
				{
					local c_target = coord(road.x+dx, road.y+dy)
					if(!(world.is_coord_valid(c_target))){ continue }
					local tile = coord2D_to_tile(c_target)
					if(!(is_member(tile, building_area_list))){ continue }
					if(tile.get_halt() != null){ continue }
					t_bldg_list.append(tile)
				}
			}
			local tbl_bldg_info = get_area_bldg_info(t_bldg_list)
			if(tbl_bldg_info.bldg_counter >= 10 || tbl_bldg_info.total_bldg_level >= 3 || tbl_bldg_info.total_bldg_level >= 20)
			{
				rtn.append(road)
				t_bus_stop.append(road)
				building_area_list = filter(building_area_list, @(a) !(is_member(a, tbl_bldg_info.bldg_tile_list)))
			}
		}
		return rtn
	}

	/*********************************************
	 * 条件の合うタイル検索
	 * 候補の基準となる座標を左上として同心円状に検索していく
	 * 引数：候補の基準となる座標(Coord)、候補の横幅(int)、候補の縦幅(int)、検索回数開始位置(int)、最大検索回数(int)、検索条件の関数
	 * 戻り値：条件の合うタイルリスト(tile_x)
	 * 備考：候補がマルチタイル(候補の横幅、縦幅のいずれかが2以上)の場合、左上を返す
	 *       検索回数開始位置とは、検索開始時に予め上下左右に候補の横幅、縦幅ずつずらしておくという意味
	 *         例えばx=1,y=1,init_cov=3の場合、target座標から上下左右に±2の座標が検索対象外となる
	 *       最大検索回数とは、基準となる座標から上下左右に候補の横幅、縦幅ずつ最大検索回数回ずらした地点まで検索するという意味
	 *         例えばx=1,y=1,max_cov=5の場合、target座標から上下左右に±4の座標まで検索する
	 *********************************************/
	static function find_target_places(target, x, y, init_cov, max_cov, func)
	{
		if(max_cov > world.get_size().x && max_cov > world.get_size().y){ return null }
		local rtn = []
		local cov = init_cov
		while(rtn.len() == 0 && cov < max_cov)
		{
			for(local dx = -cov; dx <= cov; dx++)
			{
				// 検索エリア範囲をx,yとしてtargetの上側を検索
				local target_area_list = []
				local continue_flg = false
				local search_area_reverse_flg = true
				for(local ii=target.x + dx; ii<target.x + dx + x; ii++)
				{
					for(local jj=target.y - cov; jj>target.y - cov - y; jj--)
					{
						local c_target = coord(ii ,jj)
						if(!(world.is_coord_valid(c_target)))
						{
							continue_flg = true
							break
						}
						target_area_list.append(coord2D_to_tile(c_target))
					}
					if(continue_flg){ break }
				}
				if(!(continue_flg))
				{
					// 検索エリアに対する検索条件結果取得
					local result_list = map(target_area_list, func)
					if(!(is_member(false, result_list)))
					{
						local rtn_temp = coord2D_to_tile(coord(target.x + dx, target.y - cov - y + 1))
						if(!(is_member(rtn_temp, rtn)))
						{
							rtn.append(rtn_temp)
							search_area_reverse_flg = false
						}
					}
					// cov=0の場合、以降の処理は同じタイルを検索するのでここで終了
					if(cov == 0){ break }
				}

				if(search_area_reverse_flg && cov < y)
				{
					target_area_list = []
					continue_flg = false
					for(local ii=target.x + dx; ii<target.x + dx + x; ii++)
					{
						for(local jj=target.y - cov; jj<target.y - cov + y; jj++)
						{
							local c_target = coord(ii ,jj)
							if(!(world.is_coord_valid(c_target)))
							{
								continue_flg = true
								break
							}
							target_area_list.append(coord2D_to_tile(c_target))
						}
						if(continue_flg){ break }
					}
					if(!(continue_flg))
					{
						// 検索エリアに対する検索条件結果取得
						local result_list = map(target_area_list, func)
						if(!(is_member(false, result_list)) && !(is_member(target_area_list[0], rtn))){ rtn.append(target_area_list[0]) }
					}
				}

				// 検索エリア範囲をx,yとしてtargetの下側を検索
				target_area_list = []
				continue_flg = false
				for(local ii=target.x + dx; ii<target.x + dx + x; ii++)
				{
					for(local jj=target.y + cov; jj<target.y + cov + y; jj++)
					{
						local c_target = coord(ii ,jj)
						if(!(world.is_coord_valid(c_target)))
						{
							continue_flg = true
							break
						}
						target_area_list.append(coord2D_to_tile(c_target))
					}
					if(continue_flg){ break }
				}
				if(!(continue_flg))
				{
					// 検索エリアに対する検索条件結果取得
					local result_list = map(target_area_list, func)
					if(!(is_member(false, result_list)) && !(is_member(target_area_list[0], rtn))){ rtn.append(target_area_list[0]) }
				}

				// 検索エリア範囲をx,yとしてtargetの右側を検索
				target_area_list = []
				continue_flg = false
				for(local ii=target.x + cov; ii<target.x + cov + x; ii++)
				{
					for(local jj=target.y + dx; jj<target.y + dx + y; jj++)
					{
						local c_target = coord(ii ,jj)
						if(!(world.is_coord_valid(c_target)))
						{
							continue_flg = true
							break
						}
						target_area_list.append(coord2D_to_tile(c_target))
					}
					if(continue_flg){ break }
				}
				if(!(continue_flg))
				{
					// 検索エリアに対する検索条件結果取得
					local result_list = map(target_area_list, func)
					if(!(is_member(false, result_list)) && !(is_member(target_area_list[0], rtn))){ rtn.append(target_area_list[0]) }
				}

				// 検索エリア範囲をx,yとしてtargetの左側を検索
				target_area_list = []
				continue_flg = false
				search_area_reverse_flg = true
				for(local ii=target.x - cov; ii>target.x - cov - x; ii--)
				{
					for(local jj=target.y - dx; jj<target.y - dx + y; jj++)
					{
						local c_target = coord(ii ,jj)
						if(!(world.is_coord_valid(c_target)))
						{
							continue_flg = true
							break
						}
						target_area_list.append(coord2D_to_tile(c_target))
					}
					if(continue_flg){ break }
				}
				if(!(continue_flg))
				{
					// 検索エリアに対する検索条件結果取得
					local result_list = map(target_area_list, func)
					if(!(is_member(false, result_list)))
					{
						local rtn_temp = coord2D_to_tile(coord(target.x - cov - x + 1, target.y - dx))
						if(!(is_member(rtn_temp, rtn)))
						{
							rtn.append(rtn_temp)
							search_area_reverse_flg = false
						}
					}
				}
				
				if(search_area_reverse_flg && cov < x)
				{
					target_area_list = []
					continue_flg = false
					search_area_reverse_flg = true
					for(local ii=target.x - cov; ii<target.x - cov + x; ii++)
					{
						for(local jj=target.y - dx; jj<target.y - dx + y; jj++)
						{
							local c_target = coord(ii ,jj)
							if(!(world.is_coord_valid(c_target)))
							{
								continue_flg = true
								break
							}
							target_area_list.append(coord2D_to_tile(c_target))
						}
						if(continue_flg){ break }
					}
					if(!(continue_flg))
					{
						// 検索エリアに対する検索条件結果取得
						local result_list = map(target_area_list, func)
						if(!(is_member(false, result_list)) && !(is_member(target_area_list[0], rtn))){ rtn.append(target_area_list[0]) }
					}
				}
			}
			cov++
		}
		return rtn
	}

	/*********************************************
	 * 道路に面しているかどうか
	 * 引数：座標リスト(Coord)
	 * 戻り値：true(リストの1タイルでも道路に面している),false(それ以外)
	 * 備考：斜めも面している判定
	 *********************************************/
	static function is_neighbor_road(pos_list)
	{
		local rtn = false
		foreach(pos in _step_generator(pos_list))
		{
			for(local ii=-1; ii<1; ii++)
			{
				for(local jj=-1; jj<1; jj++)
				{
					local target = coord(pos.x+ii, pos.y+jj)
					if(!(world.is_coord_valid(target)) || is_member(target, pos_list))
					{
						continue
					}
					local tile = coord2D_to_tile(target)
					if(tile.get_way(wt_road) != null)
					{
						rtn = true
						break
					}
				}
				if(rtn){ break }
			}
			if(rtn){ break }
		}
		return rtn
	}

	/*********************************************
	 * 周辺の隣接タイルリスト取得
	 * 引数：ターゲットタイルリスト(tile_xのリスト)
	 * 戻り値：隣接タイルリスト(tile_xのリスト)
	 *********************************************/
	static function bldg_neighbor_tile_list(tile_list)
	{
		local rtn = []
		foreach(bldg_tile in _step_generator(tile_list))
		{
			for(local ii=-1; ii<=1; ii++)
			{
				for(local jj=-1; jj<=1; jj++)
				{
					local target = coord(bldg_tile.x+ii, bldg_tile.y+jj)
					if(!(world.is_coord_valid(target)) || is_member(target, tile_list) || is_member(target, rtn))
					{
						continue
					}
					rtn.append(coord2D_to_tile(target))
				}
			}
		}
		return rtn
	}

	/*********************************************
	 * ベースの座標から周辺のタイルリスト取得
	 * 引数：ベース座標(Coord)、x方向距離、y方向距離、取得方法(0:ベースを中心として距離分、1:ベースを左上にして距離分
	 * 戻り値：タイルリスト(tile_x)
	 *********************************************/
	static function base_to_tile_list(pos, x, y, type)
	{
		local rtn = []
		if(x == 0 || y == 0){ coord2D_to_tile(pos) }
		local dx = 0
		local dy = 0
		if(type == 0)
		{
			if(x % 2 == 0){ dx = pos.x - x/2 }
			else{ dx = pos.x - (x - 1)/2 }
			if(y % 2 == 0){ dy = pos.y - y/2 }
			else{ dy = pos.y - (y - 1)/2 }
			if(dx < 0)
			{
				dx = 0
				x = x + dx
			}
			if(dy < 0)
			{
				dy = 0
				y = y + dy
			}
		}
		if(type == 1)
		{
			dx = pos.x
			dy = pos.y
		}
		for(local ii = dx; ii < dx + x; ii++)
		{
			for(local jj = dy; jj < dy + y; jj++)
			{
				local pos_temp = coord(ii, jj)
				if(world.is_coord_valid(pos_temp)){ rtn.append(coord2D_to_tile(pos_temp)) }
			}
		}
		return rtn
	}

	/*********************************************
	 * タイルリストを整地
	 * 引数：タイルリスト(tile_x)、プレイヤー属性(player_x)
	 * 戻り値：実行後のタイルリスト(tile_xのリスト)
	 *********************************************/
	static function flat_tiles(tile_list, pl)
	{
		if(tile_list.len() == 0){ return [] }
		local height_list = map(tile_list, @(a) a.z)
		local ave_height = get_mode(height_list)
		// エリア内に高さの差異はあるか
		local same_height = get_idx_in_member(ave_height, height_list)
		if(same_height.len() != height_list.len())
		{
			// 予算チェック
			local change_height_list = filter(tile_list, @(a) a.z != ave_height)
			local change_height_cost = 0
			foreach(change_height_tile in change_height_list)
			{
				local diff = change_height_tile.z - ave_height
				if(diff < 0)
				{
					for(local ii = 0; ii < abs(diff); ii++)
					{
						change_height_cost += command_x.slope_get_price(slope.all_up_slope)
					}
				}else{
					for(local ii = 0; ii < diff; ii++)
					{
						change_height_cost += command_x.slope_get_price(slope.all_down_slope)
					}
				}
			}
			if(change_height_cost >= pl.get_current_cash()*100){ return tile_list }
			// 高さを合わせる
			foreach(change_height_tile in change_height_list)
			{
				local diff = change_height_tile.z - ave_height
				if(diff < 0)
				{
					for(local ii = 0; ii < abs(diff); ii++)
					{
						command_x.set_slope(pl, change_height_tile, slope.all_up_slope)
						change_height_tile = tile_x(change_height_tile.x, change_height_tile.y, change_height_tile.z + 1)
					}
				}else{
					for(local ii = 0; ii < diff; ii++)
					{
						command_x.set_slope(pl, change_height_tile, slope.all_down_slope)
						change_height_tile = tile_x(change_height_tile.x, change_height_tile.y, change_height_tile.z - 1)
					}
				}
			}
		}
		
		local change_slope_list = filter(tile_list, @(a) a.get_slope() != 0)
		// 予算チェック
		local change_slope_cost = 0
		foreach(change_slope_tile in change_slope_list)
		{
			change_slope_cost += command_x.slope_get_price(slope.flat)
		}
		if(change_slope_cost >= pl.get_current_cash()*100){ return }
		// 平面にする
		foreach(change_slope_tile in change_slope_list)
		{
			if(command_x.can_set_slope(pl, change_slope_tile, slope.flat) == null)
			{
				command_x.set_slope(pl, change_slope_tile, slope.flat)
			}
		}
		return map(tile_list, @(a) coord2D_to_tile(a))
	}

	/*********************************************
	 * タイルリストの高さを揃える
	 * 引数：タイルリスト(tile_x)、高さ(int)、プレイヤー属性(player_x)、予算チェックするかどうか(boolean)
	 * 戻り値：実行後のタイルリスト(tile_xのリスト)
	 * 備考：この関数は高さを揃えるだけで、更に整地するならflat_tiles関数を続けて呼ぶ
	 *********************************************/
	static function align_height(tile_list, height, pl, is_check_budget)
	{
		if(is_check_budget)
		{
			local change_slope_cost = 0
			foreach(tile in _step_generator(tile_list))
			{
				local cmd_count = tile.z - height
				if(cmd_count > 0)
				{
					change_slope_cost += command_x.slope_get_price(slope.all_down_slope) * cmd_count
				}else{
					change_slope_cost += command_x.slope_get_price(slope.all_up_slope) * abs(cmd_count)
				}
			}
			if(change_slope_cost > pl.get_current_cash()*100){ return tile_list }
		}
		foreach(tile in _step_generator(tile_list))
		{
			local diff = tile.z - height
			if(diff > 0)
			{
				for(local ii = 0; ii < diff; ii++)
				{
					command_x.set_slope(pl, tile, slope.all_down_slope)
				}
			}else{
				for(local ii = 0; ii > diff; ii--)
				{
					command_x.set_slope(pl, tile, slope.all_up_slope)
				}
			}
		}
		return map(tile_list, @(a) coord2D_to_tile(a))
	}

	/*********************************************
	 * タイルリスト内の建物数と旅客レベル総計を計算
	 * 引数：タイルリスト(tile_xのリスト)
	 * 戻り値：テーブル
	 *         bldg_counter      :建物数
	 *         total_bldg_level  :旅客レベル総計
	 *         bldg_tile_list    :建物が建っているタイルリスト(tile_xのリスト)
	 *********************************************/
	static function get_area_bldg_info(tile_list)
	{
		local bldg_counter = 0
                local total_bldg_level = 0
                local bldg_tile_list = []
		foreach(tile in _step_generator(tile_list))
		{
			local flg = false
			foreach(obj in tile.get_objects())
			{
				if(obj.get_type() == mo_building)
				{
					bldg_counter++
					total_bldg_level += obj.get_passenger_level() + obj.get_mail_level()
					// 役場の場合は旅客レベルが取得できないので、一律30加算
					if(obj.get_desc().get_type() == building_desc_x.townhall){ total_bldg_level += 30 }
					flg = true
				}
				if(obj.get_type() == mo_field)
				{
					bldg_counter++
					flg = true
				}
			}
			if(flg){ bldg_tile_list.append(tile) }
		}
		local tbl_info = 
		{
			bldg_counter = bldg_counter
			total_bldg_level = total_bldg_level
			bldg_tile_list = bldg_tile_list
		}
		return tbl_info
	}

	/*********************************************
	 * 2点間のタイルを全て取得
	 * 引数：片方のタイル(coord)、もう片方のタイル(coord)
	 * 戻り値：タイルリスト(tile_xのリスト)
	 * 備考：2点はx方向とy方向のみ有効、斜めは不可
	 *********************************************/
	static function get_interpolate_tile(a_tile, b_tile)
	{
		local rtn = []
		local dx = a_tile.x - b_tile.x
		local dy = a_tile.y - b_tile.y
		if(dx == 0)
		{
			local temp = 0
			if(dy > 0)
			{
				temp = b_tile.y
			}else{
				temp = a_tile.y
			}
			for(local ii = 0; ii < abs(dy) + 1; ii++)
			{
				rtn.append(coord2D_to_tile(coord(a_tile.x, temp + ii)))
			}
		}
		if(dy == 0)
		{
			local temp = 0
			if(dx > 0)
			{
				temp = b_tile.x
			}else{
				temp = a_tile.x
			}
			for(local ii = 0; ii < abs(dx) + 1; ii++)
			{
				rtn.append(coord2D_to_tile(coord(temp + ii, a_tile.y)))
			}
		}
		return rtn
	}

	/***************************************
	 * タイルリストの中心タイル取得
	 * 引数：タイルリスト(coordのリスト)
	 * 戻り値：中心座標(coord)
	 ***************************************/
	function get_center(tile_list)
	{
		if(tile_list.len() == 0){ return }
		local cx = 0
		local cy = 0
		foreach(pos in tile_list)
		{
			cx += pos.x
			cy += pos.y
		}
		return coord(cx / tile_list.len(), cy / tile_list.len())
	}

	/*********************************************
	 * wayの終端部でタイルに段差があれば、スロープを設置
	 * 引数：タイル(tile_x)、急坂使う(true)緩坂使う(false)(boolean)、プレイヤー属性(player_x)
	 * 備考：タイルはwayの終端部を設定すること
	 *********************************************/
	static function set_slope_for_way(tile, use_double_slope, pl)
	{
		// wayがあれば、方向を取得し、終端部なら処理続行
		if(tile.has_ways())
		{
			local map_objects = tile.find_object(mo_way)
			local way_type = map_objects.get_waytype()
			if(way_type == wt_rail || way_type == wt_road)
			{
				local d = tile.get_way_dirs(way_type)
				if(!(dir.is_single(d))){ return }
				// 終端部ならその先のタイルを取得して段差の有無調査
				local neighbor_tile = null
				local c_pos = null
				local slope_direction = slope.flat
				switch(d)
				{
					case dir.north:
					c_pos = coord(tile.x, tile.y + 1)
					if(!(world.is_coord_valid(c_pos))){ return }
					neighbor_tile = coord2D_to_tile(c_pos)
					if(tile.z != neighbor_tile.z)
					{
						if(tile.z - neighbor_tile.z == 1)
						{
							if(tile.get_slope() == slope.south){ return }
							slope_direction = slope.south
						}
						if(tile.z - neighbor_tile.z == -1)
						{
							if(tile.get_slope() == slope.north){ return }
							slope_direction = slope.north
						}
					}
					break
					case dir.east:
					c_pos = coord(tile.x - 1, tile.y)
					if(!(world.is_coord_valid(c_pos))){ return }
					neighbor_tile = coord2D_to_tile(c_pos)
					if(tile.z != neighbor_tile.z)
					{
						if(tile.z - neighbor_tile.z == 1)
						{
							if(tile.get_slope() == slope.west){ return }
							slope_direction = slope.west
						}
						if(tile.z - neighbor_tile.z == -1)
						{
							if(tile.get_slope() == slope.east){ return }
							slope_direction = slope.east
						}
					}
					break
					case dir.south:
					c_pos = coord(tile.x, tile.y - 1)
					if(!(world.is_coord_valid(c_pos))){ return }
					neighbor_tile = finder.coord2D_to_tile(c_pos)
					if(tile.z != neighbor_tile.z)
					{
						if(tile.z - neighbor_tile.z == 1)
						{
							if(tile.get_slope() == slope.north){ return }
							slope_direction = slope.north
						}
						if(tile.z - neighbor_tile.z == -1)
						{
							if(tile.get_slope() == slope.south){ return }
							slope_direction = slope.south
						}
					}
					break
					case dir.west:
					c_pos = coord(tile.x + 1, tile.y)
					if(!(world.is_coord_valid(c_pos))){ return }
					neighbor_tile = finder.coord2D_to_tile(c_pos)
					if(tile.z != neighbor_tile.z)
					{
						if(tile.z - neighbor_tile.z == 1)
						{
							if(tile.get_slope() == slope.east){ return }
							slope_direction = slope.east
						}
						if(tile.z - neighbor_tile.z == -1)
						{
							if(tile.get_slope() == slope.west){ return }
							slope_direction = slope.west
						}
					}
					break
				}
				// スロープ設置
				if(neighbor_tile == null || slope_direction == slope.flat){ return }
				if(neighbor_tile.is_empty() || neighbor_tile.get_way(wt_road) != null)
				{
					if(tile.z - neighbor_tile.z == -1)
					{
						command_x.set_slope(pl, neighbor_tile, slope.all_down_slope)
						neighbor_tile.z = neighbor_tile.z - 1
					}
					command_x.set_slope(pl, neighbor_tile, slope_direction)
				}
			}
		}
	}

	/*********************************************
	 * 同一駅かチェック
	 * 引数：駅1(halt_x)、駅2(halt_x)
	 * 戻り値：チェック結果(boolean)
	 *********************************************/
	 static function is_same_halt(a_halt, b_halt)
	 {
	 	local a_tile_list = a_halt.get_tile_list()
	 	local b_tile_list = b_halt.get_tile_list()
	 	// 駅を構成するタイルが一つでも重複していれば同一駅と判定
	 	if(is_member(a_tile_list[0], b_tile_list)){ return true }
	 	return false
	 }

	/*********************************************
	 * 二つのエリアが重複しているかチェック
	 * 引数：エリア1(Coord)、エリア2(Coord)
	 * 戻り値：重複している座標リスト(Coord)
	 *********************************************/
	static function check_covered_area(a_pos_list, b_pos_list)
	{
		local rtn = []
		foreach(a_pos in _step_generator(a_pos_list))
		{
			if(is_member(a_pos, b_pos_list)){ rtn.append(a_pos) }
		}
		return rtn
	}

	/*********************************************
	 * プレイヤー会社がそのタイル上の施設を全て撤去できるかチェック
	 * 引数：タイル(tile_x)、プレイヤー会社(player_x)
	 * 戻り値：撤去できるかどうか(boolean)
	 * 備考：tile_xクラスのcan_remove_all_objects関数は機能してないようなので自作
	 *********************************************/
	static function can_remove_all_objects(tile, pl)
	{
		if(tile == null){ return false }
		local rtn = true
		foreach(obj in tile.get_objects())
		{
			switch(obj.get_type())
			{
				case mo_building:
				if(!(is_member(obj.get_owner().nr, [pl.nr, city_player_nr]))){ rtn = false }
				return rtn

				case mo_way:
				if(!(is_member(obj.get_owner().nr, [pl.nr, city_player_nr]))){ rtn = false }
				return rtn

				case mo_depot_rail:
				if(!(is_member(obj.get_owner().nr, [pl.nr, city_player_nr]))){ rtn = false }
				return rtn

				case mo_depot_road:
				if(!(is_member(obj.get_owner().nr, [pl.nr, city_player_nr]))){ rtn = false }
				return rtn

				case mo_depot_water:
				if(!(is_member(obj.get_owner().nr, [pl.nr, city_player_nr]))){ rtn = false }
				return rtn

				case mo_pillar:
				if(obj.get_owner().nr != pl.nr){ rtn = false }
				return rtn
			}
		}
		return rtn
	}

	/*********************************************
	 * 選択しているタイルに最も近い町情報を取得
	 * 引数：タイル(Coord)
	 * 戻り値：町情報(city_x)
	 * 備考：worldクラスのfind_nearest_city関数はプレイヤーが追加した町を認識してないようなので自作
	 *********************************************/
	static function find_nearest_city(pos)
	{
		local distance = world.get_size().x + world.get_size().y
		local city_info = get_nearest(city_list_x(), distance, @(a) abs(pos.x - a.get_pos().x) + abs(pos.y - a.get_pos().y))
		return city_info[0]
	}


	static function get_tiles_near_factory(factory)
	{
		local cov = settings.get_station_coverage()
		local area = []

		// generate a list of tiles that will reach the factory
		local ftiles = factory.get_tile_list()
		foreach (c in ftiles) {
			for(local dx = -cov; dx <= cov; dx++) {
				for(local dy = -cov; dy <= cov; dy++) {
					if (dx==0 && dy==0) continue;

					local x = c.x+dx
					local y = c.y+dy

					if (x>=0 && y>=0) area.append( (x << 16) + y );
				}
			}
		}
		// sort
		sleep()
		area.sort()
		return area
	}

	static function find_empty_place(area, target)
	{
		// find place closest to target
		local tx = target.x
		local ty = target.y

		local best = null
		local dist = 10000
		// check for flat and empty ground
		for(local i = 0; i<area.len(); i++) {

			local h = area[i]
			if (i>0  &&  h == area[i-1]) continue;

			local x = h >> 16
			local y = h & 0xffff

			if (world.is_coord_valid({x=x,y=y})) {
				local tile = square_x(x, y).get_ground_tile()

				if (tile.is_empty()  &&  tile.get_slope()==0) {
					local d = abs(x - tx) + abs(y - ty)
					if (d < dist) {
						dist = d
						best = tile
					}
				}
			}
		}
		return best
	}


	static function _find_places(area, test /* function */)
	{
		local list = []
		// check for flat and empty ground
		for(local i = 0; i<area.len(); i++) {

			local h = area[i]
			if (i>0  &&  h == area[i-1]) continue;

			local x = h >> 16
			local y = h & 0xffff

			if (world.is_coord_valid({x=x,y=y})) {
				local tile = square_x(x, y).get_ground_tile()

				if (test(tile)) {
					list.append(tile)
				}
			}
		}
		return list.len() > 0 ?  list : []
	}

	static function find_empty_places(area)
	{
		return _find_places(area, _tile_empty)
	}

	static function _tile_empty(tile)
	{
		return tile.is_empty()  &&  tile.get_slope()==0
	}

	static function _tile_empty_or_field(tile)
	{
		return tile.get_slope()==0  &&  (tile.is_empty()  ||  tile.find_object(mo_field))
	}

	static function find_water_places(area)
	{
		return _find_places(area, _tile_water)
	}

	static function _tile_water(tile)
	{
		return tile.is_water()  &&  (tile.find_object(mo_building)==null)  &&  (tile.find_object(mo_depot_water)==null)
	}

	static function _tile_water_way(tile)
	{
		if (tile.is_water()) {
			return true // (tile.find_object(mo_building)==null)  &&  (tile.find_object(mo_depot_water)==null)
		}
		else {
			foreach(obj in tile.get_objects()) {
				if (obj.get_type() != mo_way) continue;

				if (obj.get_waytype() == wt_water) {
					return obj.get_desc().get_topspeed() > 5
				}
			}
		}
		return false
	}

	static function find_station_place(factory, target, unload = false)
	{
		if (unload) {
			// try unload station from station manager
			local res = ::station_manager.access_freight_station(factory).road_unload
			if (res) {
				return [res]
			}
		}
		local can_delete_fields = factory.get_field_count() > factory.get_min_field_count()

		local area = get_tiles_near_factory(factory)

		if (can_delete_fields) {
			return _find_places(area, _tile_empty_or_field);
		}
		else {
			return find_empty_places(area)
		}
	}

	/**
	 * Can harbour of length @p len placed at @p pos (land tile!) in direction @p d.
	 */
	static function check_harbour_place(pos, len, d /* direction */)
	{
		local from = pos
		for(local i = 0; i<len; i++) {
			local to = from.get_neighbour(i>0 ? wt_water : wt_all, d)
			if (to  &&  _tile_water(to)  &&  to.can_remove_all_objects(our_player)==null) {
				from = to
			}
			else {
				return false
			}
		}
		return true
	}

}
