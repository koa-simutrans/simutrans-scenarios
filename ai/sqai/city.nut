/**
 * Classes for city info
 */

class city_info_t extends manager_t
{
	baescity = null		// 各ライバル会社が拠点とする町Idx
	cost_build_city = 5000000  // 町を誘致する資金(本当はsimuconf.tabから取得したかった...)

	constructor() 
	{
		base.constructor("city_info_t")
	}

	/***************************************
	 * 町の情報を取得
	 ***************************************/
	function get_city_info()
	{
		local city_info = []
		local citylist = city_list_x()
		local idx = 0

		foreach( city in citylist )
		{
			local tbl_temp_city_info = 
			{
				idx = idx
				name = city.get_name()
				citizen = (city.get_citizens())[0]
				townhall = city.get_pos()
			}
			idx++
			city_info.append(tbl_temp_city_info)
		}
		return city_info
	}

	/***************************************
	 * 拠点の町セット
	 * 引数：プレイヤーIdx
	 * 戻り値：町Idx
	 ***************************************/
	function set_base_city(pl_nr)
	{
		local base_city = null	// 拠点の町

		// 町情報取得
		local city_info = get_city_info()

		// プレイヤーIdx
		local idx = calc_idx(pl_nr, city_info.len())

		// 町情報を人口で降順ソートする
		local sort_city_info = sort(city_info, @(a,b) b.citizen <=> a.citizen)

		// プレイヤーIdxに応じて拠点の町Idxを選択する
		base_city = sort_city_info[idx].idx

		return base_city
	}

	/***************************************
	 * 拠点の町からルート選定
	 * 引数：町情報、検査対象の町役場座標(Coord)、取得する町の近さリスト(array<int>)、再帰回数(int)、ルート上の町リスト(array<int>)
	 * 町リストは町Idxで構成
	 * 再帰処理の回数が再帰回数番目の時、取得する町の近さリストの再帰回数番目の数値に近い町を選定する
	 * 取得する町の近さリスト長さを超えた場合、最近接の町を選定する
	 ***************************************/
	function select_root(city_info, c_townhall, idx_list, roop_counter, c_root_list)
	{
		// ルートにターゲットの町を追加
		local town_idx = filter(city_info, (@(a) compare_coord(c_townhall, a.townhall) == true))
		c_root_list.append(town_idx[0].idx)

		// 検査対象の町からの距離でソート
		local sort_city_info = sort(city_info, @(a,b) abs(a.townhall.x - c_townhall.x) + abs(a.townhall.y - c_townhall.y) <=> abs(b.townhall.x - c_townhall.x) + abs(b.townhall.y - c_townhall.y))

		// ソート結果のidx_list[roop_counter]番目の町Idxを取得(0番目は検査対象の町である)
		local nearest_city = sort_city_info[idx_list[roop_counter]].idx

		// 最近接の町がルートに登録済みで2番目に近い町が未登録の場合、後者をルートに登録
		// 最近接の町と2番目に近い町がルートに登録済みの場合、再帰処理を終了し、最近接の町を終点とする(環状系統orラケット型系統になる)
		local recursive_flg = true
		if(c_root_list.len() >= 2 && nearest_city == c_root_list[c_root_list.len() - 2] && city_info.len() > 2)
		{
			if(city_info.len() <= roop_counter + 1){ return c_root_list }
			nearest_city = sort_city_info[idx_list[roop_counter]+1].idx
			if(is_member(nearest_city, c_root_list))
			{
				recursive_flg = false
			}
		}
		if(recursive_flg && is_member(nearest_city, c_root_list))
		{
			c_root_list.append(nearest_city)
			recursive_flg = false
		}
		if(recursive_flg && c_root_list.len() >= max_schedule_desc){ recursive_flg = false }

		// 再帰処理
		if(recursive_flg)
		{
			local nearest_city_info = filter(city_info, (@(a) a.idx == nearest_city))
			roop_counter++
			// 取得する町の近さリスト長さを超えた場合、最近接の町を選定する
			if(idx_list.len() <= roop_counter){ idx_list.append(1) }
			c_root_list = select_root(city_info, nearest_city_info[0].townhall, idx_list, roop_counter, c_root_list)
		}

		return c_root_list
	}

