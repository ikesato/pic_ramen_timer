	list      p=12f683
	#include <p12f683.inc>

	errorlevel  -302

	__CONFIG   _CP_OFF & _CPD_OFF & _BOREN_OFF & _MCLRE_OFF & _WDT_OFF & _IESO_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT

;; 周波数             : 4MHz
;; プリスケーラ       : 1/256
;; タイマ割り込み     : 256us = 0.256[ms]
;; 0.256[ms] * 256    : 65.536[ms] = 0.065536[s]            : 1タイマ割り込みの間隔
;; 65.536[ms] * 256   : 16777.216[ms] = 16.777216[s]		: 256カウンタ1 TCNT1
;; 16.777216[s] * 256 : 4293.67296[s] = 1.19268693333333[h] : 256カウンタ2 TCNT2
;; 1min
;;    60[s]/0.065536[s] =  915.52734375 =  3*256 + 147.52734375
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

#define		TCNT1_1min	d'10'	; 1min 用
#define		TCNT2_2min	d'187'	; 1min 用
#define		TCNT1_3min	d'10'	; 3min 用
#define		TCNT2_3min	d'187'	; 3min 用
#define		TCNT1_4min	d'14'	; 4min 用
#define		TCNT2_4min	d'78'	; 4min 用
#define		TCNT1_5min	d'17'	; 5min 用
#define		TCNT2_5min	d'226'	; 5min 用

#define		LED1		GPIO,0	;LED用ポート
#define		LED2		GPIO,1	;LED用ポート
#define		LED3		GPIO,2	;LED用ポート
#define		PUSHSW1		GPIO,3	;プッシュスイッチ用ポート
#define		PUSHSW2		GPIO,4	;プッシュスイッチ用ポート
#define		BEEP		GPIO,5	;圧電スピーカポート

;***** VARIABLE DEFINITIONS
w_temp			EQU		0x20		;割り込みハンドラ用 
status_temp		EQU		0x21		;割り込みハンドラ用
TIMER_CNT1		EQU		0x22		;タイマー用
TIMER_CNT2		EQU		0x23		;タイマー用
TIMER_ZERO		EQU		0x24		;タイマーが0になったかどうか
STAGE			EQU		0x25		;ステージ変数 0:standby 1:select 2:countdown 3:music
DLY_CNT1		EQU		0x26		;ディレイ用カウント
DLY_CNT2		EQU		0x27		;ディレイ用カウント

CNT_N_100ms		EQU		0x30		;ディレイルーチン用
CNT_100ms		EQU		0x31		;ディレイルーチン用
CNT_256			EQU		0x32		;ディレイルーチン用 256*N+M のN
CNT_M			EQU		0x33		;ディレイルーチン用 256*N+M のM
CNT_N			EQU		0x34		;ディレイルーチン用 Ncycle 待ち用
WORK_CNT_100ms	EQU		0x35		;ディレイルーチン用
WORK_CNT_256	EQU		0x36		;ディレイルーチン用
WORK_CNT_M		EQU		0x37		;ディレイルーチン用
WORK_CNT_N		EQU		0x38		;ディレイルーチン用



;**********************************************************************
		ORG			0x000
		goto		main


; 割り込み処理ルーチン
		ORG			0x004
		movwf		w_temp
		movf		STATUS,w
		movwf		status_temp

		btfss		INTCON,T0IF	;もしもタイマー割り込みでなければ復帰
		goto		exit_int2

timer_int	;タイマー割り込み時
		movf		TIMER_CNT1,f
		btfss		STATUS,Z
		goto		decrement_cnt1
		movf		TIMER_CNT2,f
		btfss		STATUS,Z
		goto		decrement_cnt2

		;; 終了
		movlw		0x01
		movf		TIMER_ZERO,f
		goto		exit_int2

decrement_cnt1
		decf		TIMER_CNT1,f		;1秒カウント用をデクリメント
		goto		exit_int

decrement_cnt2		;; 繰越
		movlw		0xff
		movf		TIMER_CNT1,f
		decf		TIMER_CNT2,f		;1秒カウント用をデクリメント
		goto		exit_int

exit_int
		clrf		TMR0
		movlw		b'00100000'	;タイマー割り込み許可、T0IFフラグクリア
		movwf		INTCON

exit_int2
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

		goto		standby_stage	;電源投入されたら一旦寝る



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

select_stage
countdown_stage
music_stage
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

		bsf			LED1
		bsf			LED2
		bsf			LED3
		call		se_button
		bcf			LED1
		bcf			LED2
		bcf			LED3
		call		DLY_250
		bsf			LED1
		bsf			LED2
		bsf			LED3
		call		se_button
		bcf			LED1
		bcf			LED2
		bcf			LED3

		clrf		INTCON		;割り込み禁止
		call		DLY_250 	; ポートが安定するのを待つ
		call		DLY_250
		call		DLY_250
		call		DLY_250 


		;寝る
		bsf			STATUS,RP0	;Bank=1
		clrf		IOC			;I/O状態変化チェック解除
		bsf			IOC,5		;GPIO5のポート状態チェックを設定
		bcf			STATUS,RP0	;Bank=0
		bsf			INTCON,GPIE	;ポートからの再起動設定
		nop
		nop
		sleep					;SLEEPモードへ
		nop						;このインストラクションはフェッチされる
		nop

		movlw		0x1			;selectステージへ
		movwf		STAGE

		goto		main_loop	;メインループ実行へ

; メイン処理はここまで


;スイッチ入力チェック
sw1_check
		btfsc		PUSHSW1
		goto		sw_no		;押されていなければ0をもって即リターン
		call		DLY_100		;100mS待って
		btfsc		PUSHSW1		;まだ押されているなら1をもってリターン
		goto		sw_no
		goto		sw_yes
sw2_check
		btfsc		PUSHSW2
		goto		sw_no		;押されていなければ0をもって即リターン
		call		DLY_100		;100mS待って
		btfsc		PUSHSW2		;まだ押されているなら1をもってリターン
		goto		sw_no
		goto		sw_yes
sw_no
		retlw		0x00
sw_yes
		retlw		0x01


;時間遅延ルーチン類
DLY_250	; 250mS
		movlw		d'250'
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
		call		play_2do
		return

;;; 音を鳴らす
;;; @param w 長さ (100ms * N) のNを指定
;;; @param CNT_100ms 100ms 用カウンタ
;;; @param CNT_256 長さ 256サイクル用カウンタ
;;; @param CNT_M 長さ Nサイクル用カウンタ
play
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
		goto		play

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

play_1do
		movwf		CNT_N_100ms
		movlw		d'26'
		movwf		CNT_100ms
		movlw		d'7'
		movwf		CNT_256
		movlw		d'119'
		movwf		CNT_M
		call		play
        return
play_1re
		movwf		CNT_N_100ms
		movlw		d'29'
		movwf		CNT_100ms
		movlw		d'6'
		movwf		CNT_256
		movlw		d'117'
		movwf		CNT_M
		call		play
        return
play_1mi
		movwf		CNT_N_100ms
		movlw		d'33'
		movwf		CNT_100ms
		movlw		d'5'
		movwf		CNT_256
		movlw		d'237'
		movwf		CNT_M
		goto		play
play_2do
		movwf		CNT_N_100ms
		movlw		d'52'
		movwf		CNT_100ms
		movlw		d'3'
		movwf		CNT_256
		movlw		d'188'
		movwf		CNT_M
		goto		play

;EEPROM初期化
		ORG	0x2100
		DE	0x00, 0x01, 0x02, 0x03
		END
