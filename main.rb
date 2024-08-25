require 'gosu'

require_relative 'scenes/manager'
require_relative 'scenes/director_base'
require_relative 'scenes/title/director'
require_relative 'scenes/game/director'
require_relative 'scenes/ending/director'
require_relative 'scenes/game_over/director'

# ゲームのメインウィンドウ（メインループ）用クラス
class MainWindow < Gosu::Window
  # 各種定数定義
  WIDTH = 800
  HEIGHT = 600
  FULL_SCREEN = false

  # コンストラクタ
  def initialize
    super WIDTH, HEIGHT, FULL_SCREEN
    self.caption = 'RubyCamp2024Summer Example'

    @scene_manager = Scenes::Manager.instance
    @scene_manager.add(:title, Scenes::Title::Director.new)
    @scene_manager.add(:game, Scenes::Game::Director.new)
    @scene_manager.add(:ending, Scenes::Ending::Director.new)
    @scene_manager.add(:game_over, Scenes::GameOver::Director.new)
    @scene_manager.set(:title)
  end

  # 1フレーム分の更新処理
  def update
    exit if Gosu.button_down?(Gosu::KB_ESCAPE)
    opt = {
      mx: self.mouse_x,
      my: self.mouse_y
    }
    @scene_manager.update(opt)
  end

  # 1フレーム分の描画処理
  def draw
    @scene_manager.draw
  end
end

# ゲーム開始
window = MainWindow.new
window.show
