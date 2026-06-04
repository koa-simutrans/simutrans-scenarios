/**
 * Classes for rail info
 */

class rail_manager_t extends manager_t
{
	constructor() 
	{
		base.constructor("rail_manager_t")
	}

	/***************************************
	 * 線路アドオン選択
	 * 引数：プレイヤー属性(player_x)、置き換え対象線路アドオン(way_desc_x)
	 * 戻り値：線路アドオン(way_desc_x)
	 ***************************************/
	function select_rail(pl, old_way_desc)
	{
		local way_desc_list = way_desc_x.get_available_ways(wt_rail, st_flat)
		if(way_desc_list.len() == 0){ return }
		if(way_desc_list.len() == 1){ return way_desc_list[0] }
		
		local current_speed = 30
		if(old_way_desc != null){ current_speed = old_way_desc.get_topspeed() }
		// 30km/h未満の線路は除外
		way_desc_list = filter(way_desc_list, @(a) a.get_topspeed() >= current_speed)
		// 建設費の降順でソート
		way_desc_list = sort(way_desc_list, @(a,b) b.get_cost() <=> a.get_cost())
		// 月粗利益取得
		local profit = pl.get_profit()
		// 収入に応じて線路のグレードが上がる
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
	 * 架線アドオン選択
	 * 引数：プレイヤー属性(player_x)、置き換え対象架線アドオン(wayobj_desc_x)
	 * 戻り値：架線アドオン(wayobj_desc_x)
	 ***************************************/
	function select_wayobj(pl, old_wayobj_desc)
	{
		local wayobj_desc_list = filter(wayobj_desc_x.get_available_wayobjs(wt_rail), @(a) a.is_overhead_line())
		if(wayobj_desc_list.len() == 0){ return }
		if(wayobj_desc_list.len() == 1){ return wayobj_desc_list[0] }
		
		local current_speed = 30
		if(old_wayobj_desc != null){ current_speed = old_wayobj_desc.get_topspeed() }
		// 30km/h未満の架線は除外
		wayobj_desc_list = filter(wayobj_desc_list, @(a) a.get_topspeed() >= current_speed)
		// 建設費の降順でソート
		wayobj_desc_list = sort(wayobj_desc_list, @(a,b) b.get_cost() <=> a.get_cost())
		// 月粗利益取得
		local profit = pl.get_profit()
		// 収入に応じて架線のグレードが上がる
		for(local ii=1; ii<wayobj_desc_list.len(); ii++)
		{
			if( profit[0] >= 100000 / (wayobj_desc_list.len() - 1) * (wayobj_desc_list.len() - ii))
			{
				return wayobj_desc_list[ii-1]
			}
		}
		return wayobj_desc_list.len() != 0 ? wayobj_desc_list.top() : null
	}

	/***************************************
	 * 鉄道路線建設(線路から)
	 * 引数：プレイヤー属性(player_x)、ルート情報(町Idxのarray)
	 * 戻り値：ルート情報(町Idxのarray)
	 ***************************************/
	function build_rail_root(pl, root_info)
	{
		local city_info = persistent.city.get_city_info()
		local del_root = []
		local station = station_manager_t()

		// 産業、名所旧跡一覧取得
		local ind_att_list = []
		foreach(factory in factory_list_x())
		{
			local factory_tile_list = factory.get_tile_list()
			// 湖上の産業は除外
			factory_tile_list = filter(factory_tile_list, @(a) a.is_ground())
			if(factory_tile_list.len() != 0)
			{
				// 市内の産業は除外
//				local nearest_city = finder.find_nearest_city(factory_tile_list.top())
//				local city_limit_list = finder.base_to_tile_list(nearest_city.get_pos_nw(), abs(nearest_city.get_pos_nw().x-nearest_city.get_pos_se().x), abs(nearest_city.get_pos_nw().y-nearest_city.get_pos_se().y), 1)
//				local cover_area_list = finder.check_covered_area(factory_tile_list, city_limit_list)
//				if(cover_area_list.len() == factory_tile_list.len()){ continue }
				local flg = true
				foreach(tile in _step_generator(factory_tile_list))
				{
					if(finder.coord2D_to_tile(tile).is_water())
					{
						flg = false
						break
					}
				}
				if(flg)
				{
					ind_att_list.append(factory_tile_list[0])
				}
			}
		}

		// 湖上の名所旧跡は除外
		local att_list = filter(attraction_list_x(), @(a) a.get_desc().get_type() == building_desc_x.attraction_land)
		foreach(att in att_list)
		{
			local att_tile_list = att.get_tile_list()
			// 市内の名所旧跡は除外
//			local nearest_city = finder.find_nearest_city(att_tile_list.top())
//			local city_limit_list = finder.base_to_tile_list(nearest_city.get_pos_nw(), abs(nearest_city.get_pos_nw().x-nearest_city.get_pos_se().x), abs(nearest_city.get_pos_nw().y-nearest_city.get_pos_se().y), 1)
//			local cover_area_list = finder.check_covered_area(att_tile_list, city_limit_list)
//			if(cover_area_list.len() == att_tile_list.len()){ continue }
			local flg = true
			foreach(tile in _step_generator(att_tile_list))
			{
				if(finder.coord2D_to_tile(tile).is_water())
				{
					flg = false
					break
				}
			}
			if(flg)
			{
				ind_att_list.append(att_tile_list[0])
			}
		}
		
		// 建設する駅と接続する一つ前の駅(分岐駅化に使用)
		local prev_halt = null
		// 線路アドオンを選択
		local way = select_rail(pl, null)
		if(way == null){ return }
		local start = null    // 線路敷設始点タイル
		local end = null      // 線路敷設終点タイル
		local restart = null  // 次駅の線路敷設開始タイル
		// 町数分ループ
		for(local ii = 0; ii < root_info.len(); ii++)
		{
			// 資金チェック(初期資金の半分または線路敷設処理の最低資金を下回り、月粗利益が赤字なら建設打ち切り)
			if(pl.get_current_cash() < persistent.initial_capital / 2 && pl.get_current_cash() < construct_rail_minimum_capital && pl.get_profit()[0] < 0)
			{
				gui.add_message_at(pl, "stop construction because buget shortfall.", world.get_time())
				root_info.resize(ii)
				break
			}
		
			local city = filter(city_list_x(), @(a) compare_coord(a.get_pos(), city_info[root_info[ii]].townhall))
			// ルート上の各都市内の既存駅(公共駅含む)取得
			local already_station = finder.reseach_station_nearest_city(city[0], pl, true)
			// 街が大きいと既存駅が隣接都市の方が近いこともあるので、駅名でチェック
			if(!(already_station))
			{
				local candidate_list = filter(halt_list_x(), @(a) a.get_name().find(city[0].get_name()) != null)
				candidate_list = filter(candidate_list, @(a) a.get_owner().nr == pl.nr || a.get_owner().nr == 1)
				candidate_list = sort(candidate_list, @(a,b) b.get_capacity(good_desc_x.passenger) <=> a.get_capacity(good_desc_x.passenger))
				if(candidate_list.len() != 0)
				{
					candidate_list = filter(candidate_list, @(a) finder.check_sta_freight_property(a, wt_rail, 2).len() > 0)
					if(candidate_list.len() != 0)
					{
						already_station = candidate_list[0]
					}
				}
			}
			local tbl_sta_info = null
			// 町に既に駅がある
			if(already_station)
			{
				// 流用可能かチェック
				tbl_sta_info = check_already_station(city[0], already_station, pl, 2)
				if(tbl_sta_info)
				{
				// TODO:駅舎がない場合、バス停有無を調べて無いなら建設
					if(ii == 0)
					{
						prev_halt = already_station
						continue
					}
					// 棒線駅かつ末端駅の場合、そこから建設
					if(tbl_sta_info.tbl_form_info_list.len() == 1 && dir.is_single(tbl_sta_info.tbl_form_info_list[0].dir))
					{
						local tbl_form_info_list = tbl_sta_info.tbl_form_info_list
						tbl_sta_info.new_form_end_rail <- station.get_boundary_station_pos(tbl_form_info_list[0].stop, 4)
						start = filter(tbl_sta_info.new_form_end_rail, @(a) dir.is_single(a.get_way_dirs(wt_rail))).top()
						continue
					}else{
						// 前の駅～当駅にまだ孤立している名所旧跡・産業あれば線路敷設
						local temp_start = null
						if(prev_halt || start)
						{
							if(prev_halt)
							{
								start = finder.check_sta_freight_property(prev_halt, wt_rail, 2).top()
							}
							temp_start = insert_ind_attract(start, city_info[root_info[ii]].townhall, ind_att_list, pl, 2)
							if(temp_start)
							{
								if(temp_start.add_list.len() != 0)
								{
									ind_att_list = filter(ind_att_list, @(a) !(is_member(a, temp_start.add_list)))
								}
								local tbl_update_info = build_rail_junction(already_station, temp_start.tile, pl)
								if(tbl_update_info == null){ break }
								local temp_end = set_rail_between_station(temp_start.tile, tbl_update_info.exit, pl)
								// 建設失敗したなら撤去
								if(temp_end)
								{
									if(!(compare_coord(temp_start.tile, temp_end)))
									{
										local asf = astar_route_finder(wt_rail)
										local res = asf.search_route([temp_start.tile], [temp_end])
										if ("routes" in res)
										{
											res.routes.remove(0)
											local tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
											remove_rail(tile_list, pl)
										}
									}
								}else{
									temp_start = null
								}
							}
							start = null
						}
						if(temp_start){ break }
						prev_halt = already_station
					}
					if("new_form_end_rail" in tbl_sta_info)
					{
						start = filter(tbl_sta_info.new_form_end_rail, @(a) dir.is_single(a.get_way_dirs(wt_rail))).top()
					}else{
						continue
					}
				}
			}
			if(prev_halt)
			{
				// 分岐駅設置
				local tbl_update_info = build_rail_junction(prev_halt, city_info[root_info[ii]].townhall, pl)
				if(tbl_update_info == null){ break }
				prev_halt = null
				start = tbl_update_info.exit
			}
			
			// 新線建設
			local from_dir = null
			local to_dir = null
			// 2駅目以降の場合
			if(ii > 0 && start)
			{
				// 途中の産業・名所旧跡に駅を挿入
				local tbl_temp_start = insert_ind_attract(start, city_info[root_info[ii]].townhall, ind_att_list, pl, 2)
				if(tbl_temp_start != null)
				{
					start = tbl_temp_start.tile
					if(tbl_temp_start.add_list.len() != 0)
					{
						ind_att_list = filter(ind_att_list, @(a) !(is_member(a, tbl_temp_start.add_list)))
					}
					// 挿入した駅が町の駅として使える場合、次の町を目指す
					if(!(tbl_temp_start.blnFlg)){ continue }
					prev_halt = tbl_temp_start.already_halt
				}
				if(prev_halt)
				{
					local tbl_update_info = build_rail_junction(prev_halt, city_info[root_info[ii]].townhall, pl)
					if(tbl_update_info == null){ break }
					start = tbl_update_info.exit
				}
				from_dir = [city_info[root_info[ii]].townhall.x - start.x, city_info[root_info[ii]].townhall.y - start.y]
			}
			// 終着駅以外の場合
			if(ii != root_info.len() - 1)
			{
				to_dir = [city_info[root_info[ii+1]].townhall.x-city_info[root_info[ii]].townhall.x, city_info[root_info[ii+1]].townhall.y-city_info[root_info[ii]].townhall.y]
			}
			// 近くに鉄道駅のない空港・港がある
				// 駅設置可能
					// 駅設置
			// 駅設置
			local long_edge_length = 13
			local max_cov = city[0].get_pos_se().y-city[0].get_pos_nw().y
			if(city[0].get_pos_se().x-city[0].get_pos_nw().x > city[0].get_pos_se().y-city[0].get_pos_nw().y)
			{
				max_cov = city[0].get_pos_se().x-city[0].get_pos_nw().x
			}
			
			// 終着駅の場所選定
			if(ii == root_info.len() - 1)
			{ 
				long_edge_length = 5
			}
			local init_cov = 1
			local temp_start = start
			local sta_info = null
			local miss_sta_area_list = []
			while(init_cov < max_cov + 5)
			{
				// 行き違い設備の幅 -> 2の根拠
				// ホーム2マス、行き違いを想定して前後に3マス -> 9の根拠
				local sta_info_list = get_construct_stationinfo(city_info[root_info[ii]].townhall, from_dir, to_dir, 2, long_edge_length, init_cov, max_cov + 5, pl, true)

				// 駅建設予定地を確保できなかったら、その町は飛ばす
				if(sta_info_list.len() == 0)
				{
					// 1番目の町に駅作れなかったら鉄道を断念する
					if(ii == 0){ return }
					del_root.append(ii)
					break
				}
				// 一度線路敷設失敗した駅建設候補地はスキップ
				if(is_member(sta_info_list[0].c_in, miss_sta_area_list))
				{
					init_cov++
					continue
				}else{
					miss_sta_area_list.append(sta_info_list[0].c_in)
				}
				for(local jj = 0; jj < sta_info_list.len(); jj++)
				{
gui.add_message_at(pl,ii+"."+jj+".["+coord_to_string(sta_info_list[jj].c_in)+"]:["+coord_to_string(sta_info_list[jj].c_out)+"]",sta_info_list[jj].sta_tile_list.top())
					// 駅設置予定地を整地
					local target_tile_list = finder.get_interpolate_tile(sta_info_list[jj].c_in, sta_info_list[jj].c_out)
					finder.flat_tiles(target_tile_list, pl)
					// 駅設置予定地のz値を更新
					sta_info_list[jj].sta_tile_list = map(sta_info_list[jj].sta_tile_list, @(a) finder.coord2D_to_tile(coord(a.x, a.y)))
					// 駅構内の線路敷設
					end = finder.coord2D_to_tile(sta_info_list[jj].c_in)
					restart = finder.coord2D_to_tile(sta_info_list[jj].c_out)
					command_x.build_way(pl, end, restart, way, true)
					// 線路終端に段差があれば、スロープをセット
					finder.set_slope_for_way(end, true, pl)
					finder.set_slope_for_way(restart, true, pl)
					if(ii == 0)
					{
						sta_info = sta_info_list[jj]
						start = restart
						break
					}else{
						persistent.setting_rail <- [restart, end]
						// 駅間に線路敷設
						temp_start = set_rail_between_station(temp_start, end, pl)
						if(temp_start == null)
						{
							start = restart
							prev_halt = null
							sta_info = sta_info_list[jj]
							delete persistent.setting_rail
							break
						}
						// 設置した駅構内撤去
						local remove_rail_list = finder.get_interpolate_tile(end, restart)
						remove_rail(remove_rail_list, pl)
						delete persistent.setting_rail
					}
				}
				if(temp_start != null)
				{
					init_cov++
					continue
				}
				// 駅設置
				local err = station.build_new_station(pl, sta_info.sta_tile_list, true)
				if(err != null)
				{
					gui.add_message_at(pl, "failed build station at "+ coord_to_string(sta_info.sta_tile_list.top()) + ":" + err, sta_info.sta_tile_list.top())
					local remove_rail_list = finder.get_interpolate_tile(end, restart)
					remove_rail(remove_rail_list, pl)
					del_root.append(ii)
					// 2駅目で線路敷設失敗したら最初の駅も撤去
					if(ii == 1)
					{
						local asf = astar_route_finder(wt_rail)
						local res = asf.search_route([end], [start])
						if ("routes" in res)
						{
							res.routes.remove(0)
							local tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
							remove_rail(tile_list, pl)
						}
						root_info = []
					}
				}
				break
			}
		}

		// 新規ルートが既存ルートと重複してないかチェック
		if(is_member_in_doublearray(root_info, persistent.used_root)){ return }
		
		// 駅を建設できなかった町をルート情報から消す
		for(local ii = 0; ii < del_root.len(); ii++)
		{
			root_info.remove(del_root[ii])
			for(local jj = ii; jj < del_root.len(); jj++)
			{
				del_root[jj]--
			}
		}
		if(is_member_in_doublearray(root_info, persistent.used_root)){ return }
		
		return root_info
	}

	/***************************************
	 * 新線建設時、既存駅を流用可能かチェック
	 * 引数：町情報(city_x)、既存駅(halt_x)、プレイヤー会社(player_x)、対象貨物属性(0:荷物、1:郵便、2:旅客)
	 * 戻り値：既存駅情報
	 *         tbl_form_info_list    ：プラットホームの情報リスト
	 *                                 length：ホーム長さ
	 *                                 stop  ：列車停車位置の座標(スケジュール設定時に使用)
	 *                                 dir   ：ホーム上の列車の進行方向
	 *         sta_office_tile_list  ：駅本屋のタイルリスト
	 * 　　　　new_form_end_rail     ：新設したホームの終端線路タイルリスト
	 * 備考：戻り値の既存駅情報はstation_manager_tクラスのget_station_info関数の情報に
	 * 　　　new_form_end_railを追加したもの
	 ***************************************/
	function check_already_station(city, halt, pl, freight)
	{
		local station = station_manager_t()
		local tbl_sta_info = station.get_station_info(halt, freight, false)
		// 駅は公共駅の場合
		if(halt.get_owner().nr == 1)
		{
			//利用可能なホームのリスト取得
			local sta_stop_list = get_usable_form_info(halt, pl, freight)
			if(sta_stop_list.len() == 0)
			{
				// 公共駅拡張
				local tbl_new_halt = station.expand_station(pl, already_station)
				if(tbl_new_halt)
				{
					halt = tbl_new_halt.halt
					tbl_sta_info.new_form_end_rail <- station.get_boundary_station_pos(tbl_new_halt.expand_tile, 4)
				}else{
					// 駅拡張失敗したので自前駅取得
					if(city)
					{
						halt = finder.reseach_station_nearest_city(city, pl, false)
					}else{
						local pos = halt.get_tile_list().top()
						local distance = world.get_size().x + world.get_size().y
						local halt_list = filter(halt_list_x(), @(a) a.get_owner().nr == pl.nr)
						halt_list = filter(halt_list, @(a) finder.check_sta_freight_property(a, wt_rail, freight).len() != 0)
						halt_list = get_nearest(halt_list, distance, @(a) abs(pos.x - a.x) + abs(pos.y - a.y))
						halt = halt_list.len() != 0 ? halt_list[0] : null
					}
					// 自前駅なしならnull返す
					if(halt)
					{
						tbl_sta_info = station.get_station_info(halt, freight, false)
					}else{
						return
					}
				}
			}else{
				tbl_sta_info.tbl_form_info_list <- filter(tbl_sta_info.tbl_form_info_list, @(a) is_member(a, sta_stop_list))
			}
		}
		
		return tbl_sta_info
	}

	/***************************************
	 * 新線建設時、分岐駅設置
	 * 引数：分岐候補駅(halt_x)、分岐先の目的地(tile_x)、プレイヤー会社(player_x)
	 * 戻り値：駅の入場、出場タイル
	 * 　　　　enter：駅に入場するタイル(tile_x)
	 * 　　　　exit：分岐駅から線路敷設する時の始点(tile_x)
	 *         halt：駅(公共駅を更新したとき用)
	 ***************************************/
	function build_rail_junction(prev_halt, to_tile, pl)
	{
		local station = station_manager_t()
		// 分岐駅設置候補地探索
		local candidate_tile = search_new_junction_sta_tile(prev_halt, to_tile, pl)
		if(candidate_tile)
		{
			local temp_halt = candidate_tile.get_halt()
			if(temp_halt)
			{
				// 候補地に駅があるなら候補駅を上書き
				prev_halt = temp_halt
			}else{
				// 新駅設置
				local err = station.build_form(pl, [candidate_tile], true)
				if(err){ return }
				// 通過する路線を新駅に停車させる
				prev_halt = candidate_tile.get_halt()
				insert_new_station(prev_halt)
			}
		}else{
			candidate_tile = finder.check_sta_freight_property(prev_halt, wt_rail, 2).top()
		}

		// 分岐駅の分岐側をターミナル駅側と逆側に設定する
		local boundary_list = station.get_boundary_station_pos(candidate_tile, 2)
		local terminal = station.get_own_terminal_station(pl)
		if(terminal != null && finder.is_same_halt(prev_halt, terminal))
		{
			terminal = null
		}
		if(terminal != null)
		{
			local tbl_terminal_info = station.get_station_info(terminal, 2, false)
			local terminal_stop_list = map(tbl_terminal_info.tbl_form_info_list, @(a) a.stop)
			local asf = astar_route_finder(wt_rail)
			local tbl_list = []
			foreach(boundary in boundary_list)
			{
				local dist = world.get_size().x + world.get_size().y
				foreach(terminal_stop in terminal_stop_list)
				{
					local res = asf.search_route([terminal_stop], [boundary])
					if("err" in res){ continue }
					if(res.routes.len() < dist){ dist = res.routes.len() }
				}
				if(dist < world.get_size().x + world.get_size().y)
				{
					local tbl_temp =
					{
						dist = dist
						tile = boundary
					}
					tbl_list.append(tbl_temp)
				}
			}
			if(tbl_list.len() != 0)
			{
				tbl_list = sort(tbl_list, @(a,b) b.dist <=> a.dist)
				to_tile = tbl_list[0].tile
			}
		}
		
		// 駅を分岐駅にする
		return station.update_junction_station(pl, prev_halt, to_tile)
	}

	/***************************************
	 * 新駅建設情報作成
	 * 引数：駅設置目標物(Coord)、一つ前の駅候補からの方角(int,int)、次駅候補の方角(int,int)、新駅の短辺(int)、新駅の長辺(int)、
	 *              目標物から新駅までの最小距離(int)、目標物から新駅までの最大距離(int)、プレイヤー会社(player_x)、バス停併設フラグ(boolean)
	 * 戻り値：新駅建設情報のリスト
	 *           sta_tile_list：プラットホーム建設タイルリスト(tile_x)
	 *           c_in         ：始点側の駅構内(Coord)
	 *           c_out        ：終点側の駅構内(Coord)
	 *           construct_flg：建設するかどうか(boolean)
	 *           bus_stop_flg ：駅舎とバス停を建設するかどうか(boolean)
	 * 備考：c_in、c_outは行き違い駅の分岐部分を示す
	 * 　　　駅設置目標物は建築物が建っていること
	 ***************************************/
	function get_construct_stationinfo(target, from_dir, to_dir, short_edge_length, long_edge_length, init_cov, max_cov, pl, bus_stop_flg)
	{
		// 戻り値初期化
		local rtn_list = []
		// 駅の向き決める
		/* 一つ前の駅候補からの方角、次駅候補の方角それぞれ長辺の向きを取得
		   各長辺の向きで、短い方を駅の向きとする
		   長辺を取得できなかったらできた方だけで計算
		   全く取得できなかったら一つ前の駅候補からの方角、次駅候補の方角の相対角を取得し、
		   長い方を駅の向きとする
		*/
		local sta_dir = dir.none
		local dir_list = []
		if(from_dir != null && abs(from_dir[0]) != abs(from_dir[1]))
		{
			local from_score = abs(from_dir[0]) > abs(from_dir[1]) ? coord(from_dir[0], 0) : coord(0, from_dir[1])
			dir_list.append(from_score)
		}
		if(to_dir != null && abs(to_dir[0]) != abs(to_dir[1]))
		{
			local to_score = abs(to_dir[0]) > abs(to_dir[1]) ? coord(to_dir[0], 0) : coord(0, to_dir[1])
			dir_list.append(to_score)
		}
		if(dir_list.len() != 0)
		{
			dir_list = sort(dir_list, @(a,b) abs(a.x)+abs(a.y) <=> abs(b.x)+abs(b.y))
			sta_dir = dir_list[0].to_dir()
		}else{
			if(from_dir == null){ from_dir = [0,0] }
			if(to_dir == null){ to_dir = [0,0] }
			local relative_dir = [from_dir[0] + to_dir[0], from_dir[1] + to_dir[1]]
			sta_dir = relative_dir[0] > relative_dir[1] ? coord(relative_dir[0], 0).to_dir() : coord(0, relative_dir[1]).to_dir()
			if(abs(relative_dir[0]) == abs(relative_dir[1]))
			{
				dir_list = finder.divide_dir(coord(relative_dir[0], relative_dir[1]).to_dir())
				sta_dir = dir_list[get_idx_by_month(dir_list.len())]
			}
		}
		
		// 土地探し
		local sta_area_list = []
		local area_x = null
		local area_y = null
		if(sta_dir == dir.north || sta_dir == dir.south)
		{
			area_x = short_edge_length
			area_y = long_edge_length
		}else{
			//駅を東西方向に設置
			area_x = long_edge_length
			area_y = short_edge_length
		}
		local candidate_sta_tile_list = []
		local t_target = finder.coord2D_to_tile(target)
		local bldg = t_target.find_object(mo_building)
		if(bldg == null){ return rtn_list }
		if(bus_stop_flg)
		{
			if(bldg.is_townhall())
			{
				local city = city_x(target.x, target.y)
				local city_center_pos = finder.get_center([city.get_pos_nw(), city.get_pos_se()])
				
				// 市内に記念碑があれば、それを基準にする
				local city_bldg_area_list = finder.base_to_tile_list(city.get_pos_nw(), city.get_pos_se().x-city.get_pos_nw().x, city.get_pos_se().y-city.get_pos_nw().y, 1)
				local bldg_list = map(city_bldg_area_list, @(a) a.find_object(mo_building))
				bldg_list = filter(bldg_list, @(a) a != null && a.is_monument())
				// 記念碑がないなら、既存バス停があるならそれを基準にする
				if(bldg_list.len() == 0)
				{
					local bus_stop_list = finder.check_busstop_in_city(city, pl, false)
					bldg_list = map(bus_stop_list, @(a) a.get_tile_list().top().find_object(mo_building))
				}
				
				// 市内に記念碑がある
				if(bldg_list.len() == 1)
				{
					target = coord(bldg_list[0].x, bldg_list[0].y)
					bldg = bldg_list[0]
				}else{
					if(bldg_list.len() > 0)
					{
						if(sta_dir == dir.north || sta_dir == dir.south)
						{
							// 市域の外縁に近い順にソート
							local city_edge_list = [city.get_pos_nw().x, city.get_pos_se().x]
							local tbl_temp_list = []
							foreach(t_bldg in bldg_list)
							{
								local aa = abs(city_edge_list[0]-t_bldg.get_tile_list().top().x)
								local bb = abs(city_edge_list[1]-t_bldg.get_tile_list().top().x)
								local t_dist = aa < bb ? aa : bb
								local tbl_temp =
								{
									bldg = t_bldg
									dist = t_dist
								}
								tbl_temp_list.append(tbl_temp)
							}
							tbl_temp_list = sort(tbl_temp_list, @(a,b) a.dist <=> b.dist)
							bldg = tbl_temp_list[0].bldg
							target = coord(bldg.x, bldg.y)
						}else{
							// 市域の外縁に近い順にソート
							local city_edge_list = [city.get_pos_nw().y, city.get_pos_se().y]
							local tbl_temp_list = []
							foreach(t_bldg in bldg_list)
							{
								local aa = abs(city_edge_list[0]-t_bldg.get_tile_list().top().y)
								local bb = abs(city_edge_list[1]-t_bldg.get_tile_list().top().y)
								local t_dist = aa < bb ? aa : bb
								local tbl_temp =
								{
									bldg = t_bldg
									dist = t_dist
								}
								tbl_temp_list.append(tbl_temp)
							}
							tbl_temp_list = sort(tbl_temp_list, @(a,b) a.dist <=> b.dist)
							bldg = tbl_temp_list[0].bldg
							target = coord(bldg.x, bldg.y)
						}
					}
				}
			}

			while(init_cov < max_cov)
			{
				candidate_sta_tile_list = finder.find_target_places(target, area_x, area_y, init_cov, max_cov, @(a) a.is_empty() && a.get_slope() == slope.flat)
				if(candidate_sta_tile_list.len() == 0)
				{
					candidate_sta_tile_list = finder.find_target_places(target, area_x, area_y, init_cov, max_cov, @(a) a.is_empty())
				}
				// 始終点に他社の橋があると建設不可なので当該タイルは除外する
				candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) finder.can_remove_all_objects(a, pl))
				// 座標を駅中心に移す
				local temp_d = null
				if(is_member(sta_dir, [dir.north, dir.south]))
				{
					candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) finder.can_remove_all_objects(finder.coord2D_to_tile(finder.move_coord(a, dir.south, long_edge_length)), pl))
					candidate_sta_tile_list = map(candidate_sta_tile_list, @(a) finder.coord2D_to_tile(finder.move_coord(a, dir.south, long_edge_length / 2)))
					temp_d = dir.east
				}else{
					candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) finder.can_remove_all_objects(finder.coord2D_to_tile(finder.move_coord(a, dir.east, long_edge_length)), pl))
					candidate_sta_tile_list = map(candidate_sta_tile_list, @(a) finder.coord2D_to_tile(finder.move_coord(a, dir.east, long_edge_length / 2)))
					temp_d = dir.south
				}
				local candidate_sta_tile_list_bk = []
				foreach(candidate_sta_tile in candidate_sta_tile_list)
				{
					local opposite_sta_tile = finder.coord2D_to_tile(finder.move_coord(candidate_sta_tile, temp_d, short_edge_length-1))
					local oppo_dist = abs(opposite_sta_tile.x - target.x) + abs(opposite_sta_tile.y - target.y)
					local dist = abs(candidate_sta_tile.x - target.x) + abs(candidate_sta_tile.y - target.y)
					candidate_sta_tile = dist < oppo_dist ? candidate_sta_tile : opposite_sta_tile
					candidate_sta_tile_list_bk.append(candidate_sta_tile)
				}
				candidate_sta_tile_list = candidate_sta_tile_list_bk
				// 隣接町が近い候補地は除外
				if(bldg.is_townhall())
				{
					local city = city_x(target.x, target.y)
					candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) finder.find_nearest_city(a).get_name() == city.get_name())
				}
				
				if(from_dir != null)
				{
					// 一つ前の駅から近すぎる候補地は除外
					candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) abs(a.x-from_dir[0])+abs(a.y-from_dir[1]) >= 2*settings.get_station_coverage()+1)
				}
				local new_candidate_sta_tile_list = []
				foreach(candidate_sta_tile in candidate_sta_tile_list)
				{
					// 候補地周りに駅舎用の空き地はあるか
					local dist = candidate_sta_tile - target
					local dd = dir.north
					if(sta_dir == dir.north || sta_dir == dir.south)
					{
						if(dist.x > 0)
						{
							dd = dir.west
						}else{
							dd = dir.east
						}
					}else{
						if(dist.y > 0)
						{
							dd = dir.north
						}else{
							dd = dir.south
						}
					}

					local first_tile = finder.coord2D_to_tile(finder.move_coord(candidate_sta_tile, dd))
					local second_tile = finder.coord2D_to_tile(finder.move_coord(candidate_sta_tile, dd, 2))
					if(first_tile == null || second_tile == null){ continue }
					if(first_tile.is_empty() && (finder.get_put_bus_stop_tile(second_tile, pl) || second_tile.is_empty()))
					{
						new_candidate_sta_tile_list.append(candidate_sta_tile)
					}
				}
				if(new_candidate_sta_tile_list.len() == 0)
				{
					init_cov++
				}else{
					candidate_sta_tile_list = new_candidate_sta_tile_list
					break
				}
			}
		}else{
			// 駅設置目標物にマルチタイル建築(産業、名所旧跡)がある場合、駅網羅エリアを再検索
			candidate_sta_tile_list = get_station_coverage_list(bldg.get_tile_list())

			// 駅設置可能なタイルを抽出
			candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) check_station_area(a, area_x, area_y, @(b) b.is_empty() && b.get_slope() == slope.flat))
			if(candidate_sta_tile_list.len() == 0)
			{
				candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) check_station_area(a, area_x, area_y, @(b) b.is_empty()))
			}
			// 一つ前の駅から近すぎる候補地は除外
			if(from_dir != null)
			{
				candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) abs(a.x-from_dir[0])+abs(a.y-from_dir[1]) >= 2*settings.get_station_coverage()+1)
			}
			if(candidate_sta_tile_list.len() == 0){ return rtn_list }
			candidate_sta_tile_list = filter(candidate_sta_tile_list, @(a) a != null)
		}

		if(candidate_sta_tile_list.len() == 0){ return rtn_list }
		// 駅設置目標物から近い順にソート
		candidate_sta_tile_list = sort(candidate_sta_tile_list, @(a,b) abs(a.x-target.x)+abs(a.y-target.y) <=> abs(b.x-target.x)+abs(b.y-target.y))
		local half_long_edge = (long_edge_length - 1)/2
		// 駅構内はホームから3マスまでとする
		if(half_long_edge > 3){ half_long_edge = 3 }
		foreach(candidate_sta_tile in candidate_sta_tile_list)
		{
			local c_in = null
			local c_out = null
			switch(sta_dir)
			{
				case dir.north:
				c_in = coord(candidate_sta_tile.x, candidate_sta_tile.y + half_long_edge)
				c_out = coord(candidate_sta_tile.x, candidate_sta_tile.y - half_long_edge)
				break
				case dir.south:
				c_in = coord(candidate_sta_tile.x, candidate_sta_tile.y - half_long_edge)
				c_out = coord(candidate_sta_tile.x, candidate_sta_tile.y + half_long_edge)
				break
				case dir.east:
				c_in = coord(candidate_sta_tile.x - half_long_edge, candidate_sta_tile.y)
				c_out = coord(candidate_sta_tile.x + half_long_edge, candidate_sta_tile.y)
				break
				case dir.west:
				c_in = coord(candidate_sta_tile.x + half_long_edge, candidate_sta_tile.y)
				c_out = coord(candidate_sta_tile.x - half_long_edge, candidate_sta_tile.y)
				break
			}
			if(!(world.is_coord_valid(c_in)) || !(world.is_coord_valid(c_out))){ continue }
			local sta_info =
			{
				// ホームは3マス分確保しているが、まずは1マスだけ
				sta_tile_list = [candidate_sta_tile]
				c_in = c_in
				c_out = c_out
				construct_flg = true
				bus_stop_flg = bus_stop_flg
			}
			rtn_list.append(sta_info)
		}
		return rtn_list
	}

	/***************************************
	 * 線路敷設する時、間に経由地があれば経由して駅設置
	 * 引数：線路敷設開始地点(tile_x)、線路敷設目的地(tile_x)、経由候補地一覧(tile_xのリスト)、プレイヤー会社(player_x)、
	 *           、対象貨物属性(0:荷物、1:郵便、2:旅客)
	 * 戻り値：線路敷設の情報
	 * 　　　　tile  :線路敷設終了地点(tile_x)
	 * 　　　　blnFlg:駅設置後、次の町まで線路敷設するかどうか
	 *   already_halt:最後の駅が既存駅の場合、記録する
	 *       add_list:追加した経由地一覧(tile_xのリスト)
	 * 備考：線路敷設失敗したらnull返す
	 ***************************************/
	function insert_ind_attract(start, to, via_list, pl, freight)
	{
		local city_info = persistent.city.get_city_info()
		local station = station_manager_t()
		// 線路アドオンを選択
		local way = select_rail(pl, null)
		if(way == null){ return }
		local rtn = {tile = start, blnFlg = true, already_halt = start.get_halt(), add_list = []}
		// 線路敷設開始地点に駅がある場合
		if(rtn.already_halt)
		{
			local tbl_sta_info = station.get_station_info(rtn.already_halt, freight, false)
			// 棒線駅かつ末端駅の場合、線路敷設開始地点再設定
			if(tbl_sta_info.tbl_form_info_list.len() == 1 && dir.is_single(tbl_sta_info.tbl_form_info_list[0].dir))
			{
				local temp_list = station.get_boundary_station_pos(tbl_sta_info.tbl_form_info_list[0].stop, 4)
				temp_list = sort(temp_list, @(a,b) abs(to.x-a.x)+abs(to.y-a.y) <=> abs(to.x-b.x)+abs(to.y-b.y))
				rtn.tile <- temp_list[0]
				start = rtn.tile
				rtn.already_halt <- null
			}
		}
		local idx = 0
		local jj = 2
		// 目的地に着くまで無限ループ
		while(1)
		{
			// 線路敷設開始地点から次の町までを半径とする扇内の経由地探索
			local from_dir =[to.x-rtn.tile.x, to.y-rtn.tile.y]
			local radius = abs(from_dir[0]) + abs(from_dir[1]) - settings.get_station_coverage()
			local tan = math.atan2(from_dir[1], from_dir[0])
			local target_via_list = filter(via_list, @(a) abs(a.x-rtn.tile.x)+abs(a.y-rtn.tile.y) < radius)
			target_via_list = filter(target_via_list, @(a) (abs(tan - math.atan2(a.y-rtn.tile.y, a.x-rtn.tile.x)) <= 160 / jj) || (360 - abs(tan - math.atan2(a.y-rtn.tile.y, a.x-rtn.tile.x)) <= 160 / jj))
			
			// 線路敷設開始地点からの距離で昇順ソート
			target_via_list = sort(target_via_list, @(a,b) abs(a.x-rtn.tile.x)+abs(a.y-rtn.tile.y) <=> abs(b.x-rtn.tile.x)+abs(b.y-rtn.tile.y))
			// 前の駅建設予定地から近すぎる場所は除外
			local dist_list = map(target_via_list, @(a) abs(a.x-rtn.tile.x)+abs(a.y-rtn.tile.y))
			dist_list = filter(dist_list, @(a) a >= 2 * settings.get_station_coverage()+1)
			target_via_list = target_via_list.slice(target_via_list.len() - dist_list.len(), target_via_list.len())
			if(target_via_list.len() == 0 || idx >= target_via_list.len())
			{
				if(!(rtn.blnFlg))
				{
					local next_city = city_x(to.x, to.y)
					if(!(compare_coord(next_city.get_pos(), finder.find_nearest_city(rtn.tile).get_pos()))){ rtn.blnFlg <- true }
				}
				break
			}

			// 選定した経由地には既に駅が設置されているか
			local halt = null
			local obj = target_via_list[idx].find_object(mo_building)
			if(obj.is_townhall())
			{
				local city = filter(city_list_x(), @(a) is_member(a.get_pos(), obj.get_tile_list()))
				halt = finder.reseach_station_nearest_city(city[0], pl, true)
			}else{
				local ind_att_tile_list = obj.get_tile_list()
				local around_tile_list = get_station_coverage_list(ind_att_tile_list)
				local halt_list = filter(map(around_tile_list, @(a) a.get_halt()), @(b) b != null)
				halt_list = filter(halt_list, @(a) finder.check_sta_freight_property(a, wt_rail, freight).len() > 0)
				local public_halt_list = filter(halt_list, @(a) a.get_owner().nr == 1)
				if(public_halt_list.len() > 0)
				{
					halt = public_halt_list[0]
				}else{
					halt_list = filter(halt_list, @(a) a.get_owner().nr == pl.nr)
					halt = halt_list.len() > 0 ? halt_list[0] : null
				}
			}

			// 駅設置済み
			if(halt)
			{
				// 既存駅の情報取得
				local tbl_sta_info = check_already_station(null, halt, pl, 2)
				if(tbl_sta_info)
				{
					// 既存駅が棒線駅かつ終端駅なら終端線路の座標取得
					if(tbl_sta_info.tbl_form_info_list.len() == 1 && dir.is_single(tbl_sta_info.tbl_form_info_list[0].dir))
					{
						local temp_list = station.get_boundary_station_pos(tbl_sta_info.tbl_form_info_list[0].stop, 4)
						temp_list = filter(temp_list, @(a) dir.is_single(a.get_way_dirs(wt_rail)))
						rtn.tile <- temp_list[0]
					}else{
						// 1番目の経由地の場合、呼び出し元で分岐駅作ってるので以降の処理スキップ
						if(compare_coord(rtn.tile, start))
						{
							idx++
							continue
						}	
						rtn.already_halt <- halt
						rtn.tile <- tbl_sta_info.tbl_form_info_list[0].stop
					}
					// 既存駅が目的地付近にあり、バス停を併設しているか
					local blnBS = finder.check_sta_freight_property(halt, wt_road, 2).len()
					if(blnBS && freight == 2)
					{
						local next_city = city_x(to.x, to.y)
						local halt_in_next_city = finder.reseach_station_nearest_city(next_city, pl, false)
						if(halt_in_next_city != null && !(finder.is_same_halt(halt_in_next_city, halt))){ blnBS = !(blnBS) }
					}
					// blnFlgはtrueで経由地から目的地に延伸する
					rtn.blnFlg <- !(blnBS)
					rtn.add_list.append(target_via_list[idx])
					
					jj++
					continue
				}
			}

			if(rtn.already_halt)
			{
				// 分岐駅設置
				local tbl_update_info = build_rail_junction(rtn.already_halt, target_via_list[idx], pl)
				if(tbl_update_info == null)
				{
					 idx++
					 continue
				}
				rtn.already_halt <- null
				rtn.tile <- tbl_update_info.exit
			}

			// 線路敷設開始地点から経由地への方向 
			local temp_from_dir = [target_via_list[idx].x-rtn.tile.x, target_via_list[idx].y-rtn.tile.y]
			// 経由地から目的地への方向 
			local to_dir = [to.x-target_via_list[idx].x, to.y-target_via_list[idx].y]
			
			// ホーム1マス+駅へのアプローチを想定して前後に3マス=7の根拠
			local sta_info_list = get_construct_stationinfo(target_via_list[idx], temp_from_dir, to_dir, 1, 7, 1, settings.get_station_coverage(), pl, false)
			// 駅建設予定地探索失敗
			if(sta_info_list.len() == 0)
			{
				idx++
				if(idx == target_via_list.len())
				{
					break
				}else{
					continue
				}
			}else{
				idx = 0
			}

			// 線路敷設終了地点
			local end = null
			// 線路敷設終了後の次の敷設開始地点(敷設終了地点から駅を挟んで反対側)
			local restart = null
			local build_start_tile = rtn.tile
			local start_rail_dir = build_start_tile.get_way_dirs(wt_rail)
			local sta_info = null
			for(local kk = 0; kk < sta_info_list.len(); kk++)
			{
				// 駅設置予定地を整地
				local target_tile_list = finder.get_interpolate_tile(sta_info_list[kk].c_in, sta_info_list[kk].c_out)
				finder.flat_tiles(target_tile_list, pl)
				// 駅設置予定地のz値を更新
				local sta_tile_list = map(sta_info_list[kk].sta_tile_list, @(a) finder.coord2D_to_tile(coord(a.x, a.y)))

				// 駅構内の線路敷設
				end = finder.coord2D_to_tile(sta_info_list[kk].c_in)
				restart = finder.coord2D_to_tile(sta_info_list[kk].c_out)
				command_x.build_way(pl, end, restart, way, true)
				// 線路終端に段差があれば、スロープをセット
				finder.set_slope_for_way(end, true, pl)
				finder.set_slope_for_way(restart, true, pl)
				
				// 駅間に線路敷設
				local rtn_dir = rtn.tile.get_way_dirs(wt_rail)
				persistent.setting_rail <- [restart, end]
				sta_info = sta_info_list[kk]
				rtn.tile = set_rail_between_station(rtn.tile, end, pl)
				if(rtn.tile)
				{
					local remove_rail_list = finder.get_interpolate_tile(end, restart)
					remove_rail(remove_rail_list, pl)
				}else{
					jj++
					// 設置した駅が町近傍にあれば、バス停建設フラグon
					local near_city = finder.find_nearest_city(sta_tile_list.top())
					local c_around_sta_tile_list = get_station_coverage_list(sta_tile_list)
					local around_sta_tile_list = map(c_around_sta_tile_list,@(a) finder.coord2D_to_tile(a))
					around_sta_tile_list = filter(around_sta_tile_list, @(a) near_city.get_pos_nw().x < a.x && near_city.get_pos_nw().y < a.y && near_city.get_pos_se().x > a.x && near_city.get_pos_se().y > a.y)
					local build_sta_flg = around_sta_tile_list.len() == 0 ? true : false

					rtn = {tile = restart, blnFlg = build_sta_flg, already_halt = null, add_list = rtn.add_list}
					delete persistent.setting_rail
					break
				}
				delete persistent.setting_rail
			}
			// 駅間線路敷設失敗時
			if(!(compare_coord(rtn.tile, restart)))
			{
				local asf = astar_route_finder(wt_rail)
				local res = asf.search_route([build_start_tile], [rtn.tile])
				if(!("err" in res))
				{
					res.routes.remove(0)
					local tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
					remove_rail(tile_list, pl)
				}
				idx++
				if(idx == target_via_list.len())
				{
					break
				}else{
					continue
				}
			}

			// 駅設置
			local err = null
			if(!(rtn.blnFlg))
			{
				err = station.build_new_station(pl, sta_info.sta_tile_list, true)
				if(err != null){ err = station.build_form(pl, sta_info.sta_tile_list, true) }
			}else{
				err = station.build_form(pl, sta_info.sta_tile_list, true)
			}
			if(err != null)
			{
				gui.add_message_at(pl, "failed build station at "+ coord_to_string(sta_info.sta_tile_list.top()) + ":" + err, sta_info.sta_tile_list.top())
				local build_rail_list = station.trace_way(build_start_tile, wt_rail, dir.backward(start_rail_dir), @(a) 1)
				if(build_rail_list.len() > 1){ remove_rail(build_rail_list, pl) }
				idx++
				if(idx == target_via_list.len())
				{
					break
				}else{
					continue
				}
			}
			rtn.add_list.append(target_via_list[idx])
			jj++
		}
		
		if(compare_coord(rtn.tile, start)){ return }  /* 線路を一切敷設しなかったらnullを返す */
		return rtn
	}

	/***************************************
	 * 線路敷設
	 * 引数：線路敷設開始地点(tile_x)、線路敷設終了地点(tile_x)、プレイヤー会社(player_x)
	 * 戻り値：null(成功時)、実際の線路敷設終了地点(tile_x)(失敗時)
	 ***************************************/
	 function set_rail_between_station(start, end, pl)
	 {
	 	// 線路接続チェック & 建設
		local as = astar_builder()
		as.builder = way_planner_x(pl)
		// 線路アドオンを選択
		local way = select_rail(pl, null)
		if(way == null){ return start }
		as.way = way
		as.builder.set_build_types(way)
		as.bridger = pontifex(pl, way)
		if (as.bridger.bridge == null) {
			as.bridger = null
		}
		
		// 線路敷設時は既存線路タイルを避けるが、スイッチバック駅構内のみは許可する
		local rail_OK_area_list = [end]
		local start_rail_dir = start.get_way_dirs(wt_rail)
		if(dir.is_single(start_rail_dir))
		{
			local temp_tile = finder.move_coord(start, start_rail_dir, 6)
			if(temp_tile != null)
			{
				local temp_tile_list = finder.get_interpolate_tile(start, temp_tile)
				// 信号タイルを含む場合は、スイッチバック不可
				local sig_tile = filter(temp_tile_list, @(a) a.find_object(mo_signal) != null)
				if(sig_tile.len() == 0)
				{
					temp_tile_list = filter(temp_tile_list, @(a) a.get_halt() != null)
					temp_tile_list = sort(temp_tile_list, @(a,b) abs(a.x - start.x) + abs(a.y - start.y) <=> abs(b.x - start.x) + abs(b.y - start.y))
					if(temp_tile_list.len() != 0)
					{
						local station = station_manager_t()
						temp_tile = temp_tile_list.top()
						if(is_member(start_rail_dir, [dir.north, dir.south]))
						{
							temp_tile_list = station.trace_way(temp_tile, wt_rail, start_rail_dir, @(a) a.x == temp_tile.x && abs(temp_tile.y-a.y) < 4)
						}else{
							temp_tile_list = station.trace_way(temp_tile, wt_rail, start_rail_dir, @(a) a.y == temp_tile.y && abs(temp_tile.x-a.x) < 4)
						}
						temp_tile = temp_tile_list.top()
					}
					temp_tile_list = finder.get_interpolate_tile(start, temp_tile)
					rail_OK_area_list = combine(rail_OK_area_list, temp_tile_list)
				}
			}
		}
		as.rail_OK_area = rail_OK_area_list
		
		// 線路敷設禁止エリア設定
		/* 東向きの場合、以下のエリアが禁止エリア　凡例-:線路 x:禁止エリア *:start
		xxx
		xx
		--*
		xx
		xxx
		*/
		local tile_list = compare_coord(start, rail_OK_area_list.top()) ? [start, end, rail_OK_area_list[1]] : [start, end, rail_OK_area_list.top()]
		local prohibit_area = []
		foreach(tile in tile_list)
		{
			local area = finder.base_to_tile_list(tile, 5, 5, 0)
			local end_rail_dir = tile.get_way_dirs(wt_rail)
			if(!(dir.is_single(end_rail_dir)))
			{
				local temp_dir = coord(tile.x - start.x, tile.y - start.y)
				if(temp_dir.x == 0 && temp_dir.y == 0)
				{
					temp_dir = coord(tile.x - end.x, tile.y - end.y)
				}
				if(end_rail_dir == dir.northsouth)
				{
					if(temp_dir.y > 0)
					{
						end_rail_dir = dir.north
					}else{
						end_rail_dir = dir.south
					}
				}
				if(end_rail_dir == dir.eastwest)
				{
					if(temp_dir.x > 0)
					{
						end_rail_dir = dir.west
					}else{
						end_rail_dir = dir.east
					}
				}
			}
			// 禁止エリアに属さないエリアは除外
			if(end_rail_dir == dir.north || end_rail_dir == dir.south)
			{
				area = filter(area, @(a) a.x != tile.x)
				if(end_rail_dir == dir.north)
				{
					area = filter(area, @(a) a.y <= tile.y)
				}else{
					area = filter(area, @(a) a.y >= tile.y)
				}
			}else{
				area = filter(area, @(a) a.y != tile.y)
				if(end_rail_dir == dir.west)
				{
					area = filter(area, @(a) a.x <= tile.x)
				}else{
					area = filter(area, @(a) a.x >= tile.x)
				}
			}
			local no_prohibit_area_list = []
			local no_prohibit_area = finder.coord2D_to_tile(finder.move_coord(tile, finder.rotate_right_angle(end_rail_dir, true)))
			if(no_prohibit_area != null)
			{
				no_prohibit_area_list.append(no_prohibit_area)
			}
			no_prohibit_area = finder.coord2D_to_tile(finder.move_coord(tile, finder.rotate_right_angle(end_rail_dir, false)))
			if(no_prohibit_area != null)
			{
				no_prohibit_area_list.append(no_prohibit_area)
			}
			no_prohibit_area_list.append(end)
			
			area = filter(area, @(a) !(is_member(a, no_prohibit_area_list)))
			prohibit_area = combine(prohibit_area, area)
		}

		as.prohibit_area = prohibit_area
		
		// 敷設失敗時に終了地点から先の区間撤去するために終了地点の隣接タイル取得
		local end_rail_dir = end.get_way_dirs(wt_rail)
		local neighbor_end = end.get_neighbour(wt_rail, end_rail_dir)
		// 駅間の線路敷設
		//local rtn = as.search_route([start], [end])
		as.counter_max_flg = true
		local rtn = search_route_for_rail(as, start, end, pl)
		if(rtn != null)
		{
			if("start" in rtn){ return finder.coord2D_to_tile(rtn.start) }
		}
	 }

	/***************************************
	 * 線路分岐用の新駅設置するのに最適な場所を探索
	 * 引数：探索開始する既存駅(halt_x)、分岐先の目的地(Coord)、プレイヤー会社(player_x)
	 * 戻り値：新駅設置最適タイル(tile_x)
	 * 備考：新駅設置最適タイルは線路があるタイルである(既にホームがある場合もある)
	 ***************************************/
	function search_new_junction_sta_tile(halt, to, pl)
	{
		local rtn = null
		local sta_width = settings.get_station_coverage() * 2 + 1 > 13 ? settings.get_station_coverage() * 2 + 1 : 13
		local station = station_manager_t()
		local tbl_sta_info = station.get_station_info(halt, 2, false)
		local tbl_form_info_list = tbl_sta_info.tbl_form_info_list
		local already_dir = dir.none
		foreach(tbl_form_info in tbl_form_info_list)
		{
			local boundary_list = station.get_boundary_station_pos(tbl_form_info.stop, 2)
			boundary_list = sort(boundary_list, @(a,b) abs(a.x-to.x)+abs(a.y-to.y) <=> abs(b.x-to.x)+abs(b.y-to.y))
			// 探索向き(ホーム端のうち目的地に近い方)
			local d = coord(boundary_list[0].x-boundary_list[1].x, boundary_list[0].y-boundary_list[1].y).to_dir()
			if(already_dir != d)
			{
				already_dir = d
			}else{
				continue
			}
			// ホーム先端から駅範囲*2+ホーム数+1分離れた位置かつ線路がある位置取得
			local dist = settings.get_station_coverage() * 2 + tbl_form_info_list.len()
			local start_list = finder.base_to_tile_list(boundary_list[0], dist, dist, 0)
			start_list = finder.bldg_neighbor_tile_list(start_list)
			switch(d)
			{
				case dir.north:
					start_list = filter(start_list, @(a) a.y < boundary_list[0].y)
					break
				case dir.east:
					start_list = filter(start_list, @(a) a.x > boundary_list[0].x)
					break
				case dir.west:
					start_list = filter(start_list, @(a) a.x < boundary_list[0].x)
					break
				case dir.south:
					start_list = filter(start_list, @(a) a.y > boundary_list[0].y)
					break
			}
			start_list = filter(start_list, @(a) a.has_way(wt_rail))
			foreach(start in start_list)
			{
				// 探索の向き更新(線路の向きから探索向きの逆を除く)
				local rail_dir = start.get_way_dirs(wt_rail)
				local dir_list = finder.divide_dir(rail_dir)
				dir_list = filter(dir_list, @(a) a != dir.backward(d))
				dist = abs(start.x-to.x)+abs(start.y-to.y)
				foreach(dd in dir_list)
				{
					// 目的地との距離が近くなる間、線路をトレース
					local trace_list = station.trace_way(start, wt_rail, dd, @(a) dist = abs(a.x-to.x)+abs(a.y-to.y) < dist ? abs(a.x-to.x)+abs(a.y-to.y) : 0)
					// トレースリストに駅あるなら、目的地に近いものを取得
					local halt_tile_list = filter(trace_list, @(a) a.get_halt() != null)
					if(halt_tile_list.len() != 0 && abs(halt_tile_list.top().x-to.x) + abs(halt_tile_list.top().y-to.y) < dist)
					{
						rtn = halt_tile_list.top()
						dist = abs(halt_tile_list.top().x-to.x) + abs(halt_tile_list.top().y-to.y)
					}
					if(trace_list.len() < sta_width){ continue }
					// sta_width/2分前後タイルが同じ向きなら新駅設置候補タイルとする
					for(local ii = sta_width / 2; ii < trace_list.len() - sta_width / 2; ii++)
					{
						local temp_d = trace_list[ii].get_way_dirs(wt_rail)
						if(!(dir.is_straight(temp_d))){ continue }
						local target_list = trace_list.slice(ii - sta_width / 2, ii + sta_width / 2)
						target_list = filter(target_list, @(a) a.get_way_dirs(wt_rail) != temp_d || a.get_slope() != slope.flat || (a.get_slope() == slope.flat && a.find_object(mo_bridge) != null))
						if(target_list.len() == 0)
						{
							if(halt_tile_list.len() != 0 && abs(halt_tile_list.top().x-trace_list[ii].x)+abs(halt_tile_list.top().y-trace_list[ii].y) < sta_width)
							{
								continue
							}
							if(rtn == null || (rtn != null && abs(trace_list[ii].x-to.x) + abs(trace_list[ii].y-to.y) < dist))
							{
								rtn = trace_list[ii]
								dist = abs(trace_list[ii].x-to.x) + abs(trace_list[ii].y-to.y)
							}
						}
					}
				}
			}
		}
		return rtn
	}

	/***************************************
	 * 分岐駅用に設置した新駅をスケジュールに挿入
	 * 引数：新駅(halt_x)
	 ***************************************/
	function insert_new_station(halt)
	{
		local station = station_manager_t()
		local tbl_sta_info = station.get_station_info(halt, 2, false)
		local tbl_form_info_list = tbl_sta_info.tbl_form_info_list
		local next_stop_list = []
		foreach(tbl_form_info in tbl_form_info_list)
		{
			local next_halt_list = []
			local dir_list = finder.divide_dir(tbl_form_info.dir)
			foreach(d in dir_list)
			{
				// 隣接駅取得
				local tbl_halt_info = { halt = halt, dir = d }
				local next_sta_list = station.search_next_sta(tbl_halt_info, tbl_form_info.stop, d, false, [])
				// 距離の昇順にソート
				next_sta_list = sort(next_sta_list, @(a,b) abs(tbl_form_info.stop.x-a.tile_list[0].x)+abs(tbl_form_info.stop.y-a.tile_list[0].y) <=> abs(tbl_form_info.stop.x-b.tile_list[0].x)+abs(tbl_form_info.stop.y-b.tile_list[0].y))
				// 最近接駅を隣接駅とする
				if(next_halt_list.len() == 0 || !(is_member(true, map(next_halt_list, @(a) finder.is_same_halt(next_sta_list[0].halt, a)))))
				{
					next_halt_list.append(next_sta_list[0].halt)
					local tbl_info = station.get_station_info(next_sta_list[0].halt, 2, false)
					next_stop_list = combine(next_stop_list, map(tbl_info.tbl_form_info_list, @(a) a.stop))
				}
			}
			tbl_form_info.next_halt <- next_halt_list
		}
		next_stop_list = unique(next_stop_list)

		local line_list = filter(halt.get_owner().get_line_list(), @(a) a.get_waytype() == wt_rail)
		local length = 0
		foreach(line in line_list)
		{
			local pl = line.get_owner()
			local idx_list = []
			
			// 各鉄道路線が隣接駅を何番目に停車してるか、調査
			foreach(next_stop in next_stop_list)
			{
				local temp_list = station.get_idx_in_line(line, next_stop)
				idx_list = combine(idx_list, temp_list)
			}
			// 昇順にソート
			idx_list = sort(idx_list, @(a,b) a <=> b)
			local next_halt_list_list = map(tbl_form_info_list, @(a) a.next_halt)
			local schedule_entries = line.get_schedule().entries
			// 新駅が路線の始発駅や終点駅隣接にある場合、idx_listは奇数個になるので修正
			if(idx_list.len() % 2 == 1)
			{
				if(idx_list.top() == schedule_entries.len() - 1)
				{
					idx_list.append(schedule_entries.len())
				}else{
					local temp = get_idx_in_member(schedule_entries.len()/2, idx_list)
					if(temp.len() != 0){ idx_list.insert(temp, schedule_entries.len()/2) }
				}
			}
			// 修正してもidx_listが奇数個ならその路線は不適切
			if(idx_list.len() % 2 == 1){ continue }
			local chg_flg = false
			// 奇数番目とその次のインデックスの差が1なら新駅を通過してる路線
			for(local ii = 0; ii < idx_list.len() - 1; ii += 2)
			{
				if(idx_list[ii+1] - idx_list[ii] == 1)
				{
					// 新駅が路線終点駅隣接の場合、情報修正
					if(idx_list[ii] == schedule_entries.len() - 1){ idx_list[ii+1] = 0 }
					local jj = 0
					for(jj = 0; jj < tbl_form_info_list.len(); jj++)
					{
						if(is_member(true, map(next_halt_list_list[jj], @(b) finder.is_same_halt(schedule_entries[idx_list[ii+1]].get_halt(pl), b))))
						{
							break
						}
					}
					if(jj >= tbl_form_info_list.len()){ continue }
					schedule_entries.insert(idx_list[ii+1]+ii/2, schedule_entry_x(tbl_form_info_list[jj].stop, 0, 0) )
					chg_flg = true
				}
			}
			if(chg_flg)
			{
				local schedule = schedule_x(line.get_waytype(), schedule_entries)
				line.change_schedule(pl, schedule)
				// 最長編成の長さ取得
				local convoy_list = line.get_convoy_list()
				local length_list = map(convoy_list, @(a) total_array(map(a.get_vehicles(), @(b) b.get_length())))
				length_list = sort(length_list, @(a,b) a <=> b)
				if(length < length_list.top()){ length = length_list.top() }
			}
		}
		length = length % CARUNITS_PER_TILE == 0 ? length / CARUNITS_PER_TILE : length / CARUNITS_PER_TILE + 1

		// ホーム延長
		station.extend_form(halt.get_owner(), halt, length, map(tbl_form_info_list, @(a) a.stop))
	}


	/***************************************
	 * 公共駅に対して使用可能ホーム検索
	 * 引数：駅(halt_x)、プレイヤー会社(player_x)、対象貨物属性(0:荷物、1:郵便、2:旅客)
	 * 戻り値：使用可能ホームがあるタイルのリスト(tile_xのリスト)
	 * 備考：
	 ***************************************/
	function get_usable_form_info(halt, pl, freight)
	{
		local station = station_manager_t()
		local tbl_sta_info = station.get_station_info(halt, freight, false)
		local tbl_form_info_list = tbl_sta_info.tbl_form_info_list
		
		// 他社線と接続しているホームを除外(建設できないので)
		local new_tbl_form_info_list = []
		foreach(tbl_form_info in _step_generator(tbl_form_info_list))
		{
			local sta_dir = tbl_form_info.dir
			if(sta_dir == dir.northsouth){ sta_dir = dir.north }
			if(sta_dir == dir.eastwest){ sta_dir = dir.east }
			local sta_dir_list = [sta_dir, dir.backward(sta_dir)]
			local other_com_line_flg = false
			for(local dd = 0; dd < sta_dir_list.len(); dd++)
			{
				local public_rail_list = station.trace_way(tbl_form_info.stop, wt_rail, sta_dir_list[dd], @(a) a.get_way(wt_rail).get_owner().nr == 1)
				if(public_rail_list.len() != 0 && dir.is_twoway(public_rail_list.top().get_way_dirs(wt_rail)))
				{
					local temp_d = sta_dir_list[dd]
					if(public_rail_list.len() > 1)
					{
						temp_d = (coord(public_rail_list[public_rail_list.len()-2].x - public_rail_list.top().x, public_rail_list[public_rail_list.len()-2].y - public_rail_list.top().y)).to_dir()
						temp_d = public_rail_list.top().get_way_dirs(wt_rail) - temp_d
					}
					local boundary_com_pos = public_rail_list.top().get_neighbour(wt_rail, temp_d)
					if(boundary_com_pos == null){ continue }
					if(boundary_com_pos.get_way(wt_rail).get_owner().nr != pl.nr)
					{
						other_com_line_flg = true
						break
					}
				}
			}
			if(other_com_line_flg){ continue }
			new_tbl_form_info_list.append(tbl_form_info)
		}
		tbl_form_info_list = new_tbl_form_info_list
		
		// 発着可能ホーム数が0
		if(tbl_form_info_list.len() == 0){ return [] }
		return map(tbl_form_info_list, @(a) a.stop)
	}

	/***************************************
	 * 駅候補タイルに対して調査
	 * 引数：駅中心候補タイル(tile_x)、x方向の駅の広さ(int)、y方向の駅の広さ(int)、調査関数
	 * 戻り値：建設可否(boolean)
	 * 備考：駅ホームは1マスとする
	 ***************************************/
	function check_station_area(tile, x, y, func)
	{
		local station_list = finder.base_to_tile_list(tile, x, y, 0)
		local len = station_list.len()
		station_list = filter(station_list, func)
		if(station_list.len() == len){ return true }
		return false
	}

	/***************************************
	 * タイルリストのsettings.get_station_coverage分隣接したタイルリストを返す
	 * 引数：タイルリスト(coordのリスト)
	 * 戻り値：settings.get_station_coverage分隣接したタイルリスト(coordのリスト)
	 ***************************************/
	function get_station_coverage_list(tile_list)
	{
		local rtn_list = []
		for(local ii = 0; ii < settings.get_station_coverage(); ii++)
		{
			local temp = finder.bldg_neighbor_tile_list(tile_list)
			foreach(tt in _step_generator(temp))
			{
				rtn_list.append(tt)
				tile_list.append(tt)
			}
		}
		return rtn_list
	}

	/***************************************
	 * 駅設置候補の左上座標から駅設置の中心座標～ランドマークの座標の距離取得
	 * 引数：駅設置候補の左上座標(Coord)、駅の方向(dir)、駅の短辺(int)、駅の長辺(int)、ランドマーク(building_x)
	 * 戻り値：駅設置の中心座標～基準地の座標の距離(int)
	 ***************************************/
	function get_distance_between_sta_target(pos, d, short_edge_length, long_edge_length, target)
	{
		local sta_center = null
		if(d == dir.north || d == dir.south)
		{
			sta_center = coord(pos.x + short_edge_length / 2, pos.y + long_edge_length / 2)
		}else{
			sta_center = coord(pos.x + long_edge_length / 2, pos.y + short_edge_length / 2)
		}
		local target_pos_list = target.get_tile_list()
		return abs(target_pos_list[0].x - sta_center.x) + abs(target_pos_list[0].y - sta_center.y)
	}

	/***************************************
	 * 線路敷設のための経路探索
	 * 引数：経路探索&建設クラス(astar_builder)、始点(tile_x)、終点(tile_x)、プレイヤー会社(player_x)
	 * 戻り値：経路情報(table)
	 *          start：探索開始地点(coord)(分割して探索するので始点と異なる)
	 *          err  ：エラーメッセージ
	 * 備考：長距離をA*アルゴリズムで経路探索すると時間がかかりすぎるので
	 * 　　　分割して実行
	 ***************************************/
	function search_route_for_rail(as, start, end, pl)
	{
		local dx = end.x - start.x
		local dy = end.y - start.y
		local x_list = [start.x]
		// 目的地までを縦横の長さが30pixelに近い四角で分割
		local length_dx = 30
		if(dx % 30 != 0)
		{
			local temp_length_dx = abs(dx) / 30 + 1
			length_dx = abs(dx) / temp_length_dx + 1
		}
		if(abs(dx) > length_dx)
		{
			local diff = length_dx
			local temp_x = start.x
			if(start.x > end.x){ diff = -1*length_dx }
			while(abs(end.x - temp_x) > length_dx)
			{
				temp_x += diff
				x_list.append(temp_x)
			}
		}
		x_list.append(end.x)
		local y_list = [start.y]
		local length_dy = 30
		if(dx % 30 != 0)
		{
			local temp_length_dy = abs(dy) / 30 + 1
			length_dy = abs(dy) / temp_length_dy + 1
		}
		if(abs(dy) > length_dy)
		{
			local diff = length_dy
			local temp_y = start.y
			if(start.y > end.y){ diff = -1*length_dy }
			while(abs(end.y - temp_y) > length_dy)
			{
				temp_y += diff
				y_list.append(temp_y)
			}
		}
		y_list.append(end.y)

		// 終点に着くまで探索終了地点のリストを変更しながら経路探索(探索終了地点のリストは以下の通り)
		// ・自分が所属している分割四角の対角の横辺と縦辺
		// ・自分が所属している分割四角で最遠の角と終点を対角線として生成する長方形の辺のうち、
		//   自分が所属している分割四角を除いた部分
		local roop_start = start
		local trace_tile_list = []
		dx = 1
		dy = 1
		while(!(compare_coord(roop_start, end)))
		{
//gui.add_message_at(pl,"dx:"+dx+",dy:"+dy+",x_list:"+x_list[dx]+",y_list:"+y_list[dy],roop_start)
			// 経路探索開始地点がスロープの場合、その左右タイルを線路敷設対象外とする
			if(is_member(roop_start.get_slope(), [slope.north, slope.west, slope.east, slope.south]))
			{
				local slope_dir = slope.to_dir(roop_start.get_slope())
				local d_temp = finder.rotate_right_angle(slope_dir, true)
				local prohibit_area = as.prohibit_area
				prohibit_area.append(finder.coord2D_to_tile(finder.move_coord(roop_start, d_temp)))
				d_temp = finder.rotate_right_angle(slope_dir, false)
				prohibit_area.append(finder.coord2D_to_tile(finder.move_coord(roop_start, d_temp)))
				as.prohibit_area = prohibit_area
			}

			// 探索終了地点のリスト作成
			local goal_list = []
			if(dx == x_list.len() - 1 && dy == y_list.len() - 1)
			{
				goal_list.append(end)
			}else{
				if(dx < x_list.len() - 1)
				{
					goal_list = finder.get_interpolate_tile(coord(x_list[dx], y_list[dy]), coord(x_list[dx], y_list[dy-1]))
					local temp_goal_list = finder.get_interpolate_tile(coord(x_list[dx], y_list[dy-1]), coord(x_list.top(), y_list[dy-1]))
					goal_list = combine(goal_list, temp_goal_list)
					temp_goal_list = finder.get_interpolate_tile(coord(x_list.top(), y_list[dy-1]), coord(x_list.top(), y_list[dy]))
					goal_list = combine(goal_list, temp_goal_list)
				}
				if(dy < y_list.len() - 1)
				{
					local temp_goal_list = finder.get_interpolate_tile(coord(x_list[dx], y_list[dy]), coord(x_list[dx-1], y_list[dy]))
					goal_list = combine(goal_list, temp_goal_list)
					temp_goal_list = finder.get_interpolate_tile(coord(x_list[dx-1], y_list[dy]), coord(x_list[dx-1], y_list.top()))
					goal_list = combine(goal_list, temp_goal_list)
					temp_goal_list = finder.get_interpolate_tile(coord(x_list[dx-1], y_list.top()), coord(x_list[dx], y_list.top()))
					goal_list = combine(goal_list, temp_goal_list)
				}

				local temp_goal_list = finder.get_interpolate_tile(coord(x_list[dx], y_list.top()), coord(x_list.top(), y_list.top()))
				goal_list = combine(goal_list, temp_goal_list)
				temp_goal_list = finder.get_interpolate_tile(coord(x_list.top(), y_list[dy]), coord(x_list.top(), y_list.top()))
				goal_list = combine(goal_list, temp_goal_list)
				goal_list = unique(goal_list)
				
				goal_list = filter(goal_list, @(a) !(is_member(a, as.prohibit_area)))
				goal_list = filter(goal_list, @(a) a.is_empty() || (a.has_way(wt_rail) && is_member(a.get_way(wt_rail).get_owner().nr, [pl.nr, 1])))
			}

			local goal_list_bk = clone(goal_list)
			// 経路探索する時の探索終了地点は平面または一方向のスロープであること
			goal_list = filter(goal_list, @(a) is_member(a.get_slope(), [slope.flat, slope.north, slope.west, slope.east, slope.south]))			
			// 四角の淵が一つも平面でない場合、整地
			if(goal_list.len() == 0)
			{
				finder.flat_tiles(goal_list_bk, pl)
				goal_list = goal_list_bk
			}
			// 四角の淵まで既に敷設済みの場合は次の淵にスキップ
			local rtn = null
			if(dx != x_list.len() - 1 || dy != y_list.len() - 1)
			{
				local already_rail_pos_list = filter(goal_list, @(a) a.has_way(wt_rail))
				already_rail_pos_list = filter(already_rail_pos_list, @(a) a.get_way(wt_rail).get_owner().nr == pl.nr)
				local asf = astar_route_finder(wt_rail)
				foreach(already_rail_pos in _step_generator(already_rail_pos_list))
				{
					local already_route = asf.search_route([roop_start], [already_rail_pos])
					if(already_route == null || "err" in already_route){ continue }
					local point_pos = filter(already_route.routes, @(a) dir.is_threeway(tile_x(a.x, a.y, a.z).get_way(wt_rail).get_dirs()))
					point_pos = filter(point_pos, @(a) !(compare_coord(a, start)))
					if(point_pos.len() != 0){ continue }
					rtn = { start = roop_start, end = already_rail_pos, routes = []}
					break
				}
			}else{
/*local str="["
for(local ii=0; ii<goal_list.len(); ii++){
str+=coord_to_string(goal_list[ii])+"],["
}
str=str.slice(0,str.len()-2)
gui.add_message_at(pl, "next to "+str,world.get_time()) */
			}

			// 経路探索
			if(rtn == null)
			{
				rtn = as.search_route([roop_start], goal_list)
			}
			if("err" in rtn)
			{
				rtn.start <- roop_start
				return rtn
			}else{
				// 目的地についたor探索終了地点にたどり着いたら
				// 探索終了地点のリスト更新
				for(local ii = dx; ii < x_list.len(); ii++)
				{
					if(x_list[1] - x_list[0] > 0)
					{
						if(rtn.end.x >= x_list[ii])
						{
							dx = ii < x_list.len() - 1 ? ii + 1 : ii
							break
						}
					}else{
						if(rtn.end.x <= x_list[ii])
						{
							dx = ii < x_list.len() - 1 ? ii + 1 : ii
							break
						}
					}
				}
				for(local ii = dy; ii < y_list.len(); ii++)
				{
					if(y_list[1] - y_list[0] > 0)
					{
						if(rtn.end.y >= y_list[ii])
						{
							dy = ii < y_list.len() - 1 ? ii + 1 : ii
							break
						}
					}else{
						if(rtn.end.y <= y_list[ii])
						{
							dy = ii < y_list.len() - 1 ? ii + 1 : ii
							break
						}
					}
				}
			}
			roop_start = finder.coord2D_to_tile(rtn.end)
		}
	}

	/***************************************
	 * 線路を1マスずつ撤去
	 * 引数：タイルリスト(tile_xのリスト)、プレイヤー会社(player_x)
	 * 備考：引数には必ず終端の線路をいれる
	 ***************************************/
	function remove_rail(tile_list, pl)
	{
		local pos = 0
		while(tile_list.len() != 0)
		{
			tile_list = filter(tile_list, @(a) a.has_way(wt_rail))
			tile_list = filter(tile_list, @(a) a.get_way(wt_rail).get_owner().nr == pl.nr)
			tile_list = filter(tile_list, @(a) !(check_working(a)))
			if(tile_list.len() == 0){ return }
			local end_rail_tile_list = filter(tile_list, @(a) dir.is_single(a.get_way_dirs(wt_rail)))
			if(end_rail_tile_list.len() == 0){ return }
			local tile = tile_list[pos]
			local d = tile.get_way_dirs(wt_rail)
			if(dir.is_single(d))
			{
				local tool = command_x(tool_remove_way)
				local err = tool.work(pl, tile, tile.get_neighbour(wt_rail, d), "" + wt_rail)
				if(err != null){ tool.work(pl, tile, tile, "" + wt_rail) }
				if(pos > 0){ pos-- }
			}else{
				pos++
				if(pos >= tile_list.len()){ pos = 0 }
			}
		}
	}

	/***************************************
	 * 線路が営業中かどうか
	 * 引数：タイル(tile_x)
	 * 戻り値：営業中かどうか(boolean)
	 ***************************************/
	function check_working(tile)
	{
		local rtn = false
		local passed_convoy_count_list = tile.get_way(wt_rail).get_convoys_passed()
		passed_convoy_count_list = filter(passed_convoy_count_list, @(a) a > 0)
		if(passed_convoy_count_list.len() > 0){ rtn = true }
		return rtn
	}

	/***************************************
	 * 近くの終端線路を検索
	 * 引数：線路のタイル(tile_x)
	 * 戻り値：終端線路のタイル(tile_x)
	 * 備考：そんなにしっかり作ってない
	 ***************************************/
	function search_end_rail(pos)
	{
		local rtn = []
		local d = pos.get_way_dirs(wt_rail)
		if(dir.is_straight(d))
		{
			if(dir.is_single(d)){ return [pos] }
			local search_dir_list = []
			if(d == dir.northsouth){ search_dir_list = [dir.north, dir.south] }
			if(d == dir.eastwest){ search_dir_list = [dir.east, dir.west] }
			local original_pos = pos
			for(local ii = 0; ii < search_dir_list.len(); ii++)
			{
				pos = original_pos
				d = pos.get_way_dirs(wt_rail)
				local search_dir = search_dir_list[ii]
				while(dir.is_twoway(d))
				{
					pos = pos.get_neighbour(wt_rail, search_dir)
					d = pos.get_way_dirs(wt_rail)
					// カーブにさしかかったら探索終了
					if(dir.is_curve(d)){ break }
				}
				// 分岐に到達したら探索終了
				if(dir.is_threeway(d)){ continue }
				if(dir.is_single(d)){ rtn.append(pos) }
			}
		}
		return rtn
	}

	/***************************************
	 * 線路高速化
	 * 引数：対象路線(line_x)
	 * 戻り値：
	 ***************************************/
	function update_rail(line)
	{
		local schedule_entries = line.get_schedule().entries
		local sche_len = schedule_entries.len()
		local pl = line.get_owner()
		local station = station_manager_t()
		// 最低規格の線路アドオン取得
		local temp_list = station.get_boundary_station_pos(finder.coord2D_to_tile(schedule_entries[sche_len / 2]), 2)
		temp_list = sort(temp_list, @(a,b) b.get_way(wt_rail).get_desc().get_topspeed() <=> a.get_way(wt_rail).get_desc().get_topspeed())
		local old_way_desc = temp_list[0].get_way(wt_rail).get_desc()
		// アップデート後の線路アドオン取得
		local way_desc = select_rail(pl, old_way_desc)
		if(way_desc == null){ return }
		
		local cost = way_desc.get_cost()
		local mainte = way_desc.get_maintenance()
		// 線路引き直し
		local asf = astar_route_finder(wt_rail)
		for(local ii = 0; ii < sche_len - 1; ii++)
		{
			local res = asf.search_route([schedule_entries[ii]], [schedule_entries[ii + 1]])
			if ("err" in res)
			{
				gui.add_message_at(pl,"err:"+res.err+",["+coord_to_string(schedule_entries[ii])+"] -> ["+coord_to_string(schedule_entries[ii + 1])+"]",world.get_time())
				break
			}
			// 事業実施判断
			local tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
			// 立体交差している箇所を除外
			tile_list = filter(tile_list, @(a) a.get_way(wt_rail) != null)
			tile_list = filter(tile_list, @(a) a.get_way(wt_rail).get_desc().get_cost() < way_desc.get_cost())
			if(tile_list.len() == 0){ continue }
			if(!(judge_investment(cost * tile_list.len(), (mainte - old_way_desc.get_maintenance()) * tile_list.len()))){ break }
			
			tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
			// 立体交差している箇所を除外
			tile_list = filter(tile_list, @(a) a.get_way(wt_rail) != null)
			for(local jj = 0; jj < tile_list.len() - 1; jj++)
			{
				// ポイント部分は高速化しない
				if(jj < tile_list.len()-2 && dir.is_curve(tile_list[jj].get_way_dirs(wt_rail)))
				{
					if(dir.is_threeway(tile_list[jj+1].get_way_dirs(wt_rail)) && tile_list[jj].get_way_dirs(wt_rail) != tile_list[jj+2].get_way_dirs(wt_rail))
					{
						continue
					}
				}
				if(jj > 1 && dir.is_curve(tile_list[jj].get_way_dirs(wt_rail)))
				{
					if(dir.is_threeway(tile_list[jj-1].get_way_dirs(wt_rail)) && tile_list[jj].get_way_dirs(wt_rail) != tile_list[jj-2].get_way_dirs(wt_rail))
					{
						continue
					}
				}
				// 橋梁部分
				if(tile_list[jj].find_object(mo_bridge) != null){ continue }
				command_x.build_way(pl, tile_list[jj], tile_list[jj + 1], way_desc, true )
			}
		}
	}

	/***************************************
	 * 電化(架線の更新も実施)
	 * 引数：対象路線(line_x)
	 * 戻り値：電化したか(boolean)
	 ***************************************/
	function electrify_line(line)
	{
		local schedule_entries = line.get_schedule().entries
		local sche_len = schedule_entries.len()
		local pl = line.get_owner()
		// 最低規格の架線アドオン取得
		local tile = finder.coord2D_to_tile(schedule_entries[sche_len / 2])
		local old_wayobj = tile.find_object(mo_wayobj)
		local catenary = (old_wayobj == null) ? select_wayobj(pl, null) : select_wayobj(pl, old_wayobj.get_desc())
		if(catenary == null){ return false }
		
		local cost = catenary.get_cost()
		local asf = astar_route_finder(wt_rail)
		local res = asf.search_route([schedule_entries[0]], [schedule_entries[sche_len / 2]])
		if ("err" in res)
		{
			gui.add_message_at(pl,"[electrify_line] err:"+res.err,world.get_time())
			return false
		}
		// 事業実施判断
		local tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
		local mainte = old_wayobj == null ? catenary.get_maintenance() : catenary.get_maintenance() - old_wayobj.get_desc().get_maintenance()
		// 立体交差している箇所を除外
		tile_list = filter(tile_list, @(a) a.get_way(wt_rail) != null)
		if(tile_list.len() == 0){ return false }
		if(old_wayobj == null)
		{
			if(!(judge_investment(cost * res.routes.len(), mainte * res.routes.len()))){ return false }
		}

		local station = station_manager_t()
		for(local ii = 0; ii < sche_len - 1; ii++)
		{
			res = asf.search_route([schedule_entries[ii]], [schedule_entries[ii + 1]])
			if(old_wayobj != null)
			{
				if(!(judge_investment(cost * res.routes.len(), mainte * res.routes.len()))){ return false }
			}
			
			local temp_list = station.get_boundary_station_pos(finder.coord2D_to_tile(schedule_entries[ii]), 4)
			command_x.build_wayobj(pl, temp_list[0], temp_list[1], catenary)
			tile_list = map(res.routes, @(a) finder.coord2D_to_tile(a))
			// 立体交差している箇所を除外
			tile_list = filter(tile_list, @(a) a.get_way(wt_rail) != null)
			if(tile_list.len() == 0){ return false }
			for(local jj = 0; jj < tile_list.len() - 1; jj++)
			{
				command_x.build_wayobj(pl, tile_list[jj], tile_list[jj + 1], catenary)
			}
		}
		local temp_list = station.get_boundary_station_pos(finder.coord2D_to_tile(schedule_entries[sche_len / 2]), 4)
		command_x.build_wayobj(pl, temp_list[0], temp_list[1], catenary)
		
		// 近くの車庫も電化
		local tile = finder.coord2D_to_tile(schedule_entries[0])
		local depot_pos = search_depot(tile, pl)
		command_x.build_wayobj(pl, tile, depot_pos, catenary)
		return true
	}

	/***************************************
	 * 車庫探索
	 * 引数：駅の座標(tile_x)、会社属性(player_x)
	 * 戻り値：車庫座標(tile_x)
	 ***************************************/
	function search_depot(stop, pl)
	{
		// 車庫探索
		local depot_list = depot_x.get_depot_list(pl, wt_rail)
		if(depot_list.len() == 0)
		{
			// 車庫建設
			local c_depot = build_depot(stop, pl)
			return c_depot
		}else{
			// 駅と車庫との接続チェック
			local asf = astar_route_finder(wt_rail)
			local ii = 0
			foreach(depot in depot_list)
			{
				local res = asf.search_route([stop], [depot.get_pos()])
				if ("routes" in res)
				{
					break
				}
				ii++
			}

			if(ii >= depot_list.len())
			{
gui.add_message_at(pl, "depot debuk:"+ii+":"+depot_list.len()+":["+coord_to_string(stop)+"],["+coord_to_string(depot_list[0].get_pos())+"]", world.get_time())
				// 既存の車庫では出庫できないので、車庫建設
				local c_depot = build_depot(stop, pl)
				return c_depot
			}
			return tile_x(depot_list[ii].get_pos().x, depot_list[ii].get_pos().y, depot_list[ii].get_pos().z)
		}
	}

	/***************************************
	 * 車庫建設
	 * 引数：建設基準座標(この座標付近の空き地に建設)(tile_x)、会社属性(player_x)
	 * 戻り値：車庫座標(tile_x)
	 ***************************************/
	function build_depot(pos, pl)
	{
		// 建設基準座標が駅なら近くの終端線路を探索
		if(pos.get_halt())
		{
			local station = station_manager_t()
			local pos_list = station.get_boundary_station_pos(pos, 4)
			pos_list = filter(pos_list, @(a) dir.is_single(a.get_way_dirs(wt_rail)))
			if(pos_list.len() != 0){ pos = pos_list[0] }
		}
		//車庫建設場所の準備
		local as = rail_depot_pathfinder()
		as.builder = way_planner_x(pl)
		// 線路アドオンを選択
		local way = select_rail(pl, null)
		if(way == null){ return }
		as.builder.set_build_types(way)
		local res = as.search_route(pos, way)

		if ("err" in res) {
			gui.add_message_at(pl, " "+res.err, world.get_time())
			return
		}
		local d = res.end
		local c_depot = tile_x(d.x, d.y, d.z)

		// 車庫建設
		local depot_list = building_desc_x.get_building_list(building_desc_x.depot)
		// 車庫を抽出
		depot_list= filter(depot_list, @(a) a.get_waytype() == wt_rail && a.get_type() == building_desc_x.depot)
		local err = command_x.build_depot(pl, c_depot, depot_list[0])
		if(err)
		{
			gui.add_message_at(pl, "Failed construct depot with "+err, c_depot)
			return
		}
		return c_depot
	}
}

/***************************************
 * 車庫建設場所検索クラス
 * ：
 ***************************************/
class rail_depot_pathfinder extends astar_builder
{
	function estimate_distance(c)
	{
		local t = tile_x(c.x, c.y, c.z)
		local depot = t.find_object(mo_depot_rail)
		if (depot  &&  depot.get_owner().nr == our_player_nr) {
			return 0
		}
		local way = t.get_way(wt_rail)
		if(way) {
			if(way.get_owner().nr == our_player_nr) {
				if(dir.is_single(t.get_way_dirs(wt_rail))){ return 0 }
			}
		}
		if (t.is_empty()  &&  t.get_slope()==0) {
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
					gui.add_message_at(our_player, "Failed to build rail from  " + coord_to_string(route[i-1]) + " to " + coord_to_string(route[i]) +"\n" + err, route[i])
					return { err =  err }
				}
			}
			return { start = route[ route.len()-1], end = route[0] }
		}
		print("No route found")
		return { err =  "No route" }
	}
}