pic_led_helloworld
==================
- ラーメンタイマー
 書籍「やさしい PIC マイコン プログラミング＆電子工作 第二版」を参考にした

- 3,4,5 分のタイマー

- FRISK ケースに収める


仕様
----
- micon  : PIC12F683
- output : LED x 3
- output : 圧電スピーカ
- input  : push sw x2
- power  : CR2032

操作方法
--------
- 左スイッチで 3,4,5 分を選択
-- 3分はLED 1つ点灯
-- 4分はLED 2つ点灯
-- 5分はLED 3つ点灯

- 右スイッチでスタート
- 選択した時間経過後、チャルメラの音楽を流す
- 音楽流した後はスリープ

- 選択中、１分放置でスリープに移行
- カウントダウン中、ボタン同時長押しでスリープに移行


回路図
------
![回路図] (master/rtimer_circuit_diagram.png)



動作ムービー
------------




他
--
- PIC12F683 はやっぱり工場出荷のロード 0x3ff があると動かない





他PICセットアップ手順など
=========================


pickit2 との接続方法
--------------------
![回路図] (http://www006.upp.so-net.ne.jp/picbegin/proj1/pic_zu802.gif)

pickit2 での書き込み方法
------------------------
$ pk2cmd -PPIC12F683 -M -F dist/default/production/ramen_timer.X.production.hex


pickit2 で電源供給方法
----------------------
$ pk2cmd -PPIC12F683 -T         # 5V 供給
$ pk2cmd -PPIC12F683 -T -A 3.3  # 3.3V 供給
$ pk2cmd -PPIC12F683 -W         # pickit2 からの電源供給停止
