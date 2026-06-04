/**
 * Main file of the AI player.
 */

// TODO obey construction speed setting
// TODO check allowed transport types

// some meta data - unused
ai <- {}
ai.short_description <- "Test AI player implementation"

ai.author <-"koa"
ai.version <- "0.5"

// includes
include("basic")  // .. definition of basic node classes
include("astar")  // .. route search for way building etc
include("save")   // .. routines to save class instances
include("math")   // .. math functions

//include("factorysearcher")              // .. checks factories for available connections
include("industry_connection_planner")  // .. plans connection between 2 factories
include("combined_connections")         // .. plans connections using water + land transport
include("industry_manager")             // .. manages existing connection (buys, sells, upgrades convoys)
include("placefinder")                  // .. utility functions to find places for stations near factories etc
include("prototyper")                   // .. plans convoy-type for a connection
//include("road_connector")               // .. builds road connection
//include("rail_connector")               // .. builds rail connection
//include("ship_connector")               // .. creates ship connection
include("station_manager")              // .. keeps information about freight station
include("vehicle_constructor")          // .. constructs convoy, assign to line, start
include("city")
include("road_manager")
include("rail_manager")

// basic functions
sum <- @(a,b) a+b
function abs(x) { return x>=0 ? x : -x }

/*****************************************
 *     common func
 *****************************************/
function _step_generator(iteratable) {
  foreach (obj in iteratable) {
    yield obj
  }
}

function filter(array, func) {
  local new_array = []
  foreach (obj in _step_generator(array)) {
    if(func(obj)) {
      new_array.append(obj)
    }
  }
  return new_array
} 

function map(array, func) {
  local new_array = []
  foreach (obj in _step_generator(array)) {
    new_array.append(func(obj))
  }
  return new_array
}

function sort(array, func) {
  local new_array = []
  foreach (obj in _step_generator(array)) {
    if (new_array.len() < 1) {
      new_array.append(obj)
    }else{
      local length = new_array.len()
      for(local ii = 0; ii < length; ii++) {
        if (func(new_array[ii], obj) == 1) {
          new_array.insert(ii, obj)
          break
        }
        if (ii == length - 1) {
          new_array.append(obj)
        }
      }
    }
  }
  return new_array
}

// 配列内の重複値を消す
function unique(array) {
  local new_array = []
  foreach(obj in _step_generator(array)) {
    if (!(is_member(obj, new_array))) {
      new_array.append(obj)
    }
  }
  return new_array
}

// 配列を結合する
function combine(arrayTo, arrayFrom) {
  foreach(obj in _step_generator(arrayFrom)) {
    arrayTo.append(obj)
  }
  return arrayTo
}

function total_array(a) {
  local rtn = 0
  for(local ii = 0; ii < a.len(); ii++)
  {
    rtn += a[ii]
  }
  return rtn
}

function compare_coord(a,b) { return ((a.x == b.x) && (a.y == b.y)) ? true : false }

function compare_coord3d(a,b) { return ((a.x == b.x) && (a.y == b.y) && (a.z == b.z)) ? true : false }

function is_member(a,b) {
  if(typeof(a) == "coord" || typeof(a) == "coord3d" || typeof(a) == "instance") {
    local rtn = false
    if("x" in a && "y" in a) {
      if("z" in a) {
        for(local ii = 0; ii < b.len(); ii++) {
          if(compare_coord3d(a, b[ii]))
          {
             rtn = true
             break
          }
        }
      }else{
        for(local ii = 0; ii < b.len(); ii++) {
          if(compare_coord(a, b[ii]))
          {
             rtn = true
             break
          }
        }
      }
    }else{
      for(local ii = 0; ii < b.len(); ii++) {
        if(a.is_equal(b[ii]))
        {
           rtn = true
           break
        }
      }
    }
    return rtn
  }else{
    return ((b.find(a) != null) ? true : false)
  }
}

