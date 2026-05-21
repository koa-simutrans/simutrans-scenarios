/**
 * Classes for math function.
 */

class math
{
	/*********************************************
	 * xy座標から角度を取得する(近似式を用いる)
	 * 引数：y座標(int)、x座標(int)
	 * 戻り値：角度(度)(int)
	 * 出典：https://garchiving.com/approximation-atan2/
	 *********************************************/
	 static function atan2(y, x)
	 {
	 	local abs_x = abs(x)
	 	local abs_y = abs(y)
	 	local low_angle_flg = abs_y < abs_x ? true : false
	 	local inverse_tan = 0
	 	if(low_angle_flg)
	 	{
	 		inverse_tan = abs_y / abs_x.tofloat()
	 	}else{
	 		inverse_tan = abs_x / abs_y.tofloat()
	 	}
	 	// arctan(x)を4次関数で近似すると8.2975x^4-20.114x^3+0.5812x^2+57.412x
	 	local angle = inverse_tan * (inverse_tan * (inverse_tan * (829 * inverse_tan - 2011) - 58) + 5741)
	 	
	 	if(low_angle_flg)
	 	{
	 		if(x > 0)
	 		{
	 			if(y < 0){ angle *= -1 }
	 		}else{
	 			if(y >= 0)
	 			{
	 				angle = 18000 -angle
	 			}else{
	 				angle = angle - 18000
	 			}
	 		}
	 	}else{
	 		if(x >= 0)
	 		{
	 			if(y >= 0)
	 			{
	 				angle = 9000 - angle
	 			}else{
	 				angle = angle - 9000
	 			}
	 		}else{
	 			if(y >= 0)
	 			{
	 				angle = 9000 + angle
	 			}else{
	 				angle = -1 * angle - 9000
	 			}
	 		}
	 	}
	 	return angle / 100
	 }

	/*********************************************
	 * テント写像(パラメータμは2)
	 * 引数：初期値(float)、繰り返し回数(int)
	 * 戻り値：値(float)
	 *********************************************/
	static function tent_map(init, counter)
	{
		local rtn = init
		for(local ii = 0; ii < counter; ii++)
		{
			if(rtn > 0.5)
			{
				rtn = 2 * (1 - rtn)
			}else{
				rtn = 2 * rtn
			}
		}
		return rtn // TODO : rtn==0,rtn==1について対応
	}

	/*********************************************
	 * 桁取得
	 * 引数：数(int)  ※正の数に限る
	 * 戻り値：桁数(int)
	 *********************************************/
	 static function get_digit(num)
	 {
	 	local str = num.tostring()
	 	return str.len()
	 }
}
