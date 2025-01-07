//+------------------------------------------------------------------+
//|                                                dj_akira_sada.mq4 |
//|                                  Copyright 2025, SexyDesign Ltd. |
//|                                      https://www.sexydesign.club |
//+------------------------------------------------------------------+
#property copyright "dj_akira_sada"
#property link      "https://www.sexydesign.club/"
#property version   "1.00"
#property strict // strictは絶対に削除しない事

// マクロ定義
#define    OBJ_HEAD              ( __FILE__ + "_" )  // オブジェクトヘッダ名
#define    MAGIC_NO              20250101            // EA識別用マジックナンバー(他EAと被らない任意の値を使用する)

// ヘッダインクルード
#include <stdlib.mqh>          // ライブラリインクルード

//――― 型宣言 ――――――――――――――――――――――――
struct struct_PositionInfo {                // ポジション情報構造体型
    int               ticket_no;                // チケットNo
    int               entry_dir;                // エントリーオーダータイプ
    double            set_limit;                // リミットレート
    double            set_stop;                 // ストップレート
};


// enum列挙型宣言
enum ENUM_MA_CROSS {                            // 移動平均クロス列挙
    MAC_NO = 0,                                 // 無し
    MAC_UP_CHANGE,                              // MA上抜け
    MAC_DOWN_CHANGE                             // MA下抜け
};

// 静的グローバル変数
static struct_PositionInfo  _StPositionInfoData;    // ポジション情報構造体データ
static double _MinLot = 0.01;                   // 最小ロット

//+------------------------------------------------------------------+
//| OnInit(初期化)イベント
//+------------------------------------------------------------------+
int OnInit()
{
//    if ( IsDemo() == false ) {            // デモ口座以外の場合
//        Print("デモ口座でのみ動作します");
//        return INIT_FAILED;                            // 処理終了
//    }

    _MinLot = MarketInfo( Symbol() , MODE_MINLOT );        // 最小ロットを取得

    return( INIT_SUCCEEDED );      // 戻り値：初期化成功
}

//+------------------------------------------------------------------+
//| OnDeinit(アンロード)イベント
//+------------------------------------------------------------------+
void OnDeinit( const int reason ) {

    if ( IsTesting() == false ) {   // バックテスト時以外
        ObjectsDeleteAll(          // 追加したオブジェクトを全削除
                        0,           // チャートID
                        OBJ_HEAD    // オブジェクト名の接頭辞
                       );
    }

}

//+------------------------------------------------------------------+
//| tick受信イベント
//| EA専用のイベント関数
//+------------------------------------------------------------------+
void OnTick()
{

    TaskPeriod();                   // ローソク足確定時の処理
    TaskSetMinPeriod();             // 指定時間足確定時の処理

}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ローソク足確定時の処理
//+------------------------------------------------------------------+
void TaskPeriod() {
    static    datetime s_lasttime;                      // 最後に記録した時間軸時間
                                                        // staticはこの関数が終了してもデータは保持される

    datetime temptime    = iTime( Symbol(), Period() ,0 );  // 現在の時間軸の時間取得

    if ( temptime == s_lasttime ) {                     // 時間に変化が無い場合
        return;                                         // 処理終了
    }
    s_lasttime = temptime;                              // 最後に記録した時間軸時間を保存

    // ----- 処理はこれ以降に追加 -----------
    ENUM_MA_CROSS temp_cross;                         // SMA判定結果
    temp_cross = MACrossJudge();                        // 移動平均線のクロス判定
    JudgeClose( temp_cross );                           // 決済オーダー判定
    JudgeEntry( temp_cross );                           // エントリーオーダー判定

    DispDebugInfo(_StPositionInfoData);               // デバッグ情報出力

    // printf( "[%d]ローソク足確定%s" , __LINE__ , TimeToStr( Time[0] ) );
}

//+------------------------------------------------------------------+
//| 指定時間足確定時の処理
//+------------------------------------------------------------------+
void TaskSetMinPeriod() {
    static    datetime s_lastset_mintime;               // 最後に記録した時間軸時間
                                                        // staticはこの関数が終了してもデータは保持される

    datetime temptime    = iTime( Symbol(), PERIOD_M30 ,0 );  // 現在の時間軸の時間取得

    if ( temptime == s_lastset_mintime ) {                 // 時間に変化が無い場合
        return;                                         // 処理終了
    }
    s_lastset_mintime = temptime;                          // 最後に記録した時間軸時間を保存

    // ----- 処理はこれ以降に追加 -----------
    ClearPosiInfo(_StPositionInfoData);                 // ポジション情報クリア(決済済みの場合)

    // printf( "[%d]指定時間足確定%s" , __LINE__ , TimeToStr( Time[0] ) );

}

