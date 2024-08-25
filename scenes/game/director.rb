require_relative 'card/base'
require_relative 'card/spade'
require_relative 'card/diamond'
require_relative 'card/heart'
require_relative 'card/club'

module Scenes
  module Game
    # ゲーム本編シーンの担当ディレクタークラス
    class Director < DirectorBase
      SUIT_AMOUNT = 13                  # 各マーク毎のカード枚数
      CORRECTED_MESSAGE = "当たり！！"    # 開いた2枚のカードの番号が一致した場合（当たり）の表示メッセージ
      INCORRECTED_MESSAGE = "ハズレ！！"  # 開いた2枚のカードの番号が一致しなかった場合（ハズレ）の表示メッセージ
      CORRECTED_SCORE = 10              # 当たりの際に追加される点数
      INCORRECTED_SCORE = 1             # ハズレの際に引かれる点数
      GAME_CLEAR_SCORE = 10             # ゲームクリアに必要な点数（サンプルのため、1回分の当たり点数と同じにしている）
      MESSAGE_DISPLAY_FRAMES = 60       # 当たり／ハズレのメッセージを画面上に表示しておくフレーム数（60フレーム＝2秒）
      JUDGEMENT_MESSAGE_Y_POS = 250     # 当たり／ハズレのメッセージを表示するY座標
      TIMELIMIT_BAR_Z_INDEX = 3500      # 当たり／ハズレのメッセージを表示するZ座標（奥行）
      TIMELIMIT_SEC = 60                # タイムリミットバーの最大秒数
      TIMELIMIT_BAR_MARGIN = 5          # タイムリミットバーの表示上の余白サイズ（ピクセル）
      FPS = 30                          # 1秒間の表示フレーム数

      # コンストラクタ
      def initialize
        super
        # 画像オブジェクトの読み込み
        @bg_img = Gosu::Image.new("images/bg_game.png", tileable: true)
        @timelimit_bar = Gosu::Image.new("images/timelimit_bar.png", tileable: true)
        @bgm = load_bgm("bgm2.mp3", 0.1)

        # 各種インスタンス変数の初期化
        @cards = []                                            # 全てのカードを保持する配列
        @opened_cards = []                                     # オープンになっているカードを保持する配列
        @message_display_frame_count = 0                       # メッセージ表示フレーム数のカウンタ変数
        @judgement_result = false                              # 当たり／ハズレの判定結果（true: 当たり）
        @score = 0                                             # 総得点
        @cleared = false                                       # ゲームクリアが成立したか否かを保持するフラグ
        @timelimit_scale = 1.0                                 # タイムリミットバー画像の初期長さ（割合で減衰を表現する）
        @timelimit_decrease_unit = 1.0 / TIMELIMIT_SEC / FPS   # タイムリミットバーの減衰単位
        @drag_start_pos = nil                                  # マウスドラッグ用フラグ兼ドラッグ開始位置記憶用変数
        @offset_mx = 0                                         # マウスドラッグ中のカーソル座標補正用変数（X成分用）
        @offset_my = 0                                         # マウスドラッグ中のカーソル座標補正用変数（Y成分用）

        # 4種のカードについて、それぞれ13枚ずつランダムな座標にカードをばら撒く
        # NOTE: 各カードのZ値は、生成順に1から順にインクリメントして重ね合わせを表現する
        z = 1
        [
          Card::Spade,
          Card::Diamond,
          Card::Heart,
          Card::Club
        ].each do |klass|
          1.upto(SUIT_AMOUNT) do |num|
            x = rand(MainWindow::WIDTH - Card::Base::WIDTH)
            y = rand(MainWindow::HEIGHT - Card::Base::HEIGHT - @timelimit_bar.height - TIMELIMIT_BAR_MARGIN)
            @cards << klass.new(num, x, y, z)
            z += 1
          end
        end
      end

      # 1フレーム分の更新処理
      def update(opt = {})
        # BGMをスタートする（未スタート時のみ）
        @bgm.play if @bgm && !@bgm.playing?

        # マウスの現在座標を変数化しておく
        mx = opt.has_key?(:mx) ? opt[:mx] : 0
        my = opt.has_key?(:my) ? opt[:my] : 0

        # ゲームクリアフラグが立ち、且つ画面への判定結果表示が完了済みの場合、エンディングシーンへ切り替えを行う
        if @cleared && @message_display_frame_count == 0
          @bgm.stop if @bgm && @bgm.playing?
          transition(:ending)
        end

        # タイムラインバーの長さが0になったらゲームオーバーとする
        if @timelimit_scale <= 0
          @bgm.stop if @bgm && @bgm.playing?
          transition(:game_over)
        end

        # メッセージ表示中とそれ以外で処理を分岐
        if @message_display_frame_count > 0
          # メッセージ表示中の場合
          # メッセージ表示フレーム数をデクリメントし、残り1フレーム分まで来たら開いているカードに関する後処理を行う
          # NOTE: このように実装することで、メッセージ表示中はマウスクリック等が反応しないようにしている
          @message_display_frame_count -= 1
          cleaning_up if @message_display_frame_count == 1
        else
          # メッセージ非表示の場合
          # マウスクリック及び合致判定を実施する
          check_mouse_operations(mx, my)
          judgement
        end

        # タイムリミットバーの長さを更新
        # NOTE: メッセージ表示中か否かによらず、毎フレーム一定の減衰を行うため、条件分岐の外に定義する
        @timelimit_scale -= @timelimit_decrease_unit if @timelimit_scale > 0
      end

      # 1フレーム分の描画処理
      def draw
        # 背景画像を表示
        @bg_img.draw(0, 0, 0)

        # 全カードを表示
        # NOTE: 重なり合わせを適正に表現するため、各カードの最新Z値でソートして表示する（マウスクリックでカードのZ値が変化するため）
        @cards.sort_by{|c| c.z }.each do |card|
          card.draw
        end

        # メッセージ表示フレーム数が2以上の場合はメッセージを表示する
        if @message_display_frame_count > 1
          draw_text(@message_body, :center, JUDGEMENT_MESSAGE_Y_POS, font: :judgement_result, color: @message_color)
        end

        # スコアを表示
        draw_text("SCORE: #{@score}", :right, 5, font: :score, color: :white)

        # タイムリミットバーを表示
        @timelimit_bar.draw(0, MainWindow::HEIGHT - @timelimit_bar.height, TIMELIMIT_BAR_Z_INDEX, @timelimit_scale)
      end

      private

      # 2枚のカードがオープンされた状況における当たり／ハズレ判定処理
      def judgement
        return if @opened_cards.size != 2 # 開かれているカードが2枚でなければ何もしない

        # 開かれた2枚のカードの合致判定
        if @opened_cards.first.num == @opened_cards.last.num
          # 合致していた場合
          @judgement_result = true
          @score += CORRECTED_SCORE
          @message_body = CORRECTED_MESSAGE
          @message_color = :blue

          # 加算後のスコアが条件を満たす場合、ゲームクリアフラグを立てる
          if @score >= GAME_CLEAR_SCORE
            @cleared = true
          end
        else
          # 合致していなかった場合
          @judgement_result = false
          @score -= INCORRECTED_SCORE
          @message_body = INCORRECTED_MESSAGE
          @message_color = :red
        end

        # 当たっても外れても、いずれにしてもメッセージは表示するので、メッセージ表示フレーム数を設定する
        @message_display_frame_count = MESSAGE_DISPLAY_FRAMES
      end

      # マウスによる操作判定
      def check_mouse_operations(mx, my)
        if Gosu.button_down?(Gosu::MsLeft)
          # マウスの左ボタンがクリックされている場合
          unless @drag_start_pos
            # マウスドラッグが開始されていない場合、現在のマウス座標からドラッグを開始する
            start_drag(mx, my)
            @drag_start_pos = [mx, my]
          else
            # マウス左クリック＆ドラッグ開始済みであるため、ドラッグ中と判定し処理を実施する
            dragging(mx, my)
          end
        else
          # マウスの左ボタンが解放されている場合
          # ドラッグ中であれば、ドロップ処理を実施し、ドラッグ中フラグを下ろす
          dropped if @drag_start_pos
          @drag_start_pos = nil
        end
      end

      # 新規ドラッグ開始時の処理
      # マウスカーソル座標上に存在する最もZ値の高いカードをオープンし、掴んだ状態にする
      def start_drag(mx, my)
        # 判定対象となるカードを一時的にまとめるための配列を初期化
        clicked_cards = []

        # 全カードに対して、現在のマウス座標が自身の表示エリアに被っているか判定させ、被っているカードを配列に納めていく
        @cards.each do |card|
          clicked_cards << card if card.clicked?(mx, my)
        end

        # マウスカーソルの座標上に1枚以上カードが存在する場合
        if clicked_cards.size > 0
          # マウス座標と被っているカードが1個以上ある場合、そのZ座標（重なり具合）でソートし、最も上にあるカードのみをオープンする
          @opened_card = clicked_cards.sort_by{|c| c.z }.last
          @opened_card.open

          # クリックされたカードのZ値を、全てのカードに対して最大化する（一番上に重なるようにする）
          @opened_card.z = @cards.max_by{|c| c.z }.z + 1

          # マウス座標とクリックされたカードの左上座標の差分をドラッグ時のオフセット値として保存する。
          @offset_mx = mx - @opened_card.x
          @offset_my = my - @opened_card.y
        end
      end

      # ドラッグ中に発生する処理
      def dragging(mx, my)
        # 現在開いているカードが無い場合は何もしない（移動するべき対象物が無いため）
        return unless @opened_card

        # 現フレームにおけるマウス座標がドラッグ開始位置と同一の場合は何もしない
        return if @drag_start_pos == [mx, my]

        # 上記いずれにも該当しない場合、対象カードの座標を移動する
        # NOTE: その際、ドラッグ開始時点で保存したオフセット値を引くことで、マウス座標が不自然に移動することを防止する
        @opened_card.x = mx - @offset_mx
        @opened_card.y = my - @offset_my
      end

      # ドラッグに対するドロップ処理
      def dropped
        # オープン済みカードが無ければ何もしない
        return unless @opened_card

        # オープンされたカードが既にオープン済みでなければ、オープン済みカードリストに追加する
        @opened_cards << @opened_card unless @opened_cards.include?(@opened_card)
        @opened_card = nil
      end

      # 開いたカードの後始末を行う
      def cleaning_up
        # 判定結果に沿って開いたカードの状態を変化させる
        # * 一致した場合： 開いたカードを消去
        # * 一致しなかった場合： 開いたカードを閉じるのみ
        @opened_cards.each do |c|
          c.reverse
          @cards.delete(c) if @judgement_result
        end

        # 開いたカードリストをクリア
        @opened_cards.clear
      end
    end
  end
end
