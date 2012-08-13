	list      p=12f629
	#include <p12f629.inc>

	errorlevel  -302

;	__CONFIG   _CP_OFF & _CPD_OFF & _BODEN_OFF & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT
	__CONFIG   _CP_OFF & _CPD_OFF & _BOREN_OFF & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT

#define		TCNT50MS	d'61'	; 割り込みによる50mS計測のための定数
#define		TCNT1S		d'20'	; 1S = 50ms X 20
#define		TIME_GO		d'181'	; 3分(引いてゼロになった瞬間に音が鳴るので+1しておく)
#define		TIME_OUT	d'60'	; 1分以上ブザーなっても手遅れ

#define		BEEP_P		GPIO,2	;ビープ用スピーカポート
#define		PUSH_SW		GPIO,5	;プッシュスイッチ用ポート
#define		LED_P		GPIO,1	;動作確認LED用ポート

;***** VARIABLE DEFINITIONS
w_temp		EQU		0x20		;割り込みハンドラ用 
status_temp	EQU		0x21		;割り込みハンドラ用
CNT1		EQU		0x22		;ディレイルーチン用
CNT2		EQU		0x23		;ディレイルーチン用
TMP_TMO		EQU		0x24		;アラームタイムアウト用
TMP_CNT1	EQU		0x25		;テンポラリ
TMP_CNT2	EQU		0x26		;テンポラリ
TIM1		EQU		0x30		;1秒カウント用
TIM2		EQU		0x31		;3分カウント用
TIM_F		EQU		0x32		;1秒経過チェック用


;**********************************************************************
		ORG			0x000
		goto		main


; 割り込み処理ルーチン

		ORG			0x004
		movwf		w_temp
		movf		STATUS,w
		movwf		status_temp

		btfss		INTCON,T0IF	;もしもタイマー割り込みでなければ復帰
		goto		ret_main2

tim_int	;タイマー割り込み時
		;50mS毎の割り込みハンドル
		decf		TIM1,f		;1秒カウント用をデクリメント 
		btfss		STATUS,Z	;1秒経過したか？
		goto		ret_main	;まだなら復帰
		bsf			TIM_F,0		;1秒チェックフラグを立てる
		movlw		TCNT1S		;1秒データを再セット
		movwf		TIM1

ret_main
		movlw		TCNT50MS	;タイマー0を再セット
		movwf		TMR0

		movlw		b'00100000'	;タイマー割り込み許可、T0IFフラグクリア
		movwf		INTCON

ret_main2
		movf		status_temp,w
		movwf		STATUS
		swapf		w_temp,f
		swapf		w_temp,w
		retfie


;ここからメイン
main
		;内部クロックキャリブレーション
		call		0x3FF		;工場出荷時データ読み込み
		bsf			STATUS,RP0	;Bank=1 
		movwf		OSCCAL		;OSCALに値を設定 
		bcf			STATUS,RP0	;Bank=0

		;ここからメイン処理
		;電源投入&リセット時の初期化処理

		clrf		INTCON		;割り込み禁止

		clrf		GPIO		;GPIO出力を0に
		movlw		0x07		;
		movwf		CMCON		;コンパレータを使用禁止に設定
		bsf			STATUS,RP0	;Bank=1
		clrf		TRISIO		;GPIOを出力に設定
		bsf			TRISIO,5	;GP5だけ入力に設定
		clrf		IOC			;I/O状態変化チェック解除
		movlw		b'10000111'	;プルアップ無し、エッジ割り込み無し、タイマー0は内部クロック
		movwf		OPTION_REG	;プリスケーラー1/256に設定
		bcf			STATUS,RP0	; Bnak=0

		goto		stanby_mode	;電源投入されたら一旦寝る

main_loop
		movlw		TCNT50MS		;タイマー関連の値をセット
		movwf		TMR0
		movlw		TCNT1S
		movwf		TIM1
		movlw		TIME_GO
		movwf		TIM2

		movlw		b'00100000'	;タイマー0割り込みセット
		movwf		INTCON

		call		DLY_250		;レディ音前のディレイ

		movlw		d'100'		;レディ音鳴らす
		movwf		TMP_CNT2
		bsf			LED_P		;音といっしょにLEDも