//+------------------------------------------------------------------+
//| テスト用オブジェクト描画
//+------------------------------------------------------------------+
void TestDispObject( int    in_index ) {

    // インデックスが範囲外の場合は描画しない
    if ( in_index < 0 ) {
        return;
    }

    if ( in_index >= Bars ) {
        return;
    }

    string obj_name;            // オブジェクト名
    obj_name = StringFormat( "%sEATest%s" , OBJ_HEAD, TimeToStr( Time[in_index] ) );

    if ( ObjectFind( obj_name ) >= 0 ) {  // オブジェクト名重複チェック
        // 重複している場合

        ObjectDelete( obj_name );        // 指定したオブジェクトを削除する
    }


    ObjectCreate(                                  // オブジェクト生成
                    obj_name,                        // オブジェクト名
                    OBJ_ARROW_RIGHT_PRICE,        // オブジェクトタイプ
                    0,                               // ウインドウインデックス
                    Time[in_index] ,                // 1番目の時間のアンカーポイント
                    Close[in_index]                // 1番目の価格のアンカーポイント
                    );


    // オブジェクトプロパティ設定
    ObjectSetInteger( 0, obj_name, OBJPROP_COLOR, clrYellow);     // ラインの色設定
    ObjectSetInteger( 0, obj_name, OBJPROP_WIDTH, 1);            // ラインの幅設定
    ObjectSetInteger( 0 ,obj_name, OBJPROP_BACK, false);         // オブジェクトの背景表示設定
    ObjectSetInteger( 0 ,obj_name, OBJPROP_SELECTABLE, false);   // オブジェクトの選択可否設定
    ObjectSetInteger( 0 ,obj_name, OBJPROP_SELECTED, false);     // オブジェクトの選択状態
    ObjectSetInteger( 0 ,obj_name, OBJPROP_HIDDEN, true);        // オブジェクトリスト表示設定
}

//+------------------------------------------------------------------+
//| 移動平均線のクロス判定
//+------------------------------------------------------------------+
ENUM_MA_CROSS MACrossJudge(){

    ENUM_MA_CROSS ret = MAC_NO;

    double base_short_ma_rate;  // 確定した短期移動平均
    double base_middle_ma_rate; // 確定した長期移動平均

    double last_short_ma_rate;  // 前回の短期移動平均
    double last_middle_ma_rate; // 前回の長期移動平均

    // 確定した短期SMAを取得
    base_short_ma_rate = iMA (               // 移動平均算出
                             Symbol(),      // 通貨ペア
                             Period(),      // 時間軸
                             12,             // MAの平均期間
                             0,              // MAシフト
                             MODE_EMA,     // MAの平均化メソッド
                             PRICE_CLOSE,  // 適用価格
                             1               // シフト
                        );

    // 確定した長期SMAを取得
    base_middle_ma_rate = iMA (               // 移動平均算出
                             Symbol(),      // 通貨ペア
                             Period(),      // 時間軸
                             26,             // MAの平均期間
                             0,              // MAシフト
                             MODE_EMA,     // MAの平均化メソッド
                             PRICE_CLOSE,  // 適用価格
                             1               // シフト
                        );

    // 前回の短期SMAを取得
    last_short_ma_rate = iMA (               // 移動平均算出
                             Symbol(),      // 通貨ペア
                             Period(),      // 時間軸
                             12,             // MAの平均期間
                             0,              // MAシフト
                             MODE_EMA,     // MAの平均化メソッド
                             PRICE_CLOSE,  // 適用価格
                             2               // シフト
                        );

    // 前回の長期SMAを取得
    last_middle_ma_rate = iMA (               // 移動平均算出
                             Symbol(),      // 通貨ペア
                             Period(),      // 時間軸
                             26,             // MAの平均期間
                             0,              // MAシフト
                             MODE_EMA,     // MAの平均化メソッド
                             PRICE_CLOSE,  // 適用価格
                             2               // シフト
                        );


    // 短期SMAが長期SMAを上抜け
    if (  base_short_ma_rate > base_middle_ma_rate
       && last_short_ma_rate <= last_middle_ma_rate
    ) {
        ret = MAC_UP_CHANGE;
    }
    else if ( base_short_ma_rate < base_middle_ma_rate
            && last_short_ma_rate >= last_middle_ma_rate
    ) {
        // 短期SMAが長期SMAを下抜け
        ret = MAC_DOWN_CHANGE;
    }

    // if ( ret == MAC_UP_CHANGE || ret == MAC_DOWN_CHANGE ) {
    //      TestDispObject(1); // テスト用オブジェクトを描画
    // }

    return ret;
}

