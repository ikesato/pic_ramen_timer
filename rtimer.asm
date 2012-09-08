	list      p=12f683
	#include <p12f683.inc>

	errorlevel  -302

;	__CONFIG   _CP_OFF & _CPD_OFF & _BOREN_OFF & _MCLRE_OFF & _WDT_OFF & _IESO_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT
	__CONFIG   _CP_OFF & _CPD_OFF & _BOREN_ON & _MCLRE_OFF & _WDT_OFF & _IESO_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT

;; 周波数             : 4MHz
;; プリスケーラ       : 1/256
;; タイマ割り込み     : 256us = 0.256[ms]
;; 0.256[ms] * 256    : 65.536[ms] = 0.065536[s]            : タイマ割り込みの間隔 (TMR0 が 0..256 で1周した場合)
;; 65.536[ms] * 256   : 16777.216[ms] = 16.777216[s]		: 256カウンタ1 TCNT1
;; 16.777216[s] * 256 : 4293.67296[s] = 1.19268693333333[h] : 256カウンタ2 TCNT2
;; 4293.67296[s] * 256 : 1099180.27776[s] = 305.327854933333[h] = 12.7219939555556[days] : 256カウンタ3 TCNT3 (使わないけどどのくらいか計算してみた)
;;
;;
;; 10sec
;;    10[s]/0.065536[s] = 152.587890625 = 0*256 + 152.587890625
;; 20sec
;;    20[s]/0.065536[s] = 305.17578125  = 1*256 + 49.17578125
;; 30sec
;;    30[s]/0.065536[s] = 457.763671875 = 1*256 + 201.763671875
;; 1min
;;    60[s]/0.065536[s] =  915.52734375 = 3*256 + 147.52734375
;; 2min
;;   120[s]/0.065536[s] = 1831.0546875  = 7*256 + 39.0546875
;; 3min
;;   180[s]/0.065536[s] = 2746.58203125 = 10*256 + 186.58203125
;; 4min
;;   240[s]/0.065536[s] = 3662.109375   = 14*256 + 78.109375
;; 5min
;;   300[s]/0.065536[s] = 4577.63671875 = 17*256 + 225.63671875
;;
;;
;; ステージ
;; 0 : standby
;;     スタンバイステージ
;;     sleep とし省電力モードになる
;;     input1,2    : ボタンが押されたら select ステージへ
;;     output1,2,3 : 全てOFF
;; 1 : select
;;     3,4,5分を選択するステージ
;;     1分無操作の場合は standby ステージへ
;;     input1  : countdown ステージへ
;;     input2  : 3,4,5 分を選択する。3->4->5->3...
;;     output1 : 3分
;;     output2 : 4分
;;     output3 : 5分
;; 2 : countdown
;;     カウントダウン。タイマーが0になったら music ステージへ
;;     input1  : 終了音を鳴らして standby ステージへ
;;     input2  : 終了音を鳴らして standby ステージへ
;;     output1 : 0-1分:点滅1  1分以上:点灯
;;     output2 : 0-1分:消灯   1-2分:点滅1  2分以上:点灯
;;     output3 : 0-2分:消灯   2-3分:点滅1  3-5分:それぞれの分の回数分だけ点滅
;; 3 : music
;;　　 音楽を鳴らすステージ
;;     input1  : 終了音を鳴らして standby ステージへ
;;     input2  : 終了音を鳴らして standby ステージへ
;;     output1 : 点滅
;;     output2 : 点滅
;;     output3 : 点滅
;;
;;
;; GPIO
;;  GP0 : output : LED1
;;  GP1 : output : LED2
;;  GP2 : output : LED3
;;  GP3 : input  : プッシュスイッチ1
;;  GP4 : input  : プッシュスイッチ2
;;  GP5 : output : 圧電スピーカ
;;

