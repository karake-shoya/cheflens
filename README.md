# cheflens

冷蔵庫の中身を撮影して食材を認識する Flutter アプリのサンプルリポジトリです。

## 主な機能

### 画像取得
- **カメラ撮影**: リアルタイムで冷蔵庫の写真を撮影
- **ギャラリー選択**: 既存の写真から選択

### 画像認識モード
アプリでは以下の4つの認識モードを提供しています：

1. **食材認識** (Label Detection)
   - Google Vision API の Label Detection を使用
   - 画像全体から食材関連のラベルを検出
   - 信頼度フィルタリングと類似食材の統合機能付き

2. **物体検出** (Object Localization)
   - 画像内の物体の位置と種類を検出
   - 信頼度情報を表示

3. **商品認識** (Web Detection)
   - Web上の類似画像や商品情報を活用した認識
   - パッケージ商品などの詳細な識別に適している

4. **高精度認識** (統合モード)
   - Object Detection と Web Detection を組み合わせた高精度な認識
   - 複数の物体を個別にトリミングして認識
   - 検出回数と信頼度を統合した重み付け結果を提供

### 結果表示
- 認識された食材を一覧表示
- 画像プレビューと検出結果を同時に確認可能

## はじめに（セットアップ）

前提:

- Flutter SDK がインストールされていること（`flutter --version` で確認）
- Xcode（iOS 開発を行う場合）や Android Studio（Android）などの開発ツール
- Google Cloud Platform アカウントと Vision API の有効化（後述）

クローン後の基本手順:

```bash
# リポジトリルートで
flutter pub get
```

### 環境変数の設定

Google Vision API を使用するため、`.env` ファイルをプロジェクトルートに作成し、API キーを設定してください。

```bash
# .env ファイルを作成
touch .env
```

`.env` ファイルに以下の内容を追加：

```env
GOOGLE_VISION_API_KEY=your_api_key_here
```

**注意**: `.env` ファイルは `.gitignore` に追加済みです。API キーを誤ってコミットしないよう注意してください。

Google Vision API のキー取得方法:
1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. プロジェクトを作成（または既存のプロジェクトを選択）
3. Vision API を有効化
4. 「認証情報」→「認証情報を作成」→「API キー」を選択
5. 作成された API キーをコピーして `.env` に設定

エミュレータ／シミュレータで実行:

```bash
# 利用可能デバイス一覧を確認
flutter devices

# シミュレータ名や deviceId で実行（例）
flutter run -d "iPhone SE (3rd generation)"
```

実機での実行（iOS）はコード署名（Signing）が必要です。Xcode で Team を設定し、プロビジョニングの準備を行ってください。

## iOS ローカル設定（重要）

このプロジェクトでは、個人の Apple Team ID やプロビジョニング情報を誤ってコミットしないように
ローカル専用の `ios/Local.xcconfig` を使う運用にしています。手順は以下の通りです。

1. テンプレートをコピーしてローカルファイルを作成:

```bash
cp ios/Local.xcconfig.example ios/Local.xcconfig
```

2. `ios/Local.xcconfig` を開き、必要な行のコメント（`//`）を外して自分の値を設定します:

```text
DEVELOPMENT_TEAM = <YOUR_TEAM_ID>
BUNDLE_IDENTIFIER = com.yourname.cheflens
PROVISIONING_PROFILE_SPECIFIER = "Your Provisioning Profile"
```

3. `ios/Local.xcconfig` は `.gitignore` に追加済みです。絶対にコミットしないでください。

4. Xcode を再起動、またはプロジェクトをクリーンして設定を反映します。

補足:

- Xcode 側で署名設定を触ると `ios/Runner.xcodeproj/project.pbxproj` にローカル差分が書かれることがあります。
	コミット前に `git status` を確認し、余計な差分がある場合は `git restore ios/Runner.xcodeproj/project.pbxproj` で戻してください。

## よくあるトラブルと対処

- iOS シミュレータでアプリを起動できない（ランタイムが足りない）:
	- Xcode → Settings → Components で必要なシミュレータランタイムをインストール

- 実機にインストールしたがアプリが起動しない／すぐ落ちる:
	- `Info.plist` にカメラや写真ライブラリの使用説明（`NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription`）が必要です
	- 署名エラーが出る場合は Xcode の Signing & Capabilities で Team を設定し、自動プロビジョニングを試してください

- カメラ機能のテストについて:
	- シミュレータは実機のカメラ入力を提供しないため、`xcrun simctl addmedia booted /path/to/photo.jpg` で画像を追加してギャラリーベースで動作確認してください

## プロジェクト構成

```
lib/
├── data/
│   └── food_data.json          # 食材データ（翻訳、フィルタリング設定など）
├── models/
│   ├── detected_object.dart    # 検出された物体のモデル
│   └── food_data_model.dart    # 食材データのモデル
├── screens/
│   ├── camera_screen.dart      # メイン画面（カメラ・画像選択・認識）
│   └── result_screen.dart      # 結果表示画面
└── services/
    ├── vision_service.dart          # 画像認識サービスのメインクラス
    ├── vision_api_client.dart       # Google Vision API との通信
    ├── ingredient_filter.dart       # 食材フィルタリングロジック
    ├── ingredient_translator.dart   # 英語→日本語翻訳
    ├── image_processor.dart         # 画像処理（トリミングなど）
    └── food_data_service.dart       # 食材データの読み込み
```

## 貢献と開発者向けヒント

- `ios/Local.xcconfig.example` をリポジトリで共有しています。クローンしたら必ずコピーして自分の `ios/Local.xcconfig` を作ってください。
- 食材データは `lib/data/food_data.json` で管理されています。新しい食材の追加やフィルタリングルールの調整はこのファイルを編集してください。