//+------------------------------------------------------------------+
//| エントリーオーダー判定
//+------------------------------------------------------------------+
void JudgeEntry( ENUM_MA_CROSS in_ma_cross ) {

    bool entry_bool = false;    // エントリー判定
    bool entry_long = false;    // ロングエントリー判定

    if ( in_ma_cross == MAC_UP_CHANGE ) {           // MA上抜け
        entry_bool = true;
        entry_long = true;
    } else if ( in_ma_cross == MAC_DOWN_CHANGE ) {  // MA下抜け
        entry_bool = true;
        entry_long = false;
    }

    GetPosiInfo( _StPositionInfoData );        // ポジション情報を取得

    if ( _StPositionInfoData.ticket_no > 0 ) { // ポジション保有中の場合
        entry_bool = false;                    // エントリー禁止
    }

    if ( entry_bool == true ) {
        EA_EntryOrder( entry_long );        // 新規エントリー
    }
}

//+------------------------------------------------------------------+
//| 決済オーダー判定
//+------------------------------------------------------------------+
void JudgeClose( ENUM_MA_CROSS in_ma_cross ) {

    bool close_bool = false;    // 決済判定

    if ( _StPositionInfoData.ticket_no > 0 ) { // ポジション保有中の場合

        if ( _StPositionInfoData.entry_dir == OP_SELL ) {       // 売りポジ保有中の場合
            if ( in_ma_cross == MAC_UP_CHANGE ) {               // MA上抜け
                close_bool = true;
            }

        } else if ( _StPositionInfoData.entry_dir == OP_BUY ) { // 買いポジ保有中の場合
            if ( in_ma_cross == MAC_DOWN_CHANGE ) {             // MA下抜け
                close_bool = true;
            }
        }
    }

    if ( close_bool == true ) {
        bool close_done = false;
        close_done = EA_Close_Order( _StPositionInfoData.ticket_no );        // 決済処理

        if ( close_done == true ) {
            ClearPosiInfo(_StPositionInfoData);                             // ポジション情報クリア(決済済みの場合)
        }
    }
}


//+------------------------------------------------------------------+
//| ポジション情報を取得
//+------------------------------------------------------------------+
bool GetPosiInfo( struct_PositionInfo &in_st ){

    bool ret = false;
    int  position_total = OrdersTotal();     // 保有しているポジション数取得

    // 全ポジション分ループ
    for ( int icount = 0 ; icount < position_total ; icount++ ) {

        if ( OrderSelect( icount , SELECT_BY_POS ) == true ) {          // インデックス指定でポジションを選択

            if ( OrderMagicNumber() != MAGIC_NO ) {                   // マジックナンバー不一致判定
                continue;                                               // 次のループ処理へ
            }

            if ( OrderSymbol() != Symbol() ) {                        // 通貨ペア不一致判定
                continue;                                               // 次のループ処理へ
            }

            in_st.ticket_no      = OrderTicket();                       // チケット番号を取得
            in_st.entry_dir      = OrderType();                         // オーダータイプを取得
            in_st.set_limit      = OrderTakeProfit();                   // リミットを取得
            in_st.set_stop       = OrderStopLoss();                     // ストップを取得

            ret = true;

            break;                                                      // ループ処理中断
        }
    }

    return ret;
}

//+------------------------------------------------------------------+
//| ポジション情報をクリア(決済済みの場合)
//+------------------------------------------------------------------+
void ClearPosiInfo( struct_PositionInfo &in_st ) {

    if ( in_st.ticket_no > 0 ) { // ポジション保有中の場合

        bool select_bool;                // ポジション選択結果

        // ポジションを選択
        select_bool = OrderSelect(
                        in_st.ticket_no ,// チケットNo
                        SELECT_BY_TICKET // チケット指定で注文選択
                    );

        // ポジション選択失敗時
        if ( select_bool == false ) {
            printf( "[%d]不明なチケットNo = %d" , __LINE__ , in_st.ticket_no);
            return;
        }

        // ポジションがクローズ済みの場合
        if ( OrderCloseTime() > 0 ) {
            ZeroMemory( in_st );            // ゼロクリア
        }

    }

}