click1							;起動確認音
		bsf			BEEP_P		;約0.1秒だけ鳴る
		call		DLY_05m
		bcf			BEEP_P
		call		DLY_05m
		decfsz		TMP_CNT2,f
		goto		click1
		bcf			BEEP_P
		bcf			LED_P		;LEDオフ

		bsf			INTCON,GIE	;タイマー割り込み開始

loop1		
		btfss		TIM_F,0		;タイマー割り込みが1秒分あったか？
		goto		loop1		;無ければフラグ待ち
		decfsz		TIM2,f		;目的の時間まで繰り返す
		goto		led_blink	;まだなら動作中LEDを点滅
		bcf			INTCON,GIE	;経過したなら割り込みを禁止して
		goto		time_up		;ブザーを鳴らしに
led_blink						;カウントダウン中LED点滅
		bcf			TIM_F,0		;1秒経過フラグ解除
		bsf			LED_P		;LEDオン
		call		DLY_50		;0.05秒待って
		bcf			LED_P		;LEDオフ
		goto		loop1

time_up
		movlw		TIME_OUT	;ビープのタイムアウトを設定
		movwf		TMP_TMO
beep							;ビープループ 音を断続で鳴りつづけさせる
		bsf			LED_P		;音ともにLEDも点滅
		movlw		d'2'
		movwf		TMP_CNT1
beep1
		movlw		d'250'
		movwf		TMP_CNT2
beep2
		call		sw_check	;スイッチが押されたか
		andlw		0x01
		btfss		STATUS,Z
		goto		stanby_mode	;押されていればスタンバイモードへ
		bsf			BEEP_P		;約0.5秒鳴って
		call		DLY_05m
		bcf			BEEP_P
		call		DLY_05m
		decfsz		TMP_CNT2,f
		goto		beep2
		decfsz		TMP_CNT1,f
		goto		beep1
		bcf			LED_P		;LEDオフ

		call		DLY_250		;約0.5秒休む
		call		DLY_250
		decfsz		TMP_TMO,f	;タイムアウト時間経過してもスイッチ無ければスタンバイ
		goto		beep

;スタンバイモード
;LEDで確認表示した後、寝る
stanby_mode
		bcf			BEEP_P		;BEEP用ポートをLoに
		bsf			LED_P		;LEDをオン
		call		DLY_250		;LEDを1秒点灯
		call		DLY_250
		call		DLY_250
		bcf			LED_P		;LEDをオフ

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

		goto		main_loop	;メインループ実行へ

; メイン処理はここまで


;スイッチ入力チェック
sw_check
		btfsc		PUSH_SW
		goto		sw_no		;押されていなければ0をもって即リターン
		call		DLY_100		;100mS待って
		btfsc		PUSH_SW		;まだ押されているなら1をもってリターン
		goto		sw_no
		goto		sw_yes
sw_no
		retlw		0x00
sw_yes
		retlw		0x01


;時間遅延ルーチン類
DLY_250	; 250mS
		movlw		d'250'
		movwf		CNT1
DLP1	; 1mS
		movlw		d'250'
		movwf		CNT2
DLP2
		nop
		nop
		decfsz		CNT2,f
		goto		DLP2
		decfsz		CNT1,f
		goto		DLP1
		return

DLY_100	; 100mS
		movlw		d'100'
		movwf		CNT1
DLP1_1	; 1mS
		movlw		d'250'
		movwf		CNT2
DLP1_2
		nop
		nop
		decfsz		CNT2,f
		goto		DLP1_2
		decfsz		CNT1,f
		goto		DLP1_1
		return

DLY_50	; 50mS
		movlw		d'50'
		movwf		CNT1
DLP5_1	; 1mS
		movlw		d'250'
		movwf		CNT2
DLP5_2
		nop
		nop
		decfsz		CNT2,f
		goto		DLP5_2
		decfsz		CNT1,f
		goto		DLP5_1
		return

DLY_05m	; ビープ音の周波数生成用
		movlw		d'60'	;これを減らすと高音、増やすと低音
		movwf		CNT2	;ただし鳴動時間に影響する
DLY05_1
		nop
		nop
		nop
		decfsz		CNT2,f
		goto		DLY05_1
		return		


;EEPROM初期化
 
		ORG	0x2100
		DE	0x00, 0x01, 0x02, 0x03


		END