function get_idx_in_member(a,b) {
  local rtn = []
  if(typeof(a) == "coord" || typeof(a) == "coord3d" || typeof(a) == "instance") {
    if("x" in a && "y" in a) {
      if("z" in a) {
        for(local ii = 0; ii < b.len(); ii++) {
          if(compare_coord3d(a, b[ii]))
          {
             rtn.append(ii)
          }
        }
      }else{
        for(local ii = 0; ii < b.len(); ii++) {
          if(compare_coord(a, b[ii]))
          {
             rtn.append(ii)
          }
        }
      }
    }else{
      for(local ii = 0; ii < b.len(); ii++) {
        if(a.is_equal(b[ii]))
        {
           rtn.append(ii)
        }
      }
    }
  }else{
    for(local ii = 0; ii < b.len(); ii++) {
      if(a == b[ii])
      {
         rtn.append(ii)
      }
    }
  }
  return rtn
}
// 組み合わせが一致しているか a:1次元配列、b:二重配列
function is_member_in_doublearray(a,b) {
  local rtn = false
  for(local ii = 0; ii < b.len(); ii++) {
    local tmp = []
    for(local jj = 0; jj < a.len(); jj++) {
      tmp.append(is_member(a[jj], b[ii]))
    }
    if(!(is_member(false, tmp))){
      rtn = true
      break
    }
  }
  return rtn
}
// 同一の配列が二重配列に存在するか a:1次元配列、b:二重配列
function is_duplicate_in_doublearray(a,b) {
  local rtn = false
  foreach(jj in _step_generator(b)) {
    if(a.len() != jj.len()){ continue }
    rtn = true
    for(local ii = 0; ii < a.len(); ii++) {
      if(a[ii] != jj[ii]) {
        rtn = false
        break
      }
    }
    if(rtn){ break }
  }
  return rtn
}
// 最頻値取得
function get_mode(array) {
  if(array.len() == 0){ return null }
  local list = []
  foreach(val in _step_generator(array)) {
    local add_flg = true
    if(list.len() > 0) {
      local val_list = map(list, @(a) a.val)
      if(is_member(val, val_list)){ add_flg = false }
    }
    if(list.len() == 0 || add_flg) {
      local idx_list = get_idx_in_member(val,array)
      local tbl_val =
      {
        val = val
        hit = idx_list.len()
      }
      list.append(tbl_val)
    }
  }
  list = sort(list, @(a,b) b.hit <=> a.hit)
  return list[0].val
}
// 条件に最も近い項目取得
function get_nearest(array, init_score, func) {
  local nearest_list = []
  local score = init_score
  foreach(obj in _step_generator(array))
  {
    local temp_score = func(obj)
    if(temp_score == null){ continue }
    if(temp_score < score)
    {
      nearest_list = []
      nearest_list.append(obj)
      score = temp_score
    }
    if(temp_score == score)
    {
      nearest_list.append(obj)
    }
  }
  return nearest_list
}
// player_nrからリストのIdxを算出する
function calc_idx(pl_nr, array_len) {
  // ライバルプレイヤーIdxは最小値2のため、0オリジンにする
  local idx = pl_nr - 2
  return ( idx >= array_len && array_len > 0 ? idx % array_len : idx )
}
// 活動月に応じてリストのIdxを選択する
function get_idx_by_month(array_len) {
  local month = world.get_time().month
  if(array_len < 2){ return 0 }
  // 1月は強制的にIdxを0にする(calc_idx関数の0割り回避と、戻り値にメリハリをつけるため)
  if(month == 0){ month = array_len - 2 }
  return abs(calc_idx(array_len, month))
}

// global variables
debug_mode <- 1
our_player_nr <- -1
our_player    <- null // player_x instance
city_player_nr <- 16  // 市道・市内建築所有者Idx
// max schedule_desc_x(片道の最大停車駅数 実際はこれに終点のターミナルがつくのでmax_schedule_desc+1)
max_schedule_desc <- 14
city_bus_max_schedule_desc <- 6 // 市内バスの片道の最大停留所数
set_max_city_bus_line <- 10     // 一度に作成する市内バス路線数
construct_rail_minimum_capital <- 1000000  // 線路敷設処理の最低資金

// the AI is organized as a tree,
// all the work is done in the nodes of the tree
tree <- {}

// nodes with particular jobs
cityInfo <- null
factorysearcher  <- null
industry_manager <- null
station_manager  <- null

// stepping info
s <- {}
s._step <- 0
s._next_construction_step <- 0

// the table 'persistent' will be saved in the savegame
persistent.s <- s

// 2.. 14 = 13 names
possible_names <- ["moe", "kaede", "koharu", "mei", "miku",
	"hinano & yumeko", "anzu & nao", "yumina & kiara", "yuina", "nagomi", "ruka & nanase", "kaya", "non"
			]

/**
 * Start-routine. Will be called when AI is initialized.
 * Parameter: the number of the AI player.
 */
function start(pl_nr)
{
	init()
	our_player_nr = pl_nr

	if (our_player_nr > 1  &&  our_player_nr-2 < possible_names.len()) {
		player_x(our_player_nr).set_name( possible_names[our_player_nr-2]);
	}
	our_player = player_x(our_player_nr)

	print("Act as player no " + our_player_nr + " under the name " + our_player.get_name())
	// set pause by script error
	debug.set_pause_on_error(true)

	// 開業資金情報取得
	if (!("initial_capital" in persistent)) 
	{
		persistent.initial_capital <- our_player.get_current_cash()
	}
	// 街情報取得
	init_city_info()
	gui.add_message_at(player_x(our_player_nr), " start!!! ", world.get_time())
}

