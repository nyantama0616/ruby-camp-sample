require 'singleton'

module Scenes
  # シーン（場面）制御用クラス
  class Manager
    include Singleton # 個々のシーン毎のディレクターオブジェクトからも使用するためシングルトン構造を導入する

    # コンストラクタ
    def initialize
      @scenes = {}   # 個別シーンの進行を担当するディレクターオブジェクトをラベルと共に保持するハッシュ
      @current = nil # ある1フレームにおけるアクティブなディレクターオブジェクト（のラベル）を指す
    end

    # 管理下に置くディレクターオブジェクトの追加
    def add(label, director)
      raise "ディレクターオブジェクト（DirectorBaseを継承したクラスのインスタンス）のみ追加可能です" unless director.is_a?(DirectorBase)
      @scenes[label.to_sym] = director
    end

    # カレントシーンの切り替え
    def set(label)
      @current = label.to_sym
    end

    # ある1フレームの場面更新処理の呼び出し
    def update(opt = {})
      validate_current
      @scenes[@current].update(opt)
    end

    # ある1フレームの場面描画処理の呼び出し
    def draw
      validate_current
      @scenes[@current].draw
    end

    private

    # カレントシーンのラベルとそれに対応するディレクターオブジェクトが実在するかどうかの判定
    def validate_current
      raise "setメソッドを実行してカレントシーンを設定してください" unless @current
      raise "'#{@current}'というラベルを持つシーンは登録されていません" unless @scenes.has_key?(@current)
    end
  end
end