#define		TCNT2_10sec	d'0'	; 1min 用
#define		TCNT1_10sec	d'153'	; 1min 用
#define		TCNT2_20sec	d'1'	; 1min 用
#define		TCNT1_20sec	d'49'	; 1min 用
#define		TCNT2_30sec	d'1'	; 1min 用
#define		TCNT1_30sec	d'202'	; 1min 用
#define		TCNT2_1min	d'3'	; 1min 用
#define		TCNT1_1min	d'148'	; 1min 用
#define		TCNT2_2min	d'7'	; 2min 用
#define		TCNT1_2min	d'39'	; 2min 用
#define		TCNT2_3min	d'10'	; 3min 用
#define		TCNT1_3min	d'187'	; 3min 用
#define		TCNT2_4min	d'14'	; 4min 用
#define		TCNT1_4min	d'78'	; 4min 用
#define		TCNT2_5min	d'17'	; 5min 用
#define		TCNT1_5min	d'226'	; 5min 用
#define		SW1_PORT	4
#define		SW2_PORT	3

#define		LED1		GPIO,0	;LED用ポート
#define		LED2		GPIO,1	;LED用ポート
#define		LED3		GPIO,2	;LED用ポート
#define		PUSHSW1		GPIO,SW1_PORT	;プッシュスイッチ用ポート
#define		PUSHSW2		GPIO,SW2_PORT	;プッシュスイッチ用ポート
#define		BEEP		GPIO,5	;圧電スピーカポート

;***** VARIABLE DEFINITIONS
w_temp			EQU		0x20		;割り込みハンドラ用 
status_temp		EQU		0x21		;割り込みハンドラ用
TCNT1			EQU		0x22		;タイマー用
TCNT2			EQU		0x23		;タイマー用
TIMER_ZERO		EQU		0x24		;タイマーが0になったかどうか用
STAGE			EQU		0x25		;ステージ変数 0:standby 1:select 2:countdown 3:music
DLY_CNT1		EQU		0x26		;ディレイ用カウント
DLY_CNT2		EQU		0x27		;ディレイ用カウント
PUSHSW_STATE	EQU		0x28		;プッシュスイッチのup/down状態
									;  bit 0,1 : push up/down 状態  0:SW1 down 1:SW1 down
PUSHSW_TRIGGER	EQU		0x29		;プッシュスイッチのtrigger状態
									;  bit 0,1 : push trigger 状態  0:SW1 pushed 1:SW1 pushed

CNT_N_100ms		EQU		0x30		;ディレイルーチン用
CNT_100ms		EQU		0x31		;ディレイルーチン用
CNT_256			EQU		0x32		;ディレイルーチン用 256*N+M のN
CNT_M			EQU		0x33		;ディレイルーチン用 256*N+M のM
CNT_N			EQU		0x34		;ディレイルーチン用 Ncycle 待ち用
WORK_CNT_100ms	EQU		0x35		;ディレイルーチン用
WORK_CNT_256	EQU		0x36		;ディレイルーチン用
WORK_CNT_M		EQU		0x37		;ディレイルーチン用
WORK_CNT_N		EQU		0x38		;ディレイルーチン用

SELECT_MIN		EQU		0x40		;3,4,5分選択用 0:3分 1:4分 2:5分
WORK_CNT		EQU		0x41		;カウンタ演算用ワーク変数

;**********************************************************************
		ORG			0x000
		goto		main


; 割り込み処理ルーチン
		ORG			0x004
		movwf		w_temp
		movf		STATUS,w
		movwf		status_temp
		bcf			INTCON,GIE	;全割り込み停止

		btfss		INTCON,T0IF	;もしもタイマー割り込みでなければ復帰
		goto		exit_int2

timer_int	;タイマー割り込み時		
		movf		TCNT1,f
		btfss		STATUS,Z
		goto		decrement_cnt1
		movf		TCNT2,f
		btfss		STATUS,Z
		goto		decrement_cnt2

		;; 終了
		bcf			INTCON,T0IE	;タイマー割り込み停止
		bsf			TIMER_ZERO,0
		goto		exit_int2

decrement_cnt1
		decf		TCNT1,f
		goto		exit_int

decrement_cnt2		;; 繰越
		movlw		0xff
		movwf		TCNT1
		decf		TCNT2,f
		goto		exit_int

exit_int
		clrf		TMR0
;		movlw		b'00100000'	;タイマー割り込み許可、T0IFフラグクリア
;		movwf		INTCON
		bsf			INTCON,T0IE

exit_int2
		bcf			INTCON,T0IF
		bcf			INTCON,INTF
		bcf			INTCON,GPIF
		bsf			INTCON,GIE	;全割り込み開始
		movf		status_temp,w
		movwf		STATUS
		swapf		w_temp,f
		swapf		w_temp,w
		retfie