//+------------------------------------------------------------------+
//| デバッグ用コメント表示
//+------------------------------------------------------------------+
void DispDebugInfo( struct_PositionInfo &in_st ){

    string temp_str = "";               // 表示する文字列

    // \n は改行コード
    temp_str += StringFormat( "チケットNo    :%d\n" , in_st.ticket_no );
    temp_str += StringFormat( "オーダータイプ:%d\n" , in_st.entry_dir );
    temp_str += StringFormat( "リミット      :%s\n" , DoubleToStr(in_st.set_limit,Digits) );
    temp_str += StringFormat( "ストップ      :%s\n" , DoubleToStr(in_st.set_stop,Digits) );

    Comment( temp_str );                // コメント表示
}

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| 新規エントリー
//+------------------------------------------------------------------+
bool EA_EntryOrder(
                    bool in_long // true:Long false:Short
) {

    bool   ret        = false;      // 戻り値
    int    order_type = OP_BUY;     // 注文タイプ
    double order_lot  = _MinLot;    // ロット
    double order_rate = Ask;        // オーダープライスレート

    if ( in_long == true ) {        // Longエントリー
        order_type = OP_BUY;
        order_rate = Ask;

    } else {                        // Shortエントリー
        order_type = OP_SELL;
        order_rate = Bid;
    }

    int ea_ticket_res = -1; // チケットNo

    ea_ticket_res = OrderSend(                           // 新規エントリー注文
                                Symbol(),                // 通貨ペア
                                order_type,               // オーダータイプ[OP_BUY / OP_SELL]
                                order_lot,                // ロット[0.01単位]
                                order_rate,               // オーダープライスレート
                                100,                      // スリップ上限    (int)[分解能 0.1pips]
                                0,                        // ストップレート
                                0,                        // リミットレート
                                "SMAクロスEA",            // オーダーコメント
                                MAGIC_NO                  // マジックナンバー(識別用)
                               );

    if ( ea_ticket_res != -1) {    // オーダー正常完了
        ret = true;

    } else {                       // オーダーエラーの場合

        int    get_error_code   = GetLastError();                   // エラーコード取得
        string error_detail_str = ErrorDescription(get_error_code); // エラー詳細取得

        // エラーログ出力
        printf( "[%d]エントリーオーダーエラー。 エラーコード=%d エラー内容=%s"
            , __LINE__ ,  get_error_code , error_detail_str
         );
    }

    return ret;
}

//+------------------------------------------------------------------+
//| 注文決済
//+------------------------------------------------------------------+
bool EA_Close_Order( int in_ticket ){

    bool select_bool;                // ポジション選択結果
    bool ret = false;                // 結果

    // ポジションを選択
    select_bool = OrderSelect(
                    in_ticket ,      // チケットNo
                    SELECT_BY_TICKET // チケット指定で注文選択
                );

    // ポジション選択失敗時
    if ( select_bool == false ) {
        printf( "[%d]不明なチケットNo = %d" , __LINE__ , in_ticket);
        return ret;    // 処理終了
    }

    // ポジションがクローズ済みの場合
    if ( OrderCloseTime() > 0 ) {
        printf( "[%d]ポジションクローズ済み チケットNo = %d" , __LINE__ , in_ticket );
        return true;   // 処理終了
    }

    bool   close_bool;                  // 注文結果
    int    get_order_type;               // エントリー方向
    double close_rate = 0 ;              // 決済価格
    double close_lot  = 0;               // 決済数量

    get_order_type = OrderType();        // 注文タイプ取得
    close_lot      = OrderLots();        // ロット数


    if ( get_order_type == OP_BUY ) {            // 買いの場合
        close_rate = Bid;

    } else if ( get_order_type == OP_SELL ) {    // 売りの場合
        close_rate = Ask;

    } else {                                      // エントリー指値注文の場合
        return ret;                              // 処理終了
    }


    close_bool = OrderClose(              // 決済オーダー
                    in_ticket,              // チケットNo
                    close_lot,              // ロット数
                    close_rate,             // クローズ価格
                    20,                     // スリップ上限    (int)[分解能 0.1pips]
                    clrWhite              // 色
                  );

    if ( close_bool == false) {    // 失敗

        int    get_error_code   = GetLastError();                   // エラーコード取得
        string error_detail_str = ErrorDescription(get_error_code); // エラー詳細取得

        // エラーログ出力
        printf( "[%d]決済オーダーエラー。 エラーコード=%d エラー内容=%s"
            , __LINE__ ,  get_error_code , error_detail_str
         );
    } else {
        ret = true; // 戻り値設定：成功
    }

    return ret; // 戻り値を返す

}