/*****************************************
 *     町の情報取得
 *****************************************/
function init_city_info()
{
	if ( cityInfo == null)
	{
		cityInfo = city_info_t()
	}
	if (!("city" in persistent)) 
	{
		persistent.city <- cityInfo
	}

	// 拠点の町Idx
	if (!("base_city" in persistent)) 
	{
		local base_city = persistent.city.set_base_city(our_player_nr)
		persistent.base_city <- base_city
	}

	// 設定済みルート
	if (!("used_root" in persistent)) 
	{
		local used_root = []
		persistent.used_root <- used_root
	}
}

/**
 * Initialize the tree with basic nodes.
 */
function init_tree()
{
	if (factorysearcher == null) {
		factorysearcher = factorysearcher_t()
	}
	if (industry_manager == null) {
		industry_manager = industry_manager_t()
	}
	if (!("tree" in persistent)) {
		tree = manager_t()
		tree.append_child(factorysearcher)
		tree.append_child(industry_manager)
		persistent.tree <- tree
	}
	else {
		if (persistent.tree.getclass() != manager_t) {
			// upgrade
			tree = manager_t()
			foreach(i in ["nodes", "next_to_step"]) {
				tree[i] = persistent.tree[i]
			}
		}
		else {
			tree = persistent.tree
		}
	}

	if (!("station_manager" in persistent)) {
		persistent.station_manager <- freight_station_manager_t()
	}
}

/**
 * Called after savegame is loaded.
 */
function resume_game(pl_nr)
{
	init()
	our_player_nr = pl_nr
	our_player    = player_x(our_player_nr)

	init_city_info()
	gui.add_message_at(our_player, " load!!! ", world.get_time())
	if (!("initial_capital" in persistent)) 
	{
		persistent.initial_capital <- 0
	}
	s = persistent.s
	
	// 敷設途中の線路を撤去
	if("setting_rail" in persistent && persistent.setting_rail != null)
	{
		local list = persistent.setting_rail
		local rail_info = rail_manager_t()
		local remove_rail_list = finder.get_interpolate_tile(list[0], list[1])
		rail_info.remove_rail(remove_rail_list, our_player)
		delete persistent.setting_rail
	}
}

function init()
{
	annotate_classes() // sets class name as attribute for all known classes (save.nut)
}

/**
 * The heart beat of the player.
 * If the routine will take too much time, execution is suspended and later resumed.
 * This should be completely transparent to the script.
 * Then the main program is still responsive.
 */