;ここからメイン
main
		bsf			STATUS,RP0	;Bank=1
		movlw		0x60		;4MHz
		movwf		OSCCON		;OSCALに値を設定
		bcf			STATUS,RP0	;Bank=0

		;ここからメイン処理
		;電源投入&リセット時の初期化処理
		clrf		INTCON		;割り込み禁止

		clrf		GPIO		;GPIO出力を0に
		movlw		0x07		;
		movwf		CMCON0		;コンパレータを使用禁止に設定
		bsf			STATUS,RP0	;Bank=1
		clrf		TRISIO		;GPIOを出力に設定
		bsf			TRISIO,3	;GP3入力に設定
		bsf			TRISIO,4	;GP4入力に設定
		clrf		IOC			;I/O状態変化チェック解除
		movlw		b'10000111'	;プルアップ無し、エッジ割り込み無し、タイマー0は内部クロック
		movwf		OPTION_REG	;プリスケーラー1/256に設定
		clrf 		ANSEL 		;digital I/O
		bcf			STATUS,RP0	; Bnak=0

		movlw		0x0			; デフォルト3分
		movwf		SELECT_MIN

		clrf		PUSHSW_STATE 	;プッシュSWの状態初期化
		clrf		PUSHSW_TRIGGER	;プッシュSWのトリガー状態初期化


		call		DLY_250
		call		init_select_stage

;;		movlw		1
;;		movwf		SELECT_MIN
;;		goto		goto_countdown_stage

		
;;
main_loop
		;; STAGE==0x1
		movf		STAGE,w
		sublw		0x1
		btfsc		STATUS,Z
		goto		select_stage

		;; STAGE==0x2
		movf		STAGE,w
		sublw		0x2
		btfsc		STATUS,Z
		goto		countdown_stage

		;; STAGE==0x3
		goto		music_stage


init_1min_timer
		movlw		TCNT1_1min
		movwf		TCNT1
		movlw		TCNT2_1min
		movwf		TCNT2
		goto		init_timer_register
init_3min_timer
		movlw		TCNT1_3min
		movwf		TCNT1
		movlw		TCNT2_3min
		movwf		TCNT2
		goto		init_timer_register
init_4min_timer
		movlw		TCNT1_4min
		movwf		TCNT1
		movlw		TCNT2_4min
		movwf		TCNT2
		goto		init_timer_register
init_5min_timer
		movlw		TCNT1_5min
		movwf		TCNT1
		movlw		TCNT2_5min
		movwf		TCNT2
		goto		init_timer_register
init_timer_register
		clrf		TIMER_ZERO
		clrf		TMR0
		bsf			INTCON,GIE	;タイマー割り込み開始
		bcf			INTCON,GPIE	;ポートからの再起動クリア
		bsf			INTCON,T0IE
		return

;;------------------------------------------------- select stage
init_select_stage
		call		update_pushsw_state_for_resume
		movlw		0x1			;selectステージへ
		movwf		STAGE
		goto		init_1min_timer

select_stage
		btfsc		TIMER_ZERO,0
		goto		standby_stage

		call		update_pushsw_state
		btfsc		PUSHSW_TRIGGER,1
		goto		goto_countdown_stage	;SW2が押されていれば countdown ステージへ

		btfss		PUSHSW_TRIGGER,0
		goto		select_stage_draw_led	;押されていなければLED描画へ

		call		se_button
		call		init_1min_timer
		incf		SELECT_MIN,f
		movlw		0x3
		subwf		SELECT_MIN,w
		btfsc		STATUS,Z
		movwf		SELECT_MIN				;3まで行っていたら繰越で0にする
select_stage_draw_led
		;; 3min SELECT_MIN==0
		movf		SELECT_MIN,w
		sublw		0x0
		btfsc		STATUS,Z
		goto		select_stage_draw_led1
		;; 4min SELECT_MIN==1
		movf		SELECT_MIN,w
		sublw		0x1
		btfsc		STATUS,Z
		goto		select_stage_draw_led12
		;; 5min SELECT_MIN==2
		goto		select_stage_draw_led123
		
select_stage_draw_led1
		bsf			LED1
		bcf			LED2
		bcf			LED3
		goto		main_loop