	/***************************************
	 * 拠点の町に本社建設
	 * 引数：町情報(city_x)、プレイヤー会社(player_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function build_headquarter(city, pl)
	{
		// hq_levelは本社未建設で0
		local hq_level = pl.get_headquarter_level()
		local hq_list = building_desc_x.get_building_list(building_desc_x.headquarter)
		// 拡張の上限に達したので処理終了
		if(hq_level == hq_list.len()){ return }
		hq_list = sort(hq_list, @(a,b) a.get_headquarter_level() <=> b.get_headquarter_level())
		// 予算チェック
		if(pl.get_current_cash()*100 <= hq_list[hq_level].get_cost() || pl.get_operating_profit()[0]*100 < pl.get_current_maintenance()+hq_list[hq_level].get_maintenance()){ return }
		// 本社建設に必要なタイル数取得
		local size = hq_list[hq_level].get_size(0)

		// 本社の現在位置取得
		local pos = []
		local match_size_flg = false
		if(hq_level > 0)
		{
			pos.append(pl.get_headquarter_pos())
			match_size_flg = compare_coord(hq_list[hq_level-1].get_size(0), size)
			if(!match_size_flg){ compare_coord(hq_list[hq_level-1].get_size(0), coord(size.y, size.x)) }
		}

		if(!(match_size_flg))
		{
			// バスターミナル位置取得
			local terminal = finder.get_bus_terminal(city, pl)
			// 本社建設位置探索
			local city_xsize = abs(city.get_pos_nw().x - city.get_pos_se().x)
			local city_ysize = abs(city.get_pos_nw().y - city.get_pos_se().y)
			local city_size = city_xsize > city_ysize ? city_xsize : city_ysize
			pos = finder.find_target_places(terminal, size.x, size.y, 1, city_size, @(a) a.is_empty())
			if(pos.len() == 0 && size.x != size.y)
			{
				pos = finder.find_target_places(terminal, size.y, size.x, 1, city_size, @(a) a.is_empty())
				size = coord(size.y, size.x)
			}
			// TODO : 建設地が道路に面するように制御したい
			if(pos.len() == 0)
			{
				return "failed build headquarter in "+city.get_name()
			}
		}
		// 本社建設
		local cmd = command_x(tool_headquarter)
		return cmd.work(pl, finder.coord2D_to_3D(pos[0]))
	}

	/***************************************
	 * 町誘致
	 * 引数：プレイヤー会社(player_x)
	 * 戻り値：エラーメッセージ
	 ***************************************/
	function build_city(pl)
	{
		// 予算チェック(後ろの一万cはバッファ)
		if(pl.get_current_cash() * 100 < cost_build_city * 100 + command_x.slope_get_price(slope.all_up_slope) * 25 + 1000000){ return }
		local new_city_pos = null
		local rand_flg = true
		// バス以外の交通機関がある公共駅周辺に誘致
		local public_sta = finder.get_complex_public_sta()
		// 駅近くに既に町がある場合、候補から除外
		local target_sta = []
		foreach(sta in _step_generator(public_sta))
		{
			local sta_pos = (sta.get_tile_list())[0]
			local nearest_city = finder.find_nearest_city(sta_pos)
			local distance = abs(sta_pos.x - nearest_city.get_pos().x) + abs(sta_pos.y - nearest_city.get_pos().y)
			local tbl_factory = 
			{
				distance = distance
				pos = sta_pos
			}
			target_sta.append(tbl_factory)
		}
		target_sta = filter(target_sta, @(a) a.distance > 2*settings.get_station_coverage()+5)
		if(target_sta.len() != 0)
		{
			//検索回数開始位置、最大検索回数は適当
			local candidate_tile_list = finder.find_target_places(target_sta[0].pos, 5, 5, 5, 15, @(a) a.is_empty())
			if(candidate_tile_list.len() != 0)
			{
				new_city_pos = candidate_tile_list[calc_idx(pl.nr, candidate_tile_list.len())]
				rand_flg = false
			}
		}
		// 活動月が偶数月なら産業の近く、奇数付きなら名所旧跡の近く、どちらにも既に町がある場合は適当な地に誘致
		if(new_city_pos == null)
		{
			if(world.get_time().month % 2 == 1)
			{
				// 地上の産業取得
				local factory_list = filter(factory_list_x(), @(a) a.get_desc().get_building_desc().can_be_built_aboveground())
				// 産業近くに既に町がある場合、候補から除外
				local factory_info = []
				foreach(factory in _step_generator(factory_list))
				{
					local factory_pos = (factory.get_tile_list())[0]
					local nearest_city = finder.find_nearest_city(factory_pos)
					local distance = abs(factory_pos.x - nearest_city.get_pos().x) + abs(factory_pos.y - nearest_city.get_pos().y)
					local size = factory.get_desc().get_building_desc().get_size(0)
					local tbl_factory = 
					{
						distance = distance
						long_length = size.x > size.y ? size.x : size.y
						pos = factory_pos
						factory = factory
					}
					factory_info.append(tbl_factory)
				}
				factory_info = filter(factory_info, @(a) a.distance > 10 + a.long_length)
				if(factory_info.len() != 0)
				{
					local candidate_tile_list = finder.find_target_places(factory_info[0].pos, 5, 5, factory_info[0].long_length, factory_info[0].long_length + 10, @(a) a.is_empty())
					if(candidate_tile_list.len() != 0)
					{
						new_city_pos = candidate_tile_list[calc_idx(pl.nr, candidate_tile_list.len())]
						rand_flg = false
					}
				}
			}else{
				// 地上かつ市外の名所旧跡取得
				local attraction_list = filter(attraction_list_x(), @(a) a.get_desc().can_be_built_aboveground())
				attraction_list = filter(attraction_list, @(a) a.get_desc().get_type() == building_desc_x.attraction_land)	
				// 名所旧跡近くに既に町がある場合、候補から除外
				local attraction_info = []
				foreach(attraction in _step_generator(attraction_list))
				{
					local attraction_pos = (attraction.get_tile_list())[0]
					local nearest_city = finder.find_nearest_city(attraction_pos)
					local distance = abs(attraction_pos.x - nearest_city.get_pos().x) + abs(attraction_pos.y - nearest_city.get_pos().y)
					local size = attraction.get_desc().get_size(0)
					local tbl_attraction = 
					{
						distance = distance
						long_length = size.x > size.y ? size.x : size.y
						pos = attraction_pos
						attraction = attraction
					}
					attraction_info.append(tbl_attraction)
				}
				attraction_info = filter(attraction_info, @(a) a.distance > 10 + a.long_length)
				if(attraction_info.len() != 0)
				{
					local candidate_tile_list = finder.find_target_places(attraction_info[0].pos, 5, 5, attraction_info[0].long_length, attraction_info[0].long_length + 10, @(a) a.is_empty())
					if(candidate_tile_list.len() != 0)
					{
						new_city_pos = candidate_tile_list[calc_idx(pl.nr, candidate_tile_list.len())]
						rand_flg = false
					}
				}
			}
		}
		if(rand_flg)
		{
			local x = 0.0
			local y = 0.0
			if(pl.nr * world.get_size().x > world.get_time().raw)
			{
				x = world.get_time().raw.tofloat() / (pl.nr * world.get_size().x)
			}else{
				x = (pl.nr * world.get_size().x) / world.get_time().raw.tofloat()
			}
			if(pl.nr * world.get_size().y > world.get_time().raw)
			{
				y = world.get_time().raw.tofloat() / (pl.nr * world.get_size().y)
			}else{
				y = (pl.nr * world.get_size().y) / world.get_time().raw.tofloat()
			}
			
			// floatから座標値に変換
			local ii = 0
			local dist_list = []
			local target = null
			do{
				if(ii != 0)
				{
					x = math.tent_map(x, ii)
					y = math.tent_map(y, ii + 1)
				}
				local pos_x = x
				for(local jj = 0; jj < math.get_digit(world.get_size().x); jj++){ pos_x *= 10 }
				local pos_y = y
				for(local jj = 0; jj < math.get_digit(world.get_size().y); jj++){ pos_y *= 10 }
				target = coord(pos_x.tointeger(), pos_y.tointeger())
				if(!(world.is_coord_valid(target))){ target = coord(target.x % world.get_size().x, target.y % world.get_size().y) }
				//既存の町からある程度離す
				dist_list = map(city_list_x(), @(a) abs(a.get_pos().x-target.x)+abs(a.get_pos().y-target.y))
				dist_list = filter(dist_list, @(a) a < 20)
				ii++
			}while(dist_list.len() != 0 && ii < 5000)

			if(ii < 5000)
			{
				local candidate_tile_list = finder.find_target_places(target, 5, 5, 1, 50, @(a) a.is_empty())
				if(candidate_tile_list.len() == 0){ return "No land for making city." }
				new_city_pos = candidate_tile_list[calc_idx(pl.nr, candidate_tile_list.len())]
			}
		}
		if(new_city_pos == null){ return "No space to add city." }

		// 町誘致場所を整地
		local build_city_area = finder.base_to_tile_list(new_city_pos, 3, 3, 0)
		finder.flat_tiles(build_city_area, pl)
		// 町誘致
		local cmd = command_x(tool_add_city)
		local err = cmd.work(pl, build_city_area[calc_idx(pl.nr, build_city_area.len())])
		if(err != null){ return err }
		gui.add_message_at(pl, pl.get_name()+" add city.", new_city_pos)
		// 誘致した町の市域取得
		local add_city = finder.find_nearest_city(new_city_pos)
		local city_limit = []
		for(local ii = add_city.get_pos_nw().x; ii <= add_city.get_pos_se().x; ii++)
		{
			for(local jj = add_city.get_pos_nw().y; jj <= add_city.get_pos_se().y; jj++)
			{
				city_limit.append(finder.coord2D_to_tile(coord(ii, jj)))
			}
		}
		// 道路の先端に段差がある時はスロープをつける
		local road_list = filter(city_limit, @(a) a.get_way(wt_road))
		foreach(road in _step_generator(road_list))
		{
			finder.set_slope_for_way(road, false, pl)
		}
	}
}