function step()
{
	s._step++
/*if (s._step % 130 == 10 * our_player_nr)
{
gui.add_message_at(our_player, "test start!", world.get_time())
local rail_info = rail_manager_t()
local station = station_manager_t()
local aaa = finder.coord2D_to_tile(coord(498,451))
local target = finder.coord2D_to_tile(coord(499,451))
local bbb=station.expand_straight_rail(our_player, target, aaa)
gui.add_message_at(our_player, ""+coord_to_string(bbb), bbb)
gui.add_message_at(our_player, "test end", world.get_time())
}*/
	if (s._step % 1930 == 10 * our_player_nr)
	{
		// 街誘致
		persistent.city.build_city(our_player)
	}

	local root_len = persistent.used_root.len()

	// 新路線探索
	// 経路探索中に月を跨ぐと、途中で探索方法が変わって無限ループが発生することがある
	// 翌月になると解消する
	if (s._step % 1430 == 10 * our_player_nr)
	{
		// 既存ルートがある程度設定できたら、新規ルート選定前に会社の体力と相談する
		if(root_len > 4)
		{
			local profit_list = our_player.get_operating_profit()
			if((profit_list[1] > 0 && our_player.get_current_cash()*100 <= 100000000) || (profit_list[1] < 0 && profit_list[1] > profit_list[2])){ return }
		}

		// 町情報取得
		local city_info = persistent.city.get_city_info()
		if(city_info.len() < 2){ return }
		// 新規ルート選定(基本は最近接の町を結ぶんだけど、既存ルートと重複する時とか寄り道するようなルートの時は2番目、3番目を選択する)
		local new_root = []
		local c_townhall = coord(city_info[persistent.base_city].townhall.x, city_info[persistent.base_city].townhall.y)
		local idx_list = [1]
		local used_idx_list = []
		local continue_flg = true
		local dupligate_root_flg = false
		do
		{
			local temp_idx_list = clone(idx_list)
			new_root = []
			new_root = persistent.city.select_root(city_info, c_townhall, idx_list, 0, new_root)

			// ライバルプレイヤーIdxが10以上でルート選定の方法を変える
			if(our_player_nr < 10){ idx_list = temp_idx_list }
			/* idx_listでルート選定時のルートm番目の町からn番目に近い町を結ぶ、のmとnを決めている
			   ルートm番目の町～m+1番目の町の距離とm番目の町～m+2番目の町の向きが折り返しに近い場合、idx_listの配列長さを追加 
			   nのカウントアップはidx_listの末尾で行う */
			local first_angle = 0
			local second_angle = 0
			local inverse_idx = 0
			if(new_root.len() > 2)
			{
				for(local ii = 1; ii < new_root.len() - 1; ii++)
				{
					local x_distance = city_info[new_root[ii]].townhall.x - city_info[new_root[ii-1]].townhall.x
					local y_distance = city_info[new_root[ii]].townhall.y - city_info[new_root[ii-1]].townhall.y
					first_angle = math.atan2(y_distance, x_distance)
					
					x_distance = city_info[new_root[ii+1]].townhall.x - city_info[new_root[ii]].townhall.x
					y_distance = city_info[new_root[ii+1]].townhall.y - city_info[new_root[ii]].townhall.y
					second_angle = math.atan2(y_distance, x_distance)
					
					// 選定ルートが行ったり来たりしているか
					if(abs(second_angle - first_angle) > 95 && abs(second_angle - first_angle) <= 265)
					{
						inverse_idx = ii
						break
					}
				}
			}

			local incrementFlg = true
			if(inverse_idx)
			{
				/* ルートが行ったり来たりしている.
				   初回時は袋小路でルートをぶった切り、2回目から袋小路を通らないルートを検索する */
				new_root.resize(inverse_idx + 1)
				if(is_member_in_doublearray(new_root, persistent.used_root))
				{
					/* 袋小路の手前の町から袋小路の町より遠い町を通過するルートを検索 */
					if(idx_list.len() > inverse_idx)
					{
						local temp_list = []
						/* 袋小路の町より遠い町を選択する時、遠さが町の数の半分に達したらループ止め. 
						  条件式の-2はelse側にある、idx_listの配列長さを追加する処理に配列長さを合わせている */
						while(idx_list[inverse_idx] < city_info.len() / 2 - 2)
						{
							idx_list[inverse_idx] = idx_list[inverse_idx] + 1
							temp_list = clone(idx_list).resize(inverse_idx + 1)
							if(!(is_duplicate_in_doublearray(temp_list, used_idx_list))){ break }
						}
						if(idx_list[inverse_idx] < city_info.len() / 2 - 2)
						{
							idx_list = idx_list.resize(inverse_idx + 1)
							incrementFlg = false
						}
					}else{
						local init= 2
						if(world.get_time().month % 2 == 0)
						{
							// 任意のidxを-1してその次のidxに2以上の数を付与(任意のidxは活動月に応じて決定)
							local pos = get_idx_by_month(idx_list.len()-1)
							if(pos == 0 && idx_list[pos] < city_info.len() / 2)
							{
								idx_list[pos] = idx_list[pos] + 1   //無限ループ時はここを2に変更
								init = 1
							}else{
								if(idx_list[pos] > 1){ idx_list[pos] = idx_list[pos] - 1 }
							}
							idx_list.resize(pos + 1)
						}else{
							if(idx_list[idx_list.len()-1] > 1)
							{
								// 末尾のidxを-1して後ろに2以上の数を付与
								idx_list[idx_list.len()-1] = idx_list.top() - 1
							}
						}
						local regist_flg = false
						/* 配列長さを追加する時、inverse_idxとidx_list長さによって
						   無限ループが発生するので一度使ったidx_listを使わないようにidx_listの配列長さを追加する 
						   配列長さを追加する時、1の場合は調査済みなので最小値2からスタート */
						for(local ii=init; ii<city_info.len()/2-1; ii++)
						{
							idx_list.append(ii)
							if(!(is_duplicate_in_doublearray(idx_list, used_idx_list))){
								regist_flg = true
								break
							}
							idx_list.resize(idx_list.len()-1)
						}
						// 既に登録されている取得する町の近さリストの場合2を追加する
						if(!(regist_flg)){ idx_list.append(2) }
					}
				}
			}

			if(incrementFlg && idx_list.top() < city_info.len()/2)
			{
				idx_list[idx_list.len()-1] = idx_list.top() + 1
			}

			/* idx_listでルート選定時のルートm番目の町からn番目に近い町を結ぶのだが、
			   nが町の数の半分に達したのでm=(活動月に応じて変更)にてnのカウントアップを再開
			   ただし、選んだm番目のnが既に町の数の半分に達している場合、隣のmを選択 */
			local count_to_end_idx_list = filter(clone(idx_list), @(a) a != 1 && a >= city_info.len()/2-2)
			// m, nが双方とも町の数の半分に達した場合は探索終了
			if(count_to_end_idx_list.len() > city_info.len() / 2 && city_info.len() > 2)
			{
				dupligate_root_flg = true
				break
			}
			if(count_to_end_idx_list.len() > 0)
			{
				local pos = 0
				if(count_to_end_idx_list.len() < idx_list.len())
				{
					pos = get_idx_by_month(idx_list.len())
				}else{
					idx_list.append(1)
					pos = idx_list.len() - 1
				}

				local temp_pos = pos
				while(temp_pos >= 0 && idx_list[temp_pos] >= city_info.len()/2){ temp_pos-- }
				if(temp_pos == -1)
				{
					temp_pos = pos
					while(temp_pos < idx_list.len() && idx_list[temp_pos] >= city_info.len()/2){ temp_pos++ }
				}
				// 探索する町が尽きたか、調査. 尽きてないならidx_listの末尾に2をつけて調査続行
				if(temp_pos == idx_list.len())
				{
					local pass_city_idx = []
					foreach(used_root in persistent.used_root)
					{
						pass_city_idx = combine(pass_city_idx, used_root)
					}
					pass_city_idx = unique(pass_city_idx)
					if(pass_city_idx.len() == city_info.len())
					{
						continue_flg = false
						dupligate_root_flg = true
					}else{
						idx_list.append(2)
					}
				}else{
					pos = temp_pos
					idx_list[pos] = idx_list[pos] + 1
					idx_list.resize(pos + 1)
				}
			}
			// ルート選定を続行するか、調査
			continue_flg = is_member_in_doublearray(new_root, persistent.used_root) ? true : false /*選定ルートが既存ルートと重複してないか*/
			// 町が2つしかないなら一つしかルートが作れないので探索終了
			if(continue_flg && city_info.len() == 2)
			{
				continue_flg = false
				dupligate_root_flg = true
				break
			}
			if(is_duplicate_in_doublearray(idx_list, used_idx_list))
			{
				idx_list.append(2)
			}
			// 作成した取得する町の近さリストを登録
			used_idx_list.append(clone(idx_list))
		}while(continue_flg)
		if(dupligate_root_flg)
		{
			//TODO : All connectedって出ても実はまだ結んでない町をフォローしたい
			// idx_listでcity_info.len()が全町数の半分の値を超える辺鄙な所にあるパターン
			// continue_flg=trueの時、city_info.len()/2で条件分岐してる箇所をcity_info.len()-2にすれば行ける？
			gui.add_message_at(our_player, "All city are connected.", world.get_time())
			return
		}

		// 沿線人口調査
		local population = 0
		foreach(ii in _step_generator(new_root)){ population += city_info[ii].citizen }
if(debug_mode)
{
  local str="["
  foreach(ii in new_root)
  {
    str += city_info[ii].name + ","
  }
  str=str.slice(0,str.len()-1)
  str += "]"
  gui.add_message_at(our_player, str, world.get_time())
}
		
		//if(population > 7000)
//		{
			// 鉄道路線建設
			local rail_info = rail_manager_t()
			local temp_new_root = clone(new_root)
			new_root = rail_info.build_rail_root(our_player, new_root)
			if(new_root == null || temp_new_root.len() != new_root.len())
			{
				// 鉄道建設できなかった区間はバス代行
				local road_info = road_manager_t()
				if(new_root == null)
				{
					// 鉄道が通っている町は並行しないように整理
					for(local ii = 1; ii < temp_new_root.len(); ii++)
					{
						local break_flg = false
						local station_bus_stop =finder.get_bus_terminal(city_x(city_info[temp_new_root[ii]].townhall.x, city_info[temp_new_root[ii]].townhall.y), our_player)
						if(station_bus_stop)
						{
							local temp_list = filter(station_bus_stop.get_halt().get_line_list(), @(a) a.get_waytype() == wt_rail)
							if(temp_list.len() == 0)
							{
								break_flg = true
							}
						}else{
							break_flg = true
						}
						if(break_flg)
						{
							temp_new_root = temp_new_root.slice(ii-1)
							break
						}
					}
					temp_new_root = road_info.build_bus_root(our_player, temp_new_root)
					new_root = temp_new_root
				}else{
					temp_new_root = road_info.build_bus_root(our_player, temp_new_root.slice(new_root.len()-1))
					if(temp_new_root != null)
					{
						new_root = combine(new_root, temp_new_root.slice(1))
					}
				}
			}
//		}else{
//			// バス路線建設
//			local road_info = road_manager_t()
//			new_root = road_info.build_bus_root(our_player, new_root)
//		}
		if(new_root != null)
		{
			// 設定済みルートに作成したルートを登録
			persistent.used_root.append(new_root)
		}
	}

	// 鉄道路線設定
	if (s._step % 470 == 10 * our_player_nr)
	{
		local vehicle = vehicle_constructor_t()
		vehicle.set_rail_line(our_player)
		// 鉄道と並行バス路線は再編
		vehicle.merge_to_rail(our_player)
	}

	// 赤棒対策
	if (s._step % 670 == 10 * our_player_nr)
	{
		local vehicle = vehicle_constructor_t()
		vehicle.add_convoy(our_player)
	}

	// 市内交通対策
	if (s._step % 530 == 10 * our_player_nr)
	{
		local vehicle = vehicle_constructor_t()
		local road_info = road_manager_t()
		foreach(city in city_list_x())
		{
			// 他社のバス停がある場合は、整備しない
			local com_halt_list = []
			local com_idx = 0
			// 0はプレイヤー、1は公共
			for(local ii = 2; ii < city_player_nr; ii++)
			{
				if(our_player_nr == ii){ continue }
				com_halt_list = finder.reseach_sta_in_city(city, ii)
				if(com_halt_list.len() > 1)
				{
					com_idx = ii
					break
				}
			}

			// バス停設置
			if(com_idx == 0)
			{
				local bus_stop_list = finder.get_road_for_city_bus(city, our_player)
				if(bus_stop_list.len() != 0)
				{
					for(local ii=0; ii<bus_stop_list.len(); ii++)
					{
						local err = road_info.build_bus_stop(our_player, bus_stop_list[ii])
						if(err)
						{
							gui.add_message_at(our_player, "failed build busstop at "+ coord_to_string(bus_stop_list[ii]), bus_stop_list[ii])
						}
					}
				}
			}else{
				local terminal = finder.get_bus_terminal(city, player_x(com_idx))
				if(terminal.get_halt().get_owner().nr != 1)
				{
					local tile_list = terminal.get_halt().get_tile_list()
					local neighbor_tile_list = finder.bldg_neighbor_tile_list(tile_list)
					neighbor_tile_list = filter(neighbor_tile_list, @(a) a.has_way(wt_road) && dir.is_straight(a.get_way_dirs(wt_road)) || !(a.is_bridge() && a.get_slope() == 0))
					local err = null
					foreach(neighbor_tile in neighbor_tile_list)
					{
						err = road_info.build_bus_stop(our_player, neighbor_tile)
						if(!(err)){ break }
					}
					if(err)
					{
						foreach(com_halt in com_halt_list)
						{
							tile_list = com_halt.get_tile_list()
							neighbor_tile_list = finder.bldg_neighbor_tile_list(tile_list)
							neighbor_tile_list = filter(neighbor_tile_list, @(a) a.has_way(wt_road) && dir.is_straight(a.get_way_dirs(wt_road)) || !(a.is_bridge() && a.get_slope() == 0))
							foreach(neighbor_tile in neighbor_tile_list)
							{
								err = road_info.build_bus_stop(our_player, neighbor_tile_list[0])
								if(!(err)){ break }
							}
							if(!(err)){ break }
						}
					}
				}
			}
		}
		foreach(city in city_list_x())
		{
			// 一旦、市域内の利用可能バス停を取得(スケジュール設定中に落ちても再開できるように)
			local halt_in_city_list = finder.check_busstop_in_city(city, our_player, 0)
			local initial_halt_list = filter(halt_in_city_list, @(a) a.get_line_list().get_count() == 0)
			local public_halt_in_city_list = finder.check_busstop_in_city(city, player_x(1), 1)
			for(local ii = 0; ii< public_halt_in_city_list.len(); ii++)
			{
				// 公共駅の隣接タイルに自社駅がある場合は、のちに自社駅を公共化するので公共駅を除外
				local around_pos_list = finder.bldg_neighbor_tile_list(public_halt_in_city_list[ii].get_tile_list())
				local around_halt_list = map(around_pos_list, @(a) a.get_halt())
				around_halt_list = filter(around_halt_list, @(a) a != null && a.get_owner().nr == our_player_nr)
				if(around_halt_list.len() != 0){ continue }
				// 自社バス停と重複してない公共駅をスケジュールに組み込む
				if(!(is_member(true, map(halt_in_city_list, @(a) finder.is_same_halt(a, public_halt_in_city_list[ii])))))
				{
					halt_in_city_list.append(public_halt_in_city_list[ii])
				}
				local line_list = public_halt_in_city_list[ii].get_line_list()
				line_list = filter(line_list, @(a) a.get_owner().nr == our_player_nr)
				if(line_list.len() == 0){ initial_halt_list.append(public_halt_in_city_list[ii]) }
			}
			// 路線に所属していないバス停がないなら処理終了
			if(initial_halt_list.len() == 0){ continue }
			// 市域内に使用可能なバス停が一つしかないなら処理終了
			local terminal = finder.get_bus_terminal(city, our_player)
			if(halt_in_city_list.len() == 1 && is_member(terminal, halt_in_city_list[0].get_tile_list())){ continue }
			local initial_bus_stop_list = []
			foreach(halt in initial_halt_list)
			{
				local temp = finder.check_sta_freight_property(halt, wt_road, 2)
				if(temp.len() != 0){ initial_bus_stop_list.append(temp[0]) }
			}
			local bus_stop_list = []
			foreach(halt in halt_in_city_list)
			{
				if(!(is_member(halt.get_owner().nr, [1, our_player_nr]))){ continue }
				local temp = finder.check_sta_freight_property(halt, wt_road, 2)
				if(temp.len() != 0){ bus_stop_list.append(temp[calc_idx(our_player_nr, temp.len())]) }
			}
			// スケジュール設定
			vehicle.set_line_for_citybus(city, initial_bus_stop_list, terminal, bus_stop_list, [], our_player)
		}
	}
	if (s._step % 210 == 10 * our_player_nr)
	{
		// 車両がない路線を取得し、当該路線に対して車両を配置
		local vehicle = vehicle_constructor_t()
		local road_info = road_manager_t()
		local rail_info = rail_manager_t()
		local line_list = our_player.get_line_list()
		for(local ii=0; ii<line_list.get_count(); ii++)
		{
			if(line_list[ii].get_convoy_list().get_count() == 0 && line_list[ii].get_waytype() == wt_road)
			{
				// 車庫探索・建設
				local depot_pos = road_info.search_bus_depot(line_list[ii].get_schedule().entries.top(), our_player)
				if(depot_pos == null){ continue }
				local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
				// バス購入
				local convoy = vehicle.buy_convoy(depot, our_player, wt_road, null)
				if(convoy != null)
				{
					convoy.set_line(our_player, line_list[ii])
					// 運行開始
					depot.start_convoy(our_player, convoy)
				}
			}

			if(line_list[ii].get_convoy_list().get_count() == 0 && line_list[ii].get_waytype() == wt_rail)
			{
				local schedule_entry_list = line_list[ii].get_schedule().entries
				// 車庫探索・建設
				local depot_pos = rail_info.search_depot(tile_x(schedule_entry_list[0].x, schedule_entry_list[0].y, schedule_entry_list[0].z), our_player)
				if(depot_pos == null){ continue }
				
				// 余力があれば、電化
				rail_info.electrify_line(line_list[ii])
				
				// 列車購入
				local depot = depot_x(depot_pos.x, depot_pos.y, depot_pos.z)
				local is_electrified = false
				if(depot_pos.get_way(wt_rail).is_electrified())
				{
					local sche_len = schedule_entry_list.len() / 2
					if(finder.coord2D_to_tile(schedule_entry_list[sche_len]).find_object(mo_wayobj) != null)
					{
						is_electrified = true
					}
				}
				local convoy = vehicle.buy_convoy(depot, our_player, wt_rail, null, is_electrified)
				// 購入できなかった場合、市電で代用
				if(convoy == null)
				{
					
				}else{
					// スケジュール設定
					convoy.set_line(our_player, line_list[ii])
					// 営業中の途中駅で棒線駅があれば、行き違い設備を設ける
					local station = station_manager_t()
					local sche_len = schedule_entry_list.len()
					for(local jj = 1; jj< sche_len/2; jj++)
					{
						local halt = finder.coord2D_to_tile(schedule_entry_list[jj]).get_halt()
						local temp_line_list = halt.get_line_list()
						temp_line_list = filter(temp_line_list, @(a) a.get_waytype() == wt_rail)
						if(temp_line_list.len() > 1)
						{
							station.set_passing_each_other(our_player, halt)
						}
					}
					// ホーム長さ調整
					foreach(schedule in schedule_entry_list)
					{
						station.extend_form(our_player, schedule.get_halt(our_player), convoy.get_tile_length(), [schedule])
					}
					
					// 運行開始
					depot.start_convoy(our_player, convoy)
				}
			}
		}
	}

	// 鉄道の一斉出庫
	if (s._step % 760 == 10 * our_player_nr)
	{
		local vehicle = vehicle_constructor_t()
		local depot_list = depot_x.get_depot_list(our_player, wt_rail)
		foreach(depot in depot_list)
		{
			local convoy_list = depot.get_convoy_list()
		 	foreach(convoy in convoy_list)
		 	{
		 		vehicle.start_convoy(convoy, depot, our_player)
		 	}
		}
		vehicle.merge_to_rail(our_player)
	}

	// 減便
	if (s._step % 910 == 10 * our_player_nr)
	{
		local vehicle = vehicle_constructor_t()
		local line_list = our_player.get_line_list()
		foreach(line in _step_generator(line_list))
		{
			vehicle.pop_convoy(line, our_player)
		}
	}

	// デッドロック対策
	if (s._step % 370 == 10 * our_player_nr)
	{
		local vehicle = vehicle_constructor_t()
		vehicle.solute_dead_lock(our_player)
	}

	// 駅隣接地が他社駅なら当該駅公共化
	if (s._step % 450 == 10 * our_player_nr)
	{
		local sta_list = filter(halt_list_x(), @(a) a.get_owner().nr == our_player_nr)
		foreach(sta in sta_list)
		{
			local tile_list = sta.get_tile_list()
			local around_pos_list = finder.bldg_neighbor_tile_list(tile_list)
			around_pos_list = filter(around_pos_list, @(a) a.get_halt() != null)
			local around_halt_list = map(around_pos_list, @(a) a.get_halt())
			around_halt_list = filter(around_halt_list, @(a) a.get_owner().nr != our_player_nr)
			if(around_halt_list.len() != 0)
			{
				local budget = 0
				foreach(tile in tile_list)
				{
					local mo = tile.find_object(mo_building)
					if(mo != null){ budget += mo.get_desc().get_maintenance() }
					mo = tile.get_way(wt_rail)
					if(mo != null){ budget += mo.get_desc().get_maintenance() }
				}
				// 公共化は維持費の60倍(現金があるか、負債があっても黒字経営なら公共化実施)
				if(our_player.get_current_cash() * 100 > settings.get_make_public_months() * budget || judge_investment(settings.get_make_public_months() * budget, 0))
				{
					local sta_name = around_halt_list[0].get_name()
					local cmd = command_x(tool_make_stop_public)
					cmd.work(our_player, tile_list[0])
					tile_list[0].get_halt().set_name(sta_name)
				}else{
					gui.add_message_at(our_player, sta.get_name() +" is missed making to public stop.", tile_list[0])
				}
			}
		}
	}

	// 鉄道路線と並行しているバス路線は路線縮小
	if (s._step % 1410 == 10 * our_player_nr)
	{
		local vehicle = vehicle_constructor_t()
		vehicle.merge_to_rail(our_player)
	}

	// 本社建設
	if (s._step % 870 == 10 * our_player_nr)
	{
		local city_info = persistent.city.get_city_info()
		local city = filter(city_list_x(), @(a) compare_coord(a.get_pos(), city_info[persistent.base_city].townhall))
		if(city.len() == 0){ return }
		local err = persistent.city.build_headquarter(city[0], our_player)
		if(err != null){ gui.add_message_at(our_player, "build headquarter error:"+err, world.get_time()) }
	}
}