select_stage_draw_led12
		bsf			LED1
		bsf			LED2
		bcf			LED3
		goto		main_loop
select_stage_draw_led123
		bsf			LED1
		bsf			LED2
		bsf			LED3
		goto		main_loop
goto_countdown_stage
		;; 3min SELECT_MIN==0
		movf		SELECT_MIN,w
		sublw		0x0
		btfss		STATUS,Z
		goto		goto_countdown_stage_4min
		call		init_3min_timer
		goto		goto_countdown_stage_end
goto_countdown_stage_4min
		;; 4min SELECT_MIN==1
		movf		SELECT_MIN,w
		sublw		0x1
		btfss		STATUS,Z
		goto		goto_countdown_stage_5min
		call		init_4min_timer
		goto		goto_countdown_stage_end
goto_countdown_stage_5min
		;; 5min SELECT_MIN==2
		call		init_5min_timer
goto_countdown_stage_end
		call		se_start_countdown
		movlw		0x2			;countdownステージへ
		movwf		STAGE
		goto		main_loop



;;------------------------------------------------- countdown stage
countdown_stage
		btfsc		TIMER_ZERO,0
		goto		goto_music_stage 		;時間経過したら music stage へ

		;; 同時押しでstandbyステージへ
		call		update_pushsw_state
		btfss		PUSHSW_TRIGGER,0
		goto		countdown_stage_timer_check	;押されていなければ skip
		btfss		PUSHSW_TRIGGER,1
		goto		countdown_stage_timer_check	;押されていなければ skip
		goto		standby_stage
		

countdown_stage_timer_check	;SW2が押されていれば countdown ステージへ
		;; 5-4min かどうかの判定
		movlw		TCNT2_4min
		subwf		TCNT2,w
		btfss		STATUS,C
		goto		countdown_stage_4_3min		;TCNT2-w < 0 の場合
		btfss		STATUS,Z
		goto		countdown_draw_5min			;TCNT2-w > 0 の場合
		movlw		TCNT1_4min
		subwf		TCNT1,w
		btfsc		STATUS,C
		goto		countdown_draw_5min			;TCNT1-w >= 0 の場合
countdown_stage_4_3min
		;; 4-3min かどうかの判定
		movlw		TCNT2_3min
		subwf		TCNT2,w
		btfss		STATUS,C
		goto		countdown_stage_3_2min		;TCNT2-w < 0 の場合
		btfss		STATUS,Z
		goto		countdown_draw_4min			;TCNT2-w > 0 の場合
		movlw		TCNT1_3min
		subwf		TCNT1,w
		btfsc		STATUS,C
		goto		countdown_draw_4min			;TCNT1-w >= 0 の場合
countdown_stage_3_2min
		;; 3-2min かどうかの判定
		movlw		TCNT2_2min
		subwf		TCNT2,w
		btfss		STATUS,C
		goto		countdown_stage_2_1min		;TCNT2-w < 0 の場合
		btfss		STATUS,Z
		goto		countdown_draw_3min			;TCNT2-w > 0 の場合
		movlw		TCNT1_2min
		subwf		TCNT1,w
		btfsc		STATUS,C
		goto		countdown_draw_3min			;TCNT1-w >= 0 の場合
countdown_stage_2_1min
		;; 2-1min かどうかの判定
		movlw		TCNT2_1min
		subwf		TCNT2,w
		btfss		STATUS,C
		goto		countdown_stage_60_30sec	;TCNT2-w < 0 の場合
		btfss		STATUS,Z
		goto		countdown_draw_2min			;TCNT2-w > 0 の場合
		movlw		TCNT1_1min
		subwf		TCNT1,w
		btfsc		STATUS,C
		goto		countdown_draw_2min			;TCNT1-w >= 0 の場合
countdown_stage_60_30sec
		;; 60-30sec かどうかの判定
		movlw		TCNT2_30sec
		subwf		TCNT2,w
		btfss		STATUS,C
		goto		countdown_stage_30_10sec	;TCNT2-w < 0 の場合
		btfss		STATUS,Z
		goto		countdown_draw_60sec		;TCNT2-w > 0 の場合
		movlw		TCNT1_30sec
		subwf		TCNT1,w
		btfsc		STATUS,C
		goto		countdown_draw_60sec		;TCNT1-w >= 0 の場合
