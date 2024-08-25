module Scenes
  # ディレクタークラスの共通部分
  class DirectorBase
    FONT_FILENAME = "DelaGothicOne-Regular.ttf" # 画面描画用フォントファイル名
    RIGHT_MARGIN = 10 # 文字列描画における右端寄せ指定の際の右側余白ピクセル数

    @@key_state = {} # キーの押下判定（押しっ放しではなく、1回押して離すまでを1回と捉える判定）用キャッシュ

    # コンストラクタ
    def initialize
      @fonts = {
        base: Gosu::Font.new(32, name: FONT_FILENAME),
        title: Gosu::Font.new(48, name: FONT_FILENAME),
        score: Gosu::Font.new(64, name: FONT_FILENAME),
        judgement_result: Gosu::Font.new(128, name: FONT_FILENAME),
      }

      @colors = {
        black: 0xff_000000,
        white: 0xff_ffffff,
        red: 0xff_ff0000,
        green: 0xff_00ff00,
        blue: 0xff_0000ff,
      }
    end

    # 1フレーム分の更新処理
    def update(opt = {})
      raise "override me"
    end

    # 1フレーム分の描画処理
    def draw
      raise "override me"
    end

    private

    # BGMファイルを読み込みオブジェクト化して返す
    # NOTE: ファイルが存在しない場合はnilを返す
    def load_bgm(filename, volume)
      bgm = nil
      bgm = Gosu::Song.new(filename) if File.exist?(filename)
      bgm.volume = volume if File.exist?(filename)
      bgm
    end

    # キーの押下判定
    # ※ 単純に「Gosu.button_down?」だけで判定すると毎フレームで押しっ放し判定になってしまうため、「押して離す」を1セットとした押下判定を行うためのメソッド
    def key_push?(key_label)
      if !@@key_state[key_label] && Gosu.button_down?(key_label)
        @@key_state[key_label] = true
        return true
      end

      if @@key_state[key_label] && !Gosu.button_down?(key_label)
        @@key_state[key_label] = false
      end

      return false
    end

    # シーン切り替えの実行
    def transition(label)
      Scenes::Manager.instance.set(label.to_sym)
    end

    # 文字列描画におけるX座標の変換処理
    # 「:left」（左寄せ）「:center」（中央寄せ）「:right」（右寄せ）それぞれの座標を計算する
    def convert_x_pos(x, text, font)
      case x
      when :left
        return 0
      when :center
        return MainWindow::WIDTH / 2 - (font.text_width(text) / 2)
      when :right
        return MainWindow::WIDTH - font.text_width(text) - RIGHT_MARGIN
      end
    end

    # 画面への文字列描画をラップする
    def draw_text(text, x, y, opt = {})
      font = @fonts[:base]
      if opt.has_key?(:font)
        font = @fonts[opt[:font].to_sym]
      end

      pos_x = 0
      if x.is_a?(Symbol)
        pos_x = convert_x_pos(x, text, font)
      else
        pos_x = x
      end

      z = 300
      if opt.has_key?(:z)
        z = opt[:z].to_i
      end

      scale_x = 1
      if opt.has_key?(:scale_x)
        scale_y = opt[:scale_x].to_f
      end

      scale_y = 1
      if opt.has_key?(:scale_y)
        scale_y = opt[:scale_y].to_f
      end

      color = @colors[:black]
      if opt.has_key?(:color)
        if(opt[:color].is_a?(Symbol))
          color = @colors[opt[:color]]
        else
          color = opt[:color]
        end
      end

      font.draw_text(text, pos_x, y, z, scale_x, scale_y, color)
    end
  end
end