/**
 * Helper routine: translate 3d-coordinate to string.
 * This can be used as key in tables.
 */
function coord3d_to_key(c)
{
	return ("coord3d_" + c.x + "_" + c.y + "_" + c.z).toalnum();
}

function coord_to_key(c)
{
	return ("coord_" + c.x + "_" + c.y).toalnum();
}

function equal_coord3d(a,b)
{
	return a.x == b.x  &&  a.y == b.y  &&  a.z == b.z
}


function is_cash_available(cost /* in 1/100 cr */)
{
	//gui.add_message_at(our_player, " ***** cash : " + our_player.get_current_cash(), world.get_time())
	//gui.add_message_at(our_player, " ***** cost : " + cost, world.get_time())
	return cost + 2*our_player.get_current_maintenance() < our_player.get_current_cash()*100
}

/***************************************
 * 設備投資判断
 * 引数：建設費(int)、投資に伴い増加する維持費(int)
 * 戻り値：投資実行可否(boolean)
 ***************************************/
function judge_investment(cost, maintenance)
{
	local rtn = false
	// 先月の粗利益取得
	local profit = our_player.get_profit()
	local cash = our_player.get_operating_profit()
	// スロット上5社は起業直後の場合は建設費のみで判断
	if(profit[1] == 0 && profit[2] == 0 && our_player.nr < 7)
	{
		return cost < our_player.get_current_cash() * 100 ? true : false
	}
	if(profit[0] *100 > maintenance && cash[0] *100 > cost){ return true }
	if(profit[1] *100 > maintenance && cash[1] *100 > cost){ return true }
	
	// TODO : 赤字の場合でもスピードボーナスで黒字化が見込めば投資okにしてもいいんだけど
	return rtn
}

/**
 * Called to save into savegame.
 * Returns string that will be saved.
 * Here: we turn the persistent table into a string using recursive_save (from script/script_base.nut).
 */
function save()
{
	local str = ""
	local tic = get_ops_total()
	local rem = get_ops_remaining()

	str = "persistent = " + recursive_save(persistent, "\t", [ persistent ] )

	local toc = get_ops_total()
	print("save used " + (toc-tic) + " ops, remaining = " + rem)
	return str
}