countdown_stage_30_10sec
		;; 30-10sec かどうかの判定
		movlw		TCNT2_10sec
		subwf		TCNT2,w
		btfss		STATUS,C
		goto		countdown_stage_10_0sec		;TCNT2-w < 0 の場合
		btfss		STATUS,Z
		goto		countdown_draw_30sec		;TCNT2-w > 0 の場合
		movlw		TCNT1_10sec
		subwf		TCNT1,w
		btfsc		STATUS,C
		goto		countdown_draw_30sec		;TCNT1-w >= 0 の場合
countdown_stage_10_0sec
		goto		countdown_draw_10sec		;TCNT1-w >= 0 の場合

;;; 
		goto		goto_music_stage
		goto		main_loop

countdown_draw_5min
		bsf			LED1
		bsf			LED2
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		call		DLY_200
		goto		main_loop
countdown_draw_4min
		bsf			LED1
		bsf			LED2
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		call		DLY_200
		goto		main_loop
countdown_draw_3min
		bsf			LED1
		bsf			LED2
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		bsf			LED3
		call		DLY_200
		bcf			LED3
		call		DLY_200
		call		DLY_200
		goto		main_loop
countdown_draw_2min
		bsf			LED1
		bcf			LED3
		bsf			LED2
		call		DLY_200
		bcf			LED2
		call		DLY_200
		bsf			LED2
		call		DLY_200
		bcf			LED2
		call		DLY_200
		call		DLY_200
		goto		main_loop
countdown_draw_1min
		bcf			LED2
		bcf			LED3
		bsf			LED1
		call		DLY_200
		bcf			LED1
		call		DLY_200
		goto		main_loop
countdown_draw_60sec
		bcf			LED2
		bcf			LED3
		bsf			LED1
		call		DLY_200
		bcf			LED1
		call		DLY_200
		goto		main_loop
countdown_draw_30sec
		bcf			LED2
		bcf			LED3
		bsf			LED1
		call		DLY_100
		bcf			LED1
		call		DLY_100
		goto		main_loop
countdown_draw_10sec
		bcf			LED2
		bcf			LED3
		bsf			LED1
		call		DLY_50
		bcf			LED1
		call		DLY_50
		goto		main_loop

goto_music_stage
		movlw		0x3			;musicdownステージへ
		movwf		STAGE
		goto		main_loop

;;------------------------------------------------- music stage
music_stage
        movlw       d'3'
		call        play_2do
		movlw       d'3'
		call        play_2re
		movlw       d'14'
		call        play_2mi
		movlw       d'3'
		call        play_2re
		movlw       d'5'
		call        play_2do
		call        DLY_100
		call        DLY_100
		movlw       d'3'
		call        play_2do
		movlw       d'3'
		call        play_2re
		movlw       d'3'
		call        play_2mi
		movlw       d'3'
		call        play_2re
		movlw       d'3'
		call        play_2do
		movlw       d'17'
		call        play_2re
		call        DLY_100
		call        DLY_100
		call        DLY_100

		goto		standby_stage
;		movlw		TCNT50MS		;タイマー関連の値をセット
;		movwf		TMR0
;		movlw		TCNT1S
;		movwf		TIM1
;		movlw		TIME_GO
;		movwf		TIM2
;
;		movlw		b'00100000'	;タイマー0割り込みセット
;		movwf		INTCON
;
;		call		DLY_250		;レディ音前のディレイ
;
;		movlw		d'100'		;レディ音鳴らす
;		movwf		TMP_CNT2
;		bsf			LED_P		;音といっしょにLEDも
;	click1							;起動確認音
;			bsf			BEEP_P		;約0.1秒だけ鳴る
;			call		DLY_05m
;			bcf			BEEP_P
;			call		DLY_05m
;			decfsz		TMP_CNT2,f
;			goto		click1
;			bcf			BEEP_P
;			bcf			LED_P		;LEDオフ
;
;			bsf			INTCON,GIE	;タイマー割り込み開始
;
;	loop1
;			btfss		TIM_F,0		;タイマー割り込みが1秒分あったか？
;			goto		loop1		;無ければフラグ待ち
;			decfsz		TIM2,f		;目的の時間まで繰り返す
;			goto		led_blink	;まだなら動作中LEDを点滅
;			bcf			INTCON,GIE	;経過したなら割り込みを禁止して
;			goto		time_up		;ブザーを鳴らしに
;	led_blink						;カウントダウン中LED点滅
;			bcf			TIM_F,0		;1秒経過フラグ解除
;			bsf			LED_P		;LEDオン
;			call		DLY_50		;0.05秒待って
;			bcf			LED_P		;LEDオフ
;			goto		loop1
;
;	time_up
;			movlw		TIME_OUT	;ビープのタイムアウトを設定
;			movwf		TMP_TMO
;	beep							;ビープループ 音を断続で鳴りつづけさせる
;			bsf			LED_P		;音ともにLEDも点滅
;			movlw		d'2'
;			movwf		TMP_CNT1
;	beep1
;			movlw		d'250'
;			movwf		TMP_CNT2
;	beep2
;			call		sw_check	;スイッチが押されたか
;			andlw		0x01
;			btfss		STATUS,Z
;			goto		standby_mode	;押されていればスタンバイモードへ
;			bsf			BEEP_P		;約0.5秒鳴って
;			call		DLY_05m
;			bcf			BEEP_P
;			call		DLY_05m
;			decfsz		TMP_CNT2,f
;			goto		beep2
;			decfsz		TMP_CNT1,f
;			goto		beep1
;			bcf			LED_P		;LEDオフ
;
;			call		DLY_250		;約0.5秒休む
;			call		DLY_250
;			decfsz		TMP_TMO,f	;タイムアウト時間経過してもスイッチ無ければスタンバイ
;			goto		beep























;スタンバイモード
;LEDで確認表示した後、寝る
standby_stage
		movlw		0x0			;意味ないけど一応セット
		movwf		STAGE

		clrf		INTCON		;割り込み禁止
		clrf		GPIO
		call		DLY_250 	; ポートが安定するのを待つ
		call		DLY_250
		call		DLY_250
		call		DLY_250
		clrf		GPIO
		clrf		INTCON		;割り込み禁止

		;寝る
		bsf			STATUS,RP0	;Bank=1
		clrf		IOC			;I/O状態変化チェック解除
		bsf			IOC,SW1_PORT;プッシュSW1の割り込みを設定
		bsf			IOC,SW2_PORT;プッシュSW2の割り込みを設定
		bcf			STATUS,RP0	;Bank=0
		bsf			INTCON,GPIE	;ポートからの再起動設定
		bcf			INTCON,GIE	;

		nop
		nop
		sleep					;SLEEPモードへ
		nop						;このインストラクションはフェッチされる
		nop

		;起きた
		;音を鳴らす
		bsf			LED1
		bsf			LED2
		bsf			LED3
		call		se_button
		bcf			LED1
		bcf			LED2
		bcf			LED3

		call		init_select_stage
		goto		main_loop	;メインループ実行へ


;;---------------------------------------------------------- sub routines

;スイッチ入力チェック
update_pushsw_state
		movf		PUSHSW_STATE,w 	;前回の状態をwレジスタへ保持
		clrf		PUSHSW_STATE
		btfss		PUSHSW1
		bsf			PUSHSW_STATE,0
		btfss		PUSHSW2
		bsf			PUSHSW_STATE,1
		xorwf		PUSHSW_STATE,w	;前回の状態とXORし結果を w レジスタへ格納
		andwf		PUSHSW_STATE,w	;現在の状態とANDを取ることでトリガーを検出
		movwf		PUSHSW_TRIGGER
		return
update_pushsw_state_for_resume	;sleep から起きた場合はトリガー状態は変化なしとする
		clrf		PUSHSW_STATE
		btfss		PUSHSW1
		bsf			PUSHSW_STATE,0
		btfss		PUSHSW2
		bsf			PUSHSW_STATE,1
		clrf		PUSHSW_TRIGGER
		return


;時間遅延ルーチン類
DLY_250	; 250mS
		movlw		d'250'
		movwf		DLY_CNT1
		goto		DLY1
DLY_200	; 200mS
		movlw		d'200'
		movwf		DLY_CNT1
		goto		DLY1
DLY_150	; 150mS
		movlw		d'150'
		movwf		DLY_CNT1
		goto		DLY1
DLY_100	; 100mS
		movlw		d'100'
		movwf		DLY_CNT1
		goto		DLY1
DLY_50	; 50mS
		movlw		d'50'
		movwf		DLY_CNT1
		goto		DLY1
DLY_05	; 5mS
		movlw		d'5'
		movwf		DLY_CNT1
		goto		DLY1
DLY1	; 1mS
		movlw		d'250'
		movwf		DLY_CNT2
DLY2
		nop
		decfsz		DLY_CNT2,f
		goto		DLY2
		decfsz		DLY_CNT1,f
		goto		DLY1
		return







se_button
		movlw		0x1
		call		play_3do
		return
se_start_countdown
		movlw		0x1
		call		play_3do
		call		DLY_100
		movlw		0x1
		call		play_3do
		return

;;; 音を鳴らす
;;; @param w 長さ (100ms * N) のNを指定
;;; @param CNT_100ms 100ms 用カウンタ
;;; @param CNT_256 長さ 256サイクル用カウンタ
;;; @param CNT_M 長さ Nサイクル用カウンタ
play
		incf		CNT_N_100ms,f
play_loop
		decfsz		CNT_N_100ms,f
		goto		play_100ms
		return
play_100ms
		movf		CNT_100ms,w
		movwf		WORK_CNT_100ms
play_100ms_loop
		bsf			BEEP
		call		delay_NMcycle
		bcf			BEEP
		call		delay_NMcycle
		decfsz		WORK_CNT_100ms,f
		goto		play_100ms_loop
		goto		play_loop

;;; 約256*N+M サイクル待つ
;;;
;;; WORK_CNT_256, WORK_CNT_M レジスタを使用
;;; @param CNT_256 256*N+M の N を指定
;;; @param CNT_M 256*N+M の M を指定
delay_NMcycle
		movf		CNT_256,w
		movwf		WORK_CNT_256
		incf		WORK_CNT_256,f
delay_NMcycle_loop
		decfsz		WORK_CNT_256,f
		goto		delay_NMcycle_256cycle
		movf		CNT_M,w
		movwf		CNT_N
		goto		delay_Ncycle
delay_NMcycle_256cycle
		call		delay_256cycle
		goto		delay_NMcycle_loop

;;; Nサイクル delay
;;;
;;; WORK_CNT_N レジスタを使用
;;; @param CNT_N サイクルを指定
delay_Ncycle
		;; 12cycle必要
		movf		CNT_N,w
		movwf		WORK_CNT_N
		bcf			STATUS,C		; ループに 4cycle 必要なので4で割る
		rrf			WORK_CNT_N,f
		bcf			STATUS,C
		rrf			WORK_CNT_N,f
		movlw		d'3'			; ここが 12cycle 必要なの3ループ分引いておく
		subwf		WORK_CNT_N,f
		btfsc		STATUS,Z
		return
		btfss		STATUS,C
		return
delay_Ncycle_loop
		; 1ループに 4cycle 必要
		nop
		decfsz		WORK_CNT_N,f
		goto		delay_Ncycle_loop
		return
delay_256cycle
		movlw		d'63'		;256/4-1 -1はここが4cycle必要なので1を引く
		movwf		WORK_CNT_N
		goto		delay_Ncycle_loop

play_2do
		movwf		CNT_N_100ms
		movlw		d'52'
		movwf		CNT_100ms
		movlw		d'3'
		movwf		CNT_256
		movlw		d'188'
		movwf		CNT_M
		goto		play
play_2re
		movwf		CNT_N_100ms
		movlw		d'59'
		movwf		CNT_100ms
		movlw		d'3'
		movwf		CNT_256
		movlw		d'83'
		movwf		CNT_M
		goto		play
play_2mi
		movwf		CNT_N_100ms
		movlw		d'66'
		movwf		CNT_100ms
		movlw		d'2'
		movwf		CNT_256
		movlw		d'246'
		movwf		CNT_M
		goto		play
play_3do
		movwf		CNT_N_100ms
		movlw		d'105'
		movwf		CNT_100ms
		movlw		d'1'
		movwf		CNT_256
		movlw		d'222'
		movwf		CNT_M
		goto		play

;EEPROM初期化
		ORG	0x2100
		DE	0x00, 0x01, 0x02, 0x03
		